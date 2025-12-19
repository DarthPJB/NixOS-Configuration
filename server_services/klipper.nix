{ config, pkgs, self, ... }: {


  #TODO: prometheus-klipper-exporter
  services.prometheus = {
    exporters.klipper = {
      enable = true;
      port = 3104;
      #extraFlags = [ "st
    };
  };
  networking.firewall.interfaces."wireg0".allowedTCPPorts = [ config.services.prometheus.exporters.klipper.port ];


  services.klipper = {
    enable = true;
    user = "klipper";
    group = "klipper";
    mutableConfig = true; # Use declarative config
    configDir = "/var/lib/moonraker/config";

    firmwares =
      {
        "mcu" = {
          enable = false;
          configFile = ./klipper/skr-e3.cfg;
          enableKlipperFlash = false;
          serial = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_18004D000350415339373620-if00";
        };
      };
    settings = {
      "mcu" = {
        serial = "/dev/serial/by-id/usb-Klipper_stm32g0b1xx_18004D000350415339373620-if00";
      };
      "bed_mesh" = {
        speed = 200;
        horizontal_move_z = 10;
        mesh_min = "15, 15";
        mesh_max = "200, 220";
        probe_count = "10, 10";
        algorithm = "bicubic";
      };
      "safe_z_home" = {
        home_xy_position = "151,115"; # Nozzle coordinates"
        speed = "250";
        z_hop = "6";
        z_hop_speed = "50";
      };
      "probe" = {
        pin = "^!PC14";
        z_offset = "1.925";
        x_offset = "-44";
        y_offset = "-4";
        speed = "10";
        lift_speed = "20";
        samples = "3";
        samples_tolerance_retries = "3";
      };
      "stepper_x" = {
        step_pin = "PB13";
        dir_pin = "!PB12";
        enable_pin = "!PB14";
        microsteps = "16";
        rotation_distance = "40";
        endstop_pin = "^PC0";
        position_endstop = "0";
        position_max = "245";
        homing_speed = "50";
      };
      "tmc2209 stepper_x" = {
        uart_pin = "PC11";
        tx_pin = "PC10";
        uart_address = "0";
        run_current = "0.580";
        stealthchop_threshold = "999999";
      };
      "stepper_y" = {
        step_pin = "PB10";
        dir_pin = "!PB2";
        enable_pin = "!PB11";
        microsteps = "16";
        rotation_distance = "40";
        endstop_pin = "^PC1";
        position_endstop = "0";
        position_max = "240";
        homing_speed = "50";
      };
      "tmc2209 stepper_y" = {
        uart_pin = "PC11";
        tx_pin = "PC10";
        uart_address = "2";
        run_current = "0.580";
        stealthchop_threshold = "999999";
      };
      "stepper_z" = {
        step_pin = "PB0";
        dir_pin = "PC5";
        enable_pin = "!PB1";
        microsteps = "16";
        rotation_distance = "8";
        position_min = "-2";
        endstop_pin = "probe:z_virtual_endstop";
        position_max = "200";
      };
      "tmc2209 stepper_z" = {
        uart_pin = "PC11";
        tx_pin = "PC10";
        uart_address = "1";
        run_current = "0.580";
        stealthchop_threshold = "999999";
      };
      "extruder" = {
        step_pin = "PB3";
        dir_pin = "!PB4";
        enable_pin = "!PD1";
        microsteps = "16";
        rotation_distance = "21.9232";
        nozzle_diameter = "1.0";
        filament_diameter = "1.750";
        heater_pin = "PC8";
        sensor_type = "EPCOS 100K B57560G104F";
        sensor_pin = "PA0";
        control = "pid";
        pid_Kp = "21.527";
        pid_Ki = "1.063";
        pid_Kd = "108.982";
        min_temp = "0";
        max_temp = "290";
      };
      "tmc2209 extruder" = {
        uart_pin = "PC11";
        tx_pin = "PC10";
        uart_address = "3";
        run_current = "0.650";
        stealthchop_threshold = "999999";
      };
      "heater_bed" = {
        heater_pin = "PC9";
        sensor_type = "ATC Semitec 104GT-2";
        sensor_pin = "PC4";
        control = "pid";
        pid_Kp = "54.027";
        pid_Ki = "0.770";
        pid_Kd = "948.182";
        min_temp = "0";
        max_temp = "130";
      };
      "heater_fan heatbreak_cooling_fan" = {
        pin = "PC7";
      };
      "heater_fan controller_fan" = {
        pin = "PB15";
      };
      "fan" = {
        pin = "PC6";
      };
      "printer" = {
        kinematics = "cartesian";
        max_velocity = "300";
        max_accel = "3000";
        max_z_velocity = "5";
        max_z_accel = "100";
      };
      "board_pins" = {
        aliases =
          ''    # EXP1 header
          EXP1_1=PB5,  EXP1_3=PA9,   EXP1_5=PA10, EXP1_7=PB8, EXP1_9=<GND>,
          EXP1_2=PA15, EXP1_4=<RST>, EXP1_6=PB9,  EXP1_8=PD6, EXP1_10=<5V>'';

      }; # See the sample-lcd.cfg file for definitions of common LCD displays.
      "display" = {
        lcd_type = "st7920";
        cs_pin = "EXP1_7";
        sclk_pin = "EXP1_6";
        sid_pin = "EXP1_8";
        encoder_pins = "^EXP1_5, ^EXP1_3";
        click_pin = "^!EXP1_2";
      };
      "output_pin beeper" = {
        pin = "EXP1_1";
      };
      "virtual_sdcard" = {
        path = "/var/lib/moonraker/gcodes";
      };
      "display_status" = { };
      "pause_resume" = { };
      "gcode_macro CANCEL_PRINT" = {
        description = "Cancel the actual running print";
        rename_existing = "CANCEL_PRINT_BASE";
        gcode =
          ''TURN_OFF_HEATERS
          CANCEL_PRINT_BASE
          G0 X200 Y200 Z100'';
      };
    };
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/moonraker 0775 klipper moonraker - -"
    "d /var/lib/moonraker/config 0775 klipper moonraker - -"
  ];
  security.polkit.enable = true;
  services.moonraker = {
    enable = true;
    user = "moonraker";
    group = "moonraker";
    address = "10.88.127.30"; # Allow access from network
    port = 7125;
    allowSystemControl = true; # Optional= "Enable system operations"
    settings = {
      server = {
        host = "print-controller.johnbargman.net";
      };
      authorization = {
        cors_domains = [ "*.johnbargman.net" "http://10.88.127.30" ];
        force_logins = false;
        trusted_clients = [
          "127.0.0.0/24"
          "10.88.127.0/24"
        ];
      };
      octoprint_compat = { }; # Optional compatibility
    };
  };

  services.fluidd = {
    enable = true;
    hostName = "print-controller.johnbargman.net"; # Access via http://localhost:80; change for domain
    nginx = { };
  };

  users.users.klipper = {
    isSystemUser = true;
    group = "klipper";
    extraGroups = [ "moonraker" ]; # Moonraker needs access to Klipper files
    home = "/var/lib/klipper";
    #createHome = true;
  };
  users.groups.klipper = { };

  users.users.moonraker = {
    isSystemUser = true;
    group = "moonraker";
    extraGroups = [ "klipper" ]; # Moonraker needs access to Klipper files
    home = "/var/lib/moonraker";
    #createHome = true;
  };
  users.groups.moonraker = { };

  # Open firewall ports if needed
  networking.firewall.allowedTCPPorts = [ 80 7125 ];

  # Ensure nginx is enabled via Fluidd
  secrix.services.nginx.secrets.ldap_master_password.encrypted.file = "${self}/secrets/ldap_master_password";

  #TODO: Nginx with LDAP via PAM
  services.nginx = {
    enable = true;
  };
}
