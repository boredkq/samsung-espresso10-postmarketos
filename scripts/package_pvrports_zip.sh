#!/usr/bin/env bash
# ==============================================================================
# package_pvrports_zip.sh - Создание TWRP-прошиваемого архива 3D ускорения PVRports
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10: GT-P5100, GT-P5110, GT-P5113)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BUILD_DIR="/tmp/pvrports_zip_build"
PVR_BASE="https://pvrports.antonialoytorrens.com/pvrports/v23.12/armv7"

echo "================================================================="
echo " Сборка TWRP ZIP с 3D ускорением PVRports (PowerVR SGX540)"
echo "================================================================="

mkdir -p "$OUTPUT_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/META-INF/com/google/android"
mkdir -p "$BUILD_DIR/rootfs"

TMP_DOWNLOAD="/tmp/pvr_apk_downloads"
rm -rf "$TMP_DOWNLOAD"
mkdir -p "$TMP_DOWNLOAD"

PVR_PACKAGES=(
    "pvrports-keys-1-r0.apk"
    "sgx-ddk-um-1.17.4948957-r1.apk"
    "sgx-ddk-um-ti443x-1.17.4948957-r1.apk"
    "sgx-ddk-um-openrc-1.17.4948957-r1.apk"
    "mesa-pvr-dri-classic-21.3.9-r1.apk"
    "libglvnd-1.6.0-r2.apk"
)

echo "-> Скачивание бинарных пакетов PVRports с официального зеркала..."
for pkg in "${PVR_PACKAGES[@]}"; do
    echo "   Скачивание $pkg..."
    wget -q -O "$TMP_DOWNLOAD/$pkg" "$PVR_BASE/$pkg" || {
        echo "Ошибка скачивания $pkg"
        exit 1
    }
    tar -xf "$TMP_DOWNLOAD/$pkg" -C "$BUILD_DIR/rootfs" 2>/dev/null || \
    tar -xzf "$TMP_DOWNLOAD/$pkg" -C "$BUILD_DIR/rootfs" 2>/dev/null || true
done

# Удаляем метаданные пакетов apk из распакованного дерева
rm -f "$BUILD_DIR/rootfs/.PKGINFO" "$BUILD_DIR/rootfs/.SIGN."*

# Создаем конфигурационный маркер
mkdir -p "$BUILD_DIR/rootfs/etc/pvrports"
cat << 'EOF' > "$BUILD_DIR/rootfs/etc/pvrports/pvrports.conf"
PVR_CHIPSET=omap4
PVR_GPU=sgx540
PVR_DRIVER_VER=1.17
PVR_ACCELERATION=enabled
EOF

# Пакуем файлы системы в files.tar.gz
echo "-> Создание архива файлов системы files.tar.gz..."
tar -czf "$BUILD_DIR/files.tar.gz" -C "$BUILD_DIR/rootfs" .
rm -rf "$BUILD_DIR/rootfs" "$TMP_DOWNLOAD"

# Создаем установщик update-binary для TWRP
cat << 'EOF' > "$BUILD_DIR/META-INF/com/google/android/update-binary"
#!/sbin/sh
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
ui_print " PVRports 3D Hardware Acceleration         "
ui_print " PowerVR SGX540 DDK 1.17 + Mesa Classic DRI"
ui_print "==========================================="

set_progress 0.2

# Поиск и монтирование корневой файловой системы postmarketOS
TARGET_DIR=""
MOUNT_POINT="/tmp/pmos_root"

# 1. Проверяем уже смонтированные разделы в TWRP
if [ -d "/data/usr/lib" ] || [ -d "/data/lib" ]; then
    TARGET_DIR="/data"
elif [ -d "/system/usr/lib" ] || [ -d "/system/lib" ]; then
    TARGET_DIR="/system"
fi

# 2. Если не смонтированы, монтируем DATAFS или SYSTEM
if [ -z "$TARGET_DIR" ]; then
    mkdir -p "$MOUNT_POINT"
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
            if [ -d "$MOUNT_POINT/usr" ] || [ -d "$MOUNT_POINT/etc" ]; then
                TARGET_DIR="$MOUNT_POINT"
                break
            else
                umount "$MOUNT_POINT" 2>/dev/null || true
            fi
        fi
    done
fi

if [ -z "$TARGET_DIR" ]; then
    ui_print "ОШИБКА: Не удалось смонтировать раздел с postmarketOS!"
    exit 1
fi

ui_print "Корневой раздел найден: $TARGET_DIR"
set_progress 0.5

TMPDIR="/tmp/pvr_twrp_install"
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"

ui_print "Распаковка 3D библиотек и служб..."
unzip -o "$ZIPFILE" "files.tar.gz" -d "$TMPDIR"

if [ ! -f "$TMPDIR/files.tar.gz" ]; then
    ui_print "ОШИБКА: files.tar.gz не найден в архиве!"
    exit 1
fi

tar -xzf "$TMPDIR/files.tar.gz" -C "$TARGET_DIR"
sync
set_progress 0.8

# Включение службы OpenRC sgx-ddk-um в уровень запуска default
if [ -d "$TARGET_DIR/etc/runlevels/default" ] && [ -f "$TARGET_DIR/etc/init.d/sgx-ddk-um" ]; then
    ln -sf /etc/init.d/sgx-ddk-um "$TARGET_DIR/etc/runlevels/default/sgx-ddk-um"
fi

if [ "$TARGET_DIR" = "$MOUNT_POINT" ]; then
    umount "$MOUNT_POINT" 2>/dev/null || true
fi

set_progress 1.0
rm -rf "$TMPDIR"

ui_print "==========================================="
ui_print " 3D ускорение PVRports успешно установлено!"
ui_print " Перезагрузите планшет: Reboot System      "
ui_print "==========================================="
exit 0
EOF

chmod +x "$BUILD_DIR/META-INF/com/google/android/update-binary"
echo "# dummy" > "$BUILD_DIR/META-INF/com/google/android/updater-script"

FINAL_PVR_ZIP="$OUTPUT_DIR/pvrports-samsung-espresso10-twrp.zip"
rm -f "$FINAL_PVR_ZIP"
(cd "$BUILD_DIR" && zip -r9 "$FINAL_PVR_ZIP" .)

echo "================================================================="
echo " TWRP ZIP 3D УСКОРЕНИЯ УСПЕШНО СОЗДАН!"
echo " Файл: $FINAL_PVR_ZIP"
echo " Размер: $(du -h "$FINAL_PVR_ZIP" | cut -f1)"
echo "================================================================="
rm -rf "$BUILD_DIR"
