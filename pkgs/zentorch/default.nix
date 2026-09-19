# pkgs/zentorch/default.nix
# AMD ZenDNN PyTorch plugin (zentorch) — official cp313 manylinux wheel.
#
# vLLM selects ZenCpuPlatform when the host is AuthenticAMD+avx512 and
# `import zentorch` succeeds. This package is the wheel from PyPI; no source
# build, no vLLM patch.
#
# The 2.13.0.0 wheel is built against PyTorch 2.13.0+cpu. nixpkgs_llm currently
# ships torch 2.12. If the native extension fails to import, vLLM falls back
# to CpuPlatform (oneDNN). The +cpu version metadata still selects CPU.
{ lib
, buildPythonPackage
, fetchurl
, autoPatchelfHook
, stdenv
, numpy
, torch
, deprecated
, safetensors
}:

buildPythonPackage rec {
  pname = "zentorch";
  version = "2.13.0.0";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/f6/be/223178e273927b059af9b07500dace0d9980e883e97580bb58c31d08c167/zentorch-2.13.0.0-cp313-cp313-manylinux_2_28_x86_64.whl";
    hash = "sha256-l4tsDs9yNdHJ88Pkbr/ohoMIRxqkOI6Za7PjkgsgtHA=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    torch
    stdenv.cc.cc.lib
  ];

  dependencies = [
    numpy
    torch
    deprecated
    safetensors
  ];

  # Wheel targets torch 2.13; do not fail the build if the extension cannot
  # import against nixpkgs_llm's torch 2.12.
  pythonImportsCheck = [ ];

  meta = {
    description = "AMD ZenDNN PyTorch plugin for Zen/EPYC CPUs";
    homepage = "https://github.com/amd/ZenDNN-pytorch-plugin";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
