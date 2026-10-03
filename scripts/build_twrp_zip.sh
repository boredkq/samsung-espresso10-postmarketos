#!/usr/bin/env bash
# ==============================================================================
# build_twrp_zip.sh - Сборка прошиваемого ZIP-архива для TWRP Recovery
# Устройство: Samsung Galaxy Tab 2 10.1 (samsung-espresso10)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_PARTITION="${1:-data}"               # По умолчанию: data (12.1 ГБ DATAFS), также: external_sd
UI="${2:-openbox}"
TARGET_SESSION="openbox"
PMB_UI="xfce4"

case "$UI" in
    openbox|lxqt|mate|"")
        echo "UI '$UI' mapped to Openbox + tint2 (рекордно быстрый X11 интерфейс, ~35 МБ RAM)."
        UI="openbox"
        TARGET_SESSION="openbox"
        PMB_UI="xfce4"
        ;;
    xfce4)
        echo "UI '$UI' selected: XFCE4 desktop."
        TARGET_SESSION="xfce"
        PMB_UI="xfce4"
        ;;
    phosh)
        echo "UI '$UI' selected: Phosh Wayland desktop."
        TARGET_SESSION="phosh"
        PMB_UI="phosh"
        ;;
    weston)
        echo "UI '$UI' selected: Weston Wayland."
        TARGET_SESSION="weston"
        PMB_UI="weston"
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
ui = $PMB_UI
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
pmbootstrap $PMB_FLAGS checksum device-samsung-espresso10

# Проверка наличия уже скомпилированного пакета ядра (в кэше CI или в GitHub Releases)
sudo mkdir -p "$WORK_DIR/packages" 2>/dev/null || mkdir -p "$WORK_DIR/packages" || true
sudo chmod -R 777 "$WORK_DIR/packages" 2>/dev/null || true
KERNEL_APK=$(find "$WORK_DIR/packages" -name "linux-openpvrsgx-*.apk" 2>/dev/null | head -n 1 || true)

if [ -z "$KERNEL_APK" ] || [ ! -f "$KERNEL_APK" ]; then
    echo "Пакет ядра не найден в локальном кэше. Проверка наличия в GitHub Releases..."
    if command -v gh &>/dev/null; then
        sudo mkdir -p "$WORK_DIR/packages/edge/armv7"
        sudo chmod -R 777 "$WORK_DIR/packages" 2>/dev/null || true
        if gh release download latest -p "linux-openpvrsgx-*.apk" -D "$WORK_DIR/packages/edge/armv7" 2>/dev/null; then
            KERNEL_APK=$(find "$WORK_DIR/packages" -name "linux-openpvrsgx-*.apk" 2>/dev/null | head -n 1 || true)
            if [ -n "$KERNEL_APK" ] && [ -f "$KERNEL_APK" ]; then
                echo "-> Успешно загружен готовый пакет ядра из GitHub Releases: $KERNEL_APK"
            fi
        fi
    fi
fi

if [ -n "$KERNEL_APK" ] && [ -f "$KERNEL_APK" ]; then
    echo "================================================================="
    echo " НАЙДЕНО ГОТОВОЕ СКОМПИЛИРОВАННОЕ ЯДРО: $KERNEL_APK"
    echo " Пропуск 40-минутной компиляции ядра Linux OMAP (экономия минут CI)!"
    echo "================================================================="
    sudo touch "$KERNEL_APK" 2>/dev/null || touch "$KERNEL_APK"
    pmbootstrap $PMB_FLAGS index --arch=armv7 || true
else
    echo "[2/5] Сборка ядра Linux OMAP 7.1.5 с поддержкой WM1811 и разгоном..."
    pmbootstrap $PMB_FLAGS checksum linux-openpvrsgx
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
fi

echo "[3/5] Сборка пакета устройства device-samsung-espresso10..."
pmbootstrap $PMB_FLAGS -y build --arch=armv7 device-samsung-espresso10

