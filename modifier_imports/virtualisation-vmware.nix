{ config, pkgs, lib, ... }:
{
  networking.firewall.trustedInterfaces = [ "virbr0" ];

  # The vmware module package installs via upstream's hand-rolled
  # `make install`, bypassing kbuild's modules_install recipe
  # (install → strip → sign). The sign step is where kmodigest — the
  # cmd_sign override carried by kernelModuleMakeFlags — writes each
  # module's `.ko.cer` certificate, which kmod/aggregator.nix merges
  # unconditionally into modules.cer. Without it the modules buildEnv
  # dies on `cat: misc/vmmon.ko.cer: No such file or directory`.
  # Route installation through kbuild modules_install (the broadcom-sta
  # pattern) so vmmon/vmnet are signed and certified like every other
  # external module. Layout `misc/` matches upstream's install path.
  boot.kernelPackages = pkgs.linuxPackages.extend (final: prev: {
    vmware = prev.vmware.overrideAttrs (old: {
      makeFlags = (old.makeFlags or [ ]) ++ final.kernelModuleMakeFlags;
      installPhase = ''
        runHook preInstall
        for mod in vmmon-only vmnet-only; do
          make ${lib.escapeShellArgs final.kernelModuleMakeFlags} \
            -C ${final.kernel.dev}/lib/modules/${final.kernel.modDirVersion}/build \
            "M=$PWD/$mod" \
            "INSTALL_MOD_PATH=$out" \
            "INSTALL_MOD_DIR=misc" \
            modules_install
        done
        runHook postInstall
      '';
    });
  });

  virtualisation.vmware.host = {
    enable = true;
    extraConfig = ''
       # Allow unsupported device's OpenGL and Vulkan acceleration for guest vGPU
      mks.gl.allowUnsupportedDrivers = "TRUE"
      mks.vk.allowUnsupportedDevices = "TRUE"
    '';
  };
  boot.kernelParams = [ "transparent_hugepage=never" ];
}
