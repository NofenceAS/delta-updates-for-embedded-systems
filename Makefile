BOARD54 := nrf54l15dk/nrf54l15/cpuapp
BOARD52 := nrf52840dk/nrf52840

PY := python3 

#device flash map
SLOT_SIZE := 0x67000
HEADER_SIZE := 512
SLOT0_OFFSET := 0xc000
SLOT1_OFFSET := 0x73000
PATCH_OFFSET := 0xf8000
MAX_PATCH_SIZE := 0x6000
PATCH_HEADER_SIZE := 0x8 

#relevant directories that the user might have to update
BOOT_DIR := app/build/mcuboot/zephyr#bootloader image location
BUILD_DIR := zephyr/build#zephyr build directory
KEY_PATH := bootloader/mcuboot/root-rsa-2048.pem#key for signing images

#Names of generated folders and files (can be changed to whatever)
BIN_DIR := binaries
IMG_DIR := $(BIN_DIR)/signed_images
PATCH_DIR := $(BIN_DIR)/patches
DUMP_DIR := $(BIN_DIR)/flash_dumps

SOURCE_PATH := $(IMG_DIR)/source.bin
TARGET_PATH := $(IMG_DIR)/target.bin
PATCH_PATH := $(PATCH_DIR)/patch.bin
SLOT0_PATH := $(DUMP_DIR)/slot0.bin
SLOT1_PATH := $(DUMP_DIR)/slot1.bin

#commands + flags and scripts
PYFLASH := pyocd flash -e sector 
DETOOLS := detools create_patch --compression heatshrink
BUILD_APP52 := west build -p -b $(BOARD52) --sysbuild
BUILD_APP54 := west build -p -b $(BOARD54) --sysbuild
SIGN := west sign -t imgtool -d $(BUILD_DIR)
IMGTOOL_SETTINGS := --version 1.0 --header-size $(HEADER_SIZE) \
                    --slot-size $(SLOT_SIZE) --align 4 --key $(KEY_PATH)
PAD_SCRIPT := $(PY) scripts/pad_patch.py
DUMP_SCRIPT := $(PY) scripts/jflashrw.py read
SET_SCRIPT := $(PY) scripts/set_current.py 
OPTIONS := chip_erase_mode=ERASE_RANGES_TOUCHED_BY_FIRMWARE,verify=VERIFY_READ
all: build-boot flash-boot build flash-image

help:
	@echo "Make commands that may be utilized:"	
	@echo "all                Build + flash bootloader and build"
	@echo "                   + flash firmware."
	@echo "build              Build the firmware image."		
	@echo "build-boot         Build the bootloader."
	@echo "flash-image        Flash the firmware image."
	@echo "flash-boot         Erase the flash and flash the bootloader."
	@echo "flash-patch        Flash the patch to the storage partition."
	@echo "create_patch       1. Create a patch based on the firmware"
	@echo "                     image and the upgraded firmware image."
	@echo "                   2. Append NEWPATCH and patch size to"
	@echo "                     the beginning of the image."
	@echo "connect            Connect to the device terminal."
	@echo "dump-flash         Dump slot 1 and 0 to files."
	@echo "clean              Remove all generated binaries."
	@echo "tools              Install used tools."

build-source-and-flash54:
	@echo "Building firmware source image for nRF54L15..."	
	mkdir -p $(IMG_DIR)
	cd app/ && $(BUILD_APP54)
	west flash --erase --build-dir app/build
	mv app/build/app/zephyr/zephyr.signed.bin $(SOURCE_PATH)

build-target54:
	@echo "Building target firmware image for nRF54L15..."	
	cd app/ && $(BUILD_APP54)
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)

build-source-and-flash52:
	@echo "Building firmware source image for nRF52840..."	
	mkdir -p $(IMG_DIR)
	cd app/ && $(BUILD_APP52)
	west flash --erase --build-dir app/build
	mv app/build/app/zephyr/zephyr.signed.bin $(SOURCE_PATH)

build-target52:
	@echo "Building target firmware image for nRF52840..."	
	cd app/ && $(BUILD_APP52)
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)

flash-boot:
	@echo "Flashing latest bootloader image..."	
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS}

flash-patch:
	@echo "Flashing latest patch to patch partition..."
	nrfutil device program --firmware $(PATCH_DIR)/patch.hex --options chip_erase_mode=ERASE_RANGES_TOUCHED_BY_FIRMWARE
	$(SET_SCRIPT) $(TARGET_PATH) $(SOURCE_PATH)
	nrfutil device reset
	
create-patch-nrf52:
	@echo "Creating patch..."
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	$(PAD_SCRIPT) $(PATCH_PATH) $(MAX_PATCH_SIZE) $(PATCH_HEADER_SIZE)
	arm-none-eabi-objcopy -I binary -O ihex --change-addresses 0x000F8000 $(PATCH_PATH) $(PATCH_DIR)/patch.hex

create-patch-nrf54:
	@echo "Creating patch..."
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	$(PAD_SCRIPT) $(PATCH_PATH) $(MAX_PATCH_SIZE) $(PATCH_HEADER_SIZE)
	arm-none-eabi-objcopy -I binary -O ihex --change-addresses 0x0015C000 $(PATCH_PATH) $(PATCH_DIR)/patch.hex
	
connect:
	@echo "Connecting to device console.."
	JLinkRTTLogger -device NRF52 -if SWD -speed 5000 -rttchannel 0 /dev/stdout

dump-flash: dump-slot0 dump-slot1

dump-slot0:
	@echo "Dumping slot 0 contents.."
	mkdir -p $(DUMP_DIR)
	rm -f $(SLOT0_PATH)
	touch $(SLOT0_PATH)
	$(DUMP_SCRIPT) --start $(SLOT0_OFFSET) --length $(SLOT_SIZE) --file $(SLOT0_PATH)

dump-slot1:
	@echo "Dumping slot 1 contents.."
	mkdir -p $(DUMP_DIR)
	rm -f $(SLOT1_PATH)
	touch $(SLOT1_PATH)
	$(DUMP_SCRIPT) --start $(SLOT1_OFFSET) --length $(SLOT_SIZE) --file $(SLOT1_PATH)

clean:
	rm -r -f $(BOOT_DIR)/build
	rm -r -f zephyr/build

tools:
	@echo "Installing tools..."
	pip3 install west
	pip3 install detools
	pip3 install pyocd
	pip3 install pynrfjprog
	pip3 install imgtool
	@echo "Done"

extra-tools:
	@echo "Installing extra tools..."
	pip3 install -r zephyr/scripts/requirements.txt
	pip3 install -r bootloader/mcuboot/scripts/requirements.txt
	@echo "Done"
