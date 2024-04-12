let
  pkgs = import <nixpkgs> {};
  nanomsg-py = ...build expression for this python library...;
in pkgs.mkShell {
  buildInputs = [
    pkgs.python310
    pkgs.python310.pkgs.requests
    python310Packages.virtualenv
    pkgs.python310Packages.gst-python
    cudaPackages.cudatoolkit
    linuxPackages.nvidia_x11
    portaudio
    gcc
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    pkg-config
    gobject-introspection
    cairo
    xorg.libxcb.dev
    xorg.libX11.dev
    xorg.xorgproto
    glib  
    libffi
    ffmpeg
    zlib
  ];
  shellHook = ''
    # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
    # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
    export PIP_PREFIX=$(pwd)/_build/pip_packages
    export PYTHONPATH="$PIP_PREFIX/${pkgs.python3.sitePackages}:$PYTHONPATH"
    export PATH="$PIP_PREFIX/bin:$PATH"
    unset SOURCE_DATE_EPOCH

    # CUDA
   # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
    export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
    export EXTRA_CCFLAGS="-I/usr/include"

    # GStreamer / Python / GObject introspection
    export GST_PLUGIN_PATH="${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
    export PATH="$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
    export PYTHONPATH="${pkgs.python310.sitePackages}"
    export GI_TYPELIB_PATH=${pkgs.glib}/lib/girepository-1.0
  '';
}