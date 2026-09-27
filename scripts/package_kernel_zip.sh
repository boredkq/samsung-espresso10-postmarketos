#!/usr/bin/env bash
# ==============================================================================
# package_kernel_zip.sh - Создание отдельного TWRP-прошиваемого ZIP ядра Linux 7.1.5
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10: GT-P5100, GT-P5110, GT-P5113)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${HOME}/.local/var/pmbootstrap"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BUILD_DIR="/tmp/kernel_twrp_build"

echo "================================================================="
echo " Сборка тестового TWRP ZIP только с ядром (boot.img + модули)"
echo "================================================================="

mkdir -p "$OUTPUT_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/META-INF/com/google/android"

# 1. Поиск boot.img
BOOT_IMG=""
if [ -f "$OUTPUT_DIR/boot.img" ]; then
    BOOT_IMG="$OUTPUT_DIR/boot.img"
elif [ -f "$WORK_DIR/chroot_rootfs_samsung-espresso10/boot/boot.img" ]; then
    BOOT_IMG="$WORK_DIR/chroot_rootfs_samsung-espresso10/boot/boot.img"
else
    BOOT_IMG=$(find "$WORK_DIR" -name "boot.img" 2>/dev/null | head -n 1 || true)
fi

if [ -z "$BOOT_IMG" ] || [ ! -f "$BOOT_IMG" ]; then
    echo "ПРЕДУПРЕЖДЕНИЕ: boot.img не найден в $OUTPUT_DIR или $WORK_DIR!"
    exit 0
fi

cp "$BOOT_IMG" "$BUILD_DIR/boot.img"
echo "-> Добавлен boot.img ($(du -h "$BUILD_DIR/boot.img" | cut -f1))"

# 2. Упаковка модулей ядра (brcmfmac.ko, brcmutil.ko и др.)
APK_FILE=$(find "$WORK_DIR/packages" -name "linux-postmarketos-omap-*.apk" 2>/dev/null | head -n 1 || true)
if [ -n "$APK_FILE" ] && [ -f "$APK_FILE" ]; then
    echo "-> Извлечение модулей из $APK_FILE..."
    TMP_EXTRACT="/tmp/apk_extract_$$"
    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"
    tar -xf "$APK_FILE" -C "$TMP_EXTRACT" 2>/dev/null || tar -xzf "$APK_FILE" -C "$TMP_EXTRACT" 2>/dev/null || true
    if [ -d "$TMP_EXTRACT/lib/modules" ]; then
        tar -czf "$BUILD_DIR/modules.tar.gz" -C "$TMP_EXTRACT" lib/modules
        echo "-> Добавлен modules.tar.gz ($(du -h "$BUILD_DIR/modules.tar.gz" | cut -f1))"
    fi
    rm -rf "$TMP_EXTRACT"
fi

# 3. Создание update-binary (POSIX shell installer для TWRP)
cat << 'EOF' > "$BUILD_DIR/META-INF/com/google/android/update-binary"
#!/sbin/sh
# TWRP update-binary for Samsung Galaxy Tab 2 10.1 (espresso10)
OUTFD=$2
ZIPFILE=$3

ui_print() {
    echo "ui_print $1" >&$OUTFD
    echo "ui_print" >&$OUTFD
}

set_progress() {
    echo "set_progress $1" >&$OUTFD
}

ui_print "==========================================="
ui_print " Samsung Galaxy Tab 2 10.1 (espresso10)    "
ui_print " Test Kernel: Linux OMAP 7.1.5            "
ui_print " Fixes: WM1811 Sound & BCM4330 WiFi       "
ui_print "==========================================="

set_progress 0.2

# Поиск раздела BOOT / KERNEL
BOOT_PART=""
for p in \
    /dev/block/platform/omap/omap_hsmmc.1/by-name/BOOT \
    /dev/block/platform/omap/omap_hsmmc.1/by-name/KERNEL \
    /dev/block/platform/omap/omap_hsmmc.1/by-name/boot \
    /dev/block/platform/omap/omap_hsmmc.1/by-name/kernel \
    /dev/block/by-name/BOOT \
    /dev/block/by-name/KERNEL \
    /dev/block/by-name/boot \
    /dev/block/by-name/kernel \
    /dev/block/mmcblk0p8; do
    if [ -b "$p" ]; then
        BOOT_PART="$p"
        break
    fi
done

if [ -z "$BOOT_PART" ]; then
    BOOT_PART=$(find /dev/block -name "BOOT" 2>/dev/null | head -n 1)
