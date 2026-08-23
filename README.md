# zmk-buildroot

Umbrella repository for ZMK keyboard configs (git submodules).

## Keyboards

| Keyboard | Switches | MCU / board | Firmware targets | Build | Flash (double-tap reset, then copy) |
|---|---|---|---|---|---|
| Mriya46 MX (`mriya46-mx`, split 46 keys) | MX | **nRF52840 (custom `mriya` board, Board-ID `nRF52840-Mriya`, Adafruit UF2 bootloader 0.6.3, SoftDevice S140 6.1.1 — verified)** | `mriya46_mx_left`, `mriya46_mx_right`, `mriya46_mx_left_studio`, `settings_reset` ×2 | `make mriya46-mx` — all; `make mriya46-mx-left`, `-right`, `-left-studio`, `-settings-reset-left/right` | `cp firmware/mriya46_mx_left.uf2 /run/media/$USER/Mriya/` — Adafruit nRF52 UF2 drive `Mriya`; repeat with `_right` for the right half (or `make flash-mriya46-mx-left/-right`) |
| Mriya46 Choc (`mriya46-choc`, split 46 keys) | Choc | **nRF52840 (custom `mriya` board, Board-ID `nRF52840-Mriya`, Adafruit UF2 bootloader 0.6.3, SoftDevice S140 6.1.1 — verified)** | `mriya46_choc_left`, `mriya46_choc_right`, `mriya46_choc_left_studio`, `settings_reset` ×2 | `make mriya46-choc` — all; `make mriya46-choc-left`, `-right`, `-left-studio`, `-settings-reset-left/right` | `cp firmware/mriya46_choc_left.uf2 /run/media/$USER/Mriya/` — same `Mriya` drive (or `make flash-mriya46-choc-left/-right`) |
| RevXLP42 Choc (`revxlp42-choc`, 42 keys, shield) | Choc | **XIAO BLE — nRF52840 (in use: Seeed XIAO nRF52840 Sense, `Seeed_XIAO_nRF52840_Sense`)** | `revxlp_xiao_ble`, `revxlp_xiao_ble_studio`, `settings_reset` | `make revxlp42-choc-xiao-ble`, `-xiao-ble-studio`, `-settings-reset` | `cp firmware/revxlp_xiao_ble.uf2 /run/media/$USER/XIAO-SENSE/` |
| | | Seeeduino XIAO — SAMD21G18A (untested) | `revxlp_xiao`, `revxlp_xiao_studio` | `make revxlp42-choc-xiao`, `-xiao-studio` | `cp firmware/revxlp_xiao.uf2 /run/media/$USER/Arduino/` |
| | | XIAO RP2040 (untested) | `revxlp_xiao_rp2040`, `revxlp_xiao_rp2040_studio` | `make revxlp42-choc-xiao-rp2040`, `-xiao-rp2040-studio` | `cp firmware/revxlp_xiao_rp2040.uf2 /run/media/$USER/RPI-RP2/` |

`make revxlp42-choc` builds all RevXLP targets; `make all` builds everything.
Submodule branches: `mriya46-mx` / `mriya46-choc` of mriya-zmk-config,
`revxlp42-choc` of revxlp-zmk-config.

All build logic lives in the root `Makefile`. Every keyboard is built in Docker
(`zmkfirmware/zmk-build-arm:stable`) from a single shared west workspace in
`./build` — zephyr and modules are downloaded once for all keyboards (blobless
clones). Firmware lands in `./firmware/<artifact>.uf2`.

Each submodule has the same layout: `config/` (west manifest, keymap,
keymap-editor JSON, board/shield), `build.yaml`, and its own
`.github/workflows/build.yml` based on ZMK's `build-user-config.yml`.

## Layers

The keymap is identical on every keyboard (shared 42-key grid; the four extra
Mriya keys — top-row corners and outer thumbs — are all empty). Legend: `.` =
empty, `_` = transparent (falls through), `s` suffix = sticky modifier,
`L1`-`L4` = momentary layer, `X/Y` = hold for modifier X (G=GUI, A=Alt,
C=Ctrl), tap for Y.

The outer columns are transparent on Symbol, Extend and Number, so the base
modifiers, Backspace and Tab keep working inside those layers regardless of
press order (`Ctrl+arrow`, `Alt+hjkl`, `GUI+digit`, …). On Control they are
empty on purpose.

