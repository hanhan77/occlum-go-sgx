#include "seal.h"
#include "seal_t.h"
#include <sgx_tseal.h>
#include <string.h>

#define SEAL_KEY_SIZE 16
#define SEAL_IV_SIZE 12
#define SEAL_TAG_SIZE 16

// Calculate the size needed for sealed data
sgx_status_t get_sealed_data_size(sgx_status_t* retval, const uint8_t* data, uint32_t data_size, uint32_t* sealed_data_size) {
    if (!data || !sealed_data_size) {
        *retval = SGX_ERROR_INVALID_PARAMETER;
        return SGX_ERROR_INVALID_PARAMETER;
    }
    
    *sealed_data_size = sgx_calc_sealed_data_size(0, data_size);
    if (*sealed_data_size == UINT32_MAX) {
        *retval = SGX_ERROR_UNEXPECTED;
        return SGX_ERROR_UNEXPECTED;
    }
    
    *retval = SGX_SUCCESS;
    return SGX_SUCCESS;
}

// Seal data within the enclave
sgx_status_t seal_data(uint8_t* sealed_blob, uint32_t data_size) {
    if (!sealed_blob) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Seal the data
    return sgx_seal_data(0, NULL, data_size, sealed_blob, data_size, (sgx_sealed_data_t*)sealed_blob);
}

// Unseal data within the enclave
sgx_status_t unseal_data(const uint8_t* sealed_blob, uint32_t data_size) {
    if (!sealed_blob) {
        return SGX_ERROR_INVALID_PARAMETER;
    }

    // Create a temporary buffer for the unsealed data
    uint8_t* temp_buffer = new uint8_t[data_size];
    if (!temp_buffer) {
        return SGX_ERROR_OUT_OF_MEMORY;
    }

    // Get the size of the unsealed data
    uint32_t mac_text_len = sgx_get_add_mac_txt_len((const sgx_sealed_data_t*)sealed_blob);
    uint32_t decrypted_text_len = sgx_get_encrypt_txt_len((const sgx_sealed_data_t*)sealed_blob);

    // Unseal the data
    sgx_status_t ret = sgx_unseal_data((const sgx_sealed_data_t*)sealed_blob, NULL, &mac_text_len, temp_buffer, &decrypted_text_len);
    
    if (ret == SGX_SUCCESS) {
        // Copy the unsealed data back to the input buffer
        memcpy((void*)sealed_blob, temp_buffer, decrypted_text_len);
    }

    delete[] temp_buffer;
    return ret;
} 