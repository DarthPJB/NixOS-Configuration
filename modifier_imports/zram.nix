{ config, pkgs, ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd"; # Efficient for low-RAM devices
    memoryPercent = 100; # Adjust based on your Pi's RAM (e.g., 50-150)
    priority = 100; # Higher than disk swap if any
  };
}
