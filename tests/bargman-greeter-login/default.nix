{
  testers,
  nixosModule,
  lib,
  testName ? "bargman-greeter-login",
  resourceDir,
  compareGoldens ? true,
  goldenThreshold ? 6.3,
}:
testers.runNixOSTest {
  imports = [ ../helpers.nix ];

  name = testName;

  extraPythonPackages = p: [ p.pillow ];

  nodes.machine = {
    imports = [ nixosModule ];

    virtualisation = {
      memorySize = 2048;
      useBootLoader = false;  # simpler boot for testing
    };

    # Don't auto-login — we want to see the greeter
    services.displayManager.autoLogin.enable = lib.mkForce false;
  };

  testScript =
    { nodes, ... }:
    let
      resources = resourceDir;
    in
    # python
    ''
      import os
      import time
      from PIL import Image, ImageChops, ImageStat

      compare_goldens = ${if compareGoldens then "True" else "False"}

      def pixel_diff(a, b):
          stat = ImageStat.Stat(ImageChops.difference(a.convert("RGB"), b.convert("RGB")))
          return sum(stat.mean) / len(stat.mean)

      def assert_matches_golden(name, threshold=${toString goldenThreshold}):
          if not compare_goldens:
              return
          actual_path = f"{os.environ['out']}/{name}.png"
          if not os.path.exists(actual_path):
              print(f"WARNING: {name}: no screenshot captured at {actual_path}")
              return
          actual = Image.open(actual_path)
          reference_path = f"${resources}/{name}.png"
          if not os.path.exists(reference_path):
              print(f"WARNING: {name}: missing golden at {reference_path}, skipping comparison")
              return
          reference = Image.open(reference_path)
          diff = pixel_diff(actual, reference)
          assert diff < threshold, f"{name}: mean pixel diff {diff:.1f} > {threshold}"

      machine.start()

      with subtest("capture lightdm-webkit2-greeter"):
          machine.wait_for_unit("display-manager.service")
          # Give the webkit greeter time to render
          time.sleep(10)
          machine.screenshot("login")
          assert_matches_golden("login")
    '';
}
