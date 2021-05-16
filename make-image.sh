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
BUILD_PATH="${BUILD_PATH:-${SCRIPT_PATH}/build}"
mkdir -p "${BUILD_PATH}"
IMAGE_FILE="sdcard.img"
TMP_IMAGE_PATH="${TMP_IMAGE_PATH:-$(mktemp --tmpdir="${BUILD_PATH}" "${IMAGE_FILE}.XXXX")}"
BOOT_MOUNT_PATH="${BOOT_MOUNT_PATH:-$(mktemp --tmpdir="${BUILD_PATH}" --directory "mnt-boot.XXXX")}"
ROOTFS_MOUNT_PATH="${ROOTFS_MOUNT_PATH:-$(mktemp --tmpdir="${BUILD_PATH}" --directory "mnt-rootfs.XXXX")}"

# artefact paths
SPL=${SPL:-"$(realpath "${SCRIPT_PATH}/sub/u-boot/MLO")"}
UBOOT_IMAGE="${UBOOT_IMAGE:-"$(realpath "${SCRIPT_PATH}/sub/u-boot/u-boot.img")"}"
UBOOT_ENV="${UBOOT_ENV:-"$(realpath "${SCRIPT_PATH}/src/uEnv-min.txt")"}"
LINUX_IMAGE="${LINUX_IMAGE:-"$(realpath "${SCRIPT_PATH}/sub//beagleboard-linux/arch/arm/boot/uImage")"}"
DTB="${DTB:-"$(realpath "${SCRIPT_PATH}/sub/beagleboard-linux/arch/arm/boot/dts/am335x-boneblack-wireless.dtb")"}"
ROOTFS_PATH="${ROOTFS_PATH:-"$(realpath "${SCRIPT_PATH}/sub/busybox/root-fs")"}"
ROOTFS_INIT="${ROOTFS_INIT:-"$(realpath "${SCRIPT_PATH}/src/init")"}"
ROOTFS_FSTAB="${ROOTFS_FSTAB:-"$(realpath "${SCRIPT_PATH}/src/fstab")"}"
ROOTFS_HOSTNAME="${ROOTFS_HOSTNAME:-"$(realpath "${SCRIPT_PATH}/src/hostname")"}"
ROOTFS_PASSWD="${ROOTFS_PASSWD:-"$(realpath "${SCRIPT_PATH}/src/passwd")"}"
CURRENT_DATE="$(date --iso-8601=ns)"

# partitions (bytes)
ALIGNMENT_BYTES=${ALIGNMENT_BYTES:-$((4*1024*1024))}
SECTOR_BYTES=${SECTOR_BYTES:-512}
align_bytes()
{
  UNALIGNED="${1}"
  BLOCKS=$(((${UNALIGNED}-1)/${ALIGNMENT_BYTES}))
  ALIGNED=$(((${BLOCKS}*${ALIGNMENT_BYTES})+${ALIGNMENT_BYTES}))
  echo "${ALIGNED}"
}
bytes_to_sectors()
{
  BYTES="${1}"
  SECTORS="$((${BYTES}/${SECTOR_BYTES}))"
  if [ "${BYTES}" != "$((${SECTORS}*${SECTOR_BYTES}))" ]; then
    echo "FATAL: Bytes not aligned to sectors: ${BYTES}"
    exit 1
  fi
  echo "${SECTORS}"
}
BOOT_START_BYTES=$((1*${ALIGNMENT_BYTES}))
BOOT_SIZE_BYTES=${BOOT_SIZE_BYTES:-$((64*1024*1024))}
ROOTFS_START_BYTES=$(align_bytes $((${BOOT_START_BYTES}+${BOOT_SIZE_BYTES})))
#ROOTFS_DATASIZE_BYTES=$(du -cs "${ROOTFS_PATH}" | awk '/total/ {print $1}')
#ROOTFS_FREESIZE_BYTES=${ROOTFS_FREESIZE_BYTES:-$((32*1024*1024))}
#ROOTFS_SIZE_BYTES=$(align_bytes $((${ROOTFS_DATASIZE_BYTES}+${ROOTFS_FREESIZE_BYTES})))
ROOTFS_SIZE_BYTES=$(align_bytes $((64*1024*1024)))
TOTAL_SIZE_BYTES=$(align_bytes $((${ROOTFS_START_BYTES}+${ROOTFS_SIZE_BYTES})))

