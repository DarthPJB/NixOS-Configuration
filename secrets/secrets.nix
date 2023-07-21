# A E S T H I C S
let
  inherit (builtins) attrValues;

  keys =
    {
      rsa_master = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5";
      decrypt_machine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPPSFI0IBhhtyMRcMtvHmMBbwklzXiOXw0OPVD3SEC+M";
    };
  allKeys = attrValues keys;
in
{
  "futureNAS_s3_key.age".publicKeys = allKeys;
  "nextcloud_password_file.age".publicKeys = allKeys;
  "nextcloud_s3_key.age".publicKeys = allKeys;
}
