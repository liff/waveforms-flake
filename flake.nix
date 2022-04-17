{
  description = "Digilent Waveforms";

  outputs = { self, nixpkgs }:
    let systems = [ "i686-linux" "x86_64-linux" "armv7l-linux" "aarch64-linux" ];
        names = [
          "adept2-runtime"
          "waveforms"
        ];

        toFlakePackage = system: name: {
          inherit name;
          value = (import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ self.overlay ];
          })."${name}";
        };

        inherit (builtins) map listToAttrs;

        eachSystem = f: listToAttrs (map (system: { name = system; value = f system; }) systems);

        packages = eachSystem (system: 
          let all = listToAttrs (map (toFlakePackage system) names);
          in all // { default = all.waveforms; }
        );

        overlay = final: prev:
          listToAttrs (
            map (name: {
              inherit name;
              value = final.callPackage (./pkgs + "/${name}") {};
            })
              names);

        apps = eachSystem (system: rec {
          waveforms = {
            type = "app";
            program = "${packages.${system}.waveforms}/bin/waveforms";
          };
          default = waveforms;
        });

        defaultPackage = eachSystem (system: packages.${system}.default);

        defaultApp = eachSystem (system: apps.${system}.default);

    in {
      inherit packages overlay defaultPackage apps defaultApp;

      overlays.default = overlay;

      nixosModule = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];
        services.udev.packages = [ pkgs.adept2-runtime ];
        environment.systemPackages = [ pkgs.waveforms ];
      };
    };
}
