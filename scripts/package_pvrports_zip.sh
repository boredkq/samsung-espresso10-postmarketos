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
    tar -xzf "$TMP_DOWNLOAD/$pkg" -C "$BUILD_DIR/rootfs"
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

# Функция надежного монтирования rootfs postmarketOS (включая вложенные разделы MBR)
find_and_mount_rootfs() {
    M_DIR="/tmp/pmos_root"
    mkdir -p "$M_DIR"

    # 1. Проверяем уже смонтированные разделы в TWRP
    if [ -d "/data/etc" ] && [ -d "/data/usr" ]; then
        echo "/data"
        return 0
    fi
    if [ -d "/system/etc" ] && [ -d "/system/usr" ]; then
        echo "/system"
        return 0
    fi

    # 2. Проверяем существующие узлы device-mapper и субразделов
    for dev in \
        /dev/mapper/*p2 \
        /dev/mapper/pmOS_root \
        /dev/mapper/*root* \
        /dev/block/mmcblk0p10p2 \
        /dev/block/platform/omap/omap_hsmmc.1/by-name/DATAFS*p2 \
        /dev/loop*p2; do
        if [ -b "$dev" ]; then
            if mount -t ext4 -o rw "$dev" "$M_DIR" 2>/dev/null || mount "$dev" "$M_DIR" 2>/dev/null; then
                if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                    echo "$M_DIR"
                    return 0
                fi
                umount "$M_DIR" 2>/dev/null || true
            fi
        fi
    done

    # 3. Поиск по метке файловой системы pmOS_root
    dev_by_label=$(findfs LABEL="pmOS_root" 2>/dev/null || findfs LABEL=pmOS_root 2>/dev/null || true)
    if [ -z "$dev_by_label" ]; then
        dev_by_label=$(blkid 2>/dev/null | grep 'LABEL="pmOS_root"' | cut -d: -f1 | head -n 1 || true)
    fi
    if [ -n "$dev_by_label" ] && [ -b "$dev_by_label" ]; then
        if mount -t ext4 -o rw "$dev_by_label" "$M_DIR" 2>/dev/null || mount "$dev_by_label" "$M_DIR" 2>/dev/null; then
            if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                echo "$M_DIR"
                return 0
            fi
            umount "$M_DIR" 2>/dev/null || true
        fi
    fi

    # 4. Поиск основного блочного устройства DATA
    RAW_DATA=""
    for d in \
        /dev/block/platform/omap/omap_hsmmc.1/by-name/DATAFS \
        /dev/block/platform/omap/omap_hsmmc.1/by-name/data \
        /dev/block/by-name/DATAFS \
        /dev/block/by-name/data \
        /dev/block/mmcblk0p10; do
        if [ -b "$d" ]; then
            RAW_DATA="$d"
            break
        fi
    done

    if [ -z "$RAW_DATA" ]; then
        RAW_DATA=$(find /dev/block -name "DATAFS" 2>/dev/null | head -n 1 || true)
    fi
    if [ -z "$RAW_DATA" ]; then
        RAW_DATA="/dev/block/mmcblk0p10"
    fi

    if [ -b "$RAW_DATA" ]; then
        # Инициализация таблицы субразделов ядра через partx/kpartx
        partx -a "$RAW_DATA" 2>/dev/null || true
        kpartx -a "$RAW_DATA" 2>/dev/null || true

        for dev in \
            /dev/mapper/*p2 \
            /dev/block/mmcblk0p10p2 \
            "${RAW_DATA}p2"; do
            if [ -b "$dev" ]; then
                if mount -t ext4 -o rw "$dev" "$M_DIR" 2>/dev/null || mount "$dev" "$M_DIR" 2>/dev/null; then
                    if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                        echo "$M_DIR"
                        return 0
                    fi
                    umount "$M_DIR" 2>/dev/null || true
                fi
            fi
        done

        # Монтирование через loop device со сканированием разделов
        LOOP_P=$(losetup -f 2>/dev/null || echo "/dev/loop5")
        if [ -n "$LOOP_P" ]; then
            losetup -P "$LOOP_P" "$RAW_DATA" 2>/dev/null || losetup "$LOOP_P" "$RAW_DATA" 2>/dev/null || true
            partx -a "$LOOP_P" 2>/dev/null || true
            for cand in "${LOOP_P}p2" "${LOOP_P}2"; do
                if [ -b "$cand" ]; then
                    if mount -t ext4 -o rw "$cand" "$M_DIR" 2>/dev/null || mount "$cand" "$M_DIR" 2>/dev/null; then
                        if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                            echo "$M_DIR"
                            return 0
                        fi
                        umount "$M_DIR" 2>/dev/null || true
                    fi
                fi
            done
        fi

        # Чтение LBA-смещения Partition 2 из MBR таблицы (байт 470, 4 байта little-endian)
        CALC_OFFSET=""
        if command -v od >/dev/null 2>&1; then
            SEC=$(dd if="$RAW_DATA" bs=1 skip=470 count=4 2>/dev/null | od -t u4 -A n 2>/dev/null | tr -d ' ')
            if [ -n "$SEC" ] && [ "$SEC" -gt 0 ] 2>/dev/null; then
                CALC_OFFSET=$((SEC * 512))
            fi
        fi

        # Перебор точного и стандартных смещений раздела pmOS_root
        for off in $CALC_OFFSET 268435456 256000000 269484032; do
            [ -z "$off" ] && continue
            [ "$off" -le 0 ] && continue
            LOOP_O=$(losetup -f 2>/dev/null || echo "/dev/loop6")
            losetup -o "$off" "$LOOP_O" "$RAW_DATA" 2>/dev/null || true
            if mount -t ext4 -o rw "$LOOP_O" "$M_DIR" 2>/dev/null || mount "$LOOP_O" "$M_DIR" 2>/dev/null; then
                if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                    echo "$M_DIR"
                    return 0
                fi
                umount "$M_DIR" 2>/dev/null || true
            fi
            losetup -d "$LOOP_O" 2>/dev/null || true
        done

        # Прямое монтирование (если раздел не разбит на subpartitions)
        if mount -t ext4 -o rw "$RAW_DATA" "$M_DIR" 2>/dev/null || mount "$RAW_DATA" "$M_DIR" 2>/dev/null; then
            if [ -d "$M_DIR/etc" ] || [ -d "$M_DIR/usr" ]; then
                echo "$M_DIR"
                return 0
            fi
            umount "$M_DIR" 2>/dev/null || true
        fi
    fi

    return 1
}

ui_print "Поиск и монтирование rootfs postmarketOS..."
TARGET_DIR=$(find_and_mount_rootfs || true)

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    ui_print "ОШИБКА: Не удалось смонтировать раздел с postmarketOS!"
    ui_print "Убедитесь, что postmarketOS установлена на планшете."
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

if [ "$TARGET_DIR" = "/tmp/pmos_root" ]; then
    sync
    umount /tmp/pmos_root 2>/dev/null || true
    losetup -D 2>/dev/null || true
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
