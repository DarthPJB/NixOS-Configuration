# pkgs/models/default.nix
# HuggingFace model package template — base builder for all Nix-managed models.
#
# Fetches model weights (safetensors) and config files from a HuggingFace
# repository, verifies every file's hash at fetch time, and installs the
# complete model directory into the Nix store. The store path is immutable,
# reproducible, and can be served by the in-house binary cache.
#
# Two source patterns are supported (either or both):
#   1. `files` — per-file fetchurl (recommended). Each entry pins one file
#      with its own SRI hash; multi-GB safetensors shards are verified
#      individually. `name` is the path relative to the repo root (may
#      include subdirectories), `hash` is the SRI sha256.
#   2. `src` — a full-repo archive fetched with fetchzip:
#        src = fetchzip {
#          url = "https://huggingface.co/Qwen/Qwen3-8B/archive/main.tar.gz";
#          hash = "sha256-...";
#          stripRoot = true;
#        };
#      Use this when the repo has many small files or a structure that is
#      tedious to enumerate.
#
# `rev` is the HuggingFace revision: a branch name ("main") or, for
# reproducibility, a commit SHA. With a moving branch the per-file hashes
# still pin the exact content — an upstream change fails the build instead
# of silently swapping weights.
#
# Usage:
#   let
#     models-template = pkgs.callPackage ./pkgs/models { };
#     qwen3-8b = models-template {
#       pname = "qwen3-8b";
#       version = "2507";
#       owner = "Qwen";
#       repo = "Qwen3-8B";
#       rev = "main"; # pin a commit SHA for immutable builds
#       files = [
#         { name = "config.json"; hash = "sha256-..."; }
#         { name = "generation_config.json"; hash = "sha256-..."; }
#         { name = "model.safetensors"; hash = "sha256-..."; }
#         { name = "tokenizer.json"; hash = "sha256-..."; }
#       ];
#       meta = {
#         description = "Qwen3-8B language model";
#         license = lib.licenses.asl20; # must be a nixpkgs license object
#       };
#     };
#   in
#   qwen3-8b
#
# Obtain hashes without downloading into the store:
#   nix store prefetch-file --json https://huggingface.co/Qwen/Qwen3-8B/resolve/main/model.safetensors
# (Use the `.hash` field from the output.)

{ lib
, stdenv
, fetchurl
, coreutils
}:

# Curried: outer args are build-time deps (callPackage), inner args are
# per-model configuration.
{ pname
, version
, owner
, repo
, rev ? "main"
, files ? [ ]
, src ? null
, requiredFiles ? [ "config.json" ]
, meta ? { }
}:

let
  hfBaseUrl = "https://huggingface.co/${owner}/${repo}";
  modelId = "${owner}/${repo}";

  # One fixed-output fetchurl per file: URL + SRI hash pin the content.
  fetchedFiles = map
    (f: {
      inherit (f) name;
      storePath = fetchurl {
        url = "${hfBaseUrl}/resolve/${rev}/${f.name}";
        hash = f.hash;
      };
    })
    files;

  defaultMeta = {
    description = "${pname} model weights (HuggingFace)";
    homepage = "https://huggingface.co/${modelId}";
    license = lib.licenses.unfreeRedistributable; # override per model!
    platforms = lib.platforms.all;
  };
in
lib.throwIfNot
  (files != [ ] || src != null)
  "pkgs/models: no source for ${pname} — provide 'files' (fetchurl list) and/or 'src' (fetchzip archive)"
  (stdenv.mkDerivation ({
    inherit pname version;

    # Model identity for consumers (vLLM module, services, golden tests)
    passthru = {
      inherit modelId rev;
    };

    # No unpacking: fetchurl files and fetchzip archives are already materialized.
    dontUnpack = true;
    # Model weights are data, not executables — skip patching and the
    # reference scanner over multi-GB binaries.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      ${lib.getExe' coreutils "mkdir"} -p "$out"

      # Full-repo archive (fetchzip): copy the unpacked tree
      ${lib.optionalString (src != null) ''
        ${lib.getExe' coreutils "cp"} -r "$src"/. "$out"/
      ''}

      # Individually fetched files — install -D creates subdirectories
      ${lib.concatMapStringsSep "\n" (f: ''
        ${lib.getExe' coreutils "install"} -D -m 0644 ${f.storePath} "$out/${f.name}"
      '') fetchedFiles}

      # Sanity check: every HF model ships at least config.json
      ${lib.concatMapStringsSep "\n" (name: ''
        ${lib.getExe' coreutils "test"} -f "$out/${name}" || {
          ${lib.getExe' coreutils "echo"} "ERROR: ${pname}: required model file missing from $out: ${name}" >&2
          exit 1
        }
      '') requiredFiles}

      runHook postInstall
    '';

    meta = defaultMeta // meta;
  } // lib.optionalAttrs (src != null) { inherit src; }))