**Base** — default layer. Every modifier is reachable from both hands:
Ctrl — left pinky, left thumb, right pinky; Alt — left pinky, right thumb;
GUI — left pinky, right thumb. Tap CAPS toggles the xkb layout
(`grp:caps_toggle`), `[` is `х` in the Russian layout, `` ` `` on the thumb
is `ё` and the zellij lock/unlock key.

```text
A/ESC  Q     W     E     R     T       Y     U     I     O     P     BSPC
C/CAPS A     S     D     F     G       H     J     K     L     '     [
LGUI   Z     X     C     V     B       N     M     ,     .     ;     C/TAB
                   L2    C/SPC G/ENT   A/`   RSHFT L1
```

**Symbol** — hold right outer thumb (L1). Bracket pairs mirror across the
hands; `:` and `"` complete the base-layer `;` and `'`. The sticky modifiers
on the right home row are for chords where the thumbs collide, e.g.
`$mod+Shift+minus` = `LGUI` + L1 + tap `J` + `A`.

```text
_     <     [     {     (     ~       ^     )     }     ]     >     _
_     -     *     =     _     $       #     SFTs  CTLs  ALTs  GUIs  "
_     +     |     @     /     %       :     \     &     ?     !     _
                  L3    _     _       _     _     _
```

**Extend** — hold left outer thumb (L2). Vim-style arrows with HOME/PGDN/PGUP/END
above them; the media and brightness keys match the sway `XF86*` bindings.
ESC/TAB/BKSP duplicate the base keys but auto-repeat when held (the base ones
are mod-taps).

```text
_     MUTE  PLAY  VOL-  VOL+  BRI+    HOME  PGDN  PGUP  END   .     _
_     GUIs  ALTs  CTLs  SFTs  BRI-    LEFT  DOWN  UP    RGHT  BKSP  _
_     ESC   PREV  NEXT  TAB   REP     REP   .     .     .     DEL   _
                  _     _     _       _     _     L3
```

**Number** — L1 + left outer thumb, or L2 + right outer thumb (L3). Odd digits
on the left, even on the right (sway pins odd workspaces to the left monitor);
F-keys sit under their digits. `. , - :` on the right home row cover IPs,
versions, dates and times without leaving the layer; Shift comes from the free
right thumb.

```text
_     7     5     3     1     9       8     0     2     4     6     _
_     GUIs  ALTs  CTLs  SFTs  F11     F12   .     ,     -     :     _
_     F7    F5    F3    F1    F9      F8    F10   F2    F4    F6    _
                  _     _     L4      _     _     _
```

**Control** — Number + the G/ENT thumb (L4), i.e. both outer thumbs + left
inner thumb. Deliberately awkward so it never fires by accident.

```text
.     CLR   .     .     .     BOOT    BOOT  .     .     .     CLR   .
.     BT0   BT1   BT2   BT3   BT4     BT4   BT3   BT2   BT1   BT0   .
.     STU   .     .     .     RST     RST   .     .     .     STU   .
                  .     .     .       .     .     .
```

Mod-taps use `tap-preferred`, 200 ms tapping term and
`require-prior-idle-ms = 125` — a key pressed within 125 ms after another key
is always a tap, so fast typing never produces a stray modifier. Holding
`C/SPC` for more than 200 ms gives Ctrl, not a space.

Host-side bindings that assume this keymap live in the dotfiles: sway
`$mod+grave` (drop-down terminal), `$mod+comma`/`period`/`Tab` (workspace
prev/next/back), zellij `Alt+=`/`Alt+;` (resize — `+`/`-` share a finger with
Alt).

## Building

```sh
git submodule update --init
make all                          # every keyboard, every target
make mriya46-mx                   # one keyboard (all its targets)
make mriya46-mx-left              # a single target
make revxlp42-choc-xiao-ble-studio
make ZMK_REV=main PRISTINE=1 all  # against ZMK main instead of the pinned tag
make ZMK_REV=<sha> PRISTINE=1 revxlp42-choc
```

The docker daemon is started automatically if it is not running (via sudo).
ZMK is pinned to the latest stable release in each submodule's
`config/west.yml` (line marked `# zmk-revision`); `ZMK_REV` overrides it per
build without touching the manifest. Use `PRISTINE=1` whenever `ZMK_REV`
changes.

## CI

`.github/workflows/build.yml` builds all keyboards in the ZMK build container
and uploads the firmware artifacts. `workflow_dispatch` accepts a `zmk_rev`
input to build against ZMK main or any commit. Each submodule additionally has
its own workflow based on ZMK's `build-user-config.yml`.

## Notes

- The `mriya` board exists in two formats: `config/boards/arm/mriya` (legacy,
  for ZMK v0.x / Zephyr 3.5) and `hwmv2/boards/mriya` (for ZMK main /
  Zephyr 4.x). The Makefile picks the right one based on `ZMK_REV`.
