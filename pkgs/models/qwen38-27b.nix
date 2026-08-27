# pkgs/models/qwen38-27b.nix
# Qwen/Qwen3.8-27B — 27B-parameter dense vision-language model (HuggingFace safetensors).
#
# Replaces qwen3-30b-a3b as LINDA's general-purpose CPU model.
# Qwen3.8-27B is Apache-2.0 licensed.
{ lib
, callPackage
}:

callPackage ./default.nix { } {
  pname = "qwen38-27b";
  version = "2508"; # repo lastModified 2026-08-14
  owner = "Qwen";
  repo = "Qwen3.8-27B";
  rev = "1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0";

  files = [
    { name = "config.json"; hash = "sha256-GR4K8jIQTti2UljPP7K4QuKIAIusp2M8EbgqGscgOqs="; }
    { name = "generation_config.json"; hash = "sha256-5wwTbBt43cH7CQW6yOczpNxEjU+FKl3XUUP//HC+VQ4="; }
    { name = "preprocessor_config.json"; hash = "sha256-JyJUUKycZSmHLuGST8sJYv9WNINPgXBA9EQRgRb05RY="; }
    { name = "tokenizer.json"; hash = "sha256-CZf0EMV6H05TsJ5L6PShctkO3ZVkNo+whHAwk3IpufM="; }
    { name = "tokenizer_config.json"; hash = "sha256-sRNJqvp83GoyB2fPfOsp7YL37aXWXo4IGedvDOlHvyc="; }
    { name = "vocab.json"; hash = "sha256-zpm0yymD0RiAbOCot3ejWwk+IAClA+veJYUyhMnfoAM="; }
    { name = "merges.txt"; hash = "sha256-qdNW173x70lJ4+dI6VuOEK2dTi6Djt3Digp7a5TR240="; }
    { name = "model.safetensors.index.json"; hash = "sha256-dwQglAdmEbaXkaYQBl8otwE7jGIXlfqG3czIusfRud8="; }
    { name = "LICENSE"; hash = "sha256-u+3D/aMwWCC5dyZfAbhhnYdXCmc53jpVgsNGSEDx5Xo="; }
    { name = "chat_template.jinja"; hash = "sha256-w8+eNKv0+eNsLXIWWqnBMtPipyW2wlhqqjqK+deoEEE="; }
    { name = "video_preprocessor_config.json"; hash = "sha256-d2ivJ8H6+pzJARwdwgBn4D+JFeA7Y1BFUOEdUGaYbRM="; }
    { name = "model-00001-of-00018.safetensors"; hash = "sha256-ugziCq5ImtGWcz2lBkvN8Vmh/oT1MzZkgZbh67d1Gxw="; }
    { name = "model-00002-of-00018.safetensors"; hash = "sha256-BqFIwBv74/qhSl8YSn/ymnBveuHIsnBdIFjibRegAfs="; }
    { name = "model-00003-of-00018.safetensors"; hash = "sha256-Lhv2LLzUBuqmS2DRA1Ph8O9AOdCXblbwXKvpU0VPmWg="; }
    { name = "model-00004-of-00018.safetensors"; hash = "sha256-UR40BjGHiCZZdTxNk/OFn5PAGf1DjYgTBxkhyB2aPxo="; }
    { name = "model-00005-of-00018.safetensors"; hash = "sha256-Y1y1NEbcdPIZdA/Fnhi3dPh3uAO5ci4onKYldabvpwE="; }
    { name = "model-00006-of-00018.safetensors"; hash = "sha256-C8UhT6xgfw5syS7sN4nUuFWUEO+fzmZiG6gVjoQQ2uA="; }
    { name = "model-00007-of-00018.safetensors"; hash = "sha256-gLDEkDPpoNV2JWKqEvSs239U2lhvPQEQ8oxI2RzweJI="; }
    { name = "model-00008-of-00018.safetensors"; hash = "sha256-cZLFtmGF01kpJ9qr7hzBnm9uDOdZiO4g6CS2JHZf2nk="; }
    { name = "model-00009-of-00018.safetensors"; hash = "sha256-rzxIzDevRPPbauBXm68BkYDUjZxSfKoKHwP/hYE6Vtg="; }
    { name = "model-00010-of-00018.safetensors"; hash = "sha256-FjSQp2876jpAhVt+/ATObSevrxo08LveSVuUkfdkV8k="; }
    { name = "model-00011-of-00018.safetensors"; hash = "sha256-XzrhuUiu7jnad67FWOgjbNZf5NfLdoana7AHrMVjxtg="; }
    { name = "model-00012-of-00018.safetensors"; hash = "sha256-o94ccRRneo9axcSJLJDoI46lweIDjIDnV9/IfDkCylU="; }
    { name = "model-00013-of-00018.safetensors"; hash = "sha256-Bqt5pB90ycXLc0gW/rDH/DZBBLInFl7nORIx4RVaoCo="; }
    { name = "model-00014-of-00018.safetensors"; hash = "sha256-QTjtlGAwZbqIS7yt7bBNdxi7QBF+heb1xvxbnAW3qFs="; }
    { name = "model-00015-of-00018.safetensors"; hash = "sha256-aSJOJ7neTn2/b8k2xuquCER72juApsMahxq0URc6/SI="; }
    { name = "model-00016-of-00018.safetensors"; hash = "sha256-c8uaEIn7YVXLZIYJR41mM76KXH2cpaBbyJJc6KVTzv4="; }
    { name = "model-00017-of-00018.safetensors"; hash = "sha256-vrUfAQVhQqxJhL2ABQew3Q/RjeV/jp726kHRo1mJg6g="; }
    { name = "model-00018-of-00018.safetensors"; hash = "sha256-HTR5UJ4hSUZY+bZNMX9eqOVcQCXSjHAtbE0LNWzo6gY="; }
  ];

  requiredFiles = [
    "config.json"
    "model.safetensors.index.json"
    "tokenizer.json"
    "preprocessor_config.json"
  ];

  meta = {
    description = "Qwen3.8-27B — 27B dense vision-language model (Apache-2.0)";
    license = lib.licenses.asl20;
  };
}
