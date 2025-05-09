卸载p28分区 data

umount /dev/mmcblk0p28

格式化P28分区

mkfs.ext4 -F /dev/mmcblk0p28

手动挂载P28

mount /dev/mmcblk0p28 /mnt/mmcblk0p28

拷贝overlay分区文件到P28分区

cp -r /overlay/* /mnt/mmcblk0p28

生成挂载文件

block detect > /etc/config/fstab

把p28分区挂载到overlay

sed -i s#/mnt/mmcblk0p28#/overlay# /etc/config/fstab

把原来的overlay挂载取消

sed -i '12s/1/0/g' /etc/config/fstab

重启

reboot
