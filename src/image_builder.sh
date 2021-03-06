#!/bin/bash

set -eu
readonly SCRIPTPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPTNAME="${SCRIPTPATH}/$(basename "${BASH_SOURCE[0]}")"
readonly WORKSPACE=$(mktemp -dt "$(basename "$SCRIPTNAME").XXXXXXXXXX")

# raw Linux image
bootable_img=$SCRIPTPATH/linux.img
# docker export the root file system
rootfs_tarball=$SCRIPTPATH/rootfs.tar
mount_point=$WORKSPACE/mnt
# grup search by label for root partition
root_label=root
root_partition_uuid=$(cat /proc/sys/kernel/random/uuid)

teardown() {
    # catch original exit code
    exit_code=$?

    # process
    if [ -z "${DEBUG:-}" ];then
        rm -rf "$WORKSPACE"
    else
        echo "[Debug] workspace is $WORKSPACE"
    fi

    # exit with original exit code
    if [ $exit_code -eq 0 ];then
        echo '------------- List Partition Table ----------------'
        sgdisk -p "$bootable_img"
    else
        exit $exit_code
    fi
}
trap teardown EXIT

docker_export_rootfs() (
    [ -f "$rootfs_tarball" ] && return

    local target=rootfs

    # Note:
    # the Centos kernel generated by yum install kernel didn't have ext4 filesystem compiled in, it's in a module.
    # so that need to boot up with the initramfs that have ext4 module on /lib/modules/<kernel version>/kernel/fs/ext4/ext4.ko.xz
    DOCKER_BUILDKIT=1 docker build -t $target -<<'EOF'
FROM centos:7.9.2009

# install vmlinuz and initramfs on /boot
RUN yum update -y \
    && yum install -y kernel \
    && KERNEL_PATH=$(rpm -ql kernel | grep '/boot/vmlinuz') \
    && INITRAMFS_PATH=$(rpm -ql kernel | grep initramfs) \
    && KERNEL_VERSION=${KERNEL_PATH#*-} \
    && dracut --filesystems ext4 -f $INITRAMFS_PATH $KERNEL_VERSION \
    && cp $KERNEL_PATH /boot/vmlinuz \
    && cp $INITRAMFS_PATH /boot/initrd.img

FROM centos:7.9.2009
COPY --from=0 /boot/vmlinuz /boot/vmlinuz
COPY --from=0 /boot/initrd.img /boot/initrd.img
RUN sed -i 's!/agetty!/agetty --autologin root!' /lib/systemd/system/serial-getty@.service \
    && cp /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service
EOF

    docker export -o $rootfs_tarball $(docker run -d $target /bin/true)
)

create_partitioned_image() {
    [ -f "$bootable_img" ] && return

    local image_size=10G
    local rootfs_partition_num=2
    # Create sparse file to represent our disk
    truncate --size $image_size $bootable_img

    # Create partition layout, find the typecode by sgdisk --list-types
     sgdisk --clear \
            --new 1::+1M --typecode=1:ef02 --change-name=1:'grub' \
            --new $rootfs_partition_num::-0 --typecode=$rootfs_partition_num:8300 \
                                            --change-name=$rootfs_partition_num:'rootfs' \
                                            --partition-guid=$rootfs_partition_num:$root_partition_uuid \
                  $bootable_img
}

create_grub_cfg() {
    # based on https://github.com/buildroot/buildroot/blob/master/boot/grub2/grub.cfg
    # add rw into kernel parameter to mount root device read-write on boot
    # more details find https://www.kernel.org/doc/html/latest/admin-guide/kernel-parameters.html
    local grub_cfg=${1:-grub.cfg}
    cat > $grub_cfg <<EOF
set default="0"
set timeout="3"

menuentry "Appliance Root" {
    search --label $root_label --set root
    linux /boot/vmlinuz root=PARTUUID=$root_partition_uuid rw console=tty0 console=ttyS0
    initrd /boot/initrd.img
}
EOF
}

# run as subshell with kpartx
install_grub2() (
    # losetup -P to add partition mappings on /dev/loop[0-7]pN, just like `kpartx -a` that add mappings under /dev/mapper.
    local loopdev=$(losetup -P -f --show "$bootable_img")
    local clean_up_cmds='losetup -d $loopdev'
    trap '[ -n "${DEBUG:-}" ] && exit; echo "Clean up $loopdev..."; eval "$clean_up_cmds"' EXIT

    # wait for partition mappings
    sleep 2

    # p2 means partition 2 which created above for Linux root filesystem
    rootfs_partition=${loopdev}p2
    mkfs.ext4 -F -L $root_label $rootfs_partition

    # Mount the filesystem
    mkdir $mount_point
    mount $rootfs_partition $mount_point
    clean_up_cmds=$clean_up_cmds';umount $mount_point'

    # Copy in the files from rootfs tarball
    tar xf $rootfs_tarball -C $mount_point

    # ref https://www.gnu.org/software/grub/manual/grub/html_node/Installing-GRUB-using-grub_002dinstall.html
    grub2-install --root-directory=$mount_point $loopdev

    create_grub_cfg $mount_point/boot/grub2/grub.cfg
)

main() {
    docker_export_rootfs
    create_grub_cfg
    create_partitioned_image
    install_grub2
}

if [ $# -lt 1 ];then
    main
else
    eval "$@"
fi
