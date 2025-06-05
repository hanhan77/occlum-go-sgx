package main

import (
	"fmt"
	"log"
	"os"
	"unsafe"
)

// #cgo CFLAGS: -I${SRCDIR}/enclave
// #cgo LDFLAGS: -L${SRCDIR}/occlum_instance/image/lib -lseal
// #include "enclave/seal.h"
import "C"

func main() {
	// Test data to seal
	testData := []byte("Hello, SGX Sealing!")

	// Seal the data
	sealedData, err := sealData(testData)
	if err != nil {
		log.Fatalf("Failed to seal data: %v", err)
	}

	// Save sealed data to file
	if err := os.WriteFile("sealed_data.bin", sealedData, 0644); err != nil {
		log.Fatalf("Failed to save sealed data: %v", err)
	}

	// Read sealed data from file
	readSealedData, err := os.ReadFile("sealed_data.bin")
	if err != nil {
		log.Fatalf("Failed to read sealed data: %v", err)
	}

	// Unseal the data
	unsealedData, err := unsealData(readSealedData)
	if err != nil {
		log.Fatalf("Failed to unseal data: %v", err)
	}

	fmt.Printf("Original data: %s\n", testData)
	fmt.Printf("Unsealed data: %s\n", unsealedData)
}

func sealData(data []byte) ([]byte, error) {
	var sealedDataPtr *C.uint8_t
	var sealedDataLen C.size_t

	ret := C.seal_data(
		(*C.uint8_t)(unsafe.Pointer(&data[0])),
		C.size_t(len(data)),
		&sealedDataPtr,
		&sealedDataLen,
	)

	if ret != 0 {
		return nil, fmt.Errorf("seal_data failed with error code: %d", ret)
	}

	sealedData := C.GoBytes(unsafe.Pointer(sealedDataPtr), C.int(sealedDataLen))
	C.free(unsafe.Pointer(sealedDataPtr))

	return sealedData, nil
}

func unsealData(sealedData []byte) ([]byte, error) {
	var unsealedDataPtr *C.uint8_t
	var unsealedDataLen C.size_t

	ret := C.unseal_data(
		(*C.uint8_t)(unsafe.Pointer(&sealedData[0])),
		C.size_t(len(sealedData)),
		&unsealedDataPtr,
		&unsealedDataLen,
	)

	if ret != 0 {
		return nil, fmt.Errorf("unseal_data failed with error code: %d", ret)
	}

	unsealedData := C.GoBytes(unsafe.Pointer(unsealedDataPtr), C.int(unsealedDataLen))
	C.free(unsafe.Pointer(unsealedDataPtr))

	return unsealedData, nil
}
