-include Rules.make

all: linux matrix-gui arm-benchmarks am-sysinfo matrix-gui-browser refresh-screen qt-tstat u-boot-spl quick-playground av-examples ti-ocf-crypto-module 
clean: linux_clean matrix-gui_clean arm-benchmarks_clean am-sysinfo_clean matrix-gui-browser_clean refresh-screen_clean qt-tstat_clean u-boot-spl_clean quick-playground_clean av-examples_clean ti-ocf-crypto-module_clean 
install: linux_install matrix-gui_install arm-benchmarks_install am-sysinfo_install matrix-gui-browser_install refresh-screen_install qt-tstat_install u-boot-spl_install quick-playground_install av-examples_install ti-ocf-crypto-module_install 
# Kernel build targets
linux:
	@echo =================================
	@echo     Building the Linux Kernel
	@echo =================================
	$(MAKE) -C $(LINUXKERNEL_INSTALL_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) tisdk_$(PLATFORM)_defconfig
	$(MAKE) -C $(LINUXKERNEL_INSTALL_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) uImage
	$(MAKE) -C $(LINUXKERNEL_INSTALL_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) modules

linux_install:
	@echo ===================================
	@echo     Installing the Linux Kernel
	@echo ===================================
	install -d $(DESTDIR)/boot
	install $(LINUXKERNEL_INSTALL_DIR)/arch/arm/boot/uImage $(DESTDIR)/boot
	install $(LINUXKERNEL_INSTALL_DIR)/vmlinux $(DESTDIR)/boot
	install $(LINUXKERNEL_INSTALL_DIR)/System.map $(DESTDIR)/boot
	$(MAKE) -C $(LINUXKERNEL_INSTALL_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) INSTALL_MOD_PATH=$(DESTDIR) modules_install

linux_clean:
	@echo =================================
	@echo     Cleaning the Linux Kernel
	@echo =================================
	$(MAKE) -C $(LINUXKERNEL_INSTALL_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) mrproper
# Make Rules for matrix-gui project
matrix-gui:
	@echo =============================
	@echo      Building Matrix GUI
	@echo =============================
	@echo    NOTHING TO DO.  COMPILATION NOT REQUIRED

matrix-gui_clean:
	@echo =============================
	@echo      Cleaning Matrix GUI
	@echo =============================
	@echo    NOTHING TO DO.

matrix-gui_install:
	@echo =============================
	@echo     Installing Matrix GUI
	@echo =============================
	@cd example-applications; cd `find . -name "*matrix-gui-2.0*"`; make install
# arm-benchmarks build targets
arm-benchmarks:
	@echo =============================
	@echo    Building ARM Benchmarks
	@echo =============================
	@cd example-applications; cd `find . -name "*arm-benchmarks*"`; make

arm-benchmarks_clean:
	@echo =============================
	@echo    Cleaning ARM Benchmarks
	@echo =============================
	@cd example-applications; cd `find . -name "*arm-benchmarks*"`; make clean

arm-benchmarks_install:
	@echo ==============================================
	@echo   Installing ARM Benchmarks - Release version
	@echo ==============================================
	@cd example-applications; cd `find . -name "*arm-benchmarks*"`; make install

arm-benchmarks_install_debug:
	@echo ============================================
	@echo   Installing ARM Benchmarks - Debug Version
	@echo ============================================
	@cd example-applications; cd `find . -name "*arm-benchmarks*"`; make install_debug
# am-sysinfo build targets
am-sysinfo:
	@echo =============================
	@echo    Building AM Sysinfo
	@echo =============================
	@cd example-applications; cd `find . -name "*am-sysinfo*"`; make

am-sysinfo_clean:
	@echo =============================
	@echo    Cleaning AM Sysinfo
	@echo =============================
	@cd example-applications; cd `find . -name "*am-sysinfo*"`; make clean

am-sysinfo_install:
	@echo ===============================================
	@echo     Installing AM Sysinfo - Release version
	@echo ===============================================
	@cd example-applications; cd `find . -name "*am-sysinfo*"`; make install

am-sysinfo_install_debug:
	@echo =============================================
	@echo     Installing AM Sysinfo - Debug version
	@echo =============================================
	@cd example-applications; cd `find . -name "*am-sysinfo*"`; make install_debug
# matrix-gui-browser build targets
matrix-gui-browser:
	@echo =================================
	@echo    Building Matrix GUI Browser
	@echo =================================
	@cd example-applications; cd `find . -name "*matrix-gui-browser*"`; make -f Makefile.build release

matrix-gui-browser_clean:
	@echo =================================
	@echo    Cleaning Matrix GUI Browser
	@echo =================================
	@cd example-applications; cd `find . -name "*matrix-gui-browser*"`; make -f Makefile.build clean

matrix-gui-browser_install:
	@echo ===================================================
	@echo   Installing Matrix GUI Browser - Release version
	@echo ===================================================
	@cd example-applications; cd `find . -name "*matrix-gui-browser*"`; make -f Makefile.build install

matrix-gui-browser_install_debug:
	@echo =================================================
	@echo   Installing Matrix GUI Browser - Debug Version
	@echo =================================================
	@cd example-applications; cd `find . -name "*matrix-gui-browser*"`; make -f Makefile.build install_debug
