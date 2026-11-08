#!/bin/sh
set -eu

if [ "$(uname -m)" != x86_64 ]; then
    echo "Expected the approved x64 workshop image." >&2
    exit 1
fi
root_number="$(findmnt --noheadings --raw --output MAJ:MIN /)"
root_device="$(lsblk --paths --noheadings --raw --output NAME,MAJ:MIN | awk -v root="$root_number" '$2 == root { print $1 }')"
case "$root_device" in
    /dev/nvme*) ;;
    *) echo "Expected an NVMe root disk, found $root_device" >&2; exit 1 ;;
esac

timeout="$(cat /sys/module/nvme_core/parameters/io_timeout)"
if [ "$timeout" != 240 ]; then
    echo "Expected nvme_core.io_timeout=240 after reboot, found $timeout." >&2
    exit 1
fi
initramfs="/boot/initrd.img-$(uname -r)"
for module in nvme nvme_core; do
    filename="$(modinfo -F filename "$module")"
    if [ "$filename" != "(builtin)" ]; then
        if ! lsinitramfs "$initramfs" | grep -F "/$(basename "$filename")" >/dev/null; then
            echo "NVMe driver $module is missing from $initramfs." >&2
            exit 1
        fi
    fi
done
nvme list
/usr/local/bin/sqlplus -V
/usr/local/bin/sql -version
/usr/local/bin/rwloadsim --version
/usr/bin/python3 -c 'import oracledb; print(oracledb.__version__)'
echo "NVMe root disk, drivers, initramfs, IO timeout and Oracle clients verified after reboot."
