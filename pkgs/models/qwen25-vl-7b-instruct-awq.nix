# pkgs/models/qwen25-vl-7b-instruct-awq.nix
# Qwen/Qwen2.5-VL-7B-Instruct-AWQ — 7B vision-language model, 4-bit AWQ.
#
# GPU model for LINDA's RTX 3060. Weights live in the nix store so vLLM does
# not fetch from HuggingFace at startup.
{ lib
, callPackage
}:

callPackage ./default.nix { } {
  pname = "qwen25-vl-7b-instruct-awq";
  version = "2504"; # repo lastModified 2025-04-06
  owner = "Qwen";
  repo = "Qwen2.5-VL-7B-Instruct-AWQ";
  rev = "536a35794df8831aa814970ee8f89eff577e7718";

  files = [
    { name = "config.json"; hash = "sha256-DM1jeMGFRFEfWaL/7bKmFpdM0Xsk8zzpyqpA/bU+GHw="; }
    { name = "generation_config.json"; hash = "sha256-xoXLbKdIWSLQwXeMMNqBAuD77tqdH75Y/BnDJ6x56ow="; }
    { name = "preprocessor_config.json"; hash = "sha256-VJwVgBFAfft1DZ7FeAR8929b/jZc0KoGmlATfT+Y2d0="; }
    { name = "added_tokens.json"; hash = "sha256-WLVLvjb8dS95okonHvZqCggwBUtN+tlL3nV9hRloBgs="; }
    { name = "chat_template.json"; hash = "sha256-lBdNcXbFKnGS+W/DTrLPI8fCBZ1jzb+tyhWGuolzH7c="; }
    { name = "special_tokens_map.json"; hash = "sha256-doYudlJmuFqpRZdn4zy68Tlw8yeg6I0cZYRsLd06Hs0="; }
    { name = "merges.txt"; hash = "sha256-iDHk8aBERxNA98CoPXvXEwaluGfpX9hw900MUwipBNU="; }
    { name = "tokenizer.json"; hash = "sha256-Xu6FjFEjpCecPh97gSRzQ/NWrHZ5QLJpKpKK2SlUMhQ="; }
    { name = "tokenizer_config.json"; hash = "sha256-CmvkJdXWLsGQTetF5WnICdCXO9OaQRRSOI8mioVeMYM="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "model.safetensors.index.json"; hash = "sha256-m7t/ZncNfw88L4gPJX+ZHQ5sdW4LKobu3DfHrTfVWB0="; }
    { name = "LICENSE"; hash = "sha256-pksx0CZT5TVK4XQQG+LpfiIfV/U+0ioIS3336DZNAYs="; }
    { name = "model-00001-of-00002.safetensors"; hash = "sha256-T3Xj3nJlRu5DYg0SJ9NZbNO6D90Z8R+u6nHeV40tEFI="; }
    { name = "model-00002-of-00002.safetensors"; hash = "sha256-2uQSi7/SuNSJ6DgEjtwLvm4x8mnZuW+j7/4RzFNLjww="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
    "preprocessor_config.json"
  ];

  meta = {
    description = "Qwen2.5-VL-7B-Instruct AWQ — 7B vision-language model (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
