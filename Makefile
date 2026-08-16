# ZMK buildroot — builds firmware for every keyboard submodule in Docker,
# using a single shared west workspace in ./build (zephyr + modules are
# downloaded once for all keyboards).
#
# Variables:
#   ZMK_REV=<tag|branch|sha>  override the ZMK revision pinned in the keyboard's
#                             config/west.yml (e.g. make ZMK_REV=main, ZMK_REV=v0.3.0)
#   PRISTINE=1                force a pristine build (required after switching ZMK_REV)
#   DOCKER=0                  run west natively instead of inside the build container
#   DOCKER_IMAGE=...          build container image
#   CMAKE_ARGS=...            extra cmake arguments appended to every build
#
# Firmware is copied to ./firmware/<artifact>.uf2

ZMK_REV ?=
DOCKER ?= 1
DOCKER_IMAGE ?= zmkfirmware/zmk-build-arm:stable
BUILD_DIR ?= build
FIRMWARE_DIR ?= firmware
CMAKE_ARGS ?=
PRISTINE ?=
# Blobless clones: full history metadata, file contents fetched on demand.
# Cuts the first `west update` download several-fold; safe for switching ZMK_REV.
WEST_UPDATE_ARGS ?= --fetch-opt=--filter=blob:none

.DEFAULT_GOAL := all

# ZMK <= v0.3.x is based on Zephyr 3.5 (hardware model v1); ZMK main is based
# on Zephyr 4.x (HWMv2 only). Several things differ between the two worlds.
ifneq ($(ZMK_REV),)
ifeq ($(filter v0.1% v0.2% v0.3%,$(ZMK_REV)),)
ZMK_MODERN := 1
endif
endif

ifeq ($(ZMK_MODERN),1)
# The legacy mriya board (config/boards) does not work on Zephyr 4.x: use the
# HWMv2 definition and strip the colliding legacy one from the staged config.
MRIYA_MX_BOARD_ROOT := -DBOARD_ROOT=$(CURDIR)/mriya46-mx/hwmv2
MRIYA_CHOC_BOARD_ROOT := -DBOARD_ROOT=$(CURDIR)/mriya46-choc/hwmv2
MRIYA_MX_STRIP_BOARDS := 1
# Zephyr 4.x renamed the XIAO boards; ZMK main extends them with a `zmk`
# variant that carries the ZMK defaults (USB/BLE, uf2 offsets, ...).
XIAO_BOARD := seeeduino_xiao/samd21g18a/zmk
XIAO_BLE_BOARD := xiao_ble/nrf52840/zmk
XIAO_RP2040_BOARD := xiao_rp2040/rp2040/zmk
else
XIAO_BOARD := seeeduino_xiao
XIAO_BLE_BOARD := seeeduino_xiao_ble
XIAO_RP2040_BOARD := seeeduino_xiao_rp2040
endif

ifeq ($(DOCKER),1)

# Re-invoke the same target inside the ZMK build container.
# Starts the docker daemon first if it is not running.
define zmk_build
	@docker info >/dev/null 2>&1 || sudo systemctl start docker
	docker run --rm \
		-v $(CURDIR):/work -w /work \
		-e HOME=/tmp \
		--user $(shell id -u):$(shell id -g) \
		$(DOCKER_IMAGE) \
		make $@ DOCKER=0 ZMK_REV="$(ZMK_REV)" PRISTINE="$(PRISTINE)" CMAKE_ARGS="$(CMAKE_ARGS)" WEST_UPDATE_ARGS="$(WEST_UPDATE_ARGS)"
endef

else

# $(call zmk_build,<keyboard-dir>,<artifact-name>,<board>[,<shield>[,<snippet>[,<extra-cmake-args>[,<strip-boards>]]]])
# The config is staged into the workspace so parts of it can be filtered per
# build (e.g. dropping the legacy board definition for Zephyr 4.x builds).
define zmk_build
	mkdir -p $(BUILD_DIR)/manifest $(FIRMWARE_DIR)
	cp $(1)/config/west.yml $(BUILD_DIR)/manifest/west.yml
	if [ -n "$(ZMK_REV)" ]; then \
		sed -i 's|revision: .*# zmk-revision.*|revision: $(ZMK_REV) # zmk-revision|' $(BUILD_DIR)/manifest/west.yml; \
	fi
	git -C $(BUILD_DIR)/manifest init -q 2>/dev/null || true
	if [ ! -d $(BUILD_DIR)/.west ]; then cd $(BUILD_DIR) && west init -l manifest; fi
	cd $(BUILD_DIR) && west update $(WEST_UPDATE_ARGS)
	cd $(BUILD_DIR) && west zephyr-export
	rm -rf $(BUILD_DIR)/config_$(2)
	cp -a $(1)/config $(BUILD_DIR)/config_$(2)
	$(if $(7),rm -rf $(BUILD_DIR)/config_$(2)/boards)
	cd $(BUILD_DIR) && west build -s zmk/app -p $(if $(PRISTINE),always,auto) -d build_$(2) -b $(3) $(if $(5),-S $(5)) -- \
		-DZMK_CONFIG=$(CURDIR)/$(BUILD_DIR)/config_$(2) $(if $(4),-DSHIELD="$(4)") $(CMAKE_ARGS) $(6)
	if [ -f $(BUILD_DIR)/build_$(2)/zephyr/zmk.uf2 ]; then \
		cp $(BUILD_DIR)/build_$(2)/zephyr/zmk.uf2 $(FIRMWARE_DIR)/$(2).uf2; \
	else \
		cp $(BUILD_DIR)/build_$(2)/zephyr/zmk.bin $(FIRMWARE_DIR)/$(2).bin; \
	fi
endef

endif

# ------------------------------------------------------------------ mriya46-mx

MRIYA46_MX_TARGETS := mriya46-mx-left mriya46-mx-right mriya46-mx-left-studio \
	mriya46-mx-settings-reset-left mriya46-mx-settings-reset-right

.PHONY: mriya46-mx $(MRIYA46_MX_TARGETS)

mriya46-mx: $(MRIYA46_MX_TARGETS)

