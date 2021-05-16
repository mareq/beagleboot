#!/usr/bin/env bash

#set -x
set -e

# directories and files
get_script_path () {
   SCRIPT_FILE="${0}"
   # while ${SCRIPT_FILE} is a symlink, resolve it
   while [ -h "${SCRIPT_FILE}" ]; do
      SCRIPT_PATH="$(cd -P "$(dirname "${SCRIPT_FILE}")" && pwd)"
      SCRIPT_FILE="$(readlink "${SCRIPT_FILE}")"
      # if ${SCRIPT_FILE} was a relative symlink
      # (so no `/` as prefix, need to resolve it relative to the symlink base directory)
      [[ "${SCRIPT_FILE}" =~ ^/.* ]] || SCRIPT_FILE="${SCRIPT_PATH}/${SCRIPT_FILE}"
   done
   SCRIPT_PATH="$( cd -P "$( dirname "${SCRIPT_FILE}" )" && pwd )"
   echo "${SCRIPT_PATH}"
}
SCRIPT_PATH="$(get_script_path)"
CURRENT_PATH="$(pwd)"
UBOOT_TOOLS_PATH="${UBOOT_TOOLS_PATH:-"${SCRIPT_PATH}/u-boot/tools"}"
KERNEL_SRC_PATH="${KERNEL_SRC_PATH:-"${SCRIPT_PATH}/sub/beagleboard-linux"}"

# source configuration
source "${SCRIPT_PATH}/config"

echo "= Linux Kernel ="
echo "Architecture: \`${BB_ARCH}\`"
echo "Cross-Compilation: \`${BB_CROSS_COMPILE_BAREMETAL}\`"
echo "Default Configuration: \`${BB_KDEFCONFIG}\`"
echo "Kernel Source Tree: \`${KERNEL_SRC_PATH}\`"
echo "U-Boot Tools: \`${UBOOT_TOOLS_PATH}\`"
echo

# mkimage from u-boot is needed
PATH=${UBOOT_TOOLS_PATH}:${PATH}

# build kernel
echo "== Build =="
set -x
cd "${KERNEL_SRC_PATH}"
make ARCH="${BB_ARCH}" CROSS_COMPILE="${BB_CROSS_COMPILE_BAREMETAL}" "${BB_KDEFCONFIG}"
make ARCH="${BB_ARCH}" CROSS_COMPILE="${BB_CROSS_COMPILE_BAREMETAL}" uImage dtbs LOADADDR=0x80008000 -j $(nproc)
set +x

# done
echo
echo "== Built Targets =="
echo - kernel image:
ls -al "${KERNEL_SRC_PATH}/arch/${BB_ARCH}/boot/uImage"
echo - device tree file:
ls -al "${KERNEL_SRC_PATH}/arch/${BB_ARCH}/boot/dts/am335x-boneblack-wireless.dtb"


# vim: ts=2 sw=2 et:


