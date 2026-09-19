#!/usr/bin/env bash
# Benchmark Ollama models through LiteLLM gateway on alpha-three.
# Measures cold start and warm response times per model.
#
# Usage:
#   nix run .#llm-bench                    # all models
#   nix run .#llm-bench -- linda-qwen38    # single model
#
# Output: /tmp/llm-bench-<timestamp>.log
set -euo pipefail

LITELLM_HOST="10.88.127.107"
LITELLM_PORT="8080"
SSH_PORT="1108"
SSH_USER="John88"
SSH_KEY="$HOME/.ssh/id_ed25519_master"
OLLAMA_HOST="10.88.127.88"
OLLAMA_PORT="11434"
PROMPT="Say hello in exactly 5 words."
MAX_TOKENS=20

# All Ollama models: liteLLM backend → Ollama created tag
declare -A MODELS=(
[linda-ornith9]="linda-ornith9-q4-256k"
[linda-ornith35]="linda-ornith35-q4-256k"
[linda-laguna-xs]="linda-laguna-xs-q4-256k"
[linda-laguna-xs-bf16]="linda-laguna-xs-bf16-256k"
[linda-laguna-s]="linda-laguna-s-q4-256k"
[linda-qwen38]="linda-qwen38-27b-q4-256k"
)

FILTER="${1:-}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG="/tmp/llm-bench-${TIMESTAMP}.log"

ssh_cmd() {
ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
-i "$SSH_KEY" -p "$SSH_PORT" "${SSH_USER}@${LITELLM_HOST}" "$@"
}

# Unload a model from Ollama (via LINDA directly)
unload_model() {
local tag="$1"
ssh_cmd "curl -sf http://${OLLAMA_HOST}:${OLLAMA_PORT}/api/chat \
    -d '{\"model\":\"${tag}\",\"messages\":[],\"keep_alive\":0}' >/dev/null 2>&1" || true
sleep 1
}

# Cold start test: unload, then time first request through LiteLLM
cold_test() {
local backend="$1" tag="$2"
unload_model "$tag"
sleep 2
ssh_cmd "time curl -s -w '\nCOLD_TOTAL:%{time_total}\nCOLD_TTFB:%{time_starttransfer}\nHTTP:%{http_code}\n' \
    -X POST http://127.0.0.1:${LITELLM_PORT}/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer none' \
    -d '{\"model\":\"${backend}/${tag}\",\"messages\":[{\"role\":\"user\",\"content\":\"${PROMPT}\"}],\"max_tokens\":${MAX_TOKENS}}' \
    2>&1"
}

# Warm test: immediate second request through LiteLLM
warm_test() {
local backend="$1" tag="$2"
ssh_cmd "time curl -s -w '\nWARM_TOTAL:%{time_total}\nWARM_TTFB:%{time_starttransfer}\nHTTP:%{http_code}\n' \
    -X POST http://127.0.0.1:${LITELLM_PORT}/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer none' \
    -d '{\"model\":\"${backend}/${tag}\",\"messages\":[{\"role\":\"user\",\"content\":\"${PROMPT}\"}],\"max_tokens\":${MAX_TOKENS}}' \
    2>&1"
}

echo "=== LLM Benchmark Suite ===" | tee "$LOG"
echo "Timestamp: $(date)" | tee -a "$LOG"
echo "Target: LiteLLM gateway at ${LITELLM_HOST}:${LITELLM_PORT}" | tee -a "$LOG"
echo "" | tee -a "$LOG"

for backend in $(echo "${!MODELS[@]}" | tr ' ' '\n' | sort); do
if [[ -n "$FILTER" && "$backend" != "$FILTER" ]]; then
continue
fi

tag="${MODELS[$backend]}"
echo "--- ${backend} (${tag}) ---" | tee -a "$LOG"

echo "  [cold] unloading and testing..." | tee -a "$LOG"
cold_output=$(cold_test "$backend" "$tag" 2>&1) || true
echo "$cold_output" >> "$LOG"

cold_total=$(echo "$cold_output" | grep -oP 'COLD_TOTAL:\K[0-9.]+' || echo "FAIL")
cold_ttfb=$(echo "$cold_output" | grep -oP 'COLD_TTFB:\K[0-9.]+' || echo "FAIL")
cold_http=$(echo "$cold_output" | grep -oP 'HTTP:\K[0-9]+' || echo "FAIL")
echo "  cold: total=${cold_total}s ttfb=${cold_ttfb}s http=${cold_http}" | tee -a "$LOG"

echo "  [warm] testing..." | tee -a "$LOG"
warm_output=$(warm_test "$backend" "$tag" 2>&1) || true
echo "$warm_output" >> "$LOG"

warm_total=$(echo "$warm_output" | grep -oP 'WARM_TOTAL:\K[0-9.]+' || echo "FAIL")
warm_ttfb=$(echo "$warm_output" | grep -oP 'WARM_TTFB:\K[0-9.]+' || echo "FAIL")
warm_http=$(echo "$warm_output" | grep -oP 'HTTP:\K[0-9]+' || echo "FAIL")
echo "  warm: total=${warm_total}s ttfb=${warm_ttfb}s http=${warm_http}" | tee -a "$LOG"

echo "" | tee -a "$LOG"
done

echo "=== Summary ===" | tee -a "$LOG"
echo "Full log: ${LOG}" | tee -a "$LOG"
