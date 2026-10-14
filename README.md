# figcraft-flake

A Nix flake that builds [FigCraft](https://github.com/storytold/figcraft), the open-source, Rust-native interface design and prototyping tool, straight from upstream source. Add it to your NixOS, Home Manager or nix-darwin-free Linux setup and get FigCraft without hunting for installers.

This is unofficial packaging. FigCraft is developed by the ArtCraft team and is not affiliated with this repository. Upstream describes it as early alpha, so expect rough edges.

## What you get

| Package | What it is |
|---|---|
| `figcraft` | The desktop app, plus `figcraft-cli` for headless rendering, export and MCP. Includes a desktop entry and icons. |
| `figcraft-server` | The collaboration server for live sessions. Headless, with no GUI libraries. |

Supported systems: `x86_64-linux` and `aarch64-linux`. You need a nixpkgs recent enough to ship Rust 1.95 or newer (nixos-unstable is fine); the flake stops with a clear message if yours is too old.

## Try it

```sh
nix run github:diamondmyr/figcraft-flake                       # desktop app
nix run github:diamondmyr/figcraft-flake#figcraft-server       # collaboration server
nix build github:diamondmyr/figcraft-flake                     # just build it
```

The first build compiles the whole Rust workspace, so give it a few minutes.

## Install it on NixOS

Add the flake as an input in your system flake and apply the overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    figcraft-flake = {
      url = "github:diamondmyr/figcraft-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, figcraft-flake, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          nixpkgs.overlays = [ figcraft-flake.overlays.default ];
          environment.systemPackages = [ pkgs.figcraft ];
        }
      ];
    };
  };
}
```

Prefer not to use an overlay? Reference the package directly:

```nix
environment.systemPackages = [
  figcraft-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

The same package works in Home Manager's `home.packages`.

On NixOS, make sure graphics are enabled (`hardware.graphics.enable = true;`). FigCraft renders with wgpu and needs a working Vulkan or OpenGL driver.


## Privacy note

FigCraft works offline and sends nothing until you share or join a file. **Share ▸ Online** uploads the file to a server, which stores it unencrypted. By default that is upstream's public server. Set `defaultServer = ""` if you would rather it never be offered, or host your own (see below).

## Running the collaboration server

```sh
figcraft-server --listen 127.0.0.1:47900 --data /var/lib/figcraft
```

Put it behind a TLS reverse proxy before exposing it beyond a trusted network. Configuration, public hosting, backups and moderation are covered in upstream's [server documentation](https://github.com/storytold/figcraft/blob/main/docs/server.md).


## License

The Nix code in this repository is released under the [MIT License](LICENSE). FigCraft itself is dual-licensed MIT or Apache-2.0 by its authors; see the [upstream repository](https://github.com/storytold/figcraft) for details and for the licenses of bundled fonts and assets.
