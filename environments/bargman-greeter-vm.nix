{ modulesPath, lib, config, ... }:

{
  imports = [
    "${modulesPath}/virtualisation/qemu-vm.nix"
    ./bargman-greeter-vm-accounts.nix
  ];

  virtualisation = {
    memorySize = lib.mkDefault 4096;
    diskSize = lib.mkDefault 8192;
    cores = lib.mkDefault 4;
    qemu.options = [
      "-device virtio-gpu-pci"
    ];
  };

  boot.kernelParams = [ "console=ttyS0,115200" ];

  boot.initrd.availableKernelModules = [ "virtio_gpu" ];
  boot.initrd.kernelModules = [ "virtio_gpu" ];
}
