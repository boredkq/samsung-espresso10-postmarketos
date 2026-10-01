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
APK_FILE=$(find "$WORK_DIR/packages" -name "linux-openpvrsgx-*.apk" 2>/dev/null | head -n 1 || true)
if [ -n "$APK_FILE" ] && [ -f "$APK_FILE" ]; then
    echo "-> Извлечение модулей из $APK_FILE..."
    TMP_EXTRACT="/tmp/apk_extract_$$"
    rm -rf "$TMP_EXTRACT"
    mkdir -p "$TMP_EXTRACT"
    tar -xf "$APK_FILE" -C "$TMP_EXTRACT" 2>/dev/null || tar -xzf "$APK_FILE" -C "$TMP_EXTRACT" 2>/dev/null || true
    # Alpine installs kernel modules below /usr/lib/modules. /lib is only a
    # compatibility symlink in the final rootfs and is absent in unpacked APKs.
    if [ -d "$TMP_EXTRACT/usr/lib/modules" ]; then
        tar -czf "$BUILD_DIR/modules.tar.gz" -C "$TMP_EXTRACT" usr/lib/modules
        echo "-> Добавлен modules.tar.gz ($(du -h "$BUILD_DIR/modules.tar.gz" | cut -f1))"
    elif [ -d "$TMP_EXTRACT/lib/modules" ]; then
        # Compatibility with packages produced by older Alpine releases.
        tar -czf "$BUILD_DIR/modules.tar.gz" -C "$TMP_EXTRACT" lib/modules
        echo "-> Добавлен modules.tar.gz ($(du -h "$BUILD_DIR/modules.tar.gz" | cut -f1))"
    else
        echo "ОШИБКА: каталог модулей не найден в $APK_FILE" >&2
        rm -rf "$TMP_EXTRACT"
        exit 1
    fi
    rm -rf "$TMP_EXTRACT"
fi

# 3. Add the device-specific Samsung BCM4330 firmware and NVRAM.  Do not use
# linux-firmware's generic BCM4330 blob or a hand-written NVRAM: espresso10
# needs the vendor calibration shipped by firmware-samsung-espresso.
FW_APK=$(find "$WORK_DIR/packages" "$WORK_DIR/cache_apk" "$WORK_DIR/cache_apk_armv7" \
    -name "firmware-samsung-espresso-*.apk" 2>/dev/null | head -n 1 || true)
if [ -z "$FW_APK" ] || [ ! -f "$FW_APK" ]; then
    echo "ОШИБКА: firmware-samsung-espresso APK не найден" >&2
    exit 1
fi

FW_EXTRACT="/tmp/firmware_extract_$$"
FW_STAGE="/tmp/firmware_stage_$$"
rm -rf "$FW_EXTRACT" "$FW_STAGE"
mkdir -p "$FW_EXTRACT" "$FW_STAGE/usr/lib/firmware/postmarketos/brcm"
mkdir -p "$FW_STAGE/usr/lib/firmware/brcm"
tar -xf "$FW_APK" -C "$FW_EXTRACT" 2>/dev/null || \
    tar -xzf "$FW_APK" -C "$FW_EXTRACT" 2>/dev/null

FW_DIR=$(find "$FW_EXTRACT" -type d -path "*/firmware/postmarketos/brcm" \
    | head -n 1 || true)
if [ -z "$FW_DIR" ]; then
    echo "ОШИБКА: firmware-samsung-espresso не содержит каталог brcm" >&2
    rm -rf "$FW_EXTRACT" "$FW_STAGE"
    exit 1
fi
cp -f "$FW_DIR/brcmfmac4330-sdio.bin" \
    "$FW_STAGE/usr/lib/firmware/postmarketos/brcm/"
cp -f "$FW_DIR/brcmfmac4330-sdio.samsung,espresso10.txt" \
    "$FW_STAGE/usr/lib/firmware/postmarketos/brcm/"
ln -s ../postmarketos/brcm/brcmfmac4330-sdio.bin \
    "$FW_STAGE/usr/lib/firmware/brcm/brcmfmac4330-sdio.bin"
ln -s ../postmarketos/brcm/brcmfmac4330-sdio.bin \
    "$FW_STAGE/usr/lib/firmware/brcm/brcmfmac4330-sdio.samsung,espresso10.bin"
ln -s ../postmarketos/brcm/brcmfmac4330-sdio.samsung,espresso10.txt \
    "$FW_STAGE/usr/lib/firmware/brcm/brcmfmac4330-sdio.samsung,espresso10.txt"
tar -czf "$BUILD_DIR/firmware.tar.gz" -C "$FW_STAGE" usr/lib/firmware
rm -rf "$FW_EXTRACT" "$FW_STAGE"
echo "-> Добавлена оригинальная прошивка и NVRAM WiFi BCM4330"

