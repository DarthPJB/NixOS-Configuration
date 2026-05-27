{ lib
, stdenv
, fetchFromGitHub
, meson
, ninja
, pkg-config
, wrapGAppsHook3
, lightdm
, gtk3
, webkitgtk_4_1
, dbus-glib
, glib
, runCommand
,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "lightdm-webkit2-greeter";
  version = "2.2.5";

  src = fetchFromGitHub {
    owner = "MerkeX"; # fork of Antergos
    repo = "Lightdm-webkit2-greeter";
    rev = "4549fd31e540a0fe7d4f21d8e18e6ef3f15875d6";
    hash = "sha256-AeneOJ+PT8MdYEI1Uwp8FVZi8HWb7mOEbZ/6qBdaXt8=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    lightdm
    gtk3
    webkitgtk_4_1
    dbus-glib
    glib
  ];

  mesonFlags = [
    "-Dwith-theme-dir=${placeholder "out"}/share/lightdm-webkit/themes"
    "-Dwith-config-dir=${placeholder "out"}/etc/lightdm"
    "-Dwith-desktop-dir=${placeholder "out"}/share/xgreeters"
    "-Dwith-webext-dir=${placeholder "out"}/lib/lightdm-webkit2-greeter"
    "-Dwith-locale-dir=${placeholder "out"}/share/locale"
  ];

  postPatch = ''
    substituteInPlace meson.build \
      --replace-fail "webkit2gtk-4.0" "webkit2gtk-4.1" \
      --replace-fail "webkit2gtk-web-extension-4.0" "webkit2gtk-web-extension-4.1" \
      --replace-fail "conf.set('CONFIG_DIR', '\"@0@\"'.format(get_option('with-config-dir')))" "conf.set('CONFIG_DIR', '\"/etc/lightdm\"')"

    patchShebangs build/utils.sh
    chmod +x build/utils.sh
  '';

  postInstall = ''
    if [ -f "$out/share/xgreeters/lightdm-webkit2-greeter.desktop" ]; then
      substituteInPlace "$out/share/xgreeters/lightdm-webkit2-greeter.desktop" \
        --replace-fail "Exec=lightdm-webkit2-greeter" "Exec=$out/bin/lightdm-webkit2-greeter"
    fi
  '';

  passthru = {
    xgreeters = runCommand "lightdm-webkit2-greeter-xgreeters" { } ''
      mkdir -p "$out"
      ln -s ${finalAttrs.finalPackage}/share/xgreeters/*.desktop "$out/"
    '';
  };

  meta = {
    description = "Webkit2 greeter for LightDM";
    homepage = "https://github.com/Antergos/web-greeter";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "lightdm-webkit2-greeter";
  };
})
