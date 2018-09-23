#!/bin/sh
set -ex

TARGET=x86_64-elf

${TARGET}-as boot.s -o boot.o
${TARGET}-gcc -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra
${TARGET}-gcc -T linker.ld -o myos.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc