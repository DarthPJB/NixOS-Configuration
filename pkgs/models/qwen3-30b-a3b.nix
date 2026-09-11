# pkgs/models/qwen3-30b-a3b.nix
# Qwen/Qwen3-30B-A3B — 30B-parameter MoE multilingual LLM, 3B active (HuggingFace safetensors).
#
# Uses the shared template from ./default.nix with the `files` source pattern:
# every file (config, tokenizer, and the 16 safetensors shards) is pinned to its
# own SRI hash, and the whole model is pinned to a commit SHA for immutability.
#
# This is the CPU-bound workhorse model that replaces `qwen3.8:27b-q4_K_M` and
# `laguna-s-2.1:q4_K_M` in Ollama. Qwen3-30B-A3B is Apache-2.0 licensed
# (LICENSE file included in the package).
{ lib
, callPackage
}:

# Instantiate the template (outer args resolved by callPackage), then apply the
# per-model configuration (inner args).
callPackage ./default.nix { } {
  pname = "qwen3-30b-a3b";
  version = "2507"; # repo lastModified 2025-07-26
  owner = "Qwen";
  repo = "Qwen3-30B-A3B";
  rev = "ad44e777bcd18fa416d9da3bd8f70d33ebb85d39";

  files = [
    { name = "config.json"; hash = "sha256-KFDds7967K0gthHi1E8wd/yBk/SCfJO+3dTAKtY8Ipc="; }
    { name = "generation_config.json"; hash = "sha256-IyXaDxW7hI4BjFrgcbeUMzLp+HHWtg4u0iypfUy5k9I="; }
    { name = "merges.txt"; hash = "sha256-iDHk8aBERxNA98CoPXvXEwaluGfpX9hw900MUwipBNU="; }
    { name = "tokenizer.json"; hash = "sha256-rrEzB6cazY/oGGHZStVKtonfdzMYgJ7tPL55S0SS2uQ="; }
    { name = "tokenizer_config.json"; hash = "sha256-1dCfB7SMMIbFCLMNHJEUvRGJFFt06YKiZTUMkjrNgQE="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "model.safetensors.index.json"; hash = "sha256-3w1IHsWVxVoLpYQm1Rc5DGIUpWbsT/HI/Eu86fV7PCQ="; }
    { name = "LICENSE"; hash = "sha256-gy3Z4Apo3YOzw/ufVYja19zzN6DbUPfZSD8xDNKS6S4="; }
    { name = "model-00001-of-00016.safetensors"; hash = "sha256-RU53s0amG/sgHVTfYOFRWIOM+TBhfuE1ETVWIE8oArU="; }
    { name = "model-00002-of-00016.safetensors"; hash = "sha256-R/AV1uW7F4KoNNdcBhE8Xox33coct9r4loak7A3toZ4="; }
    { name = "model-00003-of-00016.safetensors"; hash = "sha256-rAv1mQ8tqZXB6Ld6MUne5xkAtP4bimFCMd6pZHGT2Ws="; }
    { name = "model-00004-of-00016.safetensors"; hash = "sha256-ibAf00poPHD9t/IsLnCQU41lBjM1ug20bzZUZCsX0eU="; }
    { name = "model-00005-of-00016.safetensors"; hash = "sha256-mEnrNYTZKONb9ZVsz9kbZCB0Z+H62DBKrmjcTZLW1tk="; }
    { name = "model-00006-of-00016.safetensors"; hash = "sha256-96DxUlVX10AVj7aSmGrUNQbhtZAedAauZYCMZFe8U60="; }
    { name = "model-00007-of-00016.safetensors"; hash = "sha256-kgcCpQ8noAnl9nbaOwKXjb15T2rXhU8wHXCRNhVMGoQ="; }
    { name = "model-00008-of-00016.safetensors"; hash = "sha256-qFvwzIqAR8EWFy1MCM9HkutZ1DdQMnCLo+Gn/8oPcIo="; }
    { name = "model-00009-of-00016.safetensors"; hash = "sha256-Jc2KrthrjhdoXvsVKRL5JEjqP/+xvcJH8lfwTQWQdgQ="; }
    { name = "model-00010-of-00016.safetensors"; hash = "sha256-fDMH7iFHl8S8YcCZT4HWkOdoFQ318U0Y7fhOU7pIENw="; }
    { name = "model-00011-of-00016.safetensors"; hash = "sha256-xljK0oQtNvpMfH9yb4UV3FZwo9gMlOEyV9TjIv/mGYg="; }
    { name = "model-00012-of-00016.safetensors"; hash = "sha256-jLiYvF54SSYABT0RBcn/YdenGfXMKALfY+QVNaZSzCY="; }
    { name = "model-00013-of-00016.safetensors"; hash = "sha256-WZWUQh8xTLjoq0R02w60kMxjEFhQZ+gtc4ISVLkzGc4="; }
    { name = "model-00014-of-00016.safetensors"; hash = "sha256-ZtMpTpl2tfAdEXoKC+12jxKKiJjraTfiJNBR3ilh02M="; }
    { name = "model-00015-of-00016.safetensors"; hash = "sha256-L+AA2k/HOZ/2MDuw2uyMQVpdhQ9epThjOSdYx3/DdmQ="; }
    { name = "model-00016-of-00016.safetensors"; hash = "sha256-DJeeMU+vBulKXhhBq9KF1OJudjx5wavncQ1UMZLZ2kg="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
  ];

  meta = {
    description = "Qwen3-30B-A3B — 30B-parameter MoE multilingual LLM, 3B active (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