pmbootstrap $PMB_FLAGS config device samsung-espresso10
pmbootstrap $PMB_FLAGS config ui "$PMB_UI"
pmbootstrap $PMB_FLAGS config user "$USER_NAME"

echo "[4/5] Генерация TWRP flashable zip (раздел: $TARGET_PARTITION)..."
ADD_PKGS="alsa-utils,pulseaudio,pulseaudio-utils,pavucontrol,evtest,htop,zram-init,openbox,tint2,feh"
if [ "$PMB_UI" = "xfce4" ]; then
    ADD_PKGS="$ADD_PKGS,postmarketos-ui-xfce4,onboard,xfce4-whiskermenu-plugin,xfce4-pulseaudio-plugin,xfce4-power-manager,network-manager-applet,firefox-esr,lightdm-gtk-greeter"
elif [ "$PMB_UI" = "phosh" ]; then
    ADD_PKGS="$ADD_PKGS,gnome-console,firefox-esr"
fi
if ! pmbootstrap $PMB_FLAGS -y install \
    --android-recovery-zip \
    --recovery-install-partition="$TARGET_PARTITION" \
    --password="$USER_PASSWORD" \
    --add="$ADD_PKGS"; then
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
    # Экспорт скомпилированного пакета ядра в output/ для сохранения в релизах
    find "$WORK_DIR/packages" -name "linux-openpvrsgx-*.apk" -exec cp -f {} "$SCRIPT_DIR/output/" \; 2>/dev/null || true
fi

# Сборка отдельного TWRP ZIP с 3D аппаратным ускорением PVRports (SGX540)
if [ -f "$SCRIPT_DIR/scripts/package_pvrports_zip.sh" ]; then
    chmod +x "$SCRIPT_DIR/scripts/package_pvrports_zip.sh"
    "$SCRIPT_DIR/scripts/package_pvrports_zip.sh"
fi

# Встраивание 3D ускорения PVRports непосредственно в основной образ recovery.zip
if [ -n "${FINAL_ZIP:-}" ] && [ -f "$FINAL_ZIP" ]; then
    echo "================================================================="
    echo " Настройка rootfs и оптимизация системы для samsung-espresso10..."
    echo "================================================================="
    TMP_INJECT="/tmp/pmos_inject_$$"
    sudo rm -rf "$TMP_INJECT"
    mkdir -p "$TMP_INJECT/pmos" "$TMP_INJECT/rootfs" "$TMP_INJECT/pvr"

    if unzip -q "$FINAL_ZIP" "rootfs.tar.gz" -d "$TMP_INJECT/pmos" 2>/dev/null; then
        # Preserve numeric ownership from the original rootfs
        sudo tar --numeric-owner -xzf "$TMP_INJECT/pmos/rootfs.tar.gz" \
            -C "$TMP_INJECT/rootfs"

        # If PVRports 3D acceleration zip is available, merge its files into rootfs
        if [ -f "$SCRIPT_DIR/output/pvrports-samsung-espresso10-twrp.zip" ] && \
           unzip -q "$SCRIPT_DIR/output/pvrports-samsung-espresso10-twrp.zip" "files.tar.gz" -d "$TMP_INJECT/pvr" 2>/dev/null; then
            echo "-> Встраивание 3D файлов PVRports в rootfs..."
            sudo tar --numeric-owner -xzf "$TMP_INJECT/pvr/files.tar.gz" \
                -C "$TMP_INJECT/rootfs"
        fi

        # [1] Оптимизация видеодрайвера Xorg для OMAP4430 (KMS modesetting 24-bit TrueColor)
        # Удаляем fbdev_drv.so, вызывающий ошибку 'Cannot run in framebuffer mode'
        sudo rm -f "$TMP_INJECT/rootfs/usr/lib/xorg/modules/drivers/fbdev_drv.so"

        # Устанавливаем эталонный конфиг OMAPDRM без артефактов и зеленого оттенка
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/X11/xorg.conf.d"
        sudo cp -f "$SCRIPT_DIR/device-samsung-espresso10/10-omapdrm.conf" \
            "$TMP_INJECT/rootfs/etc/X11/xorg.conf.d/10-omapdrm.conf"

        # [2] Настройка LightDM и автоматического входа в $TARGET_SESSION
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf.d"
        cat << EOF | sudo tee "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf.d/50-autologin.conf" >/dev/null
