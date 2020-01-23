CC = gcc
LD = ld

SRC_DIR = src
BUILD_DIR = build

OBJECTS_DIR = $(BUILD_DIR)/objects
TARGET_DIR = $(BUILD_DIR)/target

SHARED_OBJ = $(OBJECTS_DIR)/target.so
SECTIONS = .text .sdata .data .dynamic .dynsym .rel .rela .reloc
DEBUG_SECTIONS = .debug_info .debug_abbrev .debug_loc .debug_aranges .debug_line .debug_macinfo .debug_str
TARGET = $(TARGET_DIR)/main.efi
DEBUG_TARGET = $(TARGET_DIR)/main_debug.efi
DISK_IMAGE = $(TARGET_DIR)/xistem.img

SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(patsubst $(SRC_DIR)/%.c, $(OBJECTS_DIR)/%.o, $(SRCS))

all: $(DISK_IMAGE)
.PHONY: run clean

$(DISK_IMAGE): $(TARGET) startup.nsh
	dd if=/dev/zero of=$@ bs=512 count=131072
	parted $@ -s -a minimal mklabel gpt
	parted $@ -s -a minimal mkpart EFI FAT32 2048s 131038s
	parted $@ -s -a minimal toggle 1 boot
	dd if=/dev/zero of=/tmp/partition.img bs=512 count=128991
	mformat -i /tmp/partition.img -h 32 -t 32 -n 64 -c 1
	mcopy -i /tmp/partition.img $^ ::
	dd if=/tmp/partition.img of=$(DISK_IMAGE) bs=512 count=128991 seek=2048 conv=notrunc

$(TARGET): $(OBJECTS_DIR)/target.so
	mkdir -p $(dir $@)
	objcopy $(foreach section, $(SECTIONS), -j $(section)) --target=efi-app-x86_64 $< $@

$(DEBUG_TARGET): $(OBJECTS_DIR)/target.so
	mkdir -p $(dir $@)
	objcopy $(foreach section, $(SECTIONS) $(DEBUG_SECTIONS), -j $(section)) --target=efi-app-x86_64 $< $@

$(SHARED_OBJ): $(OBJS)
	mkdir -p $(dir $@)
	$(LD) -nostdlib -znocombreloc \
	  -T /usr/lib/elf_x86_64_efi.lds -shared -Bsymbolic \
	  -L /usr/lib \
	  /usr/lib/crt0-efi-x86_64.o $(OBJS) \
	  -lefi -lgnuefi -o $@

$(OBJECTS_DIR)/%.o: $(SRC_DIR)/%.c
	mkdir -p $(dir $@)
	$(CC) $< -Wall -Wextra -c \
	  -I/usr/include/efi \
	  -I/usr/include/efi/x86_64 \
	  -I/usr/include/efi/protocol \
	  -fno-stack-protector -fpic -fshort-wchar -mno-red-zone \
	  -gdwarf-4 -ggdb3 \
	  -DEFI_FUNCTION_WRAPPER -o $@

run: all
	qemu-system-x86_64 -cpu qemu64 \
	  -L /usr/share/OVMF -bios OVMF_CODE.fd -net none \
	  -drive file=$(DISK_IMAGE),if=ide,format=raw

debug: all $(DEBUG_TARGET)
	qemu-system-x86_64 -cpu qemu64 \
	  -L /usr/share/OVMF -bios OVMF_CODE.fd -net none \
	  -drive file=$(DISK_IMAGE),if=ide,format=raw -gdb tcp::26000 -S

clean:
	rm -rf $(BUILD_DIR)
