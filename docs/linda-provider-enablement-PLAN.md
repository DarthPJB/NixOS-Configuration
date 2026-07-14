# Alpha-Three Provider Enablement Plan

**Date:** 2026-07-14
**Branch:** overlord-II
**Status:** Executing
**Target:** alpha-three ONLY (no deployment without authorization)

---

## Overview

Enable LLM-CORE provider options on alpha-three to match the updated module capabilities. The opencode-fleet module now supports three providers: `openrouter`, `opencode-go`, and `xiaomi-token-plan-sgp`. Encrypted API keys are already present in the secrix secrets directory.

## Context

### LLM-CORE Module Provider Options

The `opencode-fleet.nix` module (line 182-267) defines three providers:

| Provider | Option Path | Description |
|----------|-------------|-------------|
| OpenRouter | `providers.openrouter` | OpenRouter API gateway |
| OpenCode Go | `providers.opencode-go` | OpenCode Go subscription provider |
| Xiaomi Token Plan SGP | `providers.xiaomi-token-plan-sgp` | Xiaomi Token Plan SGP provider |

Each provider has:
- `enable` — boolean to activate
- `apiKeyFile` — absolute path to API key file
- `options` — provider-specific settings (timeout, chunkTimeout, baseURL, etc.)
- `models` — custom model definitions
- `whitelist` / `blacklist` — model filtering

### Available Encrypted Secrets

| Secret File | Purpose |
|-------------|---------|
| `secrets/openrouter-master-token` | OpenRouter API key |
| `secrets/alpha-three-openCODE-token` | OpenCode Go API key |
| `secrets/mimo-token-plan-ai-key` | Xiaomi Token Plan SGP API key |

### Target Configuration

alpha-three's `services.opencode-fleet` currently has MCP servers configured. We need to:
1. Add secrix declarations for the three provider API keys
2. Add `providers` block to `services.opencode-fleet`

---

## Phases

### Phase 1: Secrix Secret Declarations

**Goal:** Add encrypted secret declarations for the three provider API keys.

**Steps:**

1. **Add provider secret declarations to alpha-three config**

   **File:** `machines/alpha-three/default.nix`
   **Location:** After existing secrix declarations (line 69)

   Add the following secrix declarations:

   ```nix
   secrix.system.secrets.openrouter-master-token = {
     encrypted.file = "${self}/secrets/openrouter-master-token";
     decrypted = {
       user = "John88";
       group = "users";
       mode = "0440";
     };
   };
   secrix.system.secrets.alpha-three-openCODE-token = {
     encrypted.file = "${self}/secrets/alpha-three-openCODE-token";
     decrypted = {
       user = "John88";
       group = "users";
       mode = "0440";
     };
   };
   secrix.system.secrets.mimo-token-plan-ai-key = {
     encrypted.file = "${self}/secrets/mimo-token-plan-ai-key";
     decrypted = {
       user = "John88";
       group = "users";
       mode = "0440";
     };
   };
   ```

   **Success Criteria:** Secrix declarations added, paths reference existing encrypted files.

**Verification Gate:** `tpol-minimax` validates secrix declarations are syntactically correct and reference valid secret paths.

---

### Phase 2: Provider Configuration

**Goal:** Add provider configuration block to `services.opencode-fleet`.

**Steps:**

2. **Add providers block to opencode-fleet configuration**

   **File:** `machines/alpha-three/default.nix`
   **Location:** Inside `services.opencode-fleet` block (after line 98)

   Add the following providers configuration:

   ```nix
   providers.openrouter = {
     enable = true;
     apiKeyFile = config.secrix.system.secrets.openrouter-master-token.decrypted.path;
   };
   providers.opencode-go = {
     enable = true;
     apiKeyFile = config.secrix.system.secrets.alpha-three-openCODE-token.decrypted.path;
   };
   providers.xiaomi-token-plan-sgp = {
     enable = true;
     apiKeyFile = config.secrix.system.secrets.mimo-token-plan-ai-key.decrypted.path;
   };
   ```

   **Success Criteria:** Providers block added with proper secret path references.

**Verification Gate:** `tpol-minimax` validates provider configuration structure matches LLM-CORE module options.

---

### Phase 3: Validation

**Goal:** Ensure Nix evaluation succeeds and configuration is correct.

**Steps:**

3. **Validate Nix evaluation**

   ```bash
   nix eval .#nixosConfigurations.alpha-three.config.services.opencode-fleet.providers --option builders '' 2>&1
   ```

   **Success Criteria:** Evaluation returns provider configuration without errors.

4. **Verify opencode.json generation**

   ```bash
   nix eval .#nixosConfigurations.alpha-three.config.environment.etc.\"opencode/opencode.json\".source --option builders '' 2>&1
   ```

   **Success Criteria:** opencode.json includes provider block with all three providers.

**Verification Gate:** `tpol-minimax` validates evaluation output matches expected provider structure.

---

### Phase 4: Commit and Document

**Goal:** Commit changes and update documentation.

**Steps:**

5. **Commit changes**

   ```bash
   git add machines/alpha-three/default.nix
   git commit -m "feat: enable LLM-CORE providers on alpha-three

   - Add secrix declarations for openrouter, opencode-go, xiaomi-token-plan-sgp
   - Configure providers block in services.opencode-fleet
   - All three providers enabled with encrypted API key references

   Validated: nix eval succeeds, providers configuration confirmed"
   ```

   **Success Criteria:** Changes committed to overlord-II branch.

6. **Update LLM-CORE integration status**

   **File:** `documentation/llm-core-integration-status.md`

   Add provider enablement to the "What's Working" section.

   **Success Criteria:** Documentation updated with provider status.

**Verification Gate:** `tpol-minimax` validates commit exists and documentation is accurate.

---

## Summary

| Phase | Description | Steps | Agent |
|-------|-------------|-------|-------|
| 1 | Secrix Secret Declarations | 1 | bellana-deepseek |
| 2 | Provider Configuration | 1 | bellana-deepseek |
| 3 | Validation | 2 | bellana-deepseek |
| 4 | Commit and Document | 2 | bellana-deepseek |

**Total Steps:** 6
**Estimated Time:** 15 minutes
**Dependencies:** LLM-CORE flake input already updated (confirmed by user)

---

## References

- LLM-CORE module: `/speed-storage/bargman-tech/LLM-CORE/nix/modules/opencode-fleet.nix` (lines 182-267)
- Alpha-three machine config: `machines/alpha-three/default.nix`
- Secrix secrets: `secrets/openrouter-master-token`, `secrets/alpha-three-openCODE-token`, `secrets/mimo-token-plan-ai-key`
