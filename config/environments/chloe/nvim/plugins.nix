{ pkgs }:

let
  vp = pkgs.vimUtils.buildVimPluginFrom2Nix;
in
{
  vim-git = vp {
    name = "vim-git";
    src = pkgs.fetchFromGitHub {
      owner = "tpope";
      repo = "vim-git";
      rev = "88942277f22d0dcc2177009dc10453ec9dbb2132";
      sha256 = "0zzr5d50hxkbwpxmfaz85hi964pqqxhi86vgxqy9irm8995x13bg";
    };
    dependencies = [ ];
  };

  vim-haml = vp {
    name = "vim-haml";
    src = pkgs.fetchFromGitHub {
      owner = "tpope";
      repo = "vim-haml";
      rev = "6ad8a7f6d885c212497e3b07c305c313df269b07";
      sha256 = "0jg5bp88l34ly8hqs4mf9ijg8p7vahd2x5llys0z9ggxrqfsg25f";
    };
    dependencies = [ ];
  };

  vim-es6 = vp {
    name = "vim-es6";
    src = pkgs.fetchFromGitHub {
      owner = "isRuslan";
      repo = "vim-es6";
      rev = "8e8fb16edc1c39ac86441304ec158bcb538cb428";
      sha256 = "1pzijj7pvjbd3vgkadsc7kkc64v6br8xvys4gpfdskikipzd0nqj";
    };
    dependencies = [ ];
  };

  "Dockerfile.vim" = vp {
    name = "Dockerfile.vim";
    src = pkgs.fetchFromGitHub {
      owner = "ekalinin";
      repo = "Dockerfile.vim";
      rev = "da5d2b890d567e610d5f0f44a199d95b1f3148c5";
      sha256 = "1ldirs3dv93illijbnd6zd1770pn3qvbk5gw07hkg64r640lrmvb";
    };
    dependencies = [ ];
  };

  localvimrc = vp {
    name = "localvimrc";
    src = pkgs.fetchFromGitHub {
      owner = "pinktrink";
      repo = "localvimrc";
      rev = "1e2522707d29238a63e63cc4a3e7cb3d3c526a6f";
      sha256 = "07ndih1hwly6a8qvzgishvh88z23cmhcjpbh67xvq5xc2g58vanb";
    };
    dependencies = [ ];
  };

  vim-python-pep8-indent = vp {
    name = "vim-python-pep8-indent";
    src = pkgs.fetchFromGitHub {
      owner = "hynek";
      repo = "vim-python-pep8-indent";
      rev = "84f35c0a4f3fcb8a816785e02983732c4a1dcc99";
      sha256 = "1n8q8yl511x1n9af8lx0k26d9m3h2fpj3q6a2awn2lgqjbwngkqa";
    };
    dependencies = [ ];
  };

  vim-jsx = vp {
    name = "vim-jsx";
    src = pkgs.fetchFromGitHub {
      owner = "mxw";
      repo = "vim-jsx";
      rev = "ffc0bfd9da15d0fce02d117b843f718160f7ad27";
      sha256 = "0ff4w5n0cvh25mkhiq0ppn0w0lzc6sds1zwvd5ljf0cljlkm3bbg";
    };
    dependencies = [ ];
  };

  rnix-lsp = vp rec {
    name = "rnix-lsp";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "nix-community";
      repo = "rnix-lsp";
      rev = "v${version}";
      sha256 = "1s4nib2mnhagd0ymx254vf7l1iijwrh2xdqn3bdm4f1jnip81r10";
    };
  };

}
