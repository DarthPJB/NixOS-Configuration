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
, buildGoModule
, fetchFromGitHub
, versionCheckHook
}:

buildGoModule (finalAttrs: {
  pname = "prometheus-mcp-server";
  version = "0.18.0";

  src = fetchFromGitHub {
    owner = "prometheus";
    repo = "prometheus-mcp";
    tag = "v${finalAttrs.version}";
    # NOTE: On first build, replace lib.fakeHash with the hash Nix provides
    hash = lib.fakeHash;
  };

  vendorHash = lib.fakeHash;

  subPackages = [ "cmd/prometheus-mcp" ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.commit=${finalAttrs.src.rev}"
    "-X=main.date=1970-01-01T00:00:00Z"
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
