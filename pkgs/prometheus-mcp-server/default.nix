# Prometheus MCP Server — Official Prometheus project MCP server for LLMs
#
# Provides structured tool access to Prometheus metrics via the Model Context
# Protocol. Tools include query, range_query, series, label discovery, metric
# metadata, target status, TSDB stats, embedded docs search, and more.
#
# Usage:
#   prometheus-mcp-server --prometheus.url=http://10.88.127.3:8080
#   prometheus-mcp-server --prometheus.url=http://10.88.127.3:8080 --mcp.transport=http
#
# See: https://github.com/prometheus/prometheus-mcp
{ lib
, buildGo126Module
, fetchFromGitHub
, fetchzip
, versionCheckHook
}:

let
  docsVersion = "bd8a3f4fe92454ea0709895d6d9c771b8e86e710";
  docs = fetchzip {
    name = "prometheus-docs-${docsVersion}";
    url = "https://github.com/prometheus/docs/archive/${docsVersion}.tar.gz";
    hash = "sha256-S4nlqko+Boc97xF5uwukrLkcfoeF7Sn+orbyNfPmM/k=";
    stripRoot = false;
  };
in
buildGo126Module (finalAttrs: {
  pname = "prometheus-mcp-server";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "prometheus";
    repo = "prometheus-mcp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Zlzh63YnsYbr+yPDY+Pxy3uk/WOTeqx3StogfTjNO6Q=";
  };

  vendorHash = "sha256-QAny2SDYHaUHgiUn0KNesDmwfwh5NWpUB3FtwsB2g/I=";

  subPackages = [ "cmd/prometheus-mcp-server" ];

  # Copy pre-fetched Prometheus docs into the embed directory
  preBuild = ''
    DOCS_DIR="cmd/prometheus-mcp-server/external/docs"
    rm -rf "$DOCS_DIR"
    mkdir -p "$DOCS_DIR"
    cp -r ${docs}/* "$DOCS_DIR/"
    echo "${docsVersion}" > "$DOCS_DIR/COMMIT_HASH"
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/tjhop/prometheus-mcp-server/internal/version.Version=${finalAttrs.version}"
    "-X=github.com/tjhop/prometheus-mcp-server/internal/version.Commit=${finalAttrs.src.rev}"
    "-X=github.com/tjhop/prometheus-mcp-server/internal/version.BuildDate=1970-01-01T00:00:00Z"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    changelog = "https://github.com/prometheus/prometheus-mcp/releases/tag/v${finalAttrs.version}";
    description = "MCP server for LLMs to interact with Prometheus";
    homepage = "https://github.com/prometheus/prometheus-mcp";
    license = lib.licenses.asl20;
    mainProgram = "prometheus-mcp-server";
    maintainers = with lib.maintainers; [ DarthPJB ];
    platforms = lib.platforms.linux;
  };
})
