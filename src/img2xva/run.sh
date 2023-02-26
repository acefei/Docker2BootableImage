qcow2=${1?invalid input raw image}
qcow2_name=${qcow2%%.*}
qemu-img convert $qcow2 ${qcow2_name}.img
python3 img2xva.py ${qcow2_name}.img
