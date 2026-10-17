{
  lib,
  stdenv,
  runtimeShell,
  fetchurl,
  autoPatchelfHook,
  dpkg,
  qt6,
  xdg-utils,
  shared-mime-info,
  pipewire,
  adept2-runtime,
}:

let

  digilentPackages = import ../../data/packages.nix;
  inherit (digilentPackages.waveforms) version systems;
  srcInfo = systems.${stdenv.targetPlatform.system};

  rewriteUsr = "rewrite-usr" + stdenv.targetPlatform.extensions.sharedLibrary;

in

stdenv.mkDerivation {
  pname = "waveforms";
  inherit version;

  src = fetchurl {
    inherit (srcInfo) url hash;
    curlOptsList = [
      "--user-agent" "Mozilla/5.0 (X11; Linux x86_64; rv:158.0) Gecko/20100101 Firefox/158.0"
    ];
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    qt6.wrapQtAppsHook
    shared-mime-info
  ];

  buildInputs = [
    adept2-runtime
    pipewire
    qt6.qtbase
    qt6.qtmultimedia
    qt6.qtserialport
  ];

  runtimeDependencies = [ adept2-runtime ];

  unpackCmd = "dpkg -x $curSrc out";

  preFixup = ''
    qtWrapperArgs+=(--set LD_PRELOAD $out/lib/${rewriteUsr})
    qtWrapperArgs+=(--prefix PATH : $out/libexec:$out/bin)
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

    mkdir -p $out/share $out/libexec
    rm -r usr/share/lintian
    cp -a usr/* $out/
    mv $out/share/digilent/waveforms/doc $out/bin/
    cp -a ${rewriteUsr} $out/lib/
    cp -a xdg-open $out/libexec/
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
    platforms = builtins.attrNames systems;
    mainProgram = "waveforms";
  };
}
