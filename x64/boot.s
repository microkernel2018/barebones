/* Declare constants for the multiboot header. */
.set ALIGN,    1<<0             /* align loaded modules on page boundaries */
.set MEMINFO,  1<<1             /* provide memory map */
.set FLAGS,    ALIGN | MEMINFO  /* this is the Multiboot 'flag' field */
.set MAGIC,    0x1BADB002       /* 'magic number' lets bootloader find the header */
.set CHECKSUM, -(MAGIC + FLAGS) /* checksum of above, to prove we are multiboot */
 
/* 
Declare a multiboot header that marks the program as a kernel. These are magic
values that are documented in the multiboot standard. The bootloader will
search for this signature in the first 8 KiB of the kernel file, aligned at a
32-bit boundary. The signature is in its own section so the header can be
forced to be within the first 8 KiB of the kernel file.
*/
.section .multiboot
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM
 
/*
The multiboot standard does not define the value of the stack pointer register
(esp) and it is up to the kernel to provide a stack. This allocates room for a
small stack by creating a symbol at the bottom of it, then allocating 16384
bytes for it, and finally creating a symbol at the top. The stack grows
downwards on x86. The stack is in its own section so it can be marked nobits,
which means the kernel file is smaller because it does not contain an
uninitialized stack. The stack on x86 must be 16-byte aligned according to the
System V ABI standard and de-facto extensions. The compiler will assume the
stack is properly aligned and failure to align the stack will result in
undefined behavior.
*/
.section .bss
.align 16
stack_bottom:
.skip 16384 # 16 KiB
stack_top:
 
/*
The linker script specifies _start as the entry point to the kernel and the
bootloader will jump to this position once the kernel has been loaded. It
doesn't make sense to return from this function as the bootloader is gone.
*/
.section .text
.global _start
.type _start, @function
_start:
	mov $stack_top, %esp

// https://wiki.osdev.org/Setting_Up_Long_Mode

	/////////////////
	// disable paging
	
	// Set the A-register to control register 0.
	mov %cr0,%eax
	// Clear the PG-bit, which is bit 31.
	and $0b01111111111111111111111111111111,%eax
	// Set control register 0 to the A-register.
	mov %eax,%cr0

	///////////////////////
	// set up paging
	// XXXX

	///////////////////////
	// switch from protected mode to long mode

	// Set the C-register to 0xC0000080, which is the EFER MSR.
	mov $0xC0000080,%ecx
	// Read from the model-specific register.
	rdmsr
	// Set the LM-bit which is the 9th bit (bit 8).
	or $0b10000000, %eax
	// Write to the model-specific register
	wrmsr

	//////////////////////
	// enable paging
	mov %cr0,%eax
	or $0b1000000000000000000000000000000,%eax
	mov %eax,%cr0

	/////////////////////
	// enter the 64 bit submode by setting up a GDT
	// XXX NOT DONE

//	lgdt []
	jmp realm64 // we should do the 64 bit setup in the Sample before calling kernel_main
realm64:	
	
	cli
1:	hlt
	jmp 1b

GDT64:                              // Global Descriptor Table (64-bit).
    .size GDT64.Null, . - GDT64           // The null descriptor.
    .word $0xFFFF                    // Limit (low).
    .word $0                         // Base (low).
    .byte $0                         // Base (middle)
    .byte $0                         // Access.
    .byte $1                         // Granularity.
    .byte $0                         // Base (high).
    .size GDT64.Code, . - GDT64           // The code descriptor.
    .word $0                         // Limit (low).
    .word $0                         // Base (low).
    .byte $0                         // Base (middle)
    .byte $0b10011010                 // Access (exec/read).
    .byte $0b10101111                 // Granularity, 64 bits flag, limit19:16.
    .byte $0                         // Base (high).
    .size GDT64.Data, . - GDT64           // The data descriptor.
    .word $0                         // Limit (low).
    .word $0                         // Base (low).
    .byte $0                         // Base (middle)
    .byte $0b10010010                 // Access (read/write).
    .byte $0b00000000                 // Granularity.
    .byte $0                         // Base (high).
    GDT64.Pointer:                  // The GDT-pointer.
    .word . - GDT64 - 1             // Limit.
    .quad GDT64                     // Base.

/*
Set the size of the _start symbol to the current location '.' minus its start.
This is useful when debugging or when you implement call tracing.
*/
.size _start, . - _start
