BOARD54 := nrf54l15dk/nrf54l15/cpuapp
BOARD52 := nrf52840dk/nrf52840

PY := python3 

#device flash map
SLOT_SIZE := 43928
HEADER_SIZE := 0x800
SLOT0_OFFSET52 := 0xC000
SLOT0_OFFSET54 := 0xC000
SLOT1_OFFSET52 := 0x73000
SLOT1_OFFSET54 := 0xC0000
PATCH_OFFSET52 := 0xf8000
PATCH_OFFSET54 := 0x174000
MAX_PATCH_SIZE := 0x6000
PATCH_HEADER_SIZE := 0x8 

#relevant directories that the user might have to update
BOOT_DIR := app/build/mcuboot/zephyr#bootloader image location
BUILD_DIR := app/build/#zephyr build directory
KEY_PATH := app/sysbuild/nofence_rsa_private.pem#key for signing images

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
IMGTOOL_SETTINGS := --version 2.2.0 --header-size $(HEADER_SIZE) \
                    --slot-size $(SLOT_SIZE) --align 4 --key $(KEY_PATH)
PAD_SCRIPT := $(PY) scripts/pad_patch.py
DUMP_SCRIPT := $(PY) scripts/jflashrw.py read
SET_SCRIPT := $(PY) scripts/set_current.py 
OPTIONS_ERASE_ALL := chip_erase_mode=ERASE_ALL,verify=VERIFY_READ
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
	cp app/build/app/zephyr/zephyr.signed.bin $(SOURCE_PATH)
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS_ERASE_ALL}
	pyocd flash -e sector -a $(SLOT0_OFFSET54) -t nrf54l $(BUILD_DIR)app/zephyr/zephyr.signed.bin


build-target54:
	@echo "Building target firmware image for nRF54L15..."	
	cd app/ && west build -b $(BOARD54) --sysbuild
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)

build-target54-and-flash-detools:
	@echo "Building target firmware image for nRF54L15..."	
	cd app/ && west build -b $(BOARD54) --sysbuild
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	detools apply_patch $(SOURCE_PATH) $(PATCH_PATH) binaries/detoolsapplied/output.bin
	pyocd flash -e sector -a $(SLOT1_OFFSET54) -t nrf54l binaries/detoolsapplied/output.bin

build-target52-and-flash-detools:
	@echo "Building target firmware image for nRF52840..."	
	cd app/ && west build -b $(BOARD52) --sysbuild
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	detools apply_patch $(SOURCE_PATH) $(PATCH_PATH) binaries/detoolsapplied/output.bin
	pyocd flash -e sector -a $(SLOT1_OFFSET52) -t nrf52840 binaries/detoolsapplied/output.bin

build-source-and-flash52:
	@echo "Building firmware source image for nRF52840..."	
	mkdir -p $(IMG_DIR)
	cd app/ && $(BUILD_APP52)
	cp app/build/app/zephyr/zephyr.signed.bin $(SOURCE_PATH)
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS_ERASE_ALL}
	pyocd flash -e sector -a $(SLOT0_OFFSET52) -t nrf52840 $(BUILD_DIR)app/zephyr/zephyr.signed.bin

flash-everything54:
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS_ERASE_ALL}
	pyocd flash -e sector -a $(SLOT0_OFFSET54) -t nrf54l $(SOURCE_PATH)
	$(PYFLASH) -a $(PATCH_OFFSET54) -t nrf54l $(PATCH_PATH)

flash-everything52:
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS_ERASE_ALL}
	pyocd flash -e sector -a $(SLOT0_OFFSET52) -t nrf52840 $(SOURCE_PATH)
	$(PYFLASH) -a $(PATCH_OFFSET52) -t nrf52840 $(PATCH_PATH)

build-target52:
	@echo "Building target firmware image for nRF52840..."	
	cd app/ && west build -b $(BOARD52) --sysbuild
	mv app/build/app/zephyr/zephyr.signed.bin $(TARGET_PATH)

flash-boot:
	@echo "Flashing latest bootloader image..."	
	nrfutil device program --firmware $(BOOT_DIR)/zephyr.bin --options ${OPTIONS}

flash-patch52:
	@echo "Flashing latest patch to patch partition..."
	$(PYFLASH) -a $(PATCH_OFFSET52) -t nrf52840 $(PATCH_PATH)
	$(SET_SCRIPT) $(TARGET_PATH) $(SOURCE_PATH)

flash-patch54:
	@echo "Flashing latest patch to patch partition..."
	$(PYFLASH) -a $(PATCH_OFFSET54) -t nrf54l $(PATCH_PATH)
	$(SET_SCRIPT) $(TARGET_PATH) $(SOURCE_PATH)
	
create-patch-nrf52:
	@echo "Creating patch..."
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	$(PAD_SCRIPT) $(PATCH_PATH) $(MAX_PATCH_SIZE) $(PATCH_HEADER_SIZE)

create-patch-nrf54:
	@echo "Creating patch..."
	mkdir -p $(PATCH_DIR)
	rm -f $(PATCH_PATH)
	$(DETOOLS) $(SOURCE_PATH) $(TARGET_PATH) $(PATCH_PATH)
	$(PAD_SCRIPT) $(PATCH_PATH) $(MAX_PATCH_SIZE) $(PATCH_HEADER_SIZE)
	
connect:
	@echo "Connecting to device console.."
	JLinkRTTLogger -device NRF52 -if SWD -speed 5000 -rttchannel 0 /dev/stdout

dump-flash: dump-slot0 dump-slot1

dump-slot0:
	@echo "Dumping slot 0 contents.."
	mkdir -p $(DUMP_DIR)
	rm -f $(SLOT0_PATH)
	touch $(SLOT0_PATH)
	$(DUMP_SCRIPT) --start $(SLOT0_OFFSET52) --length $(SLOT_SIZE) --file $(SLOT0_PATH)

dump-slot1-54:
	@echo "Dumping slot 1 contents.."
	mkdir -p $(DUMP_DIR)
	rm -f $(SLOT1_PATH)
	touch $(SLOT1_PATH)
	$(DUMP_SCRIPT) --start $(SLOT1_OFFSET54) --length $(SLOT_SIZE) --file $(SLOT1_PATH)

dump-slot1-52:
	@echo "Dumping slot 1 contents.."
	mkdir -p $(DUMP_DIR)
	rm -f $(SLOT1_PATH)
	touch $(SLOT1_PATH)
	$(DUMP_SCRIPT) --start $(SLOT1_OFFSET52) --length $(SLOT_SIZE) --file $(SLOT1_PATH)

clean:
	rm -r -f $(BOOT_DIR)/build
	rm -r -f zephyr/build

tools:
	@echo "Installing tools..."
	pip3 install detools
	pip3 install -r bootloader/mcuboot/scripts/requirements.txt
	pip3 install pyocd
	pip3 install pynrfjprog
	pip3 install imgtool
	@echo "Done"
