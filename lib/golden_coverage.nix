{ self, lib }:

let
  registry = import ../lib/topology/mkRegistry.nix { inherit lib; };
  topology = registry.hosts;
  topologyMachines = builtins.attrNames topology;
  nixosMachines = builtins.attrNames (builtins.removeAttrs self.nixosConfigurations [ "beta-one" "display-0" "display-1" "display-2" "print-controller" "bargman-greeter-vm" "arm-bootstrap" "x86-bootstrap" "cluster-box" ]);

  goldenDir = ../goldens;
  goldenFiles = builtins.readDir goldenDir;
  goldenMachines = builtins.map
    (name: builtins.substring 0 (builtins.stringLength name - 5) name)
    (builtins.attrNames (builtins.filterAttrs
      (name: type: type == "regular" && builtins.match ".*\\.json" name != null)
      goldenFiles));

  missingTopology = builtins.filter (m: ! builtins.hasAttr m topology) nixosMachines;
  missingGolden = builtins.filter (m: builtins.elem m nixosMachines && ! builtins.elem m goldenMachines) topologyMachines;

  isComplete = missingTopology == [ ] && missingGolden == [ ];

  coveredMachines = builtins.filter
    (m: builtins.hasAttr m topology && builtins.elem m goldenMachines)
    nixosMachines;
  coveredCount = builtins.length coveredMachines;
  totalMachines = builtins.length nixosMachines;
  coveragePercent = if totalMachines == 0 then 100 else builtins.floor (coveredCount * 100.0 / totalMachines);

  missing = {
    topology = missingTopology;
    golden = missingGolden;
  };
in
{
  inherit isComplete missing coveragePercent coveredCount totalMachines;
}
