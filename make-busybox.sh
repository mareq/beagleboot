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
BUSYBOX_SRC_PATH="${BUSYBOX_SRC_PATH:-"${SCRIPT_PATH}/sub/busybox"}"
ROOTFS_PATH="${ROOTFS_PATH:-"${BUSYBOX_SRC_PATH}/root-fs"}"

# source configuration
source "${SCRIPT_PATH}/config"

echo "= Root FileSystem ="
echo "Architecture: \`${BB_ARCH}\`"
echo "Cross-Compilation: \`${BB_CROSS_COMPILE_LINUX}\`"
echo "Default Configuration: \`${BB_BDEFCONFIG}\`"
echo "BusyBox Source Tree: \`${BUSYBOX_SRC_PATH}\`"
echo

# build busybox
echo "== Build =="
set -x
cd "${BUSYBOX_SRC_PATH}"
make ARCH=${BB_ARCH} CROSS_COMPILE=${BB_CROSS_COMPILE_LINUX} ${BB_BDEFCONFIG}
make ARCH=${BB_ARCH} CROSS_COMPILE=${BB_CROSS_COMPILE_LINUX} LDFLAGS="--static" CONFIG_PREFIX="${ROOTFS_PATH}" install -j $(nproc)
cd "${ROOTFS_PATH}" && find . | cpio --create --format=newc | gzip > "../initramfs.cpio.gz"
set +x

# done
echo
echo "== Built Targets =="
echo - root file-system:
ls -al "${ROOTFS_PATH}/"
echo - busybox executable:
ls -al "${ROOTFS_PATH}/bin/busybox"
file "${ROOTFS_PATH}/bin/busybox"
echo - initramfs image:
ls -al "$(realpath "${ROOTFS_PATH}/../initramfs.cpio.gz")"


# vim: ts=2 sw=2 et:


