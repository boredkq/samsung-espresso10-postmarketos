#!/usr/bin/env bash
# ==============================================================================
# build_twrp_zip.sh - Сборка прошиваемого ZIP-архива для TWRP Recovery
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PARTITION="${1:-data}"               # По умолчанию: data (12.1 ГБ DATAFS), также: external_sd
UI="${2:-weston}"
# The SGX540 PVRports stack supports Wayland, not an Xorg LXQt/XFCE/MATE
# session.  Keep accepting the historical CI input, but build a usable
# Weston image instead of booting back to the console after LightDM starts.
case "$UI" in
    lxqt|xfce4|mate)
        echo "UI '$UI' uses Xorg and is unsupported by PVRports; using Weston."
        UI="weston"
        ;;
esac
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
    echo "PMBOOTSTRAP COMPILER DIAGNOSTICS:"
    grep -aEin 'error:|fatal error:|undefined reference|No rule to make|Killed signal|Error [0-9]+|ERROR:' \
        "$WORK_DIR/log.txt" | tail -n 200 || true
    echo "PMBOOTSTRAP LOG (LAST 300 LINES):"
    echo "================================================================="
    tail -n 300 "$WORK_DIR/log.txt" || true
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
    sudo rm -rf "$TMP_INJECT"
    mkdir -p "$TMP_INJECT/pmos" "$TMP_INJECT/rootfs" "$TMP_INJECT/pvr"

    if unzip -q "$FINAL_ZIP" "rootfs.tar.gz" -d "$TMP_INJECT/pmos" 2>/dev/null && \
       unzip -q "$SCRIPT_DIR/output/pvrports-samsung-espresso10-twrp.zip" "files.tar.gz" -d "$TMP_INJECT/pvr" 2>/dev/null; then
        # Preserve numeric ownership from the original rootfs.  Extracting and
        # repacking as the GitHub runner changes root-owned paths to UID 1001,
        # which makes tmpfiles, sshd and wpa_supplicant reject the filesystem.
        sudo tar --numeric-owner -xzf "$TMP_INJECT/pmos/rootfs.tar.gz" \
            -C "$TMP_INJECT/rootfs"
        sudo tar --numeric-owner -xzf "$TMP_INJECT/pvr/files.tar.gz" \
            -C "$TMP_INJECT/rootfs"

        # pmbootstrap's Weston UI package can leave tinydm without a selected
        # session. In that case tinydm starts, exits immediately, and the tablet
        # remains at the tty login prompt. Select the packaged Weston session
        # explicitly in the final rootfs (after all APK post-install scripts).
        WESTON_SESSION="$TMP_INJECT/rootfs/usr/share/wayland-sessions/weston.desktop"
        TINYDM_SESSION_DIR="$TMP_INJECT/rootfs/var/lib/tinydm"
        if [ ! -f "$WESTON_SESSION" ]; then
            echo "ERROR: Weston session desktop file is missing: $WESTON_SESSION" >&2
            echo "Available Wayland sessions:" >&2
            sudo find "$TMP_INJECT/rootfs/usr/share/wayland-sessions" \
                -maxdepth 1 -type f -name '*.desktop' -print 2>/dev/null || true
            exit 1
        fi
        sudo mkdir -p "$TINYDM_SESSION_DIR"
        sudo ln -sfn /usr/share/wayland-sessions/weston.desktop \
            "$TINYDM_SESSION_DIR/default-session.desktop"
        if [ -f "$WESTON_SESSION" ]; then
            sudo sed -i 's|^Exec=.*|Exec=dbus-run-session start_weston.sh|g' "$WESTON_SESSION"
        fi
        echo "Selected tinydm session: /usr/share/wayland-sessions/weston.desktop"

        # Provide DRI symlinks so standard DRI lookups resolve PVR driver
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/lib/dri"
        if [ -f "$TMP_INJECT/rootfs/usr/lib/xorg/modules/dri/pvr_dri.so" ]; then
            sudo ln -sfn ../xorg/modules/dri/pvr_dri.so "$TMP_INJECT/rootfs/usr/lib/dri/pvr_dri.so"
        fi
        if [ -f "$TMP_INJECT/rootfs/usr/lib/xorg/modules/dri/swrast_dri.so" ]; then
            sudo ln -sfn ../xorg/modules/dri/swrast_dri.so "$TMP_INJECT/rootfs/usr/lib/dri/swrast_dri.so"
        fi

        # Ensure kernel module pvrsrvkm auto-loads on boot for SGX540
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/modules-load.d"
        echo "pvrsrvkm_omap4_sgx540_120" | sudo tee "$TMP_INJECT/rootfs/etc/modules-load.d/pvrsrvkm.conf" >/dev/null
        if [ -f "$TMP_INJECT/rootfs/etc/modules" ]; then
            if ! grep -q "pvrsrvkm_omap4_sgx540_120" "$TMP_INJECT/rootfs/etc/modules"; then
                echo "pvrsrvkm_omap4_sgx540_120" | sudo tee -a "$TMP_INJECT/rootfs/etc/modules" >/dev/null
            fi
        else
            echo "pvrsrvkm_omap4_sgx540_120" | sudo tee "$TMP_INJECT/rootfs/etc/modules" >/dev/null
        fi

        # Udev permissions for PowerVR SGX GPU device node (allow non-root user session)
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/udev/rules.d"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/udev/rules.d/99-pvrsrvkm.rules" >/dev/null
KERNEL=="pvrsrvkm*", MODE="0666", GROUP="video"
EOF

        # Device-specific Weston configuration (use-pixman ensures reliable DRM KMS display)
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/xdg/weston"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/xdg/weston/weston.ini" >/dev/null
[core]
backend=drm-backend.so
use-pixman=true
xwayland=true

