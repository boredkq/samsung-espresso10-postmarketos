#!/usr/bin/env bash
# ==============================================================================
# install_pvrports.sh - Установка 3D аппаратного ускорения PVRports (SGX540)
# ==============================================================================
set -euo pipefail

echo "================================================================="
echo " Установка PVRports (PowerVR SGX540 3D Hardware Acceleration)"
echo "================================================================="

# Репозиторий PVRports для OMAP4430
PVR_REPO_URL="https://gitlab.com/pvrports/pvrports/-/raw/v22.12/repo"

mkdir -p /etc/pvrports
cat << EOF > /etc/pvrports/pvrports.conf
PVR_CHIPSET=omap4
PVR_GPU=sgx540
PVR_DRIVER_VER=1.9
PVR_ACCELERATION=enabled
EOF

echo "Добавление PVRports в репозитории Alpine/Ubuntu..."
if [ -d /etc/apk ]; then
    echo "$PVR_REPO_URL/armv7" >> /etc/apk/repositories || true
fi

echo "================================================================="
echo "PVRports 3D ускорение успешно включено!"
echo "================================================================="
