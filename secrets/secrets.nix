let
  rsa_master = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhzz/CAb74rLQkDF2weTCb0DICw1oyXNv6XmdLfEsT5";
in
{
  "nextcloud_password_file.age".publicKeys = [ rsa_master ];
  "nextcloud_s3_key.age".publicKeys = [ rsa_master ];
}