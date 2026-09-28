#!/bin/sh
# Environment optimizations for Samsung Galaxy Tab 2 (OMAP4430 / PowerVR SGX540)
# PVRports 3D Hardware Acceleration Integration

if { [ -e /dev/pvrsrvkm ] || find /usr/lib/modules -type f -name 'pvrsrvkm.ko*' -print -quit 2>/dev/null | grep -q .; } && \
   { [ -f /usr/lib/dri/pvr_dri.so ] || [ -f /usr/lib/libPVRSGX540.so ]; }; then
    # PVRports PowerVR SGX540 3D Hardware Acceleration Enabled
    unset LIBGL_ALWAYS_SOFTWARE
    export MESA_LOADER_DRIVER_OVERRIDE=pvr
    export EGL_PLATFORM=wayland
    export PVR_3D_ACCELERATION=1
else
    # Fallback to 2D-optimized software rasterizer if PVRports is not installed
    export LIBGL_ALWAYS_SOFTWARE=1
    export WLR_RENDERER=pixman
    export QT_QUICK_BACKEND=software
    export MESA_LOADER_DRIVER_OVERRIDE=swrast
fi

export QT_QPA_PLATFORMTHEME=gtk2