# refresh-screen build targets
refresh-screen:
	@echo =============================
	@echo    Building Refresh Screen
	@echo =============================
	@cd example-applications; cd `find . -name "*refresh-screen*"`; make -f Makefile.build release

refresh-screen_clean:
	@echo =============================
	@echo    Cleaning Refresh Screen
	@echo =============================
	@cd example-applications; cd `find . -name "*refresh-screen*"`; make -f Makefile.build clean

refresh-screen_install:
	@echo ================================================
	@echo   Installing Refresh Screen - Release version
	@echo ================================================
	@cd example-applications; cd `find . -name "*refresh-screen*"`; make -f Makefile.build install

refresh-screen_install_debug:
	@echo ==============================================
	@echo   Installing Refresh Screen - Debug Version
	@echo ==============================================
	@cd example-applications; cd `find . -name "*refresh-screen*"`; make -f Makefile.build install_debug
# QT Thermostat build targets
qt-tstat:
	@echo ================================
	@echo    Building QT Thermostat App
	@echo ================================
	@cd example-applications; cd `find . -name "*qt-tstat*"`; make -f Makefile.build release

qt-tstat_clean:
	@echo ================================
	@echo    Cleaning QT Thermostat App
	@echo ================================
	@cd example-applications; cd `find . -name "*qt-tstat*"`; make -f Makefile.build clean

qt-tstat_install:
	@echo ===================================================
	@echo   Installing QT Thermostat App - Release version
	@echo ===================================================
	@cd example-applications; cd `find . -name "*qt-tstat*"`; make -f Makefile.build install

qt-tstat_install_debug:
	@echo =================================================
	@echo   Installing QT Thermostat App - Debug version
	@echo =================================================
	@cd example-applications; cd `find . -name "*qt-tstat*"`; make -f Makefile.build install_debug
# u-boot build targets
u-boot-spl: u-boot
u-boot-spl_clean: u-boot_clean
u-boot-spl_install: u-boot_install

u-boot:
	$(MAKE) -C $(TI_SDK_PATH)/board-support/u-boot-* CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_MACHINE)
	$(MAKE) -C $(TI_SDK_PATH)/board-support/u-boot-* CROSS_COMPILE=$(CROSS_COMPILE)

u-boot_clean:
	$(MAKE) -C $(TI_SDK_PATH)/board-support/u-boot-* CROSS_COMPILE=$(CROSS_COMPILE) clean

u-boot_install:
	install -d $(DESTDIR)/boot
	install $(TI_SDK_PATH)/board-support/u-boot-*/u-boot.img $(DESTDIR)/boot
	install $(TI_SDK_PATH)/board-support/u-boot-*/MLO $(DESTDIR)/boot
	install $(TI_SDK_PATH)/board-support/u-boot-*/u-boot.map $(DESTDIR)/boot
# Quick Playground build targets
quick-playground:
	@echo =================================
	@echo    Building Quick Playground App
	@echo =================================
	@cd example-applications; cd `find . -name "*quick-playground*"`; make -f Makefile.build release

quick-playground_clean:
	@echo =================================
	@echo    Cleaning Quick Playground App
	@echo =================================
	@cd example-applications; cd `find . -name "*quick-playground*"`; make -f Makefile.build clean

quick-playground_install:
	@echo ====================================================
	@echo   Installing Quick Playground App - Release version
	@echo ====================================================
	@cd example-applications; cd `find . -name "*quick-playground*"`; make -f Makefile.build install

quick-playground_install_debug:
	@echo ==================================================
	@echo   Installing Quick Playground App - Debug version
	@echo ==================================================
	@cd example-applications; cd `find . -name "*quick-playground*"`; make -f Makefile.build install_debug
# av-examples make targets
av-examples:
	@echo =============================
	@echo    Building AV Examples
	@echo =============================
	@cd example-applications; cd `find . -name "*av-examples*"`; make

av-examples_clean:
	@echo =============================
	@echo    Cleaning AV Examples
	@echo =============================
	@cd example-applications; cd `find . -name "*av-examples*"`; make clean

av-examples_install:
	@echo ==============================================
	@echo    Installing AV Examples - Release version
	@echo ==============================================
	@cd example-applications; cd `find . -name "*av-examples*"`; make install

av-examples_install_debug:
	@echo ============================================
	@echo    Installing AV Examples - Debug version
	@echo ============================================
	@cd example-applications; cd `find . -name "*av-examples*"`; make install_debug
# ti-ocf-crypto-module components
ti-ocf-crypto-module: linux
	@echo ===================================
	@echo    Building TI OCF Crypto Module
	@echo ===================================
	@cd board-support/extra-drivers; cd `find . -name "*ti-ocf-crypto-module*"`; make

ti-ocf-crypto-module_clean:
	@echo ===================================
	@echo    Cleaning TI OCF Crypto Module
	@echo ===================================
	@cd board-support/extra-drivers; cd `find . -name "*ti-ocf-crypto-module*"`; make clean

ti-ocf-crypto-module_install:
	@echo =====================================
	@echo    Installing TI OCF Crypto Module
	@echo =====================================
	@cd board-support/extra-drivers; cd `find . -name "*ti-ocf-crypto-module*"`; make install
