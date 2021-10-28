{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, libusb
, avahi
, dpkg
}:

let

  digilentPackages = import ../../data/packages.nix;
  inherit (digilentPackages.adept2-runtime) version systems;
  srcInfo = systems.${stdenv.targetPlatform.system};

in

stdenv.mkDerivation rec {
  pname = "adept2-runtime";
  inherit version;

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  preferLocalBuild = true;

  nativeBuildInputs = [ dpkg autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib libusb avahi ];

  unpackCmd = "dpkg -x $curSrc out";

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{etc,share} $out/etc/udev/rules.d

    cp -a usr/lib*/digilent/adept $out/lib
    cp -a usr/sbin $out/
    cp -a usr/share/{doc,digilent} $out/share/

    cat > $out/etc/digilent-adept.conf <<EOF
    DigilentPath=$out/share/digilent
    DigilentDataPath=$out/share/digilent/adept/data
    EOF

    cat > $out/etc/udev/rules.d/52-digilent-usb.rules <<EOF
    ACTION=="add", ATTR{idVendor}=="1443", GROUP+="plugdev", TAG+="uaccess"
    ACTION=="add", ATTR{idVendor}=="0403", ATTR{manufacturer}=="Digilent", GROUP+="plugdev", TAG+="uaccess", RUN+="$out/sbin/dftdrvdtch %s{busnum} %s{devnum}"
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
}
