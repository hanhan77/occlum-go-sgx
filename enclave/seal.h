#ifndef _SEAL_H_
#define _SEAL_H_

#include <stdint.h>
#include <stddef.h>
#include <sgx_tcrypto.h>
#include <sgx_trts.h>

#ifdef __cplusplus
extern "C" {
#endif

// Calculate the size needed for sealed data
size_t get_sealed_data_size(size_t data_size);

// Seal data within the enclave
sgx_status_t seal_data(const uint8_t* data, 
                      size_t data_size,
                      uint8_t* sealed_data,
                      size_t sealed_size);

// Unseal data within the enclave
sgx_status_t unseal_data(const uint8_t* sealed_data,
                        size_t sealed_size,
                        uint8_t* data,
                        size_t data_size);

#ifdef __cplusplus
}
#endif

#endif /* _SEAL_H_ */ 