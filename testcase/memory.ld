OUTPUT_ARCH(riscv)
ENTRY(_start)

SECTIONS
{
	. = 0x00000000;
	.text : {
		*(.text._start)
		*(.text)
	}

	.rodata ALIGN(4) : {
		*(.rodata)
	}

	.data ALIGN(4) : {
		*(.data)
	}

	__bss_start = .;

	.bss ALIGN(4) : {
		*(.bss)
	}

	__bss_end = .;
	__heap_start = (__bss_end + 0xfff) & 0xfffff000;
}

