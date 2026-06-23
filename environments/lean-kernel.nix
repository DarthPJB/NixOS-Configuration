# environments/lean-kernel.nix
#
# Lean kernel configuration for Raspberry Pi 4 machines.
# Disables unnecessary drivers to reduce build time and disk usage.
#
# Current kernel: 6250 modules (generic aarch64 desktop)
# Target kernel: ~2000-3000 modules (Pi 4 specific)
#
# Build time reduction: ~7 hours → ~2-3 hours
#
{ lib, ... }:
{
  boot.kernelPatches = [
    # =============================================
    # Disable x86_64-specific GPU drivers
    # Pi 4 uses vc4/v3d, not AMD/NVIDIA/Intel
    # =============================================
    {
      name = "disable-x86-gpu";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        DRM_AMDGPU = no;
        DRM_NOUVEAU = no;
        DRM_QXL = no;
        DRM_VBOXVIDEO = no;
        DRM_VMWGFX = no;      # VMware GPU
        DRM_BOCHS = no;       # QEMU/Bochs GPU
        DRM_CIRRUS_QEMU = no; # QEMU Cirrus
        DRM_VIRTIO_GPU = no;  # VirtIO GPU
        DRM_GMA500 = no;      # Intel GMA
        DRM_AST = no;         # ASPEED server GPU
        DRM_MGAG200 = no;     # Matrox server GPU
        DRM_HISI_HIBMC = no;  # HiSilicon server GPU
      };
    }

    # =============================================
    # Disable enterprise/datacenter networking
    # Pi 4 uses onboard WiFi (brcmfmac) + Ethernet
    # =============================================
    {
      name = "disable-enterprise-net";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # Mellanox (100GbE datacenter)
        MLX5_CORE = no;
        MLXSW_CORE = no;
        MLXFW = no;
        MLXSW_SPECTRUM = no;
        MLXSW_SWITCHX2 = no;
        MLXSW_MINIMAL = no;

        # Chelsio (10/25/40/100GbE)
        CHELSIO_T1 = no;
        CHELSIO_T3 = no;
        CHELSIO_T4 = no;
        CHELSIO_T4VF = no;
        CHELSIO_CORE = no;
        CHELSIO_LIB = no;

        # Netronome (SmartNIC)
        NETDEVSIM = no;
        NFP = no;

        # Cavium/Marvell (datacenter)
        THUNDER_NIC_PF = no;
        THUNDER_NIC_VF = no;
        THUNDER_NIC_BGX = no;
        THUNDER_NIC_RGX = no;
        LIQUIDIO = no;
        LIQUIDIO_VF = no;

        # Amazon/Azure cloud NICs
        ENA_ETHERNET = no;
        MANA = no;

        # Solarflare (datacenter)
        SFC = no;
        SFC_FALCON = no;

        # QLogic (datacenter)
        QLCNIC = no;
        QED = no;
        QEDE = no;
        NETXEN_NIC = no;

        # Broadcom enterprise (not Pi WiFi)
        BNX2 = no;
        BNX2X = no;
        BNXT = no;

        # Intel enterprise (not needed on Pi)
        IGB = no;
        IXGBE = no;
        I40E = no;
        ICE = no;
        FM10K = no;
        IGBVF = no;
        IXGBEVF = no;
      };
    }

    # =============================================
    # Disable virtualization drivers
    # Pi 4 is bare metal, not a hypervisor
    # =============================================
    {
      name = "disable-virtualization";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # Xen
        XEN = no;
        XEN_DOM0 = no;
        XEN_BLKDEV_FRONTEND = no;
        XEN_BLKDEV_BACKEND = no;
        XEN_NETDEV_FRONTEND = no;
        XEN_NETDEV_BACKEND = no;
        XEN_SCSI_FRONTEND = no;
        XEN_FBDEV_FRONTEND = no;
        XEN_BALLOON = no;
        XEN_DEV_EVTCHN = no;
        XEN_GNTDEV = no;
        XEN_GRANT_DEV_ALLOC = no;
        XEN_PRIVCMD = no;

        # KVM (not needed on display machines)
        KVM = no;
        KVM_AMD = no;
        KVM_ARM = no;
        KVM_ARM_HOST = no;

        # VirtIO (QEMU/KVM guests)
        VIRTIO = no;
        VIRTIO_PCI = no;
        VIRTIO_BLK = no;
        VIRTIO_NET = no;
        VIRTIO_CONSOLE = no;
        VIRTIO_MMIO = no;
      };
    }

    # =============================================
    # Disable exotic storage drivers
    # Pi 4 uses MMC + NVMe (USB bridge)
    # =============================================
    {
      name = "disable-exotic-storage";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # Fibre Channel
        SCSI_FC_TGT_ATTRS = no;
        SCSI_FC_ATTRS = no;
        FCOE = no;
        LIBFC = no;
        LIBFCOE = no;

        # iSCSI enterprise
        ISCSI_TCP = no;
        ISCSI_BOOT = no;

        # InfiniBand
        INFINIBAND = no;
        INFINIBAND_USER_ACCESS = no;
        INFINIBAND_ADDR_TRANS = no;

        # SAS enterprise
        SCSI_ISCSI_ATTRS = no;
        SCSI_SAS_ATTRS = no;
        SCSI_SAS_LIBSAS = no;
        SCSI_SAS_ATA = no;

        # RAID controllers (enterprise)
        MEGARAID_NEWGEN = no;
        MEGARAID_MM = no;
        MEGARAID_MAILBOX = no;
        MEGARAID_LEGACY = no;
        SCSI_MPT2SAS = no;
        SCSI_MPT3SAS = no;
        SCSI_SMARTPQI = no;
        SCSI_HPSA = no;
        SCSI_AACRAID = no;
      };
    }

    # =============================================
    # Disable wireless enterprise/cellular
    # Pi 4 uses brcmfmac (Broadcom WiFi)
    # =============================================
    {
      name = "disable-enterprise-wireless";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # Enterprise WiFi (Intel, Qualcomm Atheros enterprise)
        IWLWIFI = no;         # Intel WiFi
        ATH11K = no;          # Qualcomm WiFi 6 (enterprise)
        ATH12K = no;          # Qualcomm WiFi 7
        WL18XX = no;          # TI WiFi (enterprise)
        WL12XX = no;          # TI WiFi (enterprise)
        CW1200 = no;          # ST-Ericsson WiFi
        RSICS = no;           # RSI WiFi
        WILC1000 = no;        # Microchip WiFi
        AT86RF230 = no;       # Atmel 802.15.4
        CC2520 = no;          # TI 802.15.4
        ATUSB = no;           # Atmel USB 802.15.4

        # Cellular modems (not needed on display machines)
        USB_SERIAL_OPTION = no;
        USB_SERIAL_SIERRAWIRELESS = no;
        USB_SERIAL_QUALCOMM = no;
      };
    }

    # =============================================
    # Disable misc unnecessary subsystems
    # =============================================
    {
      name = "disable-misc-unnecessary";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # PCMCIA (not on Pi)
        PCCARD = no;
        CARDBUS = no;
        YENTA = no;
        PD6729 = no;
        I82092 = no;

        # ISA/legacy bus
        ISA = no;

        # Thunderbolt (not on Pi)
        THUNDERBOLT = no;

        # FireWire (not on Pi)
        FIREWIRE = no;
        IEEE1394 = no;

        # Parallel port (not on Pi)
        PARPORT = no;

        # Amateur radio
        HAMRADIO = no;
        AX25 = no;
        NETROM = no;
        ROSE = no;

        # CAN bus (industrial, not needed)
        CAN = no;

        # NFC (not needed on display machines)
        NFC = no;
        NCI = no;
      };
    }

    # =============================================
    # Keep essential Pi 4 drivers (explicit)
    # =============================================
    {
      name = "ensure-pi4-essential";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # GPU (Pi 4 specific)
        DRM_VC4 = yes;
        DRM_V3D = yes;
        DRM_VC4_HDMI_CEC = yes;

        # Audio
        SND_BCM2835 = yes;
        SND_SOC = yes;
        SND_USB_AUDIO = yes;

        # WiFi (Pi 4 onboard)
        BRCMFMAC = yes;
        BRCMUTIL = yes;
        CFG80211 = yes;
        MAC80211 = yes;

        # Bluetooth (Pi 4 onboard)
        BT = yes;
        BT_BCM = yes;
        BT_HCIUART = yes;
        BT_HCIBTSDIO = yes;
        BT_HCIBTUSB = yes;

        # USB
        USB = yes;
        USB_DWC2 = yes;
        USB_DWC3 = yes;
        USB_XHCI_HCD = yes;
        USB_EHCI_HCD = yes;
        USB_STORAGE = yes;
        USB_HID = yes;

        # MMC/SD
        MMC = yes;
        MMC_BLOCK = yes;
        MMC_BCM2835 = yes;
        MMC_SDHCI = yes;
        MMC_SDHCI_IPROC = yes;

        # HID/Input
        HID = yes;
        HID_MULTITOUCH = yes;
        HID_GENERIC = yes;
        USB_HIDDEV = yes;

        # NVMe (via USB bridge)
        NVME_CORE = yes;
        BLK_DEV_NVME = yes;

        # WireGuard
        WIREGUARD = yes;

        # Networking essentials
        NET = yes;
        INET = yes;
        IPV6 = yes;
        NETFILTER = yes;
        NF_TABLES = yes;
        BRIDGE = yes;
        VLAN_8021Q = yes;

        # Filesystems
        EXT4_FS = yes;
        FUSE_FS = module;
        VFAT_FS = yes;
        FAT_FS = yes;

        # Video (Pi camera)
        VIDEO_BCM2835 = yes;
        V4L2_MEM2MEM = yes;
        VIDEO_CODEC_BCM2835 = yes;
        VIDEO_ISP_BCM2835 = yes;
      };
    }
  ];
}
