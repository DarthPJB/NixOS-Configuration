{ config, lib, ... }:
{
hardware.deviceTree.filter = "bcm2837-rpi-3*";
/*raspi.dtoverlays =
      [
        "hdmi_force_hotplug=1"
        "dtparam=i2c_arm=on"
        "dtparam=spi=on"
        "enable_uart=1"
        "dtoverlay=piscreen,speed=18000000,drm,rotate=180"
        "hdmi_group=2"
        "hdmi_mode=1"
        "hdmi_mode=87"
        "hdmi_cvt 480 320 60 6 0 0 0"
        "hdmi_drive=2"
      ];*/
  hardware.deviceTree = {
    overlays = [
      # Equivalent to: https://github.com/raspberrypi/linux/tree/rpi-6.6.y/arch/arm/boot/dts/overlays/piscreen-overlay.dts
      {
        name = "piscreen-overlay";
        dtsText = ''
          /*
          * Device Tree overlay for PiScreen 3.5" display shield by Ozzmaker
          *
          */

          /dts-v1/;
          /plugin/;

          #include <dt-bindings/gpio/gpio.h>

          / {
              compatible = "brcm,bcm2837";

              fragment@0 {
                  target = <&spi0>;
                  __overlay__ {
                      status = "okay";
                  };
              };

              fragment@1 {
                  target = <&spidev0>;
                  __overlay__ {
                      status = "disabled";
                  };
              };

              fragment@2 {
                  target = <&spidev1>;
                  __overlay__ {
                      status = "disabled";
                  };
              };

              fragment@3 {
                  target = <&gpio>;
                  __overlay__ {
                      piscreen_pins: piscreen_pins {
                          brcm,pins = <17 25 24 22>;
                          brcm,function = <0 1 1 1>; /* in out out out */
                      };
                  };
              };

              fragment@4 {
                  target = <&spi0>;
                  __overlay__ {
                      /* needed to avoid dtc warning */
                      #address-cells = <1>;
                      #size-cells = <0>;

                      piscreen: piscreen@0{
                          compatible = "ilitek,ili9486";
                          reg = <0>;
                          pinctrl-names = "default";
                          pinctrl-0 = <&piscreen_pins>;

                          spi-max-frequency = <24000000>;
                          rotate = <270>;
                          bgr;
                          fps = <30>;
                          buswidth = <8>;
                          regwidth = <16>;
                          reset-gpios = <&gpio 25 GPIO_ACTIVE_LOW>;
                          dc-gpios = <&gpio 24 GPIO_ACTIVE_HIGH>;
                          led-gpios = <&gpio 22 GPIO_ACTIVE_HIGH>;
                          debug = <0>;

                          init = <0x10000b0 0x00
                                  0x1000011
                              0x20000ff
                              0x100003a 0x55
                              0x1000036 0x28
                              0x10000c2 0x44
                              0x10000c5 0x00 0x00 0x00 0x00
                              0x10000e0 0x0f 0x1f 0x1c 0x0c 0x0f 0x08 0x48 0x98 0x37 0x0a 0x13 0x04 0x11 0x0d 0x00
                              0x10000e1 0x0f 0x32 0x2e 0x0b 0x0d 0x05 0x47 0x75 0x37 0x06 0x10 0x03 0x24 0x20 0x00
                              0x10000e2 0x0f 0x32 0x2e 0x0b 0x0d 0x05 0x47 0x75 0x37 0x06 0x10 0x03 0x24 0x20 0x00
                              0x1000011
                              0x1000029>;
                      };

                      piscreen_ts: piscreen-ts@1 {
                          compatible = "ti,ads7846";
                          reg = <1>;

                          spi-max-frequency = <2000000>;
                          interrupts = <17 2>; /* high-to-low edge triggered */
                          interrupt-parent = <&gpio>;
                          pendown-gpio = <&gpio 17 GPIO_ACTIVE_LOW>;
                          ti,swap-xy;
                          ti,x-plate-ohms = /bits/ 16 <100>;
                          ti,pressure-max = /bits/ 16 <255>;
                      };
                  };
              };
              __overrides__ {
                  speed =		<&piscreen>,"spi-max-frequency:0";
                  rotate =	<&piscreen>,"rotate:0",
                          <&piscreen>,"rotation:0";
                  fps =		<&piscreen>,"fps:0";
                  debug =		<&piscreen>,"debug:0";
                  xohms =		<&piscreen_ts>,"ti,x-plate-ohms;0";
                  drm =		<&piscreen>,"compatible=waveshare,rpi-lcd-35",
                          <&piscreen>,"reset-gpios:8=",<GPIO_ACTIVE_HIGH>;
                  invx =		<&piscreen_ts>,"touchscreen-inverted-x?";
                  invy =		<&piscreen_ts>,"touchscreen-inverted-y?";
                  swapxy =	<&piscreen_ts>,"touchscreen-swapped-x-y!";
              };
            };'';
      }
      {
        name = "rpi3-vc4-kms-v3d-overlay";
        dtsText = ''
/*
 * vc4-kms-v3d-overlay.dts
 */

/dts-v1/;
/plugin/;

#include <dt-bindings/clock/bcm2835.h>

/ {
	compatible = "brcm,bcm2835";

    fragment@0 {
		target = <&cma>;
		frag0: __overlay__ {
			/*
			 * The default size when using this overlay is 256 MB
			 * and should be kept as is for backwards
			 * compatibility.
			 */
			size = <0x10000000>;
		};
	};

	fragment@1 {
		target = <&i2c2>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@2 {
		target = <&fb>;
		__overlay__  {
			status = "disabled";
		};
	};

	fragment@3 {
		target = <&pixelvalve0>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@4 {
		target = <&pixelvalve1>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@5 {
		target = <&pixelvalve2>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@6 {
		target = <&hvs>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@7 {
		target = <&hdmi>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@8 {
		target = <&v3d>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@9 {
		target = <&vc4>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@10 {
		target = <&clocks>;
		__overlay__  {
			claim-clocks = <
				BCM2835_PLLD_DSI0
				BCM2835_PLLD_DSI1
				BCM2835_PLLH_AUX
				BCM2835_PLLH_PIX
			>;
		};
	};

	fragment@11 {
		target = <&vec>;
		__dormant__  {
			status = "okay";
		};
	};

	fragment@12 {
		target = <&txp>;
		__overlay__  {
			status = "okay";
		};
	};

	fragment@13 {
		target = <&hdmi>;
		__dormant__  {
			dmas;
		};
	};

	fragment@14 {
		target = <&audio>;
		__overlay__  {
		    brcm,disable-hdmi;
		};
	};

	__overrides__ {
        cma-512 = <&frag0>,"size:0=",<0x20000000>;
		cma-448 = <&frag0>,"size:0=",<0x1c000000>;
		cma-384 = <&frag0>,"size:0=",<0x18000000>;
		cma-320 = <&frag0>,"size:0=",<0x14000000>;
		cma-256 = <&frag0>,"size:0=",<0x10000000>;
		cma-192 = <&frag0>,"size:0=",<0xC000000>;
		cma-128 = <&frag0>,"size:0=",<0x8000000>;
		cma-96  = <&frag0>,"size:0=",<0x6000000>;
		cma-64  = <&frag0>,"size:0=",<0x4000000>;
		cma-size = <&frag0>,"size:0"; /* in bytes, 4MB aligned */
		cma-default = <0>,"-0";
		audio   = <0>,"!13";
		noaudio = <0>,"=13";
		composite = <0>, "=11";
		nohdmi = <0>, "-1-7";
	};
};
        '';
      }
    ];
  };
}