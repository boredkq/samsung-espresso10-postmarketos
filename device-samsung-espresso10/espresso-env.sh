#!/bin/sh
# Environment optimizations for Samsung Galaxy Tab 2 (OMAP4430 / PowerVR SGX540)
#
# SGX540 has no open-source 3D Gallium driver in mainline Mesa.
# Force software rendering and Pixman 2D rasterizer to prevent llvmpipe CPU overload.

export LIBGL_ALWAYS_SOFTWARE=1
export WLR_RENDERER=pixman
export QT_QUICK_BACKEND=software
export QT_QPA_PLATFORMTHEME=gtk2
