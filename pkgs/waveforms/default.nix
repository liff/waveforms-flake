{ lib
, stdenv
, runtimeShell
, fetchurl
, autoPatchelfHook
, dpkg
, qt5
, xdg-utils
, shared-mime-info
, adept2-runtime
}:

let

  arch = stdenv.targetPlatform.system;

  debianArch = (import ../../lib/debian-archs.nix).${arch};

  version = "3.16.3";

  hashes = {
    "x86_64-linux" = "sha256-/8AfE2SVDPawHUX5Q+/ozzYaWSvOodh6vFoQYoFs9ts=";
    "aarch64-linux" = "sha256-+0hHi30wh4rZrZA3F7eVmIMBF7fnwhMZVTF4fdrYIq4=";
    "armv7l-linux" = "sha256-CuXq47nzXsoaEIdmeh+X/7XF9wHOgrZCPTcdTdoJoIQ=";
    "i686-linux" = "sha256-61/Lcl6wg+u9Kw0kSuSgBRgQlQJUOUEZa1kekIIexzI=";
  };

  rewriteUsr = "rewrite-usr" + stdenv.targetPlatform.extensions.sharedLibrary;

in

stdenv.mkDerivation {
  pname = "waveforms";
  inherit version;

  src = fetchurl {
    url = "https://digilent.s3-us-west-2.amazonaws.com/Software/Waveforms2015/${version}/digilent.waveforms_${version}_${debianArch}.deb";
    hash = hashes.${arch};
  };

  preferLocalBuild = true;

  nativeBuildInputs = [ dpkg autoPatchelfHook qt5.wrapQtAppsHook shared-mime-info ];

  buildInputs = [ adept2-runtime qt5.qtbase qt5.qtscript qt5.qtmultimedia ];

  runtimeDependencies = [ adept2-runtime ];

  unpackCmd = "dpkg -x $curSrc out";

  preFixup = ''
    qtWrapperArgs+=(--set LD_PRELOAD $out/lib/${rewriteUsr})
    qtWrapperArgs+=(--prefix PATH : $out/bin)
    qtWrapperArgs+=(--set DIGILENT_ADEPT_CONF ${adept2-runtime}/etc/digilent-adept.conf)
  '';

  buildPhase = ''
    runHook preBuild

    $CC -Wall -std=c99 -O3 -fPIC -ldl -shared \
        -DDRV_DIR=\"$out\" \
        -o ${rewriteUsr} ${./rewrite-usr.c}

    cat > xdg-open <<EOF
    #!${runtimeShell}
    if [ "\$1" = "file:///usr/share/digilent/waveforms/" ]; then
        shift
        exec ${xdg-utils}/bin/xdg-open "file://$out/share/digilent/waveforms"
    else
        exec ${xdg-utils}/bin/xdg-open "\$@"
    fi
    EOF
    chmod +x xdg-open

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    rm -r usr/share/lintian
    cp -a usr/* $out/
    mv $out/share/digilent/waveforms/doc $out/bin/
    cp -a ${rewriteUsr} $out/lib/
    cp -a xdg-open $out/bin/
    substituteInPlace $out/share/applications/digilent.waveforms.desktop \
        --replace /usr/bin $out/bin \
        --replace /usr/share $out/share

    runHook postInstall
  '';

  meta = with lib; {
    description = "Digilent Waveforms";
    homepage = "https://store.digilentinc.com/digilent-waveforms/";
    downloadPage = "https://mautic.digilentinc.com/waveforms-download";
    license = licenses.unfree;
    maintainers = [ maintainers.liff ];
    platforms = builtins.attrNames hashes;
  };
}
