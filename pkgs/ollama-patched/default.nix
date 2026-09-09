# pkgs/ollama-patched/default.nix
# Ollama with PR #9546 "server: add num_parallel to allow per-model control".
#
# Upstream (0.32.14) exposes parallelism only via the global
# OLLAMA_NUM_PARALLEL env var. These two patches add the `num_parallel`
# Modelfile parameter so parallelism is tuned per model — small models get
# extra slots, large models stay single-slot to protect the KV cache.
#
#   num_parallel_types.patch — adds NumParallel to api.Options/Runner and
#     DefaultOptions (defaults to envconfig.NumParallel()).
#   num_parallel_sched.patch — scheduler reads req.opts.NumParallel instead
#     of the global env var when loading a runner.
#
# No rebuild of nixpkgs; just the two Go source patches applied on top of
# the CPU ollama derivation.
{ ollama }:

ollama.overrideAttrs (old: {
  pname = "ollama-num-parallel";
  patches = (old.patches or [ ]) ++ [
    ./patches/num_parallel_types.patch
    ./patches/num_parallel_sched.patch
  ];
})
