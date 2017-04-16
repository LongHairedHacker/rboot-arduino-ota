ARDUINO_PACKAGE_BASE = ~/.arduino15/packages/esp8266
ARDUINO_ESP_VERSION = 2.3.0
ARDUINO_TOOLS_BIN = $(ARDUINO_PACKAGE_BASE)/tools/xtensa-lx106-elf-gcc/1.20.0-26-gb404fb9-2/bin
ESPTOOL2 = ../esptool2/esptool2

SRCS = main.cpp rboot-bigflash.c rboot-api.c
HEADERS = rboot.h
ARDUINO_LIBS = ESP8266WiFi ESP8266HTTPClient

LIBS = m gcc hal phy pp net80211 wpa crypto main2 wps \
		axtls smartconfig mesh wpa2 lwip_gcc stdc++

ARDUINO_CORES_BASE = $(ARDUINO_PACKAGE_BASE)/hardware/esp8266/$(ARDUINO_ESP_VERSION)/cores/esp8266
ARDUINO_VARIANT_BASE = $(ARDUINO_PACKAGE_BASE)/hardware/esp8266/$(ARDUINO_ESP_VERSION)/variants/nodemcu

ARDUINO_ESP_BASE = $(ARDUINO_PACKAGE_BASE)/hardware/esp8266/$(ARDUINO_ESP_VERSION)

CC = $(ARDUINO_TOOLS_BIN)/xtensa-lx106-elf-gcc
CXX = $(ARDUINO_TOOLS_BIN)/xtensa-lx106-elf-g++
AR = $(ARDUINO_TOOLS_BIN)/xtensa-lx106-elf-ar

CFLAGS = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ -g -w -Os -Wl,-EL\
			-Wpointer-arith  -Wno-implicit-function-declaration -fno-inline-functions \
			-nostdlib -mlongcalls -mtext-section-literals -falign-functions=4 \
			-MMD -std=gnu99 -ffunction-sections -fdata-sections \
			-DF_CPU=80000000L -DLWIP_OPEN_SRC -DARDUINO=10802 -DARDUINO_ESP8266_NODEMCU \
			-DARDUINO_ARCH_ESP8266 -DARDUINO_BOARD="ESP8266_NODEMCU" -DESP8266

CXXFLAGS =  -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ \
			 -c -w -Os -g -mlongcalls -mtext-section-literals -fno-exceptions \
			 -fno-rtti -falign-functions=4 -std=c++11 -MMD -ffunction-sections -fdata-sections \
			 -DF_CPU=80000000L -DLWIP_OPEN_SRC  \
			 -DARDUINO=10802 -DARDUINO_ESP8266_NODEMCU -DARDUINO_ARCH_ESP8266 \
			 -DARDUINO_BOARD="ESP8266_NODEMCU"  -DESP8266

ASMFLAGS = -D__ets__ -DICACHE_FLASH -U__STRICT_ANSI__ -c -g -x assembler-with-cpp \
			-Wl,-EL -MMD -mlongcalls -DF_CPU=80000000L -DLWIP_OPEN_SRC -DARDUINO=10802 \
			-DARDUINO_ESP8266_NODEMCU -DARDUINO_ARCH_ESP8266 \
			-DARDUINO_BOARD="ESP8266_NODEMCU" -DESP8266

INCLUDES = $(ARDUINO_PACKAGE_BASE)/hardware/esp8266/2.3.0/tools/sdk/include \
			$(ARDUINO_PACKAGE_BASE)/hardware/esp8266/2.3.0/tools/sdk/lwip/include \
			$(ARDUINO_PACKAGE_BASE)/hardware/esp8266/2.3.0/cores/esp8266 \
			$(ARDUINO_PACKAGE_BASE)/hardware/esp8266/2.3.0/variants/nodemcu



LDFLAGS = -g -w -Os -nostdlib -Wl,--no-check-sections -u call_user_start -Wl,-static \
		-Wl,--gc-sections -Wl,-wrap,system_restart_local -Wl,-wrap,register_chipv6_phy

LIBDIRS = $(ARDUINO_PACKAGE_BASE)/hardware/esp8266/$(ARDUINO_ESP_VERSION)/tools/sdk/lib \
			$(ARDUINO_PACKAGE_BASE)/hardware/esp8266/$(ARDUINO_ESP_VERSION)/tools/sdk/ld

OBJS = $(addprefix build/,$(addsuffix .o,$(SRCS)))

ARDUINO_CORE_SRCS = $(shell (cd $(ARDUINO_ESP_BASE); find ./cores  -regex ".*\.\(cpp\|c\|S\)"))
ARDUINO_CORE_OBJS = $(addprefix build/arduino/,$(addsuffix .o,$(subst ./,,$(ARDUINO_CORE_SRCS))))

ARDUINO_LIB_SRCS = $(foreach lib,$(ARDUINO_LIBS),$(shell (cd $(ARDUINO_ESP_BASE); find ./libraries/$(lib)/src -regex ".*\.\(cpp\|c\|S\)")))
ARDUINO_LIB_OBJS = $(addprefix build/arduino/,$(addsuffix .o,$(subst ./,,$(ARDUINO_LIB_SRCS))))
INCLUDES += $(foreach lib,$(ARDUINO_LIBS),$(ARDUINO_ESP_BASE)/libraries/$(lib)/src/)

INCLUDE_ARGS = $(addprefix -I ,$(INCLUDES))
LIBDIR_ARGS = $(addprefix -L ,$(LIBDIRS))
LIB_ARGS = $(addprefix -l,$(LIBS))


all: build/arduino.ar build/rom.bin

build/arduino/%.S.o: $(ARDUINO_ESP_BASE)/%.S
	mkdir -p $(dir $@)
	$(CC) $(ASMFLAGS) -o $@ $<

build/arduino/%.c.o: $(ARDUINO_ESP_BASE)/%.c
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDE_ARGS) -c -o $@ $<

build/arduino/%.cpp.o: $(ARDUINO_ESP_BASE)/%.cpp
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(INCLUDE_ARGS) -c -o $@ $<

build/arduino.ar: $(ARDUINO_CORE_OBJS) $(ARDUINO_LIB_OBJS)
	mkdir -p $(dir $@)
	$(AR) cru $@ $^

build/%.c.o: %.c $(HEADERS)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(INCLUDE_ARGS) -c -o $@ $<

build/%.cpp.o: %.cpp $(HEADERS)
	mkdir -p $(dir $@)
	$(CXX) $(CXXFLAGS) $(INCLUDE_ARGS) -c -o $@ $<

build/rom.elf: $(OBJS) build/arduino.ar
	mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) $(LIBDIR_ARGS) -T eagle.flash.1m256.rboot.ld -o $@ \
		-Wl,--start-group $^ $(LIB_ARGS) -Wl,--end-group

build/rom.bin: build/rom.elf
	mkdir -p $(dir $@)
	$(ESPTOOL2) -quiet -bin -boot2 $< $@ .text .data .rodata

clean:
	rm -rvf build
