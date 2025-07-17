# About

Forked repository from [saralinnealindh's repository](https://github.com/saralinnealindh/delta-updates-for-embedded-systems)

This is an example program showcasing an implementation of [DETools](https://github.com/eerimoq/detools) for [Zephyr](https://www.zephyrproject.org/). It allows for incremental firmware updates, or [delta updates](https://en.wikipedia.org/wiki/Delta_update), as an alternative to the standard procedure of downloading new firmware in its entirety. 

The program itself is a modification of the Zephyr sample program "Blinky" (which flashes LED 1 on a board) with the added functionality that when button 1 is pressed the program checks for a new patch and, if such a patch exists, performs a firmware upgrade. A developer may easily modify the program code to make the application flash LED 2 instead, create a patch, download it to the board, push button 1, and confirm whether the upgrade was successful by checking which LED is flashing.

### Key features 


* The program is hardware specific either nRF52840DK or nRF54L15DK has to be used. However, it will likely very easily be ported to other [Zephyr supported boards](https://docs.zephyrproject.org/latest/boards/index.html).
* Zephyr v4.1.0 is being used.
* Downloading firmware to the device is currently only supported using the USB interface.
* The delta encoding algorithm used is the DETools implementation of [BSDiff](http://www.daemonology.net/bsdiff/) using [heat-shrink](https://github.com/atomicobject/heatshrink) for compression.
* The program utilizes the Device Firmware Upgrade features facilitated by the [MCUBoot](https://www.mcuboot.com/) bootloader, and is therefore dependent on its usage (MCUBoot is automatically included if one follows the environment set up steps below). Most notably it takes advantage of the [flash map layout](https://github.com/mcu-tools/mcuboot/blob/main/docs/readme-zephyr.md).
* The patching process makes use of three partitions: the primary partition, the secondary partition, and the patch partition. The current firmware runs on the primary partition, the new firmware is created on the secondary partition, and the patch is downloaded to the patch partition. Naturally, this means that the size of the patch partition puts an upper limit to the size of the patch. When the new firmware has been created, the device requests a swap of the primary and the secondary partition and reboots, as in the [normal upgrade scanario](https://www.mcuboot.com/documentation/design/#high-level-operation).
* Creation of patches, downloading firmware to the device, building, and a few other things may easily be done using the make commands provided in the makefile. A full list of these commands can be acquired using `make help`.
* Limited testing has resulted in patch sizes of 1.6 to 6.4 percent of target image size depending on the types of changes made. However, more extended testing has to be performed in order to make any generalized claims.

### Purpose 
Many resource-constrained IoT units are used in a manner which makes them inaccessible via cable and at the same time unable to receive large amounts of data using radio transmissions. Upgrading firmware is hence difficult or in some cases impossible. Integrating support for delta updates in the unit is a potential solution to this problem, as it significantly reduces the payload during an upgrade scenario. However, as of now there is no open-source solution for delta upgrades in embedded systems. The purpose of the application is to show that such a solution is achievable and that it causes a significant payload reduction. 

# Environment Setup
Follow Zephyr's [Getting Started Guide](https://docs.zephyrproject.org/latest/getting_started/index.html) up to step 3.2 "Get the Zephyr source code". Here one should run the commands below instead of the ones in the guide:

    $ git clone git@github.com:NofenceAS/delta-updates-for-embedded-systems.git
    $ cd delta-updates-for-embedded-systems
    $ python -m venv deltaenv
    $ source deltaenv/bin/activate
    $ make tools
    $ west init -l app/
    $ west update
    $ west zephyr-export
    $ make extra-tools

Then complete the remaining steps under section 4. 

Additionally, one will need some external development tools. Return to the project folder and run `make tools` to install the needed python packages. Download and install [nRF Command Line Tools](https://www.nordicsemi.com/Products/Development-tools/nRF-Command-Line-Tools/Download#infotabs) and [J-Link Software](https://www.segger.com/downloads/jlink/) to enable some utilities for flashing and debugging the device.

# Example Usage
This small guide features some examples of how to use the program. A good place to start might be to perform them all sequentially. The first part of the guide is for nRF54L15DK. Make sure to plug in the DK to the PC before starting

### Build and flash nRF54L15
This build the application using sysbuild, which builds the mcuboot also and flashes it on the board.

    $ make build-source-and-flash54

### Modify the program to flash another LED
In order to test the patching algorithm a new version of the program is needed. This is easiest done by modifying which LED light is flashing. This can be done by opening `delta-updates-for-embedded-systems/app/src/main.c` in ones editor of choice and replacing `#define LED0_NODE DT_ALIAS(led0)` with `#define LED0_NODE DT_ALIAS(led1)` (or some other LED). The "new" application can then be built with:

    $ make build-target54

### Create and flash the patch
Creating a patch requires step 1 and 2 to at some point have been completed, as a "currently running" and a "latest created" version of the software has to have been set. The patch created will contain instructions for how to transform the former of these into the later. 

The commands for creating the patch and downloading it the patch partition are: 

    $ make create-patch-nrf54
    $ make flash-patch

After executing the second command one will get a prompt asking if this version should be set as the currently running one. To this one might want to respond `y` if the upgrade was successful or `n` if it was not.

### Upgrade the firmware
When the patch is downloaded to the patch partition and the program is flashing LED 1 it is time to start the patching process, which one does by clicking button 1. The LED should stop blinking for a few seconds while its creating the new firmware and reboots, and then start up again doing whatever one modified the new program to do. 


### Building for nRF52840DK

In order to build and run the same experiment on nRF52840DK, just run the same make commands but replace the 54 with 52 in the end. i.e. 

    $ make build-source-and-flash54

# Notable changes


| Date | Comment | Commit |
| ------ | ------ | ------ |
| **20250717**| Fixed delta.c delta_flash_write() function to make it more robust | [fc42013](https://github.com/NofenceAS/delta-updates-for-embedded-systems/commit/fc42013ed8c71f11e0b363b21d67e986e26dbbcc) |
| **20250717**| Switched and lifted to latest NCS (3.0.2) pointing to main | [fc42013](https://github.com/NofenceAS/delta-updates-for-embedded-systems/commit/fc42013ed8c71f11e0b363b21d67e986e26dbbcc) |
| **20250702**| Lifted to Zephyr v4.1 | [fc42013](https://github.com/NofenceAS/delta-updates-for-embedded-systems/commit/fc42013ed8c71f11e0b363b21d67e986e26dbbcc) |
| **20210927**| Patch header is now shorter (8 bytes compared to 24 bytes). Patch size is no longer a string. "NEWPATCH" has been shortened to "NEWP". | [cfa78347](https://gitlab.endian.se/thesis-projects/delta-updates-for-embedded-systems/-/commit/cfa78347cefd7b46330c46a17ffad75ccb58abee) |
| **20230525**| Lifted to Zephyr v3.3 | [15a8689](https://github.com/saralinnealindh/delta-updates-for-embedded-systems/commit/15a86891df7f148e71a3ea23763e1cf1c0e8f3bb) |
