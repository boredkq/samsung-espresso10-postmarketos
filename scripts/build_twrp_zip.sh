#!/usr/bin/env bash
# ==============================================================================
# build_twrp_zip.sh - Сборка прошиваемого ZIP-архива для TWRP Recovery
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PARTITION="${1:-data}"               # По умолчанию: data (12.1 ГБ DATAFS), также: external_sd
UI="${2:-xfce4}"                            # Рекомендуется xfce4 (легковесный 2D)
USER_NAME="${PMOS_USER:-user}"              # Имя пользователя по умолчанию
USER_PASSWORD="${PMOS_PASSWORD:-147147}"    # Пароль по умолчанию для входа

echo "================================================================="
echo " Сборка TWRP Recovery ZIP для Samsung Galaxy Tab 2 10.1"
echo " Целевой раздел: $TARGET_PARTITION"
echo " Окружение (UI): $UI"
echo " Пользователь:   $USER_NAME"
echo " Пароль:         $USER_PASSWORD"
echo "================================================================="

if ! command -v pmbootstrap &> /dev/null; then
    echo "ОШИБКА: pmbootstrap не найден!"
    echo "Установите pmbootstrap: pip install --user pmbootstrap"
    exit 1
fi

WORK_DIR="$HOME/.local/var/pmbootstrap"
PMAPORTS_DIR="$WORK_DIR/cache_git/pmaports"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$CONFIG_DIR"
mkdir -p "$WORK_DIR"
echo "8" > "$WORK_DIR/version"

echo "Создание конфигурации pmbootstrap..."
cat << EOF > "$CONFIG_DIR/pmbootstrap_v3.cfg"
[pmbootstrap]
work = $WORK_DIR
aports = $PMAPORTS_DIR
device = samsung-espresso10
ui = $UI
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

echo "[1/5] Копирование пропатченных пакетов в pmaports..."
mkdir -p "$PMAPORTS_DIR/device/community/"
cp -rf "$SCRIPT_DIR/device-samsung-espresso10" "$PMAPORTS_DIR/device/community/"
cp -rf "$SCRIPT_DIR/linux-postmarketos-omap" "$PMAPORTS_DIR/device/community/"

echo "[2/5] Сборка ядра Linux OMAP 7.1.5 с поддержкой WM1811 и фиксом Wi-Fi..."
if ! pmbootstrap -y build --arch=armv7 linux-postmarketos-omap; then
    echo "================================================================="
    echo "PMBOOTSTRAP LOG (LAST 250 LINES):"
    echo "================================================================="
    cat /home/runner/.local/var/pmbootstrap/log.txt | tail -n 250 || true
    exit 1
fi

echo "[3/5] Сборка пакета устройства device-samsung-espresso10..."
pmbootstrap -y build --arch=armv7 device-samsung-espresso10

echo "[4/5] Генерация TWRP flashable zip (раздел: $TARGET_PARTITION)..."
pmbootstrap -y install \
    --android-recovery-zip \
    --recovery-install-partition="$TARGET_PARTITION" \
    --ui="$UI" \
    --user="$USER_NAME" \
    --password="$USER_PASSWORD" \
    --no-fde \
    --extra-packages="alsa-utils,pulseaudio,pulseaudio-utils,pavucontrol,evtest,htop"

echo "[5/5] Экспорт собранного архива..."
mkdir -p "$SCRIPT_DIR/output"
pmbootstrap export "$SCRIPT_DIR/output"

ZIP_FILE="$(find "$SCRIPT_DIR/output" -name "pmos-*.zip" | head -n 1)"

echo "================================================================="
echo " СБОРКА УСПЕШНО ЗАВЕРШЕНА!"
if [ -n "$ZIP_FILE" ] && [ -f "$ZIP_FILE" ]; then
    echo " Файл для TWRP: $ZIP_FILE"
    echo " Размер: $(du -h "$ZIP_FILE" | cut -f1)"
fi
echo "================================================================="
echo "КАК ПРОШИТЬ ЧЕРЕЗ TWRP:"
echo "1. Скопируйте $ZIP_FILE на MicroSD карту или через adb sideload"
echo "2. Загрузите планшет в TWRP (зажмите Power + Volume Down)"
echo "3. В TWRP:"
echo "   - Очистка (Wipe): Wipe -> Advanced Wipe -> System, Data, Cache"
echo "   - Установка (Install): выберите ZIP-архив и свайпните для прошивки"
echo "   - Перезагрузка (Reboot System)"
echo "Логин по умолчанию: $USER_NAME | Пароль: $USER_PASSWORD"
echo "================================================================="