echo "= MMC Image ="
echo "Secondary Program Loader: \`${SPL}\`"
echo "U-Boot Image: \`${UBOOT_IMAGE}\`"
echo "U-Boot Configuration: \`${UBOOT_ENV}\`"
echo "Kernle Image: \`${LINUX_IMAGE}\`"
echo "Device Tree File: \`${DTB}\`"
echo "Root File System: \`${ROOTFS_PATH}\`"
echo "Init: \`${ROOTFS_INIT}\`"
echo "FSTab: \`${ROOTFS_FSTAB}\`"
echo "HostName: \`${ROOTFS_HOSTNAME}\`"
echo "Passwd: \`${ROOTFS_PASSWD}\`"
echo "MMC Image File: \`${BUILD_PATH}/${IMAGE_FILE}\`"
echo

# init sudo
sudo echo > /dev/null

# create the bulid directory
mkdir -p "${BUILD_PATH}"

# create the image file
fallocate -l ${TOTAL_SIZE_BYTES} "${TMP_IMAGE_PATH}"
# create the partition table
SFDISK_CMD="/sbin/sfdisk --force"
SFDISK_IN=$(cat << EOF
unit: sectors
sector-size: ${SECTOR_BYTES}

$(bytes_to_sectors "${BOOT_START_BYTES}"),$(bytes_to_sectors "${BOOT_SIZE_BYTES}"),0x0c,*
$(bytes_to_sectors "${ROOTFS_START_BYTES}"),$(bytes_to_sectors "${ROOTFS_SIZE_BYTES}"),0x83
EOF
)
echo "${SFDISK_IN}" | ${SFDISK_CMD} "${TMP_IMAGE_PATH}" > /dev/null 2>&1
echo "== Partition Table =="
/sbin/sfdisk -d "${TMP_IMAGE_PATH}"
echo

# get loop device to be used
LOOP_DEV=$(sudo losetup -f)
if [ "x${?}" != "x0" ]; then
  echo "ERROR: Unable to allocate loop device"
  exit 1
fi


# secondary program loader
#dd conv=notrunc if="${SPL}" of="${TMP_IMAGE_PATH}" bs=1k seek=0; sync
#dd conv=notrunc if="${SPL}" of="${TMP_IMAGE_PATH}" bs=1k seek=128; sync
#dd conv=notrunc if="${SPL}" of="${TMP_IMAGE_PATH}" bs=1k seek=256; sync
#dd conv=notrunc if="${SPL}" of="${TMP_IMAGE_PATH}" bs=1k seek=384; sync

# boot partition
echo "== Boot =="
sudo losetup --offset "${BOOT_START_BYTES}" --sizelimit "${BOOT_SIZE_BYTES}" "${LOOP_DEV}" "${TMP_IMAGE_PATH}"
sudo mkfs.vfat -F 16 "${LOOP_DEV}" -n "BOOT"
mkdir -p "${BOOT_MOUNT_PATH}"
sudo mount "${LOOP_DEV}" "${BOOT_MOUNT_PATH}"
sudo rsync -az --no-owner --no-group "${SPL}" "${BOOT_MOUNT_PATH}/."
sudo rsync -az --no-owner --no-group "${UBOOT_IMAGE}" "${BOOT_MOUNT_PATH}/."
sudo rsync -az --no-owner --no-group "${UBOOT_ENV}" "${BOOT_MOUNT_PATH}/uEnv.txt"
sudo rsync -az --no-owner --no-group "${DTB}" "${BOOT_MOUNT_PATH}/."
sudo rsync -az --no-owner --no-group "${LINUX_IMAGE}" "${BOOT_MOUNT_PATH}/."
TEMP_FILE="$(mktemp)"
echo "Linux BeagleBoot ${CURRENT_DATE}" > "${TEMP_FILE}" 
sudo cp "${TEMP_FILE}" "${BOOT_MOUNT_PATH}/boot.id"
sudo chmod 644 "${BOOT_MOUNT_PATH}/boot.id"
rm -f "${TEMP_FILE}"
echo
echo "Contents of BOOT partition \`$(cat "${BOOT_MOUNT_PATH}/boot.id")\`"
ls -al "${BOOT_MOUNT_PATH}/."
echo
sudo umount "${LOOP_DEV}"
rm -r "${BOOT_MOUNT_PATH}"
sudo losetup --detach "${LOOP_DEV}"

