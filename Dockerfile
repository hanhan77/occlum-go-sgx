FROM occlum/occlum:0.31.0-ubuntu20.04 as builder

# Remove Intel SGX repository configuration
RUN rm -f /etc/apt/sources.list.d/intel-sgxsdk.list
ENV GO111MODULE=on

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    git \
    wget \
    libssl-dev \
    pkg-config

# Set up workspace
WORKDIR /root/occlum-go-seal
COPY . .

# Build OpenSSL with musl
RUN git clone -b OpenSSL_1_1_1 --depth 1 http://github.com/openssl/openssl && \
    cd openssl && \
    CC=occlum-gcc ./config \
        --prefix=/usr/local/occlum/x86_64-linux-musl \
        --openssldir=/usr/local/occlum/x86_64-linux-musl/ssl \
        --with-rand-seed=rdcpu \
        no-async no-zlib && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf openssl && \
    echo "=== OpenSSL installation completed ===" && \
    echo "=== Checking OpenSSL installation ===" && \
    ls -l /usr/local/occlum/x86_64-linux-musl/include/openssl && \
    ls -l /usr/local/occlum/x86_64-linux-musl/lib/libssl* && \
    echo "=== Checking musl libc paths ===" && \
    ls -l /usr/local/occlum/x86_64-linux-musl/lib/libc* && \
    echo "=== Checking SGX SDK paths ===" && \
    ls -l /opt/intel/sgxsdk/lib64/libsgx*

# Create symbolic link for AESM library
RUN mkdir -p /usr/lib && \
    ln -s /opt/intel/sgx-aesm-service/aesm/libCppMicroServices.so.4.0.0 /usr/lib/libCppMicroServices.so.4

# Build the enclave with musl
RUN cd enclave && \
    /opt/intel/sgxsdk/bin/x64/sgx_edger8r --trusted seal.edl --search-path /opt/intel/sgxsdk/include && \
    /opt/intel/sgxsdk/bin/x64/sgx_edger8r --untrusted seal.edl --search-path /opt/intel/sgxsdk/include && \
    occlum-gcc -fPIC -c seal.cpp -o seal.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/libcxx \
        -I/opt/intel/sgxsdk/include/stdc++ \
        -I/opt/intel/sgxsdk/include/linux && \
    occlum-gcc -fPIC -c seal_t.c -o seal_t.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/linux && \
    occlum-gcc -fPIC -c seal_u.c -o seal_u.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/linux && \
    occlum-gcc -shared -o libseal.so seal_u.o \
        -L/opt/intel/sgxsdk/lib64 \
        -Wl,--whole-archive -lsgx_urts -Wl,--no-whole-archive \
        -Wl,--whole-archive -lsgx_uae_service -Wl,--no-whole-archive \
        -Wl,-rpath,/opt/intel/sgxsdk/lib64 \
        -Wl,-rpath,/usr/local/occlum/x86_64-linux-musl/lib \
        -static-libstdc++ \
        -static-libgcc && \
    ar rcs libseal.a seal.o seal_t.o && \
    echo "=== Enclave build completed ===" && \
    echo "=== Checking enclave libraries ===" && \
    ls -l libseal* && \
    echo "=== Checking enclave symbols ===" && \
    nm -D libseal.so | grep -i sgx

WORKDIR /root/occlum-go-seal
RUN occlum-go mod tidy

# Set up environment for occlum-go build
ENV CGO_ENABLED=1
ENV GOARCH=amd64
ENV GOOS=linux
ENV GOFLAGS="-buildmode=pie"
ENV CC=/usr/local/occlum/bin/occlum-gcc
ENV CXX=/usr/local/occlum/bin/occlum-g++
ENV CGO_CFLAGS="-I/root/occlum-go-seal/enclave -I/opt/intel/sgxsdk/include -I/usr/local/occlum/x86_64-linux-musl/include -Wno-error=parentheses"
ENV CGO_LDFLAGS="-L/root/occlum-go-seal/enclave -lseal -L/opt/intel/sgxsdk/lib64 -Wl,--whole-archive -lsgx_urts -Wl,--no-whole-archive -Wl,--whole-archive -lsgx_uae_service -Wl,--no-whole-archive -L/usr/local/occlum/x86_64-linux-musl/lib -Wl,-rpath,/usr/local/occlum/x86_64-linux-musl/lib -static-libstdc++ -static-libgcc -nostdlib -lc -Wl,-e,_start"

# Build Go application using occlum-go
RUN occlum-go build -a -installsuffix cgo -o app main.go && \
    echo "=== Go build completed ===" && \
    echo "=== Checking Go binary ===" && \
    file app && \
    ldd app || true

# Set up Occlum
RUN mkdir -p occlum_instance/image/bin && \
    mkdir -p occlum_instance/image/lib && \
    cp app occlum_instance/image/bin/ && \
    cp enclave/libseal.so occlum_instance/image/lib/ && \
    cp enclave/libseal.a occlum_instance/image/lib/ && \
    cp /opt/intel/sgxsdk/lib64/libsgx_urts.so.2 occlum_instance/image/lib/ && \
    cp /usr/local/occlum/x86_64-linux-musl/lib/libc.so occlum_instance/image/lib/ && \
    echo "=== Checking Occlum image contents ===" && \
    ls -lR occlum_instance/image/

# Initialize and build Occlum image
RUN cd occlum_instance && \
    occlum init && \
    occlum build && \
    echo "=== Occlum build completed ===" && \
    echo "=== Checking Occlum instance ===" && \
    ls -lR

# Set the entry point
WORKDIR /root/occlum-go-seal/occlum_instance

# Create startup script
RUN printf '#!/bin/bash\n\
set -e\n\
echo "Checking CPU features..."\n\
cat /proc/cpuinfo | grep fsgsbase\n\
echo "Starting AESM service..."\n\
export LD_LIBRARY_PATH=/opt/intel/sgx-aesm-service/aesm:/usr/lib:/opt/intel/sgxsdk/lib64:/usr/local/occlum/x86_64-linux-musl/lib:$LD_LIBRARY_PATH\n\
/opt/intel/sgx-aesm-service/aesm/aesm_service &\n\
sleep 2\n\
echo "Running application..."\n\
cd /root/occlum-go-seal/occlum_instance\n\
exec occlum run /bin/app\n' > /start.sh && \
    chmod +x /start.sh

ENTRYPOINT ["/bin/bash", "/start.sh"] 