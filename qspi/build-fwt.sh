#!/bin/bash -e
# Build mk4-time without STM32CubeIDE, matching its Release configuration, and write
# output/fwt.bin with the CRC appended (the same result as fw-crc.sh).
#
# Needs the Arm GNU Toolchain 14.3.rel1 (arm-none-eabi), the GCC that STM32CubeIDE's
# "GNU Tools for STM32 14.3.rel1" is built from:
#   https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
# Point TOOLCHAIN at its bin directory, e.g.
#   TOOLCHAIN=~/develop/arm-gnu-toolchain/arm-gnu-toolchain-14.3.rel1-x86_64-arm-none-eabi/bin ./build-fwt.sh
#
# Code matches the IDE build; the libgcc/newlib builds and a few equivalent instruction
# encodings differ, so the image is not byte-identical to one from the IDE.

cd "$(dirname "$0")"
QSPI="$PWD"
SRC="$(realpath ../mk4-time)"
BUILD="${BUILD:-$(mktemp -d)}"   # objects, map and elf; kept out of the repo
: "${TOOLCHAIN:?set TOOLCHAIN to the arm-none-eabi bin directory}"
TC="$TOOLCHAIN/arm-none-eabi-"

"${TC}gcc" --version | head -1
rm -rf "$BUILD"; mkdir -p "$BUILD"

MCU=(-mcpu=cortex-m4 -mfpu=fpv4-sp-d16 -mfloat-abi=hard -mthumb)
DEFS=(-DUSE_HAL_DRIVER -DSTM32L476xx -DUSE_FULL_LL_DRIVER)
INC=()
for d in Core/Inc Drivers/CMSIS/Device/ST/STM32L4xx/Include Drivers/CMSIS/Include \
  Drivers/STM32L4xx_HAL_Driver/Inc Drivers/STM32L4xx_HAL_Driver/Inc/Legacy FATFS/App FATFS/Target \
  Middlewares/ST/STM32_USB_Device_Library/Class/CDC/Inc Middlewares/ST/STM32_USB_Device_Library/Class/MSC/Inc \
  Middlewares/ST/STM32_USB_Device_Library/Class/MSC_CDC/Inc Middlewares/ST/STM32_USB_Device_Library/Core/Inc \
  Middlewares/Third_Party/FatFs/src USB_DEVICE/App USB_DEVICE/Target; do INC+=("-I$SRC/$d"); done

cd "$SRC"
# The IDE links objects in path order, with the startup file among them
mapfile -t FILES < <(find Core Drivers FATFS Middlewares USB_DEVICE \( -name '*.c' -o -name '*.s' \) | LC_ALL=C sort)
OBJS=()
for f in "${FILES[@]}"; do
  o="$BUILD/obj/${f%.*}.o"; mkdir -p "$(dirname "$o")"
  if [[ $f == *.s ]]; then
    "${TC}gcc" "${MCU[@]}" -g0 -c -x assembler-with-cpp --specs=nano.specs -o "$o" "$f"
  else
    "${TC}gcc" "${MCU[@]}" -std=gnu11 -g0 "${DEFS[@]}" "${INC[@]}" -O3 -ffunction-sections -fdata-sections \
      -Wall -c --specs=nano.specs -o "$o" "$f" 2>>"$BUILD/warnings.log"
  fi
  OBJS+=("$o")
done

"${TC}gcc" "${MCU[@]}" -o "$BUILD/mk4-time.elf" "${OBJS[@]}" -T"$SRC/STM32L476RGTX_FLASH.ld" \
  --specs=nosys.specs -Wl,-Map="$BUILD/mk4-time.map" -Wl,--gc-sections -static -u _printf_float \
  --specs=nano.specs -Wl,--start-group -lc -lm -Wl,--end-group 2>>"$BUILD/warnings.log"
"${TC}objcopy" -O binary "$BUILD/mk4-time.elf" "$BUILD/mk4-time.bin"
"${TC}size" "$BUILD/mk4-time.elf"

# Append the CRC-32/ISO-HDLC of the image, big endian, as fw-crc.sh does
python3 -I - "$BUILD/mk4-time.bin" "$QSPI/output/fwt.bin" <<'EOF'
import sys, zlib, struct
body = open(sys.argv[1], 'rb').read()
if len(body) != 192*1024 - 4:
    sys.exit(f"unexpected image size {len(body)}")
open(sys.argv[2], 'wb').write(body + struct.pack('>I', zlib.crc32(body)))
print("Created", sys.argv[2])
EOF
