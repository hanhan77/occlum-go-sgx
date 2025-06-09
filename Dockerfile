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

# Make scripts executable and build OpenSSL with musl
RUN chmod +x down_openssl.sh && \
    ./down_openssl.sh

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
    echo "=== Checking SGX libraries ===" && \
    ls -l /opt/intel/sgxsdk/lib64/libsgx_* && \
    echo "=== Checking libsgx_urts.a symbols ===" && \
    nm -D /opt/intel/sgxsdk/lib64/libsgx_urts.so | grep -i puts && \
    echo "=== Checking libsgx_urts.a relocations ===" && \
    readelf -r /opt/intel/sgxsdk/lib64/libsgx_urts.so | grep -i puts && \
    echo "=== Checking libsgx_urts.a dynamic symbols ===" && \
    readelf -d /opt/intel/sgxsdk/lib64/libsgx_urts.so | grep -i "NEEDED" && \
    occlum-gcc -shared -o libseal.so seal_u.o \
        -L/opt/intel/sgxsdk/lib64 \
        -Wl,-Bstatic \
        -lsgx_urts \
        -Wl,-Bdynamic \
        -Wl,-rpath,/opt/intel/sgxsdk/lib64 \
        -Wl,-rpath,/usr/local/occlum/x86_64-linux-musl/lib \
        -static-libstdc++ \
        -static-libgcc && \
    ar rcs libseal.a seal.o seal_t.o

# Go module
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
ENV CGO_LDFLAGS="-L/root/occlum-go-seal/enclave -lseal -L/opt/intel/sgxsdk/lib64 -Wl,-Bstatic -lsgx_urts -Wl,-Bdynamic -L/usr/local/occlum/x86_64-linux-musl/lib -Wl,-rpath,/usr/local/occlum/x86_64-linux-musl/lib -static-libstdc++ -static-libgcc"

# Debug info
RUN cd /root/occlum-go-seal && \
    echo "=== Environment variables ===" && env | grep -E 'GO|CGO' && \
    echo "=== Compiler version ===" && occlum-gcc --version && \
    echo "=== Current directory contents ===" && ls -la && \
    echo "=== Enclave directory contents ===" && ls -la enclave/

# Build Go application using occlum-go
RUN cd /root/occlum-go-seal && \
    echo "=== Building Go application ===" && \
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 \
    occlum-go build -v -x -a -installsuffix cgo -buildmode=pie \
    -ldflags="-linkmode=external -extldflags=-L/root/occlum-go-seal/enclave -lseal -L/opt/intel/sgxsdk/lib64 -Wl,-Bstatic -lsgx_urts -Wl,-Bdynamic -static-libstdc++ -static-libgcc -lc -lm -lrt -lpthread -ldl" \
    -o app main.go

# Set up Occlum filesystem
RUN mkdir -p occlum_instance/image/bin && \
    mkdir -p occlum_instance/image/lib && \
    cp app occlum_instance/image/bin/ && \
    cp enclave/libseal.so enclave/libseal.a occlum_instance/image/lib/ && \
    cp /usr/local/occlum/x86_64-linux-musl/lib/libc.so occlum_instance/image/lib/

# Initialize and build Occlum image
RUN cd occlum_instance && \
    occlum init && \
    occlum build

# Set entrypoint
WORKDIR /root/occlum-go-seal/occlum_instance

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
