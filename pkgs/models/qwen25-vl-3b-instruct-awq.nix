# pkgs/models/qwen25-vl-3b-instruct-awq.nix
# Qwen/Qwen2.5-VL-3B-Instruct-AWQ — 3B vision-language model, 4-bit AWQ.
#
# Fits comfortably in 10GB VRAM (~3.5GB weights + ~1.5GB vision encoder + KV cache).
# Replaces qwen25-vl-7b-instruct-awq which was too large for the RTX 3060.
{ lib
, callPackage
}:

callPackage ./default.nix { } {
  pname = "qwen25-vl-3b-instruct-awq";
  version = "2504"; # repo lastModified 2025-04-06
  owner = "Qwen";
  repo = "Qwen2.5-VL-3B-Instruct-AWQ";
  rev = "e7b623934290c5a4da0ee3c6e1e57bfb6b5abbf2";

  files = [
    { name = "config.json"; hash = "sha256-I6wQ6yKdbclEiiAPlleXxWjStsminuSC2wz2AsA5h1o="; }
    { name = "generation_config.json"; hash = "sha256-xoXLbKdIWSLQwXeMMNqBAuD77tqdH75Y/BnDJ6x56ow="; }
    { name = "preprocessor_config.json"; hash = "sha256-VJwVgBFAfft1DZ7FeAR8929b/jZc0KoGmlATfT+Y2d0="; }
    { name = "tokenizer.json"; hash = "sha256-Xu6FjFEjpCecPh97gSRzQ/NWrHZ5QLJpKpKK2SlUMhQ="; }
    { name = "tokenizer_config.json"; hash = "sha256-CmvkJdXWLsGQTetF5WnICdCXO9OaQRRSOI8mioVeMYM="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "merges.txt"; hash = "sha256-iDHk8aBERxNA98CoPXvXEwaluGfpX9hw900MUwipBNU="; }
    { name = "added_tokens.json"; hash = "sha256-WLVLvjb8dS95okonHvZqCggwBUtN+tlL3nV9hRloBgs="; }
    { name = "chat_template.json"; hash = "sha256-lBdNcXbFKnGS+W/DTrLPI8fCBZ1jzb+tyhWGuolzH7c="; }
    { name = "special_tokens_map.json"; hash = "sha256-doYudlJmuFqpRZdn4zy68Tlw8yeg6I0cZYRsLd06Hs0="; }
    { name = "LICENSE"; hash = "sha256-tcDlz3TPUa8ey8SvWXz80T/ZklYRg4iEpoEHCDihSlA="; }
    { name = "model.safetensors"; hash = "sha256-cgFNaP5H1JdOIfyrDKvvLpDecR+fsaF5xfoUAOcWctc="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors"
    "tokenizer.json"
    "preprocessor_config.json"
  ];

  meta = {
    description = "Qwen2.5-VL-3B-Instruct AWQ — 3B vision-language model (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
