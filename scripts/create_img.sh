#!/bin/bash -e
[ -z "$DIR" ] && { echo "undefined variable: \$DIR"; exit 1; }
[ -z "$targetdir" ] && { echo "undefined variable: \$targetdir"; exit 1; }

cd ${DIR}
rm -rf bela.img

echo "creating Bela SD image"

# create empty 4gb disk image
dd if=/dev/zero of=${DIR}/bela.img bs=100 count=38671483

# partition it
sudo sfdisk ${DIR}/bela.img < ${DIR}/bela.sfdisk

# mount it
LOOP=`losetup -f`
LOOP=`echo $LOOP | sed "s/\/dev\///"`
#sudo losetup /dev/$LOOP
# -s makes sure the operation is applied before continuing
sudo kpartx -s -av ${DIR}/bela.img
sudo mkfs.vfat /dev/mapper/${LOOP}p1
sudo dosfslabel /dev/mapper/${LOOP}p1 BELABOOT
sudo mkfs.ext4 /dev/mapper/${LOOP}p2
sudo e2label /dev/mapper/${LOOP}p2 BELAROOTFS

mkdir -p /mnt/bela/boot
mkdir -p /mnt/bela/root
sudo mount /dev/mapper/${LOOP}p1 /mnt/bela/boot
sudo mount /dev/mapper/${LOOP}p2 /mnt/bela/root

# complete and copy uboot environment
cp ${DIR}/boot/uEnv.txt ${DIR}/boot/uEnv.tmp
echo "uname_r=`cat ${DIR}/kernel/kernel_version`" >> ${DIR}/boot/uEnv.tmp
echo "dtb=am335x-bone-bela.dtb" >> ${DIR}/boot/uEnv.tmp
echo "#dtb=am335x-bone-bela-black-wireless.dtb" >> ${DIR}/boot/uEnv.tmp
echo "mmcid=0" >> ${DIR}/boot/uEnv.tmp
sudo cp -v ${DIR}/boot/uEnv.tmp /mnt/bela/boot/uEnv.txt
rm ${DIR}/boot/uEnv.tmp

# copy bootloader and dtb
# To boot properly MLO and u-boot.img have to be the first things copied onto the partition.
# We enforce this by `sync`ing to disk after every copy
sudo cp -v ${DIR}/boot/MLO /mnt/bela/boot/
sync
sudo cp -v ${DIR}/boot/u-boot.img /mnt/bela/boot/
sync
sudo cp -v $targetdir/opt/Bela/am335x-bone-bela*.dtb /mnt/bela/boot/
sync
# copying static extras to boot partition
sudo cp -rv ${DIR}/misc/boot/* /mnt/bela/boot/
sync

# copy rootfs
sudo cp -a ${DIR}/rootfs/* /mnt/bela/root/
# seal off the motd with current tag and commit hash
APPEND_TO_MOTD="sudo tee -a /mnt/bela/root/etc/motd"
printf "Bela image, `git -C ${DIR} describe --tags --dirty=++`, `date "+%e %B %Y"`\n\n" | ${APPEND_TO_MOTD}
printf "More info at https://github.com/BelaPlatform/bela-image-builder/releases\n\n" | ${APPEND_TO_MOTD}
printf "Built with bela-image-builder `git -C ${DIR} branch | grep '\*' | sed 's/\*\s//g'`@`git -C ${DIR} rev-parse HEAD`\non `date`\n\n" | ${APPEND_TO_MOTD}

# create uEnv.txt for emmc
cp ${DIR}/boot/uEnv.txt ${DIR}/boot/uEnv.tmp
echo "uname_r=`cat ${DIR}/kernel/kernel_version`" >> ${DIR}/boot/uEnv.tmp
echo "dtb=am335x-bone-bela.dtb" >> ${DIR}/boot/uEnv.tmp
echo "#dtb=am335x-bone-bela-black-wireless.dtb" >> ${DIR}/boot/uEnv.tmp
echo "mmcid=1" >> ${DIR}/boot/uEnv.tmp
sudo cp -v ${DIR}/boot/uEnv.tmp /mnt/bela/root/opt/Bela/uEnv-emmc.txt
rm ${DIR}/boot/uEnv.tmp

# unmount
sudo umount /mnt/bela/boot
sudo umount /mnt/bela/root
sudo kpartx -d /dev/${LOOP}
sudo losetup -d /dev/${LOOP}
sudo chown $SUDO_USER ${DIR}/bela.img

echo "bela.img created"
