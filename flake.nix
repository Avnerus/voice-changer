{
  description = "Voice changer docker with Nix Flakes";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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

    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    python = pkgs.python3.override {
      packageOverrides = self: super: {
        onnxruntime-gpu = pkgs.onnxruntime.override {
          cudaSupport = true;
        };
        faiss-cpu = pkgs.python310Packages.faiss;
      };
    };

    pythonEnv =
      # Assert that versions from nixpkgs matches what's described in requirements.txt
      # In projects that are overly strict about pinning it might be best to remove this assertion entirely.
      assert project.validators.validateVersionConstraints { inherit python; } == { }; (
        # Render requirements.txt into a Python withPackages environment
        pkgs.python3.withPackages (project.renderers.withPackages {
          inherit python;
        })
      );

    myEnv = pkgs.buildEnv {
      name = "puppetbots-voice-env";
      paths = [
        pkgs.python310
        pkgs.python310.pkgs.requests
        pkgs.python310Packages.gst-python
        pkgs.linuxPackages.nvidia_x11
        pkgs.portaudio
        pkgs.gcc
        pkgs.gst_all_1.gstreamer
        pkgs.gst_all_1.gst-plugins-base
        pkgs.gst_all_1.gst-plugins-good
        pkgs.gst_all_1.gst-plugins-bad
        pkgs.gst_all_1.gst-plugins-ugly
        pkgs.pkg-config
        pkgs.gobject-introspection
        pkgs.cairo
        pkgs.xorg.libxcb.dev
        pkgs.xorg.libX11.dev
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
      contents = [ pythonEnv myEnv pkgs.bashInteractive];
      config = {
        Cmd = [ "/bin/bash" ];
        Env = [
          "LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib"
          "GST_PLUGIN_PATH=${pkgs.gst_all_1.gst-plugins-base}/lib/gstreamer-1.0:${pkgs.gst_all_1.gst-plugins-good}/lib/gstreamer-1.0"
          "PATH=$PATH:${pkgs.gst_all_1.gstreamer.dev}/bin"
          "GI_TYPELIB_PATH=${pkgs.gobject-introspection}/lib/girepository-1.0:${pkgs.gst_all_1.gstreamer.out}/lib/girepository-1.0"
          "EXTRA_LDFLAGS=-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
          "EXTRA_CCFLAGS=-I/usr/include"
        ];
      };
    };
    in {
      packages.x86_64-linux = {
        default = pkgs.mkShell {
          name = "puppetbots-voice-shell";
          buildInputs = [ myEnv pythonEnv ];
        };
        docker = dockerImage;
      };
    };
}