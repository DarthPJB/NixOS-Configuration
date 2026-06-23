# environments/lean-kernel-print.nix
#
# Lean kernel configuration for Raspberry Pi 3 print controller.
# Headless machine with USB serial for 3D printer control.
#
# Optimized for minimal build time and disk usage.
#
{ lib, ... }:
{
  boot.kernelPatches = [
    # =============================================
    # Disable all GPU/display drivers
    # Pi 3 print controller is headless
    # =============================================
    {
      name = "disable-gpu-display";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # All GPU drivers (headless)
        DRM = no;
        DRM_VC4 = no;
        DRM_V3D = no;
        DRM_GMA500 = no;
        DRM_AST = no;
        DRM_MGAG200 = no;
        DRM_HISI_HIBMC = no;

        # Framebuffer (headless)
        FB = no;
        FB_BCM2708 = no;

        # Display connectors
        DRM_DISPLAY_HELPER = no;
        DRM_DMA_HELPER = no;
      };
    }

    # =============================================
    # Disable audio (not needed for print controller)
    # =============================================
    {
      name = "disable-audio";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        SOUND = no;
        SND = no;
        SND_SOC = no;
        SND_BCM2835 = no;
        SND_USB_AUDIO = no;
        SND_PCM = no;
        SND_TIMER = no;
        SND_RAWMIDI = no;
        SND_SEQ_DEVICE = no;
        SND_COMPRESS = no;
        SND_HWDEP = no;
      };
    }

    # =============================================
    # Disable video capture (not needed)
    # =============================================
    {
      name = "disable-video";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        MEDIA_SUPPORT = no;
        MEDIA_CAMERA_SUPPORT = no;
        MEDIA_ANALOG_TV_SUPPORT = no;
        MEDIA_DIGITAL_TV_SUPPORT = no;
        MEDIA_RADIO_SUPPORT = no;
        MEDIA_SDR_SUPPORT = no;
        VIDEO_DEV = no;
        V4L2_MEM2MEM = no;
        VIDEO_BCM2835 = no;
        VIDEO_CODEC_BCM2835 = no;
        VIDEO_ISP_BCM2835 = no;
      };
    }

    # =============================================
    # Disable enterprise/datacenter networking
    # =============================================
    {
      name = "disable-enterprise-net";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # Mellanox
        MLX5_CORE = no;
        MLXSW_CORE = no;
        MLXFW = no;

        # Chelsio
        CHELSIO_T1 = no;
        CHELSIO_T3 = no;
        CHELSIO_T4 = no;
        CHELSIO_T4VF = no;
        CHELSIO_CORE = no;
        CHELSIO_LIB = no;

        # Netronome
        NETDEVSIM = no;
        NFP = no;

        # Cavium/Marvell
        THUNDER_NIC_PF = no;
        THUNDER_NIC_VF = no;
        LIQUIDIO = no;
        LIQUIDIO_VF = no;

        # Amazon/Azure
        ENA_ETHERNET = no;
        MANA = no;

        # Solarflare
        SFC = no;
        SFC_FALCON = no;

        # QLogic
        QLCNIC = no;
        QED = no;
        QEDE = no;
        NETXEN_NIC = no;

        # Broadcom enterprise
        BNX2 = no;
        BNX2X = no;
        BNXT = no;

        # Intel enterprise
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
    # Disable virtualization
    # =============================================
    {
      name = "disable-virtualization";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        XEN = no;
        XEN_DOM0 = no;
        KVM = no;
        KVM_AMD = no;
        KVM_ARM = no;
        KVM_ARM_HOST = no;
        VIRTIO = no;
        VIRTIO_PCI = no;
        VIRTIO_BLK = no;
        VIRTIO_NET = no;
      };
    }

    # =============================================
    # Disable exotic storage
    # =============================================
    {
      name = "disable-exotic-storage";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        SCSI_FC_TGT_ATTRS = no;
        SCSI_FC_ATTRS = no;
        FCOE = no;
        LIBFC = no;
        LIBFCOE = no;
        ISCSI_TCP = no;
        ISCSI_BOOT = no;
        INFINIBAND = no;
        SCSI_SAS_ATTRS = no;
        SCSI_SAS_LIBSAS = no;
        SCSI_SAS_ATA = no;
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
    # =============================================
    {
      name = "disable-enterprise-wireless";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        IWLWIFI = no;
        ATH11K = no;
        ATH12K = no;
        WL18XX = no;
        WL12XX = no;
        CW1200 = no;
        RSICS = no;
        WILC1000 = no;
        AT86RF230 = no;
        CC2520 = no;
        ATUSB = no;
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
        PCCARD = no;
        CARDBUS = no;
        YENTA = no;
        ISA = no;
        THUNDERBOLT = no;
        FIREWIRE = no;
        IEEE1394 = no;
        PARPORT = no;
        HAMRADIO = no;
        AX25 = no;
        NETROM = no;
        ROSE = no;
        CAN = no;
        NFC = no;
        NCI = no;
        BLUETOOTH = no;
        BT = no;
        BT_BCM = no;
        BT_HCIUART = no;
        RFKILL = no;
      };
    }

    # =============================================
    # Keep essential Pi 3 print controller drivers
    # =============================================
    {
      name = "ensure-print-controller-essential";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        # USB (essential for serial printer connection)
        USB = yes;
        USB_DWC2 = yes;
        USB_XHCI_HCD = yes;
        USB_EHCI_HCD = yes;
        USB_STORAGE = yes;
        USB_HID = yes;

        # USB Serial (3D printer connection)
        USB_SERIAL = yes;
        USB_SERIAL_GENERIC = yes;
        USB_SERIAL_FTDI = yes;
        USB_SERIAL_CP210X = yes;
        USB_SERIAL_CH341 = yes;
        USB_SERIAL_PL2303 = yes;
        USB_SERIAL_OPTION = yes;
        USB_ACM = yes;           # CDC ACM for STM32

        # HID (keyboard/mouse if connected)
        HID = yes;
        HID_GENERIC = yes;
        USB_HIDDEV = yes;

        # MMC/SD (boot device)
        MMC = yes;
        MMC_BLOCK = yes;
        MMC_BCM2835 = yes;
        MMC_SDHCI = yes;
        MMC_SDHCI_IPROC = yes;

        # WiFi (Pi 3 onboard - keep for network access)
        BRCMFMAC = yes;
        BRCMUTIL = yes;
        CFG80211 = yes;
        MAC80211 = yes;

        # Ethernet (Pi 3 onboard)
        NET = yes;
        INET = yes;
        IPV6 = yes;

        # WireGuard (VPN access)
        WIREGUARD = yes;

        # Filesystems
        EXT4_FS = yes;
        FUSE_FS = module;
        VFAT_FS = yes;
        FAT_FS = yes;

        # Network filtering (for firewall)
        NETFILTER = yes;
        NF_TABLES = yes;
        BRIDGE = yes;
        VLAN_8021Q = yes;

        # ZRAM (swap)
        ZRAM = yes;
        ZRAM_DEF_COMP_LZ4 = yes;
      };
    }
  ];
}