[Seat:*]
autologin-user=$USER_NAME
autologin-user-timeout=0
autologin-session=$TARGET_SESSION
logind-check-graphical=false
EOF
        if [ -f "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf" ]; then
            sudo sed -i "s|^#*autologin-user=.*|autologin-user=$USER_NAME|g" "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf"
            sudo sed -i "s|^#*autologin-session=.*|autologin-session=$TARGET_SESSION|g" "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf"
            sudo sed -i "s|^#*logind-check-graphical=.*|logind-check-graphical=false|g" "$TMP_INJECT/rootfs/etc/lightdm/lightdm.conf"
        fi

        # Назначение групп пользователя (доступ к аудио, видео, вводу, правам)
        if [ -f "$TMP_INJECT/rootfs/etc/group" ]; then
            if grep -q "^autologin:" "$TMP_INJECT/rootfs/etc/group"; then
                sudo sed -i "s|^autologin:.*|autologin:x:1001:$USER_NAME|g" "$TMP_INJECT/rootfs/etc/group"
            else
                echo "autologin:x:1001:$USER_NAME" | sudo tee -a "$TMP_INJECT/rootfs/etc/group" >/dev/null
            fi
            for grp in audio video input wheel dialout disk; do
                if grep -q "^$grp:" "$TMP_INJECT/rootfs/etc/group"; then
                    if ! grep "^$grp:" "$TMP_INJECT/rootfs/etc/group" | grep -q "$USER_NAME"; then
                        sudo sed -i "/^$grp:/ s/$/,$USER_NAME/" "$TMP_INJECT/rootfs/etc/group"
                        sudo sed -i "s/:,$USER_NAME/:$USER_NAME/" "$TMP_INJECT/rootfs/etc/group"
                    fi
                fi
            done
        fi

        # [2.5] Настройка сверхбыстрого окружения Openbox + tint2 для планшета
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/xdg/openbox"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/xdg/openbox/autostart" >/dev/null
#!/bin/sh
xsetroot -solid "#1e272e" &
tint2 &
nm-applet &
onboard &
EOF
        sudo chmod 0755 "$TMP_INJECT/rootfs/etc/xdg/openbox/autostart"

        # Меню Openbox для тачскрина
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/xdg/openbox/menu.xml" >/dev/null
<?xml version="1.0" encoding="UTF-8"?>
<openbox_menu xmlns="http://openbox.org/3.4/menu">
  <menu id="root-menu" label="Tablet Menu">
    <item label="🌐 Web Browser (Firefox)">
      <action name="Execute"><command>firefox</command></action>
    </item>
    <item label="⌨️ On-Screen Keyboard">
      <action name="Execute"><command>onboard</command></action>
    </item>
    <item label="💻 Terminal">
      <action name="Execute"><command>xfce4-terminal</command></action>
    </item>
    <item label="📁 File Manager">
      <action name="Execute"><command>thunar</command></action>
    </item>
    <item label="🔊 Volume Control">
      <action name="Execute"><command>pavucontrol</command></action>
    </item>
    <separator />
    <item label="🖥️ Switch to XFCE4 Session">
      <action name="Execute"><command>xfce4-session</command></action>
    </item>
    <separator />
    <item label="🔄 Reboot">
      <action name="Execute"><command>reboot</command></action>
    </item>
    <item label="🛑 Power Off">
      <action name="Execute"><command>poweroff</command></action>
    </item>
  </menu>
</openbox_menu>
EOF

        # Конфигурация панели tint2 под пальцы (высота 46px)
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/xdg/tint2"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/xdg/tint2/tint2rc" >/dev/null
panel_monitor = all
panel_position = bottom center horizontal
panel_size = 100% 46
panel_margin = 0 0
panel_padding = 6 4 4
panel_background_id = 1
panel_dock = 0
panel_layer = top

