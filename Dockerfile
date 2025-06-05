FROM occlum/occlum:0.29.3-ubuntu20.04

# Install Go
RUN apt-get update && apt-get install -y wget git gcc libc6-dev
RUN wget https://go.dev/dl/go1.20.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz && \
    rm go1.20.5.linux-amd64.tar.gz
ENV PATH=$PATH:/usr/local/go/bin

# Set up workspace
WORKDIR /root/occlum-go-seal
COPY . .

# Build the enclave
RUN cd enclave && \
    g++ -c seal.cpp -o seal.o -I/opt/intel/sgxsdk/include && \
    g++ -c seal_t.c -o seal_t.o -I/opt/intel/sgxsdk/include && \
    g++ -shared -o libseal.so seal.o seal_t.o -L/opt/intel/sgxsdk/sdk_libs -lsgx_trts -lsgx_tcrypto

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