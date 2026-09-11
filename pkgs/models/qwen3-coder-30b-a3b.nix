# pkgs/models/qwen3-coder-30b-a3b.nix
# Qwen/Qwen3-Coder-30B-A3B-Instruct — 30B-parameter MoE code-generation LLM,
# 3B active (HuggingFace safetensors).
#
# Uses the shared template from ./default.nix with the `files` source pattern:
# every file (config, tokenizer, and the 16 safetensors shards) is pinned to its
# own SRI hash, and the whole model is pinned to a commit SHA for immutability.
#
# This is the code-generation model that replaces `qwen3-coder:30b-a3b-q4_K_M`
# in Ollama. Qwen3-Coder-30B-A3B-Instruct is Apache-2.0 licensed (LICENSE file
# included in the package).
#
# NOTE: the official HuggingFace repo name carries the `-Instruct` suffix;
# `Qwen/Qwen3-Coder-30B-A3B` alone does not exist as a public repository.
{ lib
, callPackage
}:

# Instantiate the template (outer args resolved by callPackage), then apply the
# per-model configuration (inner args).
callPackage ./default.nix { } {
  pname = "qwen3-coder-30b-a3b";
  version = "2512"; # repo lastModified 2025-12-03
  owner = "Qwen";
  repo = "Qwen3-Coder-30B-A3B-Instruct";
  rev = "b2cff646eb4bb1d68355c01b18ae02e7cf42d120";

  files = [
    { name = "config.json"; hash = "sha256-4sjY7qOUcXhc2TN52LSCQa19zaKZATFV3QJSbjSg3mI="; }
    { name = "generation_config.json"; hash = "sha256-yZcjqzuihjDSauI973dgO1QKRpJIla9c8jR0DTsntR0="; }
    { name = "merges.txt"; hash = "sha256-WZurVAdQiHdLFzP96GXVvXR8vMelR8W8EmEOh04m9eM="; }
    { name = "tokenizer.json"; hash = "sha256-GVZKSMT3Giobk3zONMc3oeZisXHF9dft9kGhXNiW8H0="; }
    { name = "tokenizer_config.json"; hash = "sha256-YPboyxXJjdBzAKPMRl6mYt4kXSCV5CRWFq8hsjJNs/w="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "model.safetensors.index.json"; hash = "sha256-jd4ZC4YsfIDsdAPGSV3gDGC7ryRu1HnO5FBihJicWEw="; }
    { name = "LICENSE"; hash = "sha256-gy3Z4Apo3YOzw/ufVYja19zzN6DbUPfZSD8xDNKS6S4="; }
    { name = "model-00001-of-00016.safetensors"; hash = "sha256-yPTuFXwr2wBSHQ9CLAjvFvDz9ffiNHhtgpQB1ifS4Wc="; }
    { name = "model-00002-of-00016.safetensors"; hash = "sha256-jPhfDloOqNjNP9H0ERddgRynNVcSEIc/1Cu17sCzVAY="; }
    { name = "model-00003-of-00016.safetensors"; hash = "sha256-T6XMIz6WXIZx0yozUEVpf8QxfI0pOdjKX7nvYtAjMgc="; }
    { name = "model-00004-of-00016.safetensors"; hash = "sha256-wQ/xXwir6g/2Cy/DRdzDQZG8gEnQXTvs5rCBqZy/xMg="; }
    { name = "model-00005-of-00016.safetensors"; hash = "sha256-ZdNwHiNUqM9uWvo/hFIL+B7/zcKbDEgdu+sIn4A0kQA="; }
    { name = "model-00006-of-00016.safetensors"; hash = "sha256-fIMr+eUnt7bzGEtWHeBfMJgb3P3/6caeaQZM2qlwcbU="; }
    { name = "model-00007-of-00016.safetensors"; hash = "sha256-cacQw/9S6F0irj9bELmk3UmCHJUzRg+x1LshWT9xtYU="; }
    { name = "model-00008-of-00016.safetensors"; hash = "sha256-zShhYl4b2KISFRRFByudgmyXVP1GGPi4PChX/AhUt3g="; }
    { name = "model-00009-of-00016.safetensors"; hash = "sha256-gzUiX9YcD+KDqDRjqNnFwZ4hHqgEiSWwMaCI8nTrnE4="; }
    { name = "model-00010-of-00016.safetensors"; hash = "sha256-QhSBxC6NhYkcnYhJLXUw1rbYsVwjpttqm3Q44LYWEzA="; }
    { name = "model-00011-of-00016.safetensors"; hash = "sha256-191EeSjd7Gej7AbVvE/Znd6axb3wtqtQD6yl39+5Y7Q="; }
    { name = "model-00012-of-00016.safetensors"; hash = "sha256-NJoLAkfSRP/vNLwjtAPOdW9RUkIyPwJKX4AowQmnmK8="; }
    { name = "model-00013-of-00016.safetensors"; hash = "sha256-Uuf1cGSbJ7w1uM0nrGQ9IVjAKlx2B4yAqK/ESTd7UI4="; }
    { name = "model-00014-of-00016.safetensors"; hash = "sha256-CzCu0bVbPyX78sXoF4RDjQoIRhyVGOJuEZh+sQ2A69c="; }
    { name = "model-00015-of-00016.safetensors"; hash = "sha256-y4s7E8BRmHTtDL5oMqtX5RR244Icg/D/5OyDqNI/xfQ="; }
    { name = "model-00016-of-00016.safetensors"; hash = "sha256-d4R5+iuLdmuhx7/FanHtmwYAgeD7xetO2v0Zoda0wRY="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
  ];

  meta = {
    description = "Qwen3-Coder-30B-A3B-Instruct — 30B-parameter MoE code-generation LLM, 3B active (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
