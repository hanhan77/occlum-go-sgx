#include "seal.h"
#include <sgx_tcrypto.h>
#include <sgx_trts.h>
#include <sgx_utils.h>
#include <string.h>
#include <stdlib.h>

#define SEAL_KEY_SIZE 16
#define SEAL_IV_SIZE 12
#define SEAL_TAG_SIZE 16

int seal_data(const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len) {
    if (!in_data || !out_data || !out_len) {
        return -1;
    }

    // Calculate the size needed for sealed data
    size_t sealed_size = in_len + SEAL_IV_SIZE + SEAL_TAG_SIZE;
    uint8_t* sealed_data = (uint8_t*)malloc(sealed_size);
    if (!sealed_data) {
        return -1;
    }

    // Generate a random IV
    if (sgx_read_rand(sealed_data, SEAL_IV_SIZE) != SGX_SUCCESS) {
        free(sealed_data);
        return -1;
    }

    // Get the sealing key
    sgx_key_128bit_t key;
    sgx_key_request_t key_request = {0};
    key_request.key_name = SGX_KEYSELECT_SEAL;
    key_request.key_policy = SGX_KEYPOLICY_MRENCLAVE;
    if (sgx_get_key(&key_request, &key) != SGX_SUCCESS) {
        free(sealed_data);
        return -1;
    }

    // Encrypt the data
    sgx_aes_gcm_128bit_tag_t tag;
    if (sgx_rijndael128GCM_encrypt(&key,
                                  in_data,
                                  in_len,
                                  sealed_data + SEAL_IV_SIZE,
                                  sealed_data,
                                  SEAL_IV_SIZE,
                                  NULL,
                                  0,
                                  &tag) != SGX_SUCCESS) {
        free(sealed_data);
        return -1;
    }

    // Copy the tag
    memcpy(sealed_data + SEAL_IV_SIZE + in_len, tag, SEAL_TAG_SIZE);

    *out_data = sealed_data;
    *out_len = sealed_size;
    return 0;
}

int unseal_data(const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len) {
    if (!in_data || !out_data || !out_len || in_len < SEAL_IV_SIZE + SEAL_TAG_SIZE) {
        return -1;
    }

    // Calculate the size of the unsealed data
    size_t unsealed_size = in_len - SEAL_IV_SIZE - SEAL_TAG_SIZE;
    uint8_t* unsealed_data = (uint8_t*)malloc(unsealed_size);
    if (!unsealed_data) {
        return -1;
    }

    // Get the sealing key
    sgx_key_128bit_t key;
    sgx_key_request_t key_request = {0};
    key_request.key_name = SGX_KEYSELECT_SEAL;
    key_request.key_policy = SGX_KEYPOLICY_MRENCLAVE;
    if (sgx_get_key(&key_request, &key) != SGX_SUCCESS) {
        free(unsealed_data);
        return -1;
    }

    // Decrypt the data
    sgx_aes_gcm_128bit_tag_t tag;
    memcpy(tag, in_data + SEAL_IV_SIZE + unsealed_size, SEAL_TAG_SIZE);

    if (sgx_rijndael128GCM_decrypt(&key,
                                  in_data + SEAL_IV_SIZE,
                                  unsealed_size,
                                  unsealed_data,
                                  in_data,
                                  SEAL_IV_SIZE,
                                  NULL,
                                  0,
                                  &tag) != SGX_SUCCESS) {
        free(unsealed_data);
        return -1;
    }

    *out_data = unsealed_data;
    *out_len = unsealed_size;
    return 0;
} 