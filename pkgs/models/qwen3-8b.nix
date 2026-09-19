# pkgs/models/qwen3-8b.nix
# Qwen/Qwen3-8B — 8B-parameter dense multilingual LLM (HuggingFace safetensors).
#
# Uses the shared template from ./default.nix with the `files` source pattern:
# every file (config, tokenizer, and the 5 safetensors shards) is pinned to its
# own SRI hash, and the whole model is pinned to a commit SHA for immutability.
#
# Qwen3-8B is Apache-2.0 licensed (LICENSE file included in the package).
{ lib
, callPackage
}:

# Instantiate the template (outer args resolved by callPackage), then apply the
# per-model configuration (inner args).
callPackage ./default.nix { } {
  pname = "qwen3-8b";
  version = "2507"; # repo lastModified 2025-07-26
  owner = "Qwen";
  repo = "Qwen3-8B";
  rev = "b968826d9c46dd6066d109eabc6255188de91218";

  files = [
    { name = "config.json"; hash = "sha256-98Tq37v1IkcGZ7eXo8ib4lJIMtLVmXlySNwwT/9EfDA="; }
    { name = "generation_config.json"; hash = "sha256-IyXaDxW7hI4BjFrgcbeUMzLp+HHWtg4u0iypfUy5k9I="; }
    { name = "merges.txt"; hash = "sha256-iDHk8aBERxNA98CoPXvXEwaluGfpX9hw900MUwipBNU="; }
    { name = "tokenizer.json"; hash = "sha256-rrEzB6cazY/oGGHZStVKtonfdzMYgJ7tPL55S0SS2uQ="; }
    { name = "tokenizer_config.json"; hash = "sha256-1dCfB7SMMIbFCLMNHJEUvRGJFFt06YKiZTUMkjrNgQE="; }
    { name = "vocab.json"; hash = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA="; }
    { name = "model.safetensors.index.json"; hash = "sha256-+f28uRwjlxwT7F1fJXPSNJ6PYfLwSTcexpkoF0j9sbw="; }
    { name = "LICENSE"; hash = "sha256-gy3Z4Apo3YOzw/ufVYja19zzN6DbUPfZSD8xDNKS6S4="; }
    { name = "model-00001-of-00005.safetensors"; hash = "sha256-MdaoJa418R+4WxlbTELBRsBR5EZDMSWiFTNqvflcv18="; }
    { name = "model-00002-of-00005.safetensors"; hash = "sha256-WZEjbOpv4h89Q8qw8OhESHNPu+B4mBYgKYny3cnRgoI="; }
    { name = "model-00003-of-00005.safetensors"; hash = "sha256-xRhcR5S+LYqXhNV1PJki2zjfR4zhH57QtBW3ME2JaDY="; }
    { name = "model-00004-of-00005.safetensors"; hash = "sha256-te595x+/F9s9VwTgyPK8fQBcqeHXyirrGYJ7DPyqkXo="; }
    { name = "model-00005-of-00005.safetensors"; hash = "sha256-IMLWNmq4XJB4bM3YKc0rnn0w7zsuu7mYKA5+QBS1Qv8="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
  ];

  meta = {
    description = "Qwen3-8B — 8B-parameter dense multilingual LLM (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
