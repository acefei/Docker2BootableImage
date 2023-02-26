# Docker2BootableImage
Docker to bootable image conversion

## Usage
Run `make` to get help

```
https://github.com/OSInside/kiwi/issues/631
[  230s] [ INFO    ]: 09:19:47 | Creating raw disk image /usr/src/packages/KIWI-oem/SLES_15SP0_xen.x86_64-0.0.1.raw
[  230s] [ DEBUG   ]: 09:19:47 | EXEC: [qemu-img create /usr/src/packages/KIWI-oem/SLES_15SP0_xen.x86_64-0.0.1.raw 2782M]
[  230s] [ DEBUG   ]: 09:19:47 | EXEC: [losetup -f --show /usr/src/packages/KIWI-oem/SLES_15SP0_xen.x86_64-0.0.1.raw]
[  230s] [ DEBUG   ]: 09:19:47 | Initialize gpt disk
[  230s] [ DEBUG   ]: 09:19:47 | EXEC: [sgdisk --zap-all /dev/loop0]
[  231s] [ INFO    ]: 09:19:48 | --> creating EFI CSM(legacy bios) partition
[  231s] [ DEBUG   ]: 09:19:48 | EXEC: [sgdisk -n 1:0:+2M -c 1:p.legacy /dev/loop0]
[  232s] [ DEBUG   ]: 09:19:49 | EXEC: [sgdisk -t 1:EF02 /dev/loop0]
[  233s] [ INFO    ]: 09:19:50 | --> creating EFI partition
[  233s] [ DEBUG   ]: 09:19:50 | EXEC: [sgdisk -n 2:0:+20M -c 2:p.UEFI /dev/loop0]
[  234s] [ DEBUG   ]: 09:19:51 | EXEC: [sgdisk -t 2:EF00 /dev/loop0]
[  235s] [ INFO    ]: 09:19:52 | --> creating LVM root partition
[  235s] [ DEBUG   ]: 09:19:52 | EXEC: [sgdisk -n 3:0:0 -c 3:p.lxlvm /dev/loop0]
[  236s] [ DEBUG   ]: 09:19:53 | EXEC: [sgdisk -t 3:8E00 /dev/loop0]
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [kpartx -s -a /dev/loop0]
[  237s] [ INFO    ]: 09:19:55 | Creating EFI(fat16) filesystem on /dev/mapper/loop0p2
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [mkdosfs -F16 -I -n EFI /dev/mapper/loop0p2]
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [vgs --noheadings -o vg_name]
[  237s] [ INFO    ]: 09:19:55 | Creating volume group local
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [vgremove --force local]
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [pvcreate /dev/mapper/loop0p3]
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [vgcreate local /dev/mapper/loop0p3]
[  237s] [ INFO    ]: 09:19:55 | Creating volumes(ext4)
[  237s] [ DEBUG   ]: 09:19:55 | EXEC: [du -s --apparent-size --block-size 1 /usr/src/packages/KIWI-oem/build/image-root]
[  238s] [ DEBUG   ]: 09:19:55 | EXEC: [bash -c find /usr/src/packages/KIWI-oem/build/image-root | wc -l]
[  238s] [ INFO    ]: 09:19:55 | --> volume LVRoot with 2680 MB
[  238s] [ DEBUG   ]: 09:19:55 | EXEC: [lvcreate -L 2680 -n LVRoot local]
[  238s] [ DEBUG   ]: 09:19:55 | EXEC: Failed with stderr:   WARNING: Failed to connect to lvmetad. Falling back to device scanning.
[  238s]   /dev/local/LVRoot: not found: device not cleared
[  238s]   Aborting. Failed to wipe start of new LV.
[  238s] , stdout: (no output on stdout)
[  238s] [ ERROR   ]: 09:19:55 | KiwiCommandError: lvcreate: stderr:   WARNING: Failed to connect to lvmetad. Falling back to device scanning.
[  238s]   /dev/local/LVRoot: not found: device not cleared
[  238s]   Aborting. Failed to wipe start of new LV.
[  238s] , stdout: (no output on stdout)
```