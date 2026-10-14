{
  description = "FigCraft (Rust design tool) and figcraft-server, built from upstream source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Upstream source. Not a flake, hence `flake = false`. Pinned in flake.lock;
    # bump it with:  nix flake update figcraft
    figcraft = {
      url = "github:storytold/figcraft";
      flake = false;
    };

    # Optional fonts embedded at build time (Japanese, Chinese, Arabic, Latin).
    # Only used when `withFonts = true` (see mkPackages below).
    craft-fonts = {
      url = "github:storytold/craft-fonts";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      figcraft,
      craft-fonts,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Build function. Call it with different options if you want a variant:
      #   withFonts     embed upstream's craft-fonts (needs a craft-fonts commit
      #                 that matches the figcraft revision, see README note)
      #   defaultServer null  = keep upstream's built-in public sharing server
      #                 ""    = no default server (online sharing off until set)
      #                 "wss://host/" = your own figcraft-server
      mkPackages =
        pkgs:
        {
          withFonts ? false,
          defaultServer ? null,
        }:
        let
          inherit (pkgs) lib;

          src = figcraft;
          cargoToml = builtins.fromTOML (builtins.readFile "${src}/Cargo.toml");
          version = cargoToml.workspace.package.version;
          minRust = cargoToml.workspace.package."rust-version";

          # Libraries winit/wgpu/egui/rfd open with dlopen at runtime.
          # dbus is what rfd uses to reach xdg-desktop-portal (file dialogs).
          runtimeLibs = with pkgs; [
            dbus
            libxkbcommon
            wayland
            libx11
            libxcursor
            libxi
            libxrandr
            libxcb
            vulkan-loader
            libglvnd
          ];

          common = {
            inherit version src;
            cargoLock.lockFile = "${src}/Cargo.lock";
            doCheck = false; # the workspace test suite is large; run it upstream

            env = {
              FIGCRAFT_BUILD_SHA = src.shortRev or "nix";
            }
            // lib.optionalAttrs withFonts {
              # Takes precedence over the relative ../craft-fonts in .cargo/config.toml
              CRAFT_FONTS_DIR = "${craft-fonts}";
              CRAFT_FONTS_REQUIRED = "1";
            }
            // lib.optionalAttrs (defaultServer != null) {
              FIGCRAFT_DEFAULT_SERVER = defaultServer;
            };
          };

          commonMeta = {
            homepage = "https://github.com/storytold/figcraft";
            license = with lib.licenses; [
              mit
              asl20
            ];
            platforms = lib.platforms.linux;
          };
        in
        assert lib.assertMsg (lib.versionAtLeast pkgs.rustc.version minRust)
          "figcraft needs Rust >= ${minRust} but this nixpkgs has ${pkgs.rustc.version}; update nixpkgs or switch to rust-overlay/fenix";
        {
          figcraft = pkgs.rustPlatform.buildRustPackage (
            common
            // {
              pname = "figcraft";
              cargoBuildFlags = [
                "-p"
                "figcraft"
                "-p"
                "figcraft-cli"
              ];

              nativeBuildInputs = with pkgs; [
                pkg-config
                makeWrapper
                copyDesktopItems
              ];
              buildInputs = runtimeLibs;

              desktopItems = [
                (pkgs.makeDesktopItem {
                  name = "ai.storyteller.figcraft";
                  desktopName = "FigCraft";
                  genericName = "Interface Design";
                  comment = "Interface design and prototyping";
                  exec = "figcraft %F";
                  icon = "ai.storyteller.figcraft";
                  categories = [
                    "Graphics"
                    "2DGraphics"
                    "VectorGraphics"
                    "X-Design"
                  ];
                  mimeTypes = [ "application/x-figcraft" ];
                })
              ];

              postInstall = ''
                mkdir -p $out/share/icons
                cp -r assets/app-icon/hicolor $out/share/icons/
              '';

              # dlopen'd libraries are found through the binary's RUNPATH;
              # xdg-open is needed for "open link in browser".
              postFixup = ''
                patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} $out/bin/figcraft
                wrapProgram $out/bin/figcraft \
                  --prefix PATH : ${lib.makeBinPath [ pkgs.xdg-utils ]}
              '';

              meta = commonMeta // {
                description = "Open-source, Rust-native interface design and prototyping tool";
                mainProgram = "figcraft";
              };
            }
          );

          # Headless collaboration server: no GUI libraries, small closure.
          figcraft-server = pkgs.rustPlatform.buildRustPackage (
            common
            // {
              pname = "figcraft-server";
              cargoBuildFlags = [
                "-p"
                "figcraft-server"
              ];
              meta = commonMeta // {
                description = "Collaboration server for FigCraft";
                mainProgram = "figcraft-server";
              };
            }
          );
        };
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          p = mkPackages pkgs { };
        in
        p // { default = p.figcraft; }
      );

      # pkgs.figcraft and pkgs.figcraft-server once you add this overlay.
      overlays.default = final: _prev: mkPackages final { };

      # For variants:  inputs.figcraft-flake.lib.mkPackages pkgs { withFonts = true; }
      lib.mkPackages = mkPackages;
    };
}
