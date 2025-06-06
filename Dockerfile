FROM occlum/occlum:0.29.3-ubuntu20.04

# Remove Intel SGX repository configuration
RUN rm -f /etc/apt/sources.list.d/intel-sgx.list

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

# Build the enclave
RUN cd enclave && \
    /opt/intel/sgxsdk/bin/x64/sgx_edger8r --trusted seal.edl --search-path /opt/intel/sgxsdk/include && \
    /opt/intel/sgxsdk/bin/x64/sgx_edger8r --untrusted seal.edl --search-path /opt/intel/sgxsdk/include && \
    g++ -fPIC -c seal.cpp -o seal.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/libcxx \
        -I/opt/intel/sgxsdk/include/stdc++ \
        -I/opt/intel/sgxsdk/include/linux && \
    g++ -fPIC -c seal_t.c -o seal_t.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/linux && \
    g++ -fPIC -c seal_u.c -o seal_u.o \
        -I/opt/intel/sgxsdk/include \
        -I/opt/intel/sgxsdk/include/tlibc \
        -I/opt/intel/sgxsdk/include/linux && \
    g++ -shared -o libseal.so seal_u.o -L/opt/intel/sgxsdk/lib64 -lsgx_urts -lsgx_uae_service && \
    ar rcs libseal.a seal.o seal_t.o

# Build the Go application
RUN go mod tidy && \
    CGO_CFLAGS="-I/root/occlum-go-seal/enclave -I/opt/intel/sgxsdk/include" \
    CGO_LDFLAGS="-L/root/occlum-go-seal/enclave -lseal -L/opt/intel/sgxsdk/lib64 -lsgx_urts -lsgx_uae_service" \
    go build -o app

# Set up Occlum
RUN mkdir -p occlum_instance/image/bin && \
    mkdir -p occlum_instance/image/lib && \
    cp app occlum_instance/image/bin/ && \
    cp enclave/libseal.so occlum_instance/image/lib/ && \
    cp enclave/libseal.a occlum_instance/image/lib/

# Initialize and build Occlum image
RUN cd occlum_instance && \
    occlum init && \
    occlum build --debug

# Set the entry point
WORKDIR /root/occlum-go-seal/occlum_instance

# Create startup script
RUN printf '#!/bin/bash\n\
set -e\n\
export OCCLUM_DISABLE_FSGSBASE=1\n\
export OCCLUM_DISABLE_KSS=1\n\
export OCCLUM_DISABLE_HW_CHECK=1\n\
export OCCLUM_DEBUG=1\n\
cd /root/occlum-go-seal/occlum_instance\n\
exec occlum run --debug /bin/app\n' > /start.sh && \
    chmod +x /start.sh

ENTRYPOINT ["/bin/bash", "/start.sh"] 