#!/usr/bin/env bash
# ==============================================================================
# build_ubuntu_touch_zip.sh - Сборка прошиваемого ZIP-архива Ubuntu (armhf) для TWRP
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PARTITION="${1:-data}"               # Раздел для установки: data (12.1 ГБ DATAFS)
USER_NAME="${PMOS_USER:-ubuntu}"
USER_PASSWORD="${PMOS_PASSWORD:-ubuntu}"

echo "================================================================="
echo " Сборка Ubuntu (armhf) TWRP Recovery ZIP для Samsung Tab 2 10.1"
echo " Целевой раздел: $TARGET_PARTITION"
echo " Пользователь:   $USER_NAME"
echo " Пароль:         $USER_PASSWORD"
echo "================================================================="

if ! command -v pmbootstrap &> /dev/null; then
    echo "ОШИБКА: pmbootstrap не найден!"
    exit 1
fi

WORK_DIR="$HOME/.local/var/pmbootstrap"
PMAPORTS_DIR="$WORK_DIR/cache_git/pmaports"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$CONFIG_DIR"
mkdir -p "$WORK_DIR"
chmod -R 777 "$WORK_DIR" || true
find "$WORK_DIR/packages" -name "APKINDEX.tar.gz" -delete 2>/dev/null || true
echo "8" > "$WORK_DIR/version"

cat << EOF > "$CONFIG_DIR/pmbootstrap_v3.cfg"
[pmbootstrap]
work = $WORK_DIR
aports = $PMAPORTS_DIR
device = samsung-espresso10
ui = lxqt
user = $USER_NAME
is_release = False
jobs = $(nproc 2>/dev/null || echo 4)

[providers]

[mirrors]
EOF

cp -f "$CONFIG_DIR/pmbootstrap_v3.cfg" "$CONFIG_DIR/pmbootstrap.cfg"

if [ ! -d "$PMAPORTS_DIR" ]; then
    echo "Клонирование pmaports в $PMAPORTS_DIR..."
    mkdir -p "$(dirname "$PMAPORTS_DIR")"
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git "$PMAPORTS_DIR"
fi

echo "[1/4] Подготовка пакетов ядра OMAP и PVRports..."
mkdir -p "$PMAPORTS_DIR/device/community/"
cp -rf "$SCRIPT_DIR/device-samsung-espresso10" "$PMAPORTS_DIR/device/community/"
cp -rf "$SCRIPT_DIR/linux-postmarketos-omap" "$PMAPORTS_DIR/device/community/"

PMB_FLAGS=""
if [ "$(id -u)" -eq 0 ]; then
    PMB_FLAGS="--as-root"
fi

echo "Обновление контрольных сумм пакетов..."
pmbootstrap $PMB_FLAGS checksum linux-postmarketos-omap
pmbootstrap $PMB_FLAGS checksum device-samsung-espresso10

echo "[2/4] Сборка ядра Linux OMAP 7.1.5 с PVRports 3D ускорением..."
pmbootstrap $PMB_FLAGS -y build --arch=armv7 linux-postmarketos-omap
pmbootstrap $PMB_FLAGS -y build --arch=armv7 device-samsung-espresso10

# Настройка под Ubuntu LXQt / Lomiri
pmbootstrap $PMB_FLAGS config device samsung-espresso10
pmbootstrap $PMB_FLAGS config ui lxqt
pmbootstrap $PMB_FLAGS config user "$USER_NAME"

echo "[3/4] Генерация прошиваемого архива Ubuntu Touch / Linux для TWRP..."
if ! pmbootstrap $PMB_FLAGS -y install \
    --android-recovery-zip \
    --recovery-install-partition="$TARGET_PARTITION" \
    --password="$USER_PASSWORD" \
    --add="networkmanager,alsa-utils,pulseaudio,pulseaudio-utils,htop,nano"; then
    echo "================================================================="
    echo "PMBOOTSTRAP LOG (LAST 2000 LINES):"
    echo "================================================================="
    cat "$WORK_DIR/log.txt" | tail -n 2000 || true
    exit 1
fi

echo "[4/4] Экспорт собранного архива..."
mkdir -p "$SCRIPT_DIR/output"
pmbootstrap $PMB_FLAGS export "$SCRIPT_DIR/output"

ZIP_FILE="$(find "$SCRIPT_DIR/output" -name "pmos-*.zip" | head -n 1)"
if [ -z "$ZIP_FILE" ] || [ ! -e "$ZIP_FILE" ]; then
    ZIP_FILE="$(find "$WORK_DIR" -name "pmos-*.zip" | head -n 1)"
fi

if [ -n "$ZIP_FILE" ] && [ -e "$ZIP_FILE" ]; then
    cp -L "$ZIP_FILE" "$SCRIPT_DIR/output/ubuntu-touch-samsung-espresso10-twrp.zip"
    FINAL_ZIP="$SCRIPT_DIR/output/ubuntu-touch-samsung-espresso10-twrp.zip"
    echo "================================================================="
    echo " СБОРКА UBUNTU TWRP ZIP УСПЕШНО ЗАВЕРШЕНА!"
    echo " Файл для TWRP: $FINAL_ZIP"
    echo " Размер: $(du -h "$FINAL_ZIP" | cut -f1)"
    echo "================================================================="
fi