# 4. Создание update-binary (POSIX shell installer для TWRP)
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
set_progress 0.6

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

    # Resolve DATAFS like the official postmarketOS recovery installer.
    if command -v findfs >/dev/null 2>&1; then
        RAW_DATA=$(findfs PARTLABEL=DATAFS 2>/dev/null || true)
    fi

    # Older Samsung TWRP builds may expose no by-name symlinks. Read the
    # backing device from recovery.fstab/twrp.fstab in that case.
    if [ -z "$RAW_DATA" ]; then
        for fstab in /etc/recovery.fstab /etc/twrp.fstab; do
            [ -f "$fstab" ] || continue
            candidate=$(awk '
                !/^#/ && ($0 ~ /DATAFS/ || $0 ~ /[[:space:]]\/data([[:space:]]|$)/) {
                    for (i = 1; i <= NF; i++) {
                        if ($i ~ /^\/dev\//) { print $i; exit }
                    }
                }
            ' "$fstab" 2>/dev/null)
            if [ -n "$candidate" ]; then
                RAW_DATA="$candidate"
                break
            fi
        done
    fi

    if [ -n "$RAW_DATA" ]; then
        resolved=$(readlink -f "$RAW_DATA" 2>/dev/null || true)
        [ -n "$resolved" ] && RAW_DATA="$resolved"
    fi

    if [ -z "$RAW_DATA" ]; then
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
    fi

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

        # pmbootstrap creates pmOS_root at decimal 256 MB. Some old TWRP
        # builds cannot expose loopXp2 through partx/kpartx, so ask mount to
        # create a loop device directly at the filesystem offset.
        for off in 256000000 $CALC_OFFSET 268435456 269484032; do
            [ -n "$off" ] || continue
            [ "$off" -gt 0 ] 2>/dev/null || continue
            if mount -t ext4 -o "rw,loop,offset=$off" "$RAW_DATA" "$M_DIR" 2>/dev/null; then
                if [ -d "$M_DIR/etc" ] && [ -d "$M_DIR/usr" ]; then
                    echo "$M_DIR"
                    return 0
                fi
                umount "$M_DIR" 2>/dev/null || true
            fi
        done

        # Fallback for recoveries whose losetup supports an explicit offset.
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

# Монтирование rootfs и установка модулей / калибровочных данных
ui_print "Поиск и монтирование rootfs postmarketOS..."
TARGET_DIR=$(find_and_mount_rootfs || true)

if [ -n "$TARGET_DIR" ] && [ -d "$TARGET_DIR" ]; then
    ui_print "Корневой раздел смонтирован: $TARGET_DIR"

    # Установка модулей ядра
    if unzip -l "$ZIPFILE" | grep -q "modules.tar.gz"; then
        ui_print "Распаковка модулей ядра..."
        unzip -o "$ZIPFILE" "modules.tar.gz" -d "$TMPDIR"
        tar -xzf "$TMPDIR/modules.tar.gz" -C "$TARGET_DIR"
        sync
        ui_print "Модули ядра успешно установлены!"
    fi

    # Install the matching vendor firmware and board calibration.
    if unzip -l "$ZIPFILE" | grep -q "firmware.tar.gz"; then
        ui_print "Установка оригинальной прошивки WiFi BCM4330..."
        unzip -o "$ZIPFILE" "firmware.tar.gz" -d "$TMPDIR"
        tar -xzf "$TMPDIR/firmware.tar.gz" -C "$TARGET_DIR"
        sync
    fi

    if [ "$TARGET_DIR" = "/tmp/pmos_root" ]; then
        sync
        umount /tmp/pmos_root 2>/dev/null || true
        losetup -D 2>/dev/null || true
    fi
else
    ui_print "Инфо: Раздел rootfs не смонтирован. boot.img прошит."
fi

set_progress 1.0
rm -rf "$TMPDIR"
ui_print "==========================================="
ui_print " Ядро успешно обновлено!                  "
ui_print " Перезагрузите устройство: Reboot System   "
ui_print "==========================================="
exit 0
EOF

chmod +x "$BUILD_DIR/META-INF/com/google/android/update-binary"
echo "# dummy" > "$BUILD_DIR/META-INF/com/google/android/updater-script"

# 5. Создание ZIP-архива
FINAL_KERNEL_ZIP="$OUTPUT_DIR/kernel-samsung-espresso10-twrp.zip"
rm -f "$FINAL_KERNEL_ZIP"
(cd "$BUILD_DIR" && zip -0 -rq "$FINAL_KERNEL_ZIP" .)

echo "================================================================="
echo " АВТОНОМНЫЙ TWRP ZIP ЯДРА УСПЕШНО СОЗДАН!"
echo " Файл: $FINAL_KERNEL_ZIP"
echo " Размер: $(du -h "$FINAL_KERNEL_ZIP" | cut -f1)"
echo "================================================================="
rm -rf "$BUILD_DIR"