rounded = 0
border_width = 0
background_color = #181c24 95
border_color = #2c3440 100

rounded = 4
border_width = 1
background_color = #2d3748 100
border_color = #4a5568 100

launcher_padding = 6 4 6
launcher_background_id = 0
launcher_icon_size = 32
launcher_item_app = /usr/share/applications/firefox.desktop
launcher_item_app = /usr/share/applications/onboard.desktop
launcher_item_app = /usr/share/applications/xfce4-terminal.desktop
launcher_item_app = /usr/share/applications/pavucontrol.desktop

taskbar_mode = single_desktop
taskbar_padding = 4 2 4
taskbar_background_id = 0
taskbar_active_background_id = 2
task_icon = 1
task_text = 1
task_centered = 1
task_maximum_size = 220 38
task_padding = 6 3
task_font = Sans Bold 11
task_font_color = #e2e8f0 100
task_active_font_color = #63b3ed 100

systray_padding = 6 4 6
systray_background_id = 0
systray_sort = ascending
systray_icon_size = 28
systray_icon_asb = 100 0 0

time1_format = %H:%M
time2_format = %d %b
time1_font = Sans Bold 12
time2_font = Sans 9
clock_font_color = #ffffff 100
clock_padding = 6 2
clock_background_id = 0
EOF

        # Копирование настроек в домашнюю папку пользователя
        USER_HOME="$TMP_INJECT/rootfs/home/$USER_NAME"
        if [ -d "$USER_HOME" ]; then
            sudo mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/tint2"
            sudo cp -f "$TMP_INJECT/rootfs/etc/xdg/openbox/autostart" "$USER_HOME/.config/openbox/autostart"
            sudo cp -f "$TMP_INJECT/rootfs/etc/xdg/openbox/menu.xml" "$USER_HOME/.config/openbox/menu.xml"
            sudo cp -f "$TMP_INJECT/rootfs/etc/xdg/tint2/tint2rc" "$USER_HOME/.config/tint2/tint2rc"
            USER_UID="$(sudo stat -c '%u' "$USER_HOME" 2>/dev/null || echo 10000)"
            USER_GID="$(sudo stat -c '%g' "$USER_HOME" 2>/dev/null || echo 10000)"
            sudo chown -R "$USER_UID:$USER_GID" "$USER_HOME/.config" 2>/dev/null || true
        fi


        # [3] Экранная клавиатура Onboard: автозапуск для планшетного интерфейса
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/xdg/autostart"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/xdg/autostart/onboard.desktop" >/dev/null
[Desktop Entry]
Type=Application
Name=Onboard Virtual Keyboard
Exec=onboard
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

        # [4] Сжатый RAM Swap (zram, 768 МБ LZ4) - предотвращает зависания медленной eMMC
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/conf.d"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/conf.d/zram-init" >/dev/null
num_devices=1
type0=swap
size0=768
algorithm0=lz4
EOF
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/runlevels/default"
        if [ -f "$TMP_INJECT/rootfs/etc/init.d/zram-init" ]; then
            sudo ln -sf /etc/init.d/zram-init \
                "$TMP_INJECT/rootfs/etc/runlevels/default/zram-init"
        fi

        # [5] Автоматическая установка комфортной яркости экрана при загрузке
        sudo mkdir -p "$TMP_INJECT/rootfs/etc/local.d"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/local.d/backlight.start" >/dev/null
