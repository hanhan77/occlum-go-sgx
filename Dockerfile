FROM occlum/occlum:0.29.3-ubuntu20.04

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

# Install Go
RUN wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz && \
    rm go1.20.5.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Set up workspace
WORKDIR /root/occlum-go-seal
COPY . .

# Set up SGX SDK environment
ENV SGX_SDK=/opt/intel/sgxsdk
ENV PATH=$PATH:$SGX_SDK/bin:$SGX_SDK/bin/x64
ENV PKG_CONFIG_PATH=$SGX_SDK/pkgconfig
ENV LD_LIBRARY_PATH=$SGX_SDK/sdk_libs

# Build the enclave
RUN cd enclave && \
    $SGX_SDK/bin/x64/sgx_edger8r --trusted seal.edl --search-path $SGX_SDK/include && \
    g++ -fPIC -c seal.cpp -o seal.o \
        -I$SGX_SDK/include \
        -I$SGX_SDK/include/tlibc \
        -I$SGX_SDK/include/libcxx \
        -I$SGX_SDK/include/stdc++ && \
    g++ -fPIC -c seal_t.c -o seal_t.o \
        -I$SGX_SDK/include \
        -I$SGX_SDK/include/tlibc && \
    g++ -shared -o libseal.so seal.o seal_t.o \
        -L$SGX_SDK/lib64 \
        -Wl,--whole-archive \
        -lsgx_trts \
        -lsgx_tcrypto \
        -lsgx_tprotected_fs \
        -lsgx_tstdc \
        -lsgx_tservice \
        -Wl,--no-whole-archive \
        -Wl,--start-group \
        -lsgx_tservice \
        -lsgx_tstdc \
        -lsgx_tcxx \
        -lsgx_tcrypto \
        -lsgx_trts \
        -lsgx_tprotected_fs \
        -lsgx_tkey_exchange \
        -Wl,--end-group \
        -lm \
        -ldl \
        -pthread

# Build the Go application
RUN go mod init occlum-go-seal && \
    go mod tidy && \
    CGO_CFLAGS="-I/root/occlum-go-seal/enclave -I$SGX_SDK/include" \
    CGO_LDFLAGS="-L/root/occlum-go-seal/enclave -lseal" \
    go build -o app

# Set up Occlum
RUN mkdir -p occlum_instance/image/bin && \
    mkdir -p occlum_instance/image/lib && \
    cp app occlum_instance/image/bin/ && \
    cp enclave/libseal.so occlum_instance/image/lib/

# Build Occlum image
RUN cd occlum_instance && \
    occlum build

# Set the entry point
ENTRYPOINT ["occlum", "run", "/bin/app"] 