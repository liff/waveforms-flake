[![Build packages](https://github.com/liff/waveforms-flake/actions/workflows/build-packages.yml/badge.svg)](https://github.com/liff/waveforms-flake/actions/workflows/build-packages.yml)

A Nix [flake](https://nixos.wiki/wiki/Flakes) for [Digilent Waveforms](https://store.digilentinc.com/digilent-waveforms/).

# Usage

In addition to the `waveforms` package and app, this Flake provides a
NixOS module that installs the package and sets up the USB device 
permissions so that `plugdev` group users are allowed to access.

```nix
{
  waveforms.url = "github:liff/waveforms-flake";

  outputs = { self, nixpkgs, waveforms }: {
    # replace 'joes-desktop' with your hostname here.
    nixosConfigurations.joes-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # …
        waveforms.nixosModule
        ({ users.users.joe.extraGroups = [ "plugdev" ]; })
      ];
    };
  };
}
```
