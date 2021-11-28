{ config, lib, pkgs, modulesPath, ... }:

{
  networking = {
     wireless = {
     networks = {
         "Astral_Ship" = {
           pskRaw = "ff866b7b9494bd6915c28a06c8604d1e2396e590e64f71b2fdf9c0c9709ec2c4";
         };
       };
     };
   };
}