# root partition
echo "== RootFS =="
sudo losetup --offset "${ROOTFS_START_BYTES}" --sizelimit "${ROOTFS_SIZE_BYTES}" "${LOOP_DEV}" "${TMP_IMAGE_PATH}"
sudo mkfs.ext4 "${LOOP_DEV}" -L "RFS"
mkdir -p "${ROOTFS_MOUNT_PATH}"
sudo mount "${LOOP_DEV}" "${ROOTFS_MOUNT_PATH}"
sudo rsync -az --no-owner --no-group "${ROOTFS_PATH}/." "${ROOTFS_MOUNT_PATH}/."
sudo mkdir -p "${ROOTFS_MOUNT_PATH}/"{etc,tmp,proc,sys,dev,home,mnt,root,usr/{bin,sbin,lib},var,boot}
sudo chmod a+rwxt "${ROOTFS_MOUNT_PATH}/tmp"
sudo ln -s usr/lib "${ROOTFS_MOUNT_PATH}/lib"
sudo rsync -az --no-owner --no-group "${ROOTFS_INIT}" "${ROOTFS_MOUNT_PATH}/sbin/bb-init"
sudo rsync -az --no-owner --no-group "${ROOTFS_FSTAB}" "${ROOTFS_MOUNT_PATH}/etc/fstab"
sudo rsync -az --no-owner --no-group "${ROOTFS_HOSTNAME}" "${ROOTFS_MOUNT_PATH}/etc/hostname"
sudo rsync -az --no-owner --no-group "${ROOTFS_PASSWD}" "${ROOTFS_MOUNT_PATH}/etc/passwd"
sudo mknod "${ROOTFS_MOUNT_PATH}/dev/console" c 5 1
sudo mknod "${ROOTFS_MOUNT_PATH}/dev/null" c 1 3
sudo mknod "${ROOTFS_MOUNT_PATH}/dev/zero" c 1 5
TEMP_FILE="$(mktemp)"
echo "Linux BeagleBoot ${CURRENT_DATE}" > "${TEMP_FILE}" 
sudo cp "${TEMP_FILE}" "${ROOTFS_MOUNT_PATH}/rfs.id"
sudo chmod 644 "${ROOTFS_MOUNT_PATH}/rfs.id"
rm -f "${TEMP_FILE}"
echo
echo "Contents of RFS partition \`$(cat "${ROOTFS_MOUNT_PATH}/rfs.id")\`"
ls -al "${ROOTFS_MOUNT_PATH}/."
echo
sudo umount "${LOOP_DEV}"
rm -r "${ROOTFS_MOUNT_PATH}"
sudo losetup --detach "${LOOP_DEV}"

# save result
mv -f "${TMP_IMAGE_PATH}" "${BUILD_PATH}/${IMAGE_FILE}"

# cleanup
set +e
if [ -d "${BOOT_MOUNT_PATH}" ]; then
  rm -r "${BOOT_MOUNT_PATH}" || echo "Warning: Can not remove temporary mount-point for BOOT partition: \`${BOOT_MOUNT_PATH}\`"
fi
if [ -d "${ROOTFS_MOUNT_PATH}" ]; then
  rm -r "${ROOTFS_MOUNT_PATH}" || echo "Warning: Can not remove temporary mount-point for RFS partition: \`${ROOTFS_MOUNT_PATH}\`"
fi
sudo losetup -l | grep "${LOOP_DEV}" > /dev/null
if [ "x${?}" == "x0" ]; then
sudo losetup --detach "${LOOP_DEV}" || echo "Warning: Can not detach the loop device: \`${LOOP_DEV}\`"
fi

# done
echo "== Image =="
echo "Image file created: \`${BUILD_PATH}/${IMAGE_FILE}\`"


# vim: ts=2 sw=2 et:


