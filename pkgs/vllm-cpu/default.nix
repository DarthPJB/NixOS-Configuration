# pkgs/vllm-cpu/default.nix
# CPU vLLM without rebuilding the nixpkgs derivation.
#
# 0.24.0's cpu_platform_plugin() selects CpuPlatform only when
# importlib.metadata.version("vllm") contains "cpu" (official wheels are
# named 0.24.0+cpu). nixpkgs builds with VLLM_TARGET_DEVICE=cpu but leaves
# the version at 0.24.0.
#
# This derivation wraps pkgs_llm.vllm and prepends a site-packages overlay:
#   - vllm dist-info METADATA Version rewritten to ${version}+cpu
#   - zentorch on the same prefix so ZenCpuPlatform can import it
#
# Pass python313 (vLLM's interpreter). nixpkgs_llm's python3 is 3.14.
# No source patch. No overlay. No vLLM rebuild.
{ lib
, stdenvNoCC
, makeWrapper
, python3
, vllm
, zentorch
, gnused
, coreutils
, util-linux
}:

# Caller must pass the same Python vLLM was built with (python313, not
# nixpkgs_llm's default python3 which is 3.14).
let
  sitePackages = python3.sitePackages;
in

stdenvNoCC.mkDerivation {
  pname = "vllm-cpu";
  inherit (vllm) version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    site="$out/${sitePackages}"
    ${lib.getExe' coreutils "mkdir"} -p "$out/bin" "$site"

    metaSrc="${vllm}/${sitePackages}/vllm-${vllm.version}.dist-info/METADATA"
    metaDst="$site/vllm-${vllm.version}.dist-info"
    ${lib.getExe' coreutils "mkdir"} -p "$metaDst"
    ${lib.getExe gnused} "s/^Version: ${vllm.version}$/Version: ${vllm.version}+cpu/" \
      "$metaSrc" > "$metaDst/METADATA"

    ${lib.getExe' coreutils "ln"} -s ${zentorch}/${sitePackages}/zentorch "$site/zentorch"
    for d in ${zentorch}/${sitePackages}/zentorch-*.dist-info; do
      ${lib.getExe' coreutils "ln"} -s "$d" "$site/$(${lib.getExe' coreutils "basename"} "$d")"
    done

    makeWrapper ${lib.getExe' vllm "vllm"} "$out/bin/vllm" \
      --prefix PYTHONPATH : "$site" \
      --prefix PATH : ${lib.makeBinPath [ util-linux ]}

    runHook postInstall
  '';

  meta = (vllm.meta or { }) // {
    description = "vLLM CPU engine (version metadata +cpu, zentorch on PYTHONPATH)";
  };
}
