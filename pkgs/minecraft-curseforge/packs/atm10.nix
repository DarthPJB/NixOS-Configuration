{ minecraft-curseforge, fetchurl }:

minecraft-curseforge {
  name = "atm10";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8094/893/ServerFiles-7.0.zip";
    hash = "sha256-b3xzqChHx5YcrF2cV5svL096K2RtqA84soyKQG4nn2A=";
  };
}
