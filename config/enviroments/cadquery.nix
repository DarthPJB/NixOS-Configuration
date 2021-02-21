{ config, pkgs, ... }:

{
environment.systemPackages = with pkgs; [
cq-editor
];

}
