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
UBOOT_SRC_PATH="${UBOOT_SRC_PATH:-"${SCRIPT_PATH}/sub/u-boot"}"

# source configuration
source "${SCRIPT_PATH}/config"

echo "= Boot Loader ="
echo "Architecture: \`${BB_ARCH}\`"
echo "Cross-Compilation: \`${BB_CROSS_COMPILE_BAREMETAL}\`"
echo "Default Configuration: \`${BB_UDEFCONFIG}\`"
echo "U-Boot Source Tree: \`${UBOOT_SRC_PATH}\`"
echo

# build u-boot
echo "== Build =="
set -x
cd "${UBOOT_SRC_PATH}"
make ARCH="${BB_ARCH}" CROSS_COMPILE="${BB_CROSS_COMPILE_BAREMETAL}" "${BB_UDEFCONFIG}"
make ARCH="${BB_ARCH}" CROSS_COMPILE="${BB_CROSS_COMPILE_BAREMETAL}" -j $(nproc)
set +x

# done
echo
echo "== Built Targets =="
echo - secondary program loader:
ls -al ${UBOOT_SRC_PATH}/MLO
echo - u-boot image:
ls -al ${UBOOT_SRC_PATH}/u-boot.img


# vim: ts=2 sw=2 et:


