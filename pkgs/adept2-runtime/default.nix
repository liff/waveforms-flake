{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, libusb
, dpkg
}:

let

  arch = stdenv.targetPlatform.system;

  debianArch = (import ../../lib/debian-archs.nix).${arch};

  version = "2.21.3";

  hashes = {
    "x86_64-linux" = "sha256-3sLjWyAilcKiHGHYgeMDDHti2bs1q49L11BW68YXw4k=";
    "i686-linux" = "sha256-IgoS3ajfKUaygxJF2E0/dQN+qSxVo31t4ZuXpz9pe3Q=";
    "aarch64-linux" = "sha256-lLLG3Lf1VwCvKMhpaBBc2v1k2W/kfXMEsC1GA0X2TUQ=";
    "armv7l-linux" = "sha256-C+mwNQDw50aCmlT86sOxDMoNDTwkVjx968rdFeLYpzs=";
  };

in

stdenv.mkDerivation rec {
  pname = "adept2-runtime";
  inherit version;

  src = fetchurl {
    url = "https://files.digilent.com/Software/Adept2+Runtime/${version}/digilent.adept.runtime_${version}-${debianArch}.deb";
    hash = hashes.${arch};
  };

  preferLocalBuild = true;

  nativeBuildInputs = [ dpkg autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib libusb ];

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
    platforms = builtins.attrNames hashes;
  };
}
