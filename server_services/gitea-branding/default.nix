{ lib
, runCommand
, coreutils
, resvg
}:

# Fabrication Forge branding tree for Gitea's runtime asset layer.
#
# Output mirrors Gitea's `custom/` overlay layout so it can be symlinked in
# whole by server_services/gitea.nix:
#   public/assets/css/theme-fabrication-forge.css
#   public/assets/img/{logo,favicon}.{svg,png}
#   templates/custom/{header,footer,extra_links}.tmpl
runCommand "gitea-fabrication-forge-branding"
{
  meta = {
    description = "Fabrication Forge theme, logo and template hooks for Gitea";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
  ''
    ${lib.getExe' coreutils "mkdir"} -p $out/public/assets/css $out/public/assets/img $out/templates/custom

    ${lib.getExe' coreutils "cp"} ${./theme-fabrication-forge.css} $out/public/assets/css/theme-fabrication-forge.css
    ${lib.getExe' coreutils "cp"} ${./logo.svg} $out/public/assets/img/logo.svg
    ${lib.getExe' coreutils "cp"} ${./favicon.svg} $out/public/assets/img/favicon.svg

    ${lib.getExe resvg} --width 512 ${./logo.svg} $out/public/assets/img/logo.png
    ${lib.getExe resvg} --width 64 ${./favicon.svg} $out/public/assets/img/favicon.png

    ${lib.getExe' coreutils "cp"} ${./templates/header.tmpl} $out/templates/custom/header.tmpl
    ${lib.getExe' coreutils "cp"} ${./templates/footer.tmpl} $out/templates/custom/footer.tmpl
    ${lib.getExe' coreutils "cp"} ${./templates/extra_links.tmpl} $out/templates/custom/extra_links.tmpl
  ''
