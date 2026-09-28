#!/usr/bin/env bash
# ==============================================================================
# build_twrp_zip.sh - Сборка прошиваемого ZIP-архива для TWRP Recovery
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PARTITION="${1:-data}"               # По умолчанию: data (12.1 ГБ DATAFS), также: external_sd
UI="${2:-lxqt}"                            # Рекомендуется lxqt (легковесный 2D без артефактов XFCE)
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
chmod -R 777 "$WORK_DIR" || true
find "$WORK_DIR/packages" -name "APKINDEX.tar.gz" -delete 2>/dev/null || true
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
cp -rf "$SCRIPT_DIR/linux-openpvrsgx" "$PMAPORTS_DIR/device/community/"

PMB_FLAGS=""
if [ "$(id -u)" -eq 0 ]; then
    PMB_FLAGS="--as-root"
fi

echo "Обновление контрольных сумм пакетов..."
pmbootstrap $PMB_FLAGS checksum linux-openpvrsgx
pmbootstrap $PMB_FLAGS checksum device-samsung-espresso10

echo "[2/5] Сборка ядра Linux OMAP 7.1.5 с поддержкой WM1811 и фиксом Wi-Fi..."
if ! pmbootstrap $PMB_FLAGS -y build --arch=armv7 linux-openpvrsgx; then
    echo "================================================================="
    echo "PMBOOTSTRAP LOG (LAST 2000 LINES):"
    echo "================================================================="
    cat "$WORK_DIR/log.txt" | tail -n 2000 || true
    exit 1
fi

echo "[3/5] Сборка пакета устройства device-samsung-espresso10..."
pmbootstrap $PMB_FLAGS -y build --arch=armv7 device-samsung-espresso10

pmbootstrap $PMB_FLAGS config device samsung-espresso10
pmbootstrap $PMB_FLAGS config ui "$UI"
pmbootstrap $PMB_FLAGS config user "$USER_NAME"

echo "[4/5] Генерация TWRP flashable zip (раздел: $TARGET_PARTITION)..."
if ! pmbootstrap $PMB_FLAGS -y install \
    --android-recovery-zip \
    --recovery-install-partition="$TARGET_PARTITION" \
    --password="$USER_PASSWORD" \
    --add="alsa-utils,pulseaudio,pulseaudio-utils,pavucontrol,evtest,htop"; then
    echo "================================================================="
    echo "PMBOOTSTRAP INSTALL LOG (LAST 2000 LINES):"
    echo "================================================================="
    cat "$WORK_DIR/log.txt" | tail -n 2000 || true
    exit 1
fi

echo "[5/5] Экспорт собранного архива..."
mkdir -p "$SCRIPT_DIR/output"
pmbootstrap $PMB_FLAGS export "$SCRIPT_DIR/output"

ZIP_FILE="$(find "$SCRIPT_DIR/output" -name "pmos-*.zip" | head -n 1)"
if [ -z "$ZIP_FILE" ] || [ ! -e "$ZIP_FILE" ]; then
    ZIP_FILE="$(find "$WORK_DIR" -name "pmos-*.zip" | head -n 1)"
fi

if [ -n "$ZIP_FILE" ] && [ -e "$ZIP_FILE" ]; then
    cp -L "$ZIP_FILE" "$SCRIPT_DIR/output/pmos-samsung-espresso10-recovery.zip"
    FINAL_ZIP="$SCRIPT_DIR/output/pmos-samsung-espresso10-recovery.zip"
    echo "================================================================="
    echo " СБОРКА УСПЕШНО ЗАВЕРШЕНА!"
    echo " Файл для TWRP (полная ОС): $FINAL_ZIP"
    echo " Размер: $(du -h "$FINAL_ZIP" | cut -f1)"
fi

# Сборка отдельного TWRP ZIP с 3D аппаратным ускорением PVRports (SGX540)
if [ -f "$SCRIPT_DIR/scripts/package_pvrports_zip.sh" ]; then
    chmod +x "$SCRIPT_DIR/scripts/package_pvrports_zip.sh"
    "$SCRIPT_DIR/scripts/package_pvrports_zip.sh"
fi

# Встраивание 3D ускорения PVRports непосредственно в основной образ recovery.zip
if [ -n "${FINAL_ZIP:-}" ] && [ -f "$FINAL_ZIP" ] && [ -f "$SCRIPT_DIR/output/pvrports-samsung-espresso10-twrp.zip" ]; then
    echo "================================================================="
    echo " Встраивание 3D ускорения PVRports в основной образ ОС..."
    echo "================================================================="
    TMP_INJECT="/tmp/pmos_inject_$$"
    rm -rf "$TMP_INJECT"
    mkdir -p "$TMP_INJECT/pmos" "$TMP_INJECT/rootfs" "$TMP_INJECT/pvr"

    if unzip -q "$FINAL_ZIP" "rootfs.tar.gz" -d "$TMP_INJECT/pmos" 2>/dev/null && \
       unzip -q "$SCRIPT_DIR/output/pvrports-samsung-espresso10-twrp.zip" "files.tar.gz" -d "$TMP_INJECT/pvr" 2>/dev/null; then
        tar -xzf "$TMP_INJECT/pmos/rootfs.tar.gz" -C "$TMP_INJECT/rootfs"
        tar -xzf "$TMP_INJECT/pvr/files.tar.gz" -C "$TMP_INJECT/rootfs"
        mkdir -p "$TMP_INJECT/rootfs/etc/runlevels/default"
        if [ -f "$TMP_INJECT/rootfs/etc/init.d/sgx-ddk-um" ]; then
            ln -sf /etc/init.d/sgx-ddk-um "$TMP_INJECT/rootfs/etc/runlevels/default/sgx-ddk-um"
        fi
        (cd "$TMP_INJECT/rootfs" && tar -czf "$TMP_INJECT/pmos/rootfs.tar.gz" .)
        (cd "$TMP_INJECT/pmos" && zip -q -u "$FINAL_ZIP" rootfs.tar.gz)
        echo "-> 3D ускорение PVRports успешно интегрировано в $FINAL_ZIP!"
    else
        echo "ERROR: unable to inject PVRports userspace into $FINAL_ZIP" >&2
        exit 1
    fi
    rm -rf "$TMP_INJECT"
fi

# Сборка отдельного легковесного TWRP ZIP только с ядром и модулями
if [ -f "$SCRIPT_DIR/scripts/package_kernel_zip.sh" ]; then
    chmod +x "$SCRIPT_DIR/scripts/package_kernel_zip.sh"
    "$SCRIPT_DIR/scripts/package_kernel_zip.sh"
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