#!/bin/sh
for bl in /sys/class/backlight/*; do
    if [ -f "$bl/max_brightness" ]; then
        max=$(cat "$bl/max_brightness")
        echo $((max * 8 / 10)) > "$bl/brightness" 2>/dev/null || true
    elif [ -f "$bl/brightness" ]; then
        echo 7 > "$bl/brightness" 2>/dev/null || true
    fi
done
EOF
        sudo chmod 0755 "$TMP_INJECT/rootfs/etc/local.d/backlight.start"
        if [ -f "$TMP_INJECT/rootfs/etc/init.d/local" ]; then
            sudo ln -sf /etc/init.d/local \
                "$TMP_INJECT/rootfs/etc/runlevels/default/local"
        fi

        # [6] Поддержка альтернативных Wayland сессий (Phosh / Weston)
        PHOSH_SESSION="$TMP_INJECT/rootfs/usr/share/wayland-sessions/phosh.desktop"
        WESTON_SESSION="$TMP_INJECT/rootfs/usr/share/wayland-sessions/weston.desktop"
        TINYDM_SESSION_DIR="$TMP_INJECT/rootfs/var/lib/tinydm"

        if [ "$UI" = "phosh" ] && [ -f "$PHOSH_SESSION" ]; then
            sudo mkdir -p "$TINYDM_SESSION_DIR"
            sudo ln -sfn /usr/share/wayland-sessions/phosh.desktop \
                "$TINYDM_SESSION_DIR/default-session.desktop"
        elif [ "$UI" = "weston" ] && [ -f "$WESTON_SESSION" ]; then
            sudo mkdir -p "$TINYDM_SESSION_DIR"
            sudo ln -sfn /usr/share/wayland-sessions/weston.desktop \
                "$TINYDM_SESSION_DIR/default-session.desktop"
            sudo sed -i 's|^Exec=.*|Exec=dbus-run-session start_weston.sh|g' "$WESTON_SESSION"
        fi

        # Обертка phoc для программного рендеринга Wayland при необходимости
        PHOC_BIN="$TMP_INJECT/rootfs/usr/bin/phoc"
        if [ -f "$PHOC_BIN" ] && [ ! -f "$TMP_INJECT/rootfs/usr/bin/phoc.real" ]; then
            sudo mv "$PHOC_BIN" "$TMP_INJECT/rootfs/usr/bin/phoc.real"
            cat << 'EOF' | sudo tee "$PHOC_BIN" >/dev/null
#!/bin/sh
export WLR_RENDERER=pixman
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_NO_HARDWARE_CURSORS=1
exec /usr/bin/phoc.real "$@"
EOF
            sudo chmod 0755 "$PHOC_BIN"
        fi

        # Переменные окружения для программного рендеринга
        sudo mkdir -p "$TMP_INJECT/rootfs/etc"
        cat << 'EOF' | sudo tee -a "$TMP_INJECT/rootfs/etc/environment" >/dev/null
WLR_RENDERER=pixman
WLR_RENDERER_ALLOW_SOFTWARE=1
WLR_NO_HARDWARE_CURSORS=1
EOF

        # [7] Переменные окружения для тачскрина и плавного скролла Firefox / GTK
        if [ -f "$SCRIPT_DIR/device-samsung-espresso10/espresso-env.sh" ]; then
            sudo mkdir -p "$TMP_INJECT/rootfs/etc/profile.d"
            sudo cp -f "$SCRIPT_DIR/device-samsung-espresso10/espresso-env.sh" \
                "$TMP_INJECT/rootfs/etc/profile.d/espresso.sh"
            sudo chmod 0755 "$TMP_INJECT/rootfs/etc/profile.d/espresso.sh"
        fi

        # [8] DRI симлинки и модуль ядра PowerVR SGX540
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/lib/dri"
        if [ -f "$TMP_INJECT/rootfs/usr/lib/xorg/modules/dri/pvr_dri.so" ]; then
            sudo ln -sfn ../xorg/modules/dri/pvr_dri.so "$TMP_INJECT/rootfs/usr/lib/dri/pvr_dri.so"
        fi
        if [ -f "$TMP_INJECT/rootfs/usr/lib/xorg/modules/dri/swrast_dri.so" ]; then
            sudo ln -sfn ../xorg/modules/dri/swrast_dri.so "$TMP_INJECT/rootfs/usr/lib/dri/swrast_dri.so"
        fi

        sudo mkdir -p "$TMP_INJECT/rootfs/etc/modules-load.d"
        echo "pvrsrvkm_omap4_sgx540_120" | sudo tee "$TMP_INJECT/rootfs/etc/modules-load.d/pvrsrvkm.conf" >/dev/null
        if [ -f "$TMP_INJECT/rootfs/etc/modules" ]; then
            if ! grep -q "pvrsrvkm_omap4_sgx540_120" "$TMP_INJECT/rootfs/etc/modules"; then
                echo "pvrsrvkm_omap4_sgx540_120" | sudo tee -a "$TMP_INJECT/rootfs/etc/modules" >/dev/null
            fi
        else
            echo "pvrsrvkm_omap4_sgx540_120" | sudo tee "$TMP_INJECT/rootfs/etc/modules" >/dev/null
        fi

        sudo mkdir -p "$TMP_INJECT/rootfs/etc/udev/rules.d"
        cat << 'EOF' | sudo tee "$TMP_INJECT/rootfs/etc/udev/rules.d/99-pvrsrvkm.rules" >/dev/null
KERNEL=="pvrsrvkm*", MODE="0666", GROUP="video"
EOF

        # [9] Звук: ALSA UCM2 конфигурация и симлинки для espresso10-soun
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d"
        sudo ln -sfn espresso10-sound "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-soun"
        if [ -d "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-sound" ]; then
            sudo ln -sfn espresso10-sound.conf "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/conf.d/espresso10-sound/espresso10-soun.conf"
        fi
        sudo mkdir -p "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/omap/espresso10-sound"
        sudo ln -sfn espresso10-sound "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/omap/espresso10-soun"
        if [ -f "$SCRIPT_DIR/device-samsung-espresso10/HiFi.conf" ]; then
            sudo cp -f "$SCRIPT_DIR/device-samsung-espresso10/HiFi.conf" \
                "$TMP_INJECT/rootfs/usr/share/alsa/ucm2/omap/espresso10-sound/HiFi.conf"
        fi

        # [10] Проверка tinydm окружения при наличии
        PVR_TINYDM_ENV="$TMP_INJECT/rootfs/etc/tinydm.d/env-wayland.d/pvr-wayland.sh"
        if [ -f "$PVR_TINYDM_ENV" ]; then
            if ! grep -q "LIBGL_DRIVERS_PATH" "$PVR_TINYDM_ENV"; then
                cat << 'EOF' | sudo tee -a "$PVR_TINYDM_ENV" >/dev/null

# Ensure Wayland sessions have the correct EGL platform, drivers, and pixman fallback
unset EGL_PLATFORM
unset LIBGL_ALWAYS_SOFTWARE
export LIBGL_DRIVERS_PATH=/usr/lib/xorg/modules/dri:/usr/lib/dri
export WLR_RENDERER=pixman
export WLR_RENDERER_ALLOW_SOFTWARE=1
export WLR_NO_HARDWARE_CURSORS=1
EOF
            fi
        fi

        sudo mkdir -p "$TMP_INJECT/rootfs/etc/runlevels/default"
        if [ -f "$TMP_INJECT/rootfs/etc/init.d/sgx-ddk-um" ]; then
            sudo ln -sf /etc/init.d/sgx-ddk-um \
                "$TMP_INJECT/rootfs/etc/runlevels/default/sgx-ddk-um"
        fi

        # Проверка прав доступа root на ключевые директории
        for critical_path in . tmp dev run var/empty; do
            path="$TMP_INJECT/rootfs/$critical_path"
            if [ -e "$path" ] && [ "$(sudo stat -c '%u' "$path")" != "0" ]; then
                echo "ERROR: rootfs/$critical_path is not owned by root" >&2
                exit 1
            fi
        done

        # Упаковка rootfs.tar.gz и сохранение в ZIP без сжатия (STORED / zip -0 для TWRP)
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
        echo "-> Оптимизации rootfs успешно интегрированы в $FINAL_ZIP!"
    else
        echo "ERROR: unable to unpack rootfs.tar.gz from $FINAL_ZIP" >&2
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
echo "Логин по умолчанию: $USER_NAME | Пароль / PIN экрана блокировки: $USER_PASSWORD"
echo "================================================================="
