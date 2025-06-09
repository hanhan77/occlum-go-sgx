#!/bin/bash
#copyright@antfinancial:adopted from a script written by geding
set -e

rm -rf openssl
git clone -b OpenSSL_1_1_1 --depth 1 http://github.com/openssl/openssl
cd openssl
CC=occlum-gcc ./config \
    --prefix=/usr/local/occlum/x86_64-linux-musl \
    --openssldir=/usr/local/occlum/x86_64-linux-musl/ssl \
    --with-rand-seed=rdcpu \
    no-async no-zlib

if [ $? -ne 0 ]
then
  echo "./config command failed."
  exit 1
fi
make -j$(nproc)
if [ $? -ne 0 ]
then
  echo "make command failed."
  exit 1
fi
make install
if [ $? -ne 0 ]
then
  echo "make install command failed."
  exit 1
fi

ls /usr/local/occlum/x86_64-linux-musl/include
ls /usr/local/occlum/x86_64-linux-musl

echo "build and install openssl success!"