[shell]
background-image=/usr/share/wallpapers/postmarketos.jpg
panel-position=top
locking=false
EOF

        # Ensure robust start_weston.sh wrapper with automatic fallback
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/bin"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/usr/bin/start_weston.sh" >/dev/null
#!/bin/sh
export DISPLAY=:0

# Create XDG_RUNTIME_DIR
XDG_RUNTIME_DIR=/tmp/$(id -u)-runtime-dir
export XDG_RUNTIME_DIR
if ! test -d "${XDG_RUNTIME_DIR}"; then
    mkdir -p "${XDG_RUNTIME_DIR}"
    chmod 0700 "${XDG_RUNTIME_DIR}"
fi

cfg="/etc/xdg/weston/weston.ini"
[ -e "$cfg" ] || cfg="$cfg.default"

(
    for _ in $(seq 0 19); do
        sleep 0.5
        postmarketos-demos && break
    done
) &

# Launch weston. If it exits with error, retry directly with --use-pixman
if ! weston --config="$cfg" 2>&1 | logger -t "$(whoami):weston"; then
    logger -t "$(whoami):weston" "Weston failed to start; retrying with --use-pixman..."
    exec weston --config="$cfg" --use-pixman 2>&1 | logger -t "$(whoami):weston"
fi
EOF
        sudo chmod 0755 "$TMP_INJECT/rootfs/usr/bin/start_weston.sh"

        # Ensure ALSA UCM2 symlinks for truncated driver name (espresso10-soun)
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d"
        sudo ln -sfn espresso10-sound "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-soun"
        if [ -d "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-sound" ]; then
            sudo ln -sfn espresso10-sound.conf "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-sound/espresso10-soun.conf"
        fi
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/omap"
        sudo ln -sfn espresso10-sound "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/omap/espresso10-soun"

        # Ensure tinydm environment does not leak LIBGL_ALWAYS_SOFTWARE or invalid EGL_PLATFORM
        PVR_TINYDM_ENV="$TMP_INJECT/rootfs/etc/tinydm.d/env-wayland.d/pvr-wayland.sh"
        if [ -f "$PVR_TINYDM_ENV" ]; then
            if ! grep -q "LIBGL_DRIVERS_PATH" "$PVR_TINYDM_ENV"; then
                cat << 'EOF' | sudo tee -a "$PVR_TINYDM_ENV" >/dev/null

