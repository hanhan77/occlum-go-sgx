#ifndef _SEAL_H_
#define _SEAL_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int seal_data(const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len);
int unseal_data(const uint8_t* in_data, size_t in_len, uint8_t** out_data, size_t* out_len);

#ifdef __cplusplus
}
#endif

#endif /* _SEAL_H_ */ 