- ZMK Studio: flash a `*_studio` build and connect over USB; unlock with the
  `&studio_unlock` key on the Control layer.

## FAQ

**Where is the keymap declared? Is it shared between stable and main?**
In one place per keyboard: `config/<kb>.keymap` in the submodule. It is used
by every build — stable v0.3.0, ZMK main, local Makefile and CI — via
`ZMK_CONFIG`, overriding the board/shield default. The physical layout is also
single-sourced (`config/boards/arm/mriya/mriya-layouts.dtsi`; the HWMv2 board
includes it). Only the board definition itself exists twice (legacy + HWMv2),
because the Zephyr 3.5 and 4.x board formats are incompatible — when changing
pins, edit both.

**What does keymap-editor build?**
[keymap-editor](https://nickcoutsos.github.io/keymap-editor/) does not build
anything itself. It commits the edited `config/<kb>.keymap` to the submodule's
branch on GitHub; that push triggers the submodule's own workflow
(`build-user-config.yml@v0.3`), which builds every entry of that repo's
`build.yaml` against the pinned stable ZMK. The key layout it shows comes from
`config/<kb>.json`.

**Can I build a keymap-editor edit locally, including against main?**
Yes. Pull the submodule first (editor commits live only on GitHub), then build:

```sh
git -C mriya46-mx pull
make mriya46-mx                              # pinned stable
make ZMK_REV=main PRISTINE=1 mriya46-mx      # same keymap on ZMK main
```

**What is the ZMK Studio workflow?**
Flash a `*_studio` firmware (for splits — the central/left half; the other
half stays on the regular build), connect over USB, open [zmk.studio](https://zmk.studio)
(Chrome/WebSerial or the desktop app) and press the `&studio_unlock` key
(Control layer). Edits apply instantly and are stored in the settings
partition on the keyboard — they survive reboots and reflashes, but are
**not** written back to `config/<kb>.keymap`, so the repo and the device
diverge. Pick one source of truth (Studio or keymap-editor/git). To drop
Studio edits use "Restore Stock Settings" in Studio or flash the
`*_settings_reset` firmware (also clears BLE bonds). Studio edits bindings and
layers; combos, macros and behavior parameters are keymap-file only.

**Is anything cached between builds?**
Yes. The shared west workspace lives in `./build` (zephyr + modules,
downloaded once for all keyboards, blobless clones), and compilation is
incremental per build directory (`build/build_<artifact>`). `make clean`
removes build directories and firmware but keeps the workspace; `make
distclean` removes everything. Switching `ZMK_REV` refetches only the new
revision — always pass `PRISTINE=1` when you switch.

**Which firmware file do I flash, and how?**
Everything lands in `./firmware/`. Naming: `<kb>_<half/board>[_studio].uf2`,
e.g. `mriya46_mx_left_studio.uf2` or `revxlp_xiao_ble.uf2`.

1. Double-tap reset (or press a `&bootloader` key) — the UF2 bootloader drive
   mounts.
2. Copy the uf2 onto the drive; the board reboots into the new firmware by
   itself.
3. For splits repeat for the other half (`*_right.uf2`; the `*_studio` build
   goes on the central/left half only).

If the halves fail to pair afterwards or bindings act up, flash
`*_settings_reset.uf2` on both halves, wait ~10 s, then flash the regular
firmware again (this clears BLE bonds and stored settings).

**In what order do I flash wireless split halves?**
The central half of Mriya46 is the **left** one (`ZMK_SPLIT_ROLE_CENTRAL` on
`mriya_left`; the `_studio` build is also left). The order itself does not
matter — what matters is that **both halves run the same build**:

1. `*_right.uf2` → right half (peripheral)
2. `*_left.uf2` (or `*_left_studio.uf2`) → left half (central)
3. Power both on — they pair; connect the left half over USB when you need a
   cable or ZMK Studio. Never rely on the peripheral over USB — it only talks
   to the central over BLE.

If the halves fail to pair: flash `*_settings_reset.uf2` on both, wait ~10 s,
reflash the regular firmware and power both on at the same time next to each
other.

**How do I tell what is flashed from the host?**
`dmesg` / `lsusb`: a ZMK keyboard enumerates as `1d50:615e` with the product
name from `CONFIG_ZMK_KEYBOARD_NAME` (e.g. `Mriya46-MX`), full-speed USB on
nRF52840. A `*_studio` build additionally exposes a CDC-ACM serial port
(`/dev/ttyACM*`) — that is what zmk.studio connects to. A regular and an old
build of the same keyboard look identical in `dmesg` (same name), so go by
the presence of the ACM port or just reflash to be sure.
