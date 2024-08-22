  {
    description = "Voice changer docker with Nix Flakes";
    inputs.nixpkgs.url = "github:avnerus/nixpkgs/ac5231a023cc9f8a6116281b0cc124f9f433cf3a";
    inputs.pyproject-nix.url = "github:nix-community/pyproject.nix/794220b75a5cddd88f2a6ac6e557a01bc3a9806c";

    outputs = {
      self,
      nixpkgs,
      pyproject-nix
    }:

    let

      # Load/parse requirements.txt
      project = pyproject-nix.lib.project.loadRequirementsTxt {
        projectRoot = ./server;
      };

      pkgs = import nixpkgs {
        config = { 
          cudaSupport = true;
          allowUnfree = true;
        };
        system = "x86_64-linux";
      };
      
      python = pkgs.python310.override {
        packageOverrides = self: super: {
          buildPythonPackage = args: super.buildPythonPackage (args // { doCheck = false;});
          onnxruntime-gpu = pkgs.python310Packages.onnxruntime.overrideAttrs(oldAttrs: {
            passthru = oldAttrs.passthru // {
              cudaSupport = true;
            };
          });
          # https://discourse.nixos.org/t/duplicate-when-installing-extrapackage-from-overlay/7736/7
          pyopenssl = super.pyopenssl.overridePythonAttrs (oA: {
            outputs = pkgs.lib.remove "doc" oA.outputs;
            nativeBuildInputs = pkgs.lib.remove super.sphinxHook oA.nativeBuildInputs;
          });
          pyjwt = super.pyjwt.overridePythonAttrs (oA: {
            outputs = pkgs.lib.remove "doc" oA.outputs;
            nativeBuildInputs = pkgs.lib.remove super.sphinxHook oA.nativeBuildInputs;
          });  
          wrapt = super.wrapt.overridePythonAttrs (oA: {
            outputs = pkgs.lib.remove "doc" oA.outputs;
            nativeBuildInputs = pkgs.lib.remove super.sphinxHook oA.nativeBuildInputs;
          });  

          /* Conflicts? */
          gin-config = pkgs.python310Packages.gin-config;
          numpy = pkgs.python310Packages.numpy;
          six = pkgs.python310Packages.six;
          commonTorchInputs = with pkgs.python310Packages; [ numpy six gin-config ];

          faiss-cpu = pkgs.python310Packages.faiss;
          gin = pkgs.python310Packages.gin-config;
          torchcrepe = pkgs.python310Packages.buildPythonPackage rec {
            pname = "torchcrepe";
            version = "0.0.22";
            doCheck = false;
            propagatedBuildInputs = with pkgs.python310Packages; [
              setuptools
              wheel
            ];
            src = (pkgs.fetchFromGitHub {
              owner = "maxrmorrison";
              repo = "torchcrepe";
              rev = "1c002b6dba18200352c3935b52622fef1b4a9b53";
              sha256 = "1baxkhb9j7a86v817p7myhcd502wk6rvx849ln8hbbhzsh9ii8zc";
          });};
          local-attention = pkgs.python310Packages.buildPythonPackage rec {
            pname = "local-attention";
            version = "1.9.0";
            doCheck = false;
            propagatedBuildInputs = with pkgs.python310Packages; [
              setuptools
              wheel
            ];
            src = (pkgs.fetchFromGitHub {
              owner = "lucidrains";
              repo = "local-attention";
              rev = "1.9.0";
              sha256 = "sha256-QH1roiKaclkfFr+85CWKD5Xz6eJPST0jmRYwqylSdqo=";
          });};
          onnxsim = pkgs.python310Packages.buildPythonPackage rec {
            pname = "onnxsim";
            version = "0.4.36";
            format = "wheel";
            src = pkgs.fetchurl {
              url = "https://files.pythonhosted.org/packages/d9/6e/80c77b5c6ec079994295e6e685097fa42732a1e7c5a22fe9c5c4ca1aac74/onnxsim-0.4.36-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
              sha256 = "0vfrf3bc6rhhrqsl1hdj1s810jz82dnivh4cr7ffpgkmi5zq71yf";
            };
          };
          torchfcpe = pkgs.python310Packages.buildPythonPackage rec {
            pname = "torchfcpe";
            version = "0.0.4";
            doCheck = false;
            propagatedBuildInputs = with pkgs.python310Packages; [
              setuptools
              wheel
            ];
            src = (pkgs.fetchFromGitHub {
              owner = "CNChTu";
              repo = "FCPE";
              rev = "v0.0.4";
              sha256 = "0lv7vdhy20hrrxfx0qlijsacpqmpanh9al8krq8dgykp4fbl4jlw";
          });};
          # Nixpkgs bug? :(
          sphinxcontrib-jquery = super.sphinxcontrib-jquery.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ self.sphinx ];
          });
          # Nixpkgs bug? :(
          yarl = super.yarl.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ self.tomli ];
          });
          # Nixpkgs bug? :(
          pydantic = super.pydantic.overrideAttrs (oldAttrs: {
              propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ [ self.email-validator ];
          });
        };
      };

      voicePythonPackages = python.withPackages ( project.renderers.withPackages 
          {
              inherit python;
              extraPackages = ps: with ps; [
                gst-python
                pygobject3
                tqdm
                fairseq
                rich
                onnx
                pyworld
                redis
              ];
      } );

      gstPackages = pkgs.symlinkJoin {
        name="puppetbots-gst"; 
        paths = [
          pkgs.portaudio
          pkgs.gst_all_1.gstreamer
          pkgs.gst_all_1.gst-plugins-base
          pkgs.gst_all_1.gst-plugins-good
          pkgs.gst_all_1.gst-plugins-bad
          pkgs.gst_all_1.gst-plugins-ugly
          pkgs.gst_all_1.gst-plugins-rs
          pkgs.libsoup
          pkgs.libnice.dev
          pkgs.pkg-config
          pkgs.gobject-introspection
          pkgs.cairo
          pkgs.glib  
          pkgs.libffi
          pkgs.ffmpeg
          pkgs.zlib
          pkgs.cacert
        ];
      };

      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "puppetbots-voice";
        tag = "latest";
        contents = [ voicePythonPackages gstPackages pkgs.bash pkgs.coreutils ];
        config = {
          Cmd = [ "${pkgs.bash}/bin/bash" ];
          Env = [
            # For the driver library injected by nvidia-docker and onnxruntime
            "LD_LIBRARY_PATH=/usr/lib64:${pkgs.python310Packages.onnxruntime}/lib/python3.10/site-packages/onnxruntime/capi"
            "GST_PLUGIN_PATH=${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-rs}/lib/gstreamer-1.0:${pkgs.libnice.out}/lib/gstreamer-1.0"
            "PATH=$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
            "GI_TYPELIB_PATH=${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.gst_all_1.gstreamer.out}/lib/girepository-1.0"
            "EXTRA_CCFLAGS=-I/usr/include"
            # The first one is for being able to run the nvidia-smi command
            "PATH=${pkgs.linuxPackages.nvidia_x11.bin}/bin:/bin:/usr/bin:${gstPackages}/bin"
          ];
        };
      };
      in {
        packages.x86_64-linux = {
          default = pkgs.mkShell {
            name = "puppetbots-voice-shell";
            buildInputs = [ voicePythonPackages gstPackages ];
            # LD_LIBRARY_PATH is a hack for my shell only, because WSL libs require exporting LD_LIBRARY_PATH
            # But that overrides the injection of the onnxruntime lib path, so I need to export that too...
            shellHook = ''
              export LD_LIBRARY_PATH="/usr/lib/wsl/lib:${pkgs.python310Packages.onnxruntime}/lib/python3.10/site-packages/onnxruntime/capi"
              export GST_PLUGIN_PATH="${pkgs.gst_all_1.gstreamer.out}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-bad}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-ugly}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-rs}/lib/gstreamer-1.0:${pkgs.libnice.out}/lib/gstreamer-1.0"
              export PATH="$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
              export GI_TYPELIB_PATH="${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.gst_all_1.gstreamer.out}/lib/girepository-1.0"
              export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
              export EXTRA_CCFLAGS="-I/usr/include"
            '';
          };
          docker = dockerImage;
        };
      };
  }