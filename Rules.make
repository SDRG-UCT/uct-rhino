#platform
PLATFORM=rhino

#Architecture
ARCH=armv7a

#u-boot machine
UBOOT_MACHINE=rhino_config

#Points to the root of the RHINO SDK
export RHINO_SDK_PATH=__RHINO_SDK_PATH__

#root of the target file system for installing applications
DESTDIR=__DESTDIR__

#Points to the root of the Linux libraries and headers matching the
#demo file system.
export LINUX_DEVKIT_PATH=$(RHINO_SDK_PATH)/linux-devkit

#Cross compiler prefix
export CROSS_COMPILE=$(LINUX_DEVKIT_PATH)/bin/arm-arago-linux-gnueabi-

#Default CC value to be used when cross compiling.  This is so that the
#GNU Make default of "cc" is not used to point to the host compiler
export CC=$(CROSS_COMPILE)gcc

#Location of environment-setup file
export ENV_SETUP=$(LINUX_DEVKIT_PATH)/environment-setup

#The directory that points to the SDK kernel source tree
LINUXKERNEL_INSTALL_DIR=$(RHINO_SDK_PATH)/board-support/linux-2.6.37-psp04.02.00.07
