#ifndef SEAL_H
#define SEAL_H

#include <stdint.h>
#include <stddef.h>
#include <sgx_error.h>

#ifdef __cplusplus
extern "C" {
#endif

// Calculate the size needed for sealed data
sgx_status_t SGX_CDECL get_sealed_data_size(sgx_status_t* retval, const uint8_t* data, uint32_t data_size, uint32_t* sealed_data_size);

// Seal data within the enclave
sgx_status_t seal_data(uint8_t* sealed_blob, uint32_t data_size);

// Unseal data within the enclave
sgx_status_t unseal_data(const uint8_t* sealed_blob, uint32_t data_size);

#ifdef __cplusplus
}
#endif

#endif // SEAL_H 