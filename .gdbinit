set disassembly-flavor intel
set architecture i386:x86-64
layout asm
layout reg
layout split
target remote localhost:26000
symbol-file build/target/main_debug.efi
b efi_main