fi

if [ -z "$BOOT_PART" ]; then
    BOOT_PART=$(find /dev/block -name "KERNEL" 2>/dev/null | head -n 1)
fi

if [ -z "$BOOT_PART" ]; then
    ui_print "ОШИБКА: Раздел BOOT/KERNEL не найден!"
    exit 1
fi

ui_print "Целевой раздел boot: $BOOT_PART"
set_progress 0.4

TMPDIR="/tmp/kernel_twrp_install"
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"
unzip -o "$ZIPFILE" "boot.img" -d "$TMPDIR"

if [ ! -f "$TMPDIR/boot.img" ]; then
    ui_print "ОШИБКА: boot.img не найден в архиве!"
    exit 1
fi

ui_print "Прошивка boot.img..."
dd if="$TMPDIR/boot.img" of="$BOOT_PART" bs=4096
sync
ui_print "boot.img успешно записан!"
set_progress 0.7

# Установка модулей ядра
if unzip -l "$ZIPFILE" | grep -q "modules.tar.gz"; then
    ui_print "Распаковка модулей ядра..."
    unzip -o "$ZIPFILE" "modules.tar.gz" -d "$TMPDIR"

    MOUNT_POINT="/tmp/pmos_mnt"
    mkdir -p "$MOUNT_POINT"
    TARGET_DIR=""

    # 1. Проверяем уже смонтированные разделы
    if [ -d "/data/lib/modules" ]; then
        TARGET_DIR="/data"
    elif [ -d "/system/lib/modules" ]; then
        TARGET_DIR="/system"
    else
        # 2. Пробуем смонтировать DATAFS или SYSTEM
        for r in \
            /dev/block/platform/omap/omap_hsmmc.1/by-name/DATAFS \
            /dev/block/platform/omap/omap_hsmmc.1/by-name/data \
            /dev/block/platform/omap/omap_hsmmc.1/by-name/SYSTEM \
            /dev/block/platform/omap/omap_hsmmc.1/by-name/system \
            /dev/block/by-name/DATAFS \
            /dev/block/by-name/data \
            /dev/block/by-name/SYSTEM \
            /dev/block/by-name/system \
            /dev/block/mmcblk0p10 \
            /dev/block/mmcblk0p9; do
            if [ -b "$r" ]; then
                mount "$r" "$MOUNT_POINT" 2>/dev/null || mount -t ext4 "$r" "$MOUNT_POINT" 2>/dev/null
                if [ -d "$MOUNT_POINT/lib/modules" ]; then
                    TARGET_DIR="$MOUNT_POINT"
                    break
                else
                    umount "$MOUNT_POINT" 2>/dev/null || true
                fi
            fi
        done
    fi

    if [ -n "$TARGET_DIR" ]; then
        ui_print "Установка модулей в $TARGET_DIR/lib/modules/..."
        tar -xzf "$TMPDIR/modules.tar.gz" -C "$TARGET_DIR"
        sync
        ui_print "Модули ядра успешно установлены!"
        if [ "$TARGET_DIR" = "$MOUNT_POINT" ]; then
            umount "$MOUNT_POINT" 2>/dev/null || true
        fi
    else
        ui_print "Инфо: Раздел rootfs не смонтирован. boot.img прошит."
    fi
fi

set_progress 1.0
rm -rf "$TMPDIR"
ui_print "==========================================="
ui_print " Ядро успешно обновлено!                  "
ui_print " Перезагрузите устройство для проверки.    "
ui_print "==========================================="
exit 0
EOF

chmod +x "$BUILD_DIR/META-INF/com/google/android/update-binary"
echo "# dummy" > "$BUILD_DIR/META-INF/com/google/android/updater-script"

# 4. Создание ZIP-архива
FINAL_KERNEL_ZIP="$OUTPUT_DIR/kernel-samsung-espresso10-twrp.zip"
rm -f "$FINAL_KERNEL_ZIP"
(cd "$BUILD_DIR" && zip -r9 "$FINAL_KERNEL_ZIP" .)

echo "================================================================="
echo " АВТОНОМНЫЙ TWRP ZIP ЯДРА УСПЕШНО СОЗДАН!"
echo " Файл: $FINAL_KERNEL_ZIP"
echo " Размер: $(du -h "$FINAL_KERNEL_ZIP" | cut -f1)"
echo "================================================================="
rm -rf "$BUILD_DIR"
