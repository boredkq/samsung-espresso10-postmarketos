#!/bin/sh
# ==============================================================================
# install_pvrports.sh - Установка 3D аппаратного ускорения PVRports (PowerVR SGX540)
# Официальный репозиторий проекта: https://gitlab.com/pvrports/pvrports
# Зеркало пакетов: https://pvrports.antonialoytorrens.com/pvrports
# Поддерживаемые устройства: OMAP4430 (Samsung Galaxy Tab 2: espresso10 / espresso7)
# ==============================================================================
set -eu

echo "================================================================="
echo " Установка PVRports (PowerVR SGX540 3D Hardware Acceleration)"
echo " Репозиторий: https://gitlab.com/pvrports/pvrports"
echo "================================================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "ОШИБКА: Скрипт необходимо запускать от имени root (sudo ./install_pvrports.sh)!"
    exit 1
fi

PVR_REPO="https://pvrports.antonialoytorrens.com/pvrports/v23.12"
KEY_DIR="/etc/apk/keys"
KEY_FILE="$KEY_DIR/build.pvrports.rsa.pub"

# 1. Установка публичного ключа репозитория pvrports
mkdir -p "$KEY_DIR"
cat << 'EOF' > "$KEY_FILE"
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA5cqhKdTPxCahN8c4YzwR
CRgPt70i9Xr7OJ5b101GDjohKSGF4HKwfIsKnIVMefTOkC84soTGDZ0xyf1HI7AT
RbcrdoylRj9yToaM/8RcCLFIGqY/hnVgmOTlfm7FHR/Zt621JkXktqNQK5AiTFJM
bRWrqYq+s7/0i8nXa9G8dQN49Xv2lU0FRdgJiN+CPoL9I0y5ueXxBrPpjnxZL6nz
zoCGmAoM5stxcNVdA0SoAd7O0un0oKPDiZgEML6naRHvAyH8AkGa2XhKn+vKuhhw
9MjckgXFfS5WDQFQSEzr/CWnptZmehJf00N7gmRv1EoBJ/nFf9miFd90wxwbQNL6
TQIDAQAB
-----END PUBLIC KEY-----
EOF
chmod 644 "$KEY_FILE"
echo "[1/4] Публичный ключ подписи установлен в $KEY_FILE"

# 2. Добавление репозитория PVRports в /etc/apk/repositories
if ! grep -q "pvrports" /etc/apk/repositories 2>/dev/null; then
    echo "$PVR_REPO" >> /etc/apk/repositories
    echo "[2/4] Репозиторий $PVR_REPO добавлен в /etc/apk/repositories"
else
    echo "[2/4] Репозиторий pvrports уже присутствует в /etc/apk/repositories"
fi

# 3. Обновление индексов apk и установка пакетов PVR SGX540
echo "[3/4] Обновление индексов apk и установка пакетов ускорения..."
apk update

apk add --no-cache \
    gcompat \
    libc6-compat \
    pvrports-keys \
    sgx-ddk-um \
    sgx-ddk-um-ti443x \
    sgx-ddk-um-openrc \
    mesa-pvr-dri-classic \
    libglvnd

if ! find /usr/lib/modules -type f -name 'pvrsrvkm_omap4_sgx540_120.ko*' -print -quit 2>/dev/null | grep -q .; then
    echo "ОШИБКА: модуль ядра pvrsrvkm не найден. Установите образ с ядром linux-openpvrsgx." >&2
    exit 1
fi

modprobe pvrsrvkm_omap4_sgx540_120

# 4. Активация службы инициализации демона SGX (pvrsrvctl) в OpenRC
echo "[4/4] Настройка службы sgx-ddk-um..."
if [ -f /etc/init.d/sgx-ddk-um ]; then
    rc-update add sgx-ddk-um default
    /etc/init.d/sgx-ddk-um start
fi

if [ ! -e /dev/pvrsrvkm ]; then
    echo "ОШИБКА: /dev/pvrsrvkm не появился после запуска драйвера." >&2
    exit 1
fi

mkdir -p /etc/pvrports
cat << 'EOF' > /etc/pvrports/pvrports.conf
PVR_CHIPSET=omap4
PVR_GPU=sgx540
PVR_DRIVER_VER=1.17
PVR_ACCELERATION=enabled
EOF

echo "================================================================="
echo " Пакеты 3D ускорения PVRports успешно установлены!"
echo " Профиль окружения /etc/profile.d/espresso.sh активирует драйвер."
echo " Перезагрузите планшет: sudo reboot"
echo "================================================================="
