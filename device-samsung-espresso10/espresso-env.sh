#!/bin/sh
# Environment optimizations for Samsung Galaxy Tab 2 (OMAP4430 / PowerVR SGX540)
# PVRports 3D Hardware Acceleration Integration

if [ -f /usr/lib/dri/pvr_dri.so ] || [ -f /usr/lib/libPVRSGX540.so ] || [ -d /etc/pvrports ]; then
    # PVRports PowerVR SGX540 3D Hardware Acceleration Enabled
    unset LIBGL_ALWAYS_SOFTWARE
    unset MESA_LOADER_DRIVER_OVERRIDE
    export EGL_PLATFORM=x11
    export PVR_3D_ACCELERATION=1
else
    # Fallback to 2D-optimized software rasterizer if PVRports is not installed
    export LIBGL_ALWAYS_SOFTWARE=1
    export WLR_RENDERER=pixman
    export QT_QUICK_BACKEND=software
    export MESA_LOADER_DRIVER_OVERRIDE=swrast
fi

export QT_QPA_PLATFORMTHEME=gtk2
