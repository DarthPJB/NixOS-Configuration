{ minecraft-curseforge, fetchurl }:

minecraft-curseforge {
  name = "all-the-mons";
  src = fetchurl {
    url = "https://mediafilez.forgecdn.net/files/8120/605/ServerFiles-1.0.0-rc.6.zip";
    hash = "sha256-58i7bAvr1KXFciihjA6/kFKIzZGbR5idRLkOw0zxtf0=";
  };
}