mriya46-mx-left:
	$(call zmk_build,mriya46-mx,mriya46_mx_left,mriya_left,,,$(MRIYA_MX_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-mx-right:
	$(call zmk_build,mriya46-mx,mriya46_mx_right,mriya_right,,,$(MRIYA_MX_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-mx-left-studio:
	$(call zmk_build,mriya46-mx,mriya46_mx_left_studio,mriya_left,,studio-rpc-usb-uart,-DCONFIG_ZMK_STUDIO=y $(MRIYA_MX_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-mx-settings-reset-left:
	$(call zmk_build,mriya46-mx,mriya46_mx_left_settings_reset,mriya_left,settings_reset,,$(MRIYA_MX_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-mx-settings-reset-right:
	$(call zmk_build,mriya46-mx,mriya46_mx_right_settings_reset,mriya_right,settings_reset,,$(MRIYA_MX_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

# ---------------------------------------------------------------- mriya46-choc

MRIYA46_CHOC_TARGETS := mriya46-choc-left mriya46-choc-right mriya46-choc-left-studio \
	mriya46-choc-settings-reset-left mriya46-choc-settings-reset-right

.PHONY: mriya46-choc $(MRIYA46_CHOC_TARGETS)

mriya46-choc: $(MRIYA46_CHOC_TARGETS)

mriya46-choc-left:
	$(call zmk_build,mriya46-choc,mriya46_choc_left,mriya_left,,,$(MRIYA_CHOC_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-choc-right:
	$(call zmk_build,mriya46-choc,mriya46_choc_right,mriya_right,,,$(MRIYA_CHOC_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-choc-left-studio:
	$(call zmk_build,mriya46-choc,mriya46_choc_left_studio,mriya_left,,studio-rpc-usb-uart,-DCONFIG_ZMK_STUDIO=y $(MRIYA_CHOC_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-choc-settings-reset-left:
	$(call zmk_build,mriya46-choc,mriya46_choc_left_settings_reset,mriya_left,settings_reset,,$(MRIYA_CHOC_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

mriya46-choc-settings-reset-right:
	$(call zmk_build,mriya46-choc,mriya46_choc_right_settings_reset,mriya_right,settings_reset,,$(MRIYA_CHOC_BOARD_ROOT),$(MRIYA_MX_STRIP_BOARDS))

# --------------------------------------------------------------- revxlp42-choc

REVXLP42_CHOC_TARGETS := revxlp42-choc-xiao revxlp42-choc-xiao-ble revxlp42-choc-xiao-rp2040 \
	revxlp42-choc-xiao-studio revxlp42-choc-xiao-ble-studio revxlp42-choc-xiao-rp2040-studio \
	revxlp42-choc-settings-reset

.PHONY: revxlp42-choc $(REVXLP42_CHOC_TARGETS)

revxlp42-choc: $(REVXLP42_CHOC_TARGETS)

revxlp42-choc-xiao:
	$(call zmk_build,revxlp42-choc,revxlp_xiao,$(XIAO_BOARD),revxlp)

revxlp42-choc-xiao-ble:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_ble,$(XIAO_BLE_BOARD),revxlp)

revxlp42-choc-xiao-rp2040:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_rp2040,$(XIAO_RP2040_BOARD),revxlp)

revxlp42-choc-xiao-studio:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_studio,$(XIAO_BOARD),revxlp,studio-rpc-usb-uart,-DCONFIG_ZMK_STUDIO=y)

revxlp42-choc-xiao-ble-studio:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_ble_studio,$(XIAO_BLE_BOARD),revxlp,studio-rpc-usb-uart,-DCONFIG_ZMK_STUDIO=y)

revxlp42-choc-xiao-rp2040-studio:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_rp2040_studio,$(XIAO_RP2040_BOARD),revxlp,studio-rpc-usb-uart,-DCONFIG_ZMK_STUDIO=y)

revxlp42-choc-settings-reset:
	$(call zmk_build,revxlp42-choc,revxlp_xiao_ble_settings_reset,$(XIAO_BLE_BOARD),settings_reset)

# -------------------------------------------------------------------- generic

.PHONY: all clean distclean

all: mriya46-mx mriya46-choc revxlp42-choc

clean:
	rm -rf $(BUILD_DIR)/build_* $(BUILD_DIR)/config_* $(FIRMWARE_DIR)

distclean:
	rm -rf $(BUILD_DIR) $(FIRMWARE_DIR)

# --------------------------------------------------------------------- flash

# $(call uf2_flash,<artifact>,<label-glob-pattern>)
# Waits for the UF2 bootloader drive to appear (double-tap reset), mounts it
# via udisksctl if needed and copies the firmware onto it.
define uf2_flash
	@f="$(FIRMWARE_DIR)/$(1).uf2"; [ -f "$$f" ] || { echo "no $$f - build it first"; exit 1; }; \
	echo "Waiting for UF2 bootloader drive ($(2)) - double-tap reset..."; \
	dev=""; \
	for i in $$(seq 60); do \
		for d in /dev/sd? /dev/sd??; do \
			[ -b "$$d" ] || continue; \
			label=$$(lsblk -no LABEL "$$d" 2>/dev/null | head -1); \
			case "$$label" in $(2)) dev="$$d"; break;; esac; \
		done; \
		[ -n "$$dev" ] && break; sleep 1; \
	done; \
	[ -n "$$dev" ] || { echo "bootloader drive not found"; exit 1; }; \
	mp=$$(lsblk -no MOUNTPOINT "$$dev" | head -1); \
	if [ -z "$$mp" ]; then udisksctl mount -b "$$dev" >/dev/null; mp=$$(lsblk -no MOUNTPOINT "$$dev" | head -1); fi; \
	[ -n "$$mp" ] || { echo "mount failed"; exit 1; }; \
	cp "$$f" "$$mp/" && sync && echo "Flashed $$f -> $$mp" || { echo "copy failed"; exit 1; }
endef

XIAO_LABELS := XIAO-SENSE|XIAO-BLE
MRIYA_LABELS := Mriya*|MRIYA46*

.PHONY: flash-revxlp flash-revxlp-studio \
	flash-mriya46-mx-left flash-mriya46-mx-right flash-mriya46-mx-left-studio \
	flash-mriya46-choc-left flash-mriya46-choc-right flash-mriya46-choc-left-studio

flash-revxlp:
	$(call uf2_flash,revxlp_xiao_ble,$(XIAO_LABELS))

flash-revxlp-studio:
	$(call uf2_flash,revxlp_xiao_ble_studio,$(XIAO_LABELS))

flash-mriya46-mx-left:
	$(call uf2_flash,mriya46_mx_left,$(MRIYA_LABELS))

flash-mriya46-mx-right:
	$(call uf2_flash,mriya46_mx_right,$(MRIYA_LABELS))

flash-mriya46-mx-left-studio:
	$(call uf2_flash,mriya46_mx_left_studio,$(MRIYA_LABELS))

flash-mriya46-choc-left:
	$(call uf2_flash,mriya46_choc_left,$(MRIYA_LABELS))

flash-mriya46-choc-right:
	$(call uf2_flash,mriya46_choc_right,$(MRIYA_LABELS))

flash-mriya46-choc-left-studio:
	$(call uf2_flash,mriya46_choc_left_studio,$(MRIYA_LABELS))
