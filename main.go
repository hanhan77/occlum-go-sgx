package main

import (
	"fmt"
	"log"
	"unsafe"
)

// #cgo CFLAGS: -I${SRCDIR}/enclave -I/opt/intel/sgxsdk/include
// #cgo LDFLAGS: -L${SRCDIR}/enclave -lseal
// #include "enclave/seal.h"
import "C"

func main() {
	// Test data to seal
	testData := []byte("Hello, SGX Sealing!")

	// Calculate sealed data size
	var sealedSize C.uint32_t
	ret := C.get_sealed_data_size(
		(*C.uint8_t)(unsafe.Pointer(&testData[0])),
		C.uint32_t(len(testData)),
		&sealedSize,
	)
	if ret != 0 {
		log.Fatalf("Failed to calculate sealed data size: %d", ret)
	}

	// Allocate memory for sealed data
	sealedData := make([]byte, sealedSize)

	// Seal the data
	ret = C.seal_data(
		(*C.uint8_t)(unsafe.Pointer(&sealedData[0])),
		C.uint32_t(sealedSize),
	)
	if ret != 0 {
		log.Fatalf("Failed to seal data: %d", ret)
	}

	// Allocate memory for unsealed data
	unsealedData := make([]byte, len(testData))

	// Unseal the data
	ret = C.unseal_data(
		(*C.uint8_t)(unsafe.Pointer(&sealedData[0])),
		C.uint32_t(sealedSize),
	)
	if ret != 0 {
		log.Fatalf("Failed to unseal data: %d", ret)
	}

	fmt.Printf("Original data: %s\n", testData)
	fmt.Printf("Unsealed data: %s\n", unsealedData)
}
