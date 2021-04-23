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
            overlays = [ self.overlay ];
          })."${name}";
        };

        inherit (builtins) map listToAttrs;

        eachSystem = f: listToAttrs (map (system: { name = system; value = f system; }) systems);

        packages = eachSystem (system: listToAttrs (map (toFlakePackage system) names));

        overlay = final: prev:
          listToAttrs (
            map (name: {
              inherit name;
              value = final.callPackage (./pkgs + "/${name}") {};
            })
              names);

        defaultPackage = eachSystem (system: packages.${system}.waveforms);

        apps = eachSystem (system: {
          waveforms = {
            type = "app";
            program = "${packages.${system}.waveforms}/bin/waveforms";
          };
        });

        defaultApp = eachSystem (system: apps.${system}.waveforms);

    in {
      inherit packages overlay defaultPackage apps defaultApp;

      nixosModule = { pkgs, ... }: {
        nixpkgs.overlays = [ self.overlay ];
        services.udev.packages = [ pkgs.adept2-runtime ];
        environment.systemPackages = [ pkgs.waveforms ];
      };
    };
}
