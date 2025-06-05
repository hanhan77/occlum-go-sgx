# Occlum Go SGX Sealing Example

This project demonstrates how to use Intel SGX sealing functionality with Go and Occlum. It provides a simple example of sealing (encrypting) and unsealing (decrypting) data within an SGX enclave.

## Prerequisites

- Intel SGX-enabled hardware
- Ubuntu 20.04 or later
- Docker
- Intel SGX driver and PSW installed on the host system

## Project Structure

```
occlum-go-seal/
├── Dockerfile              # Docker build file
├── go.mod                 # Go module file
├── main.go               # Main Go application
├── enclave/              # SGX enclave code
│   ├── seal.edl          # Enclave definition file
│   ├── seal.cpp          # Enclave implementation
│   └── seal.h            # Enclave header
└── occlum_instance/      # Occlum configuration
    └── Occlum.json       # Occlum configuration file
```

## Building and Running

1. Build the Docker image:
```bash
docker build -t occlum-go-seal .
```

2. Run the container with SGX support:
```bash
docker run --device /dev/sgx_enclave:/dev/sgx_enclave \
           --device /dev/sgx_provision:/dev/sgx_provision \
           occlum-go-seal
```

## How it Works

1. The application creates a test message "Hello, SGX Sealing!"
2. The message is sealed (encrypted) using SGX sealing functionality
3. The sealed data is saved to a file
4. The sealed data is read back from the file
5. The data is unsealed (decrypted) using SGX sealing functionality
6. The original and unsealed messages are compared and displayed

## Security Notes

- The sealing key is derived from the CPU's unique key and is bound to the platform
- Sealed data can only be unsealed on the same platform
- The sealing process uses AES-GCM for encryption with a random IV
- All cryptographic operations are performed within the SGX enclave

## Troubleshooting

If you encounter any issues:

1. Ensure SGX is enabled in BIOS
2. Verify SGX driver and PSW are installed:
```bash
ls /dev/sgx*
```

3. Check SGX status:
```bash
dmesg | grep -i sgx
```

4. Verify the container has access to SGX devices:
```bash
docker run --device /dev/sgx_enclave:/dev/sgx_enclave \
           --device /dev/sgx_provision:/dev/sgx_provision \
           occlum-go-seal ls -l /dev/sgx*
```