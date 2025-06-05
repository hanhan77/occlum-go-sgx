FROM occlum/occlum:0.29.3-ubuntu20.04

# Install Go
RUN apt-get update && apt-get install -y wget git gcc libc6-dev
RUN wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz && \
    rm go1.20.5.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Install Intel SGX SDK
RUN apt-get install -y build-essential python3
RUN wget https://download.01.org/intel-sgx/sgx-linux/2.16/distro/ubuntu20.04-server/sgx_linux_x64_sdk_2.16.100.4.bin && \
    chmod +x sgx_linux_x64_sdk_2.16.100.4.bin && \
    echo -e 'no\n/opt/intel' | ./sgx_linux_x64_sdk_2.16.100.4.bin && \
    rm sgx_linux_x64_sdk_2.16.100.4.bin
ENV SGX_SDK=/opt/intel/sgxsdk
ENV PATH=$PATH:$SGX_SDK/bin:$SGX_SDK/bin/x64
ENV PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$SGX_SDK/pkgconfig
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SGX_SDK/sdk_libs

# Set up workspace
WORKDIR /root/occlum-go-seal
COPY . .

# Build the enclave
RUN cd enclave && \
    $SGX_SDK/bin/x64/sgx_edger8r --trusted seal.edl && \
    g++ -c seal.cpp -o seal.o -I$SGX_SDK/include && \
    g++ -c seal_t.c -o seal_t.o -I$SGX_SDK/include && \
    g++ -shared -o libseal.so seal.o seal_t.o -L$SGX_SDK/sdk_libs -lsgx_trts -lsgx_tcrypto

# Build the Go application
RUN go mod init occlum-go-seal && \
    go mod tidy && \
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