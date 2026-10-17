{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  libusb1,
  avahi,
  openssl,
  dpkg,
}:

let

  digilentPackages = import ../../data/packages.nix;
  inherit (digilentPackages.adept2-runtime) version systems;
  srcInfo = systems.${stdenv.targetPlatform.system};

in

stdenv.mkDerivation (finalAttrs: {
  pname = "adept2-runtime";
  inherit version;

  src = fetchurl {
    inherit (srcInfo) url hash;
    curlOptsList = [
      "--user-agent"
      "Mozilla/5.0 (X11; Linux x86_64; rv:158.0) Gecko/20100101 Firefox/158.0"
    ];
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  buildInputs = [
    stdenv.cc.cc.lib
    libusb1
    avahi
    openssl
  ];

  unpackCmd = "dpkg -x $curSrc out";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir --parents $out $out/etc/udev/rules.d

    cp -a usr/lib/digilent/adept $out/lib

    cat > $out/etc/digilent-adept.conf <<EOF
    DigilentPath=$out/lib
    EOF

    cat > $out/etc/udev/rules.d/52-digilent-usb.rules <<EOF
    ACTION=="add", ATTR{idVendor}=="1443", GROUP="plugdev", TAG+="uaccess"
    ACTION=="add", ATTR{idVendor}=="0403", ATTR{manufacturer}=="Digilent", GROUP="plugdev", TAG+="uaccess", RUN+="$out/lib/udev/dftdrvdtch %s{busnum} %s{devnum}"
    EOF

    runHook postInstall
  '';

  dontAutoPatchelf = true;

  postFixup = ''
    autoPatchelf "$out"

    for lib in $(find "$out/lib" -type f); do
      lib_rpath="$(patchelf --print-rpath "$lib")"
      echo "Adding self to RPATH of library $lib"
      patchelf --set-rpath "$out/lib:$lib_rpath" "$lib"
    done;
  '';

  meta = with lib; {
    description = "Digilent Adept Runtime";
    homepage = "https://reference.digilentinc.com/reference/software/adept/start";
    downloadPage = "https://mautic.digilentinc.com/adept-runtime-download";
    license = licenses.unfree;
    maintainers = [ maintainers.liff ];
    platforms = builtins.attrNames systems;
  };
})
