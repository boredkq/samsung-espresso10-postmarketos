#!/bin/sh
# Environment optimizations for Samsung Galaxy Tab 2 (OMAP4430 / PowerVR SGX540)
# PVRports 3D Hardware Acceleration Integration

if { [ -e /dev/pvrsrvkm ] || find /usr/lib/modules -type f -name 'pvrsrvkm_omap4_sgx540_120.ko*' -print -quit 2>/dev/null | grep -q .; } && \
   { [ -f /usr/lib/xorg/modules/dri/pvr_dri.so ] || [ -f /usr/lib/dri/pvr_dri.so ] || [ -f /usr/lib/libpvr_dri_support.so ]; }; then
    # PVRports PowerVR SGX540 3D Hardware Acceleration Enabled
    unset LIBGL_ALWAYS_SOFTWARE
    export MESA_LOADER_DRIVER_OVERRIDE=pvr
    export LIBGL_DRIVERS_PATH=/usr/lib/xorg/modules/dri:/usr/lib/dri
    # Do not force EGL_PLATFORM here.  This file is also sourced by tinydm
    # before it starts the compositor.  Weston must create an EGL display on
    # DRM/GBM; forcing the Wayland client platform makes it exit back to tty1.
    unset EGL_PLATFORM
    export __GLX_VENDOR_LIBRARY_NAME=amber
    export PVR_3D_ACCELERATION=1
else
    # Fallback to 2D-optimized software rasterizer if PVRports is not installed
    export LIBGL_ALWAYS_SOFTWARE=1
    export WLR_RENDERER=pixman
    export QT_QUICK_BACKEND=software
    export MESA_LOADER_DRIVER_OVERRIDE=swrast
fi

export QT_QPA_PLATFORMTHEME=gtk2
