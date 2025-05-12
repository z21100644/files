#!/bin/ash

# 配置参数
OVERLAY_PATH="/overlay"
THRESHOLD_MB=200
KEY_FILE="/lib/mmc/data_key"

# 带颜色输出的日志函数
error_echo() { echo -e "\033[31m[ERROR] $*\033[0m"; exit 1; }
warn_echo() { echo -e "\033[33m[WARN] $*\033[0m"; }
info_echo() { echo -e "\033[32m[INFO] $*\033[0m"; }

# 安全获取overlay容量（MB）
get_overlay_size() {
    local output size_kb
    # 使用POSIX兼容的方式获取块数
    if ! output=$(df -k "$OVERLAY_PATH" | awk 'NR==2 {print $2}'); then
        error_echo "无法获取overlay分区信息"
    fi
    
    # 验证数值有效性
    echo "$output" | grep -qE '^[0-9]+$' || error_echo "无效的容量数值: $output"
    
    # 转换为MB（向上取整）
    size_mb=$(( (output + 1023) / 1024 )) 
    echo $size_mb
}

# 主流程
main() {
    # 前置检查
    if ! mountpoint -q "$OVERLAY_PATH"; then
        error_echo "overlay分区未挂载"
    fi

    # 容量检测
    overlay_size=$(get_overlay_size)
    if [ "$overlay_size" -ge "$THRESHOLD_MB" ]; then
        warn_echo "overlay容量充足(${overlay_size}MB)，跳过操作"
        exit 0
    fi
    info_echo "检测到overlay容量不足(${overlay_size}MB < ${THRESHOLD_MB}MB)，开始扩容..."

    # 动态分区探测（改进版本）
    data_mmcblk=$(
        find /sys/block/mmcblk0 -name uevent -exec grep -l "PARTNAME=data" {} + \
        | awk -F'/' '{print $5}'
    )
    [ -b "/dev/$data_mmcblk" ] || error_echo "未找到data分区设备"

    # LUKS操作流程
    info_echo "正在解密加密分区..."
    cryptsetup --key-file="$KEY_FILE" luksOpen "/dev/$data_mmcblk" data || {
        error_echo "LUKS解密失败"
    }

    # 格式化验证
    info_echo "格式化加密分区..."
    if ! mkfs.ext4 -F /dev/mapper/data; then
        cryptsetup luksClose data
        error_echo "格式化失败"
    fi

    # 挂载操作
    mkdir -p /mnt/data || error_echo "无法创建挂载点"
    if ! mount /dev/mapper/data /mnt/data; then
        cryptsetup luksClose data
        error_echo "挂载失败"
    fi

    # 数据迁移
    info_echo "开始迁移overlay数据..."
    if ! cp -a /overlay/. /mnt/data; then
        umount /mnt/data
        cryptsetup luksClose data
        error_echo "数据拷贝失败"
    fi
    sync

    # 配置生成
    info_echo "更新系统配置..."
    block detect > /etc/config/fstab || error_echo "生成fstab失败"
    sed -i "s#/mnt/data#/overlay#" /etc/config/fstab

    # 智能修改原配置（避免行号依赖）
    awk -i inplace '
        /\/overlay/ && $0 ~ /mount/ {
            sub(/1/, "0", $0)
            modified=1
        }
        {print}
        END {
            if (!modified) print "未找到overlay配置项" > "/dev/stderr"
        }
    ' /etc/config/fstab

    info_echo "操作完成，即将重启..."
    cryptsetup luksClose data
    reboot
}

# 执行入口
main "$@"
