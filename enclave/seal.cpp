#include "seal.h"
#include <sgx_tcrypto.h>
#include <sgx_trts.h>
#include <sgx_utils.h>
#include <string.h>
#include <stdlib.h>

#define SEAL_KEY_SIZE 16
#define SEAL_IV_SIZE 12
#define SEAL_TAG_SIZE 16

// Calculate the size needed for sealed data
size_t get_sealed_data_size(size_t data_size) {
    return sgx_calc_sealed_data_size(0, data_size);
}

// Seal data within the enclave
sgx_status_t seal_data(const uint8_t* data, 
                      size_t data_size,
                      uint8_t* sealed_data,
                      size_t sealed_size) {
    if (!data || !sealed_data) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Verify the sealed data size
    size_t required_size = get_sealed_data_size(data_size);
    if (sealed_size < required_size) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Seal the data
    return sgx_seal_data(0, NULL, data_size, data, sealed_size, (sgx_sealed_data_t*)sealed_data);
}

// Unseal data within the enclave
sgx_status_t unseal_data(const uint8_t* sealed_data,
                        size_t sealed_size,
                        uint8_t* data,
                        size_t data_size) {
    if (!sealed_data || !data) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Get the size of the unsealed data
    uint32_t mac_text_len = 0;
    uint32_t decrypted_text_len = 0;
    sgx_status_t ret = sgx_get_add_mac_txt_len((const sgx_sealed_data_t*)sealed_data, &mac_text_len);
    if (ret != SGX_SUCCESS) {
        return ret;
    }

    ret = sgx_get_encrypt_txt_len((const sgx_sealed_data_t*)sealed_data, &decrypted_text_len);
    if (ret != SGX_SUCCESS) {
        return ret;
    }

    // Verify the data size
    if (data_size < decrypted_text_len) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Unseal the data
    return sgx_unseal_data((const sgx_sealed_data_t*)sealed_data, NULL, &mac_text_len, data, &decrypted_text_len);
} 