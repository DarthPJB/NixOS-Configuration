# pkgs/models/qwen25-7b-instruct.nix
# Qwen/Qwen2.5-7B-Instruct — 7B-parameter dense multilingual LLM (HuggingFace safetensors).
#
# Native BF16/FP16 weights — no quantization. Used for CPU vLLM dtype comparison
# testing on LINDA (float16 vs float32 execution paths).
#
# Qwen2.5-7B-Instruct is Apache-2.0 licensed.
{ lib
, callPackage
}:

callPackage ./default.nix { } {
  pname = "qwen25-7b-instruct";
  version = "2501"; # repo lastModified 2025-01-12
  owner = "Qwen";
  repo = "Qwen2.5-7B-Instruct";
  rev = "a09a35458c702b33eeacc393d103063234e8bc28";

  files = [
    { name = "config.json"; hash = "sha256-dGO7DqeDFTZebGt03k5zu8yDWd+wxac3WE4HfULAsDw="; }
    { name = "generation_config.json"; hash = "sha256-Oo+Qh+SGBUyKSgja4uWjumLiPaIStbjAi8QsuYPDRZ8="; }
    { name = "tokenizer.json"; hash = "sha256-wDghF+oynN8JcEETL21zWSS2l5JNb2/DlFcT6WzodTk="; }
    { name = "tokenizer_config.json"; hash = "sha256-W11PZdCs07LVajW1bTdKNsvByPpc87P+u7+r8i81lYM="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "merges.txt"; hash = "sha256-WZurVAdQiHdLFzP96GXVvXR8vMelR8W8EmEOh04m9eM="; }
    { name = "LICENSE"; hash = "sha256-gy3Z4Apo3YOzw/ufVYja19zzN6DbUPfZSD8xDNKS6S4="; }
    { name = "model.safetensors.index.json"; hash = "sha256-Ykv3xHzRJGj9wW44pHz08Z4EFbhZoiO6PAJ+7S8OECg="; }
    { name = "model-00001-of-00004.safetensors"; hash = "sha256-oTM+YpOFR0fEgSiOqDs0giavF43VZcSbb5SVuhlmq6c="; }
    { name = "model-00002-of-00004.safetensors"; hash = "sha256-9dJaJ3LLglFkoqLA+21RqH4oKr8h5N11vFz7PNDqYYU="; }
    { name = "model-00003-of-00004.safetensors"; hash = "sha256-jv3sTBvBIxeuGjjcQrWVznd3OKZN7qP8uKCpE4G839U="; }
    { name = "model-00004-of-00004.safetensors"; hash = "sha256-GnLUA83wwew8t/KJ8Xs5SgHmQ5TC6bPA+U284/r4eb0="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
  ];

  meta = {
    description = "Qwen2.5-7B-Instruct — 7B-parameter dense multilingual LLM (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
