{ pkgs ? import <nixpkgs> {} }:
(pkgs.buildFHSUserEnv {
  name = "pipzone";
  targetPkgs = pkgs: (with pkgs; [
    python310
    python310Packages.pip
    python310Packages.virtualenv
    python310Packages.gst-python
    cudaPackages.cudatoolkit
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
  ]);
 extraOutputsToInstall = [ "dev" ];
 extraBuildCommands = ''
   if [[ -d /usr/lib/wsl ]]
   then
     echo "found WSL lib"
     chmod 755 $out/usr/lib
     cp -rHf /usr/lib/wsl $out/usr/lib/wsl
   else
      echo "No WSL lib found!"
   fi
 '';
  profile = ''
     export CUDA_PATH=${pkgs.cudatoolkit}
     export LD_LIBRARY_PATH=/usr/lib/wsl/lib:${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
     export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
     export EXTRA_CCFLAGS="-I/usr/include"
     export GST_PLUGIN_PATH="${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
     export PATH="$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
     export PYTHONPATH="/${pkgs.python310.sitePackages}"
     export GI_TYPELIB_PATH=/usr/lib/girepository-1.0
  ''; 
  runScript = "bash";
}).env
