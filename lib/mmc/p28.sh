#!/bin/ash

#卸载p28分区

umount /dev/mapper/data

#格式化P28分区

mkfs.ext4 -F /dev/mapper/data

#手动挂载P28

mount /dev/mapper/data /mnt/data

#拷贝overlay分区文件到P28分区

cp -r /overlay/* /mnt/data

#检查是否拷贝成功，输入下面的命令回车看到 lost+found upper work文件夹，说明拷贝成功。

ls /mnt/data

#生成挂载文件

block detect > /etc/config/fstab

#把p28分区挂载到overlay

sed -i s#/mnt/data#/overlay# /etc/config/fstab

#把原来的overlay挂载取消

sed -i '12s/1/0/g' /etc/config/fstab

#最后的最后就是输入reboot后重启就可以

reboot