# Ensure Weston (running as DRM/GBM server) has the correct EGL platform and drivers
unset EGL_PLATFORM
unset LIBGL_ALWAYS_SOFTWARE
export LIBGL_DRIVERS_PATH=/usr/lib/xorg/modules/dri:/usr/lib/dri
EOF
            fi
        fi

        sudo mkdir -p "$TMP_INJECT/rootfs/etc/runlevels/default"
        if [ -f "$TMP_INJECT/rootfs/etc/init.d/sgx-ddk-um" ]; then
            sudo ln -sf /etc/init.d/sgx-ddk-um \
                "$TMP_INJECT/rootfs/etc/runlevels/default/sgx-ddk-um"
        fi

        for critical_path in . tmp dev run var/empty; do
            path="$TMP_INJECT/rootfs/$critical_path"
            if [ -e "$path" ] && [ "$(sudo stat -c '%u' "$path")" != "0" ]; then
                echo "ERROR: rootfs/$critical_path is not owned by root" >&2
                exit 1
            fi
        done

        (cd "$TMP_INJECT/rootfs" && \
            sudo tar --numeric-owner -czf "$TMP_INJECT/pmos/rootfs.tar.gz" .)
        (cd "$TMP_INJECT/pmos" && zip -0 -q "$FINAL_ZIP" rootfs.tar.gz)
        python3 -c "
import zipfile, sys
with zipfile.ZipFile('$FINAL_ZIP', 'r') as z:
    info = z.getinfo('rootfs.tar.gz')
    if info.compress_type != zipfile.ZIP_STORED:
        print(f'ERROR: rootfs.tar.gz compress_type is {info.compress_type}, expected STORED (0)', file=sys.stderr)
        sys.exit(1)
    print(f'Verified: rootfs.tar.gz is stored uncompressed (ZIP_STORED, {info.file_size} bytes)')
"
        echo "-> 3D ускорение PVRports успешно интегрировано в $FINAL_ZIP!"
    else
        echo "ERROR: unable to inject PVRports userspace into $FINAL_ZIP" >&2
        exit 1
    fi
    sudo rm -rf "$TMP_INJECT"
fi

# Сборка отдельного легковесного TWRP ZIP только с ядром и модулями
if [ -f "$SCRIPT_DIR/scripts/package_kernel_zip.sh" ]; then
    chmod +x "$SCRIPT_DIR/scripts/package_kernel_zip.sh"
    "$SCRIPT_DIR/scripts/package_kernel_zip.sh"
fi

if [ -n "${FINAL_ZIP:-}" ] && [ -f "$FINAL_ZIP" ]; then
    echo "================================================================="
    echo " Проверка целостности и методов сжатия архивов..."
    python3 -c "
import zipfile, sys
with zipfile.ZipFile('$FINAL_ZIP', 'r') as z:
    for item in z.infolist():
        method_str = 'STORED (no compression)' if item.compress_type == zipfile.ZIP_STORED else f'DEFLATED ({item.compress_type})'
        print(f'  {item.filename:20s}: {method_str:25s} ({item.file_size} bytes)')
        if item.filename == 'rootfs.tar.gz' and item.compress_type != zipfile.ZIP_STORED:
            print(f'ERROR: rootfs.tar.gz compress_type is {item.compress_type}, expected STORED (0)', file=sys.stderr)
            sys.exit(1)
print('Все файлы в $FINAL_ZIP проверены успешно!')
"
    echo "================================================================="
fi

echo "================================================================="
echo "КАК ПРОШИТЬ ЧЕРЕЗ TWRP:"
echo "1. Скопируйте ${FINAL_ZIP:-$ZIP_FILE} на MicroSD карту или через adb sideload"
echo "2. Загрузите планшет в TWRP (зажмите Power + Volume Down)"
echo "3. В TWRP:"
echo "   - Очистка (Wipe): Wipe -> Advanced Wipe -> System, Data, Cache"
echo "   - Установка (Install): выберите ZIP-архив и свайпните для прошивки"
echo "   - Перезагрузка (Reboot System)"
echo "Логин по умолчанию: $USER_NAME | Пароль: $USER_PASSWORD"
echo "================================================================="
