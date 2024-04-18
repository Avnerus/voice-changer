  {
    description = "Voice changer docker with Nix Flakes";
    inputs.nixpkgs.url = "github:avnerus/nixpkgs/ac5231a023cc9f8a6116281b0cc124f9f433cf3a";
    inputs.pyproject-nix.url = "github:nix-community/pyproject.nix";

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
              rev = "master";
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
              rev = "master";
              sha256 = "0v0bb4y821khlizp04arszi9g52fgnjsp91s9i770qyjhm9z77wh";
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
              rev = "master";
              sha256 = "0shaps3yqqzkwpi6vq3wkicybw5b3r2nnk5cnvvshj3r8sn431d4";
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
          pkgs.libsoup
          pkgs.pkg-config
          pkgs.gobject-introspection
          pkgs.cairo
          pkgs.glib  
          pkgs.libffi
          pkgs.ffmpeg
          pkgs.zlib
        ];
      };

      gitRepo = pkgs.fetchgit {
        url = "https://github.com/Avnerus/voice-changer.git";
        rev = "473f55d8f3402afe9b44d91b7f9be2672280fda9";
        sha256 = "sha256-o4M1Z1r6Yft1pMr/hUc6uy435AelRy5fhKqrA2n3gwA";
      };

      dockerImage = pkgs.dockerTools.buildLayeredImage {
        name = "puppetbots-voice";
        tag = "latest";
        contents = [ voicePythonPackages gstPackages gitRepo pkgs.bash pkgs.coreutils ];
        config = {
          Cmd = [ "${pkgs.bash}/bin/bash" ];
          Env = [
            # For the driver library injected by nvidia-docker and onnxruntime
            "LD_LIBRARY_PATH=/usr/lib64:${pkgs.python310Packages.onnxruntime}/lib/python3.10/site-packages/onnxruntime/capi"
            "GST_PLUGIN_PATH=${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
            "PATH=$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
            "GI_TYPELIB_PATH=${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.gst_all_1.gstreamer.out}/lib/girepository-1.0"
            "EXTRA_CCFLAGS=-I/usr/include"
            "PATH=/bin:/usr/bin:${gstPackages}/bin:${pkgs.linuxPackages.nvidia_x11.bin}/bin"
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
              export GST_PLUGIN_PATH="${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
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