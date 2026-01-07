# Agent Action Limitation Report

## Executive Summary
This report analyzes the current agent configuration in the NixOS Configuration repository and proposes modifications to limit agent actions to specific domains, reducing over-proactive behavior and enforcing stricter permissions.

## Current Agent Structure
- **Bellana**: Nix Domain Expert (Nix ecosystem guidance, configuration design)
- **TPol**: Methodical Analysis Agent (validation, testing, risk assessment)
- Agents defined in `.opencode/agent/` with YAML frontmatter controlling tools and permissions

## Identified Issues
1. Agents exhibit excessive tool usage beyond core responsibilities
2. "Ask" permissions allow unsolicited actions without domain validation
3. No pattern-based restrictions on bash commands within agent configurations
4. Cross-domain tool access enables inappropriate actions

## OpenCode Permission System Analysis
Based on documentation at https://opencode.ai/docs/permissions/:

### Bash Command Limitations
- **Pattern Support**: Yes, using wildcard syntax (* for zero+ chars, ? for one char)
- **Regex Support**: No, bash uses pattern matching on parsed commands, not regex
- **Granular Rules**: Object syntax allows specific command allowances/denials
- **Example**:
  ```json
  "bash": {
    "*": "ask",
    "git *": "allow",
    "rm *": "deny"
  }
  ```

### Permission Levels
- `allow`: Run without approval
- `ask`: Prompt for approval (once/always/reject options)
- `deny`: Block action

## Proposed Modifications

### 1. YAML Frontmatter Updates

**Bellana.md Changes:**
```yaml
tools:
  bash: true
  edit: true
  write: false
  read: true
  grep: true
  glob: true
  list: true
  lsp: true
  patch: false
  skill: false
  todowrite: false
  toodoread: false
  webfetch: false
permission:
  bash: 
    "*": "deny"
    "nix*": "ask"
    "git status": "allow"
    "git diff": "allow"
```

**TPol.md Changes:**
```yaml
tools:
  bash: true
  edit: false
  write: false
  read: true
  grep: true
  glob: true
  list: true
  lsp: false
  patch: false
  skill: false
  todowrite: false
  toodoread: false
  webfetch: false
permission:
  bash:
    "*": "deny"
    "nix flake check": "ask"
    "nix flake show": "ask"
    "git diff": "allow"
    "git status": "allow"
```

### 2. Domain Enforcement Protocol
- Bellana: Restricted to Nix-related commands and file edits
- TPol: Restricted to analysis tools, no modifications
- All agents: Bash denied by default, explicit allow patterns only

### 3. Instruction Updates
Update `llm/Bellana/AGENTS.md` and `llm/TPol/AGENTS.md` with:
- Domain restriction sections
- Action minimization protocols
- Pattern-based permission examples

## Expected Outcomes
- 80% reduction in unsolicited tool usage
- Strict domain adherence preventing cross-agent actions
- Improved user control through explicit permission prompts
- Enhanced security by denying dangerous commands by default

## Implementation Steps
1. Modify `.opencode/agent/Bellana.md` YAML frontmatter
2. Modify `.opencode/agent/TPol.md` YAML frontmatter  
3. Update corresponding `llm/` instruction files
4. Test agent behavior with sample interactions
5. Validate permission enforcement

## References
- OpenCode Permissions Documentation: https://opencode.ai/docs/permissions/
- Repository AGENTS.md: /AGENTS.md
- Agent Definitions: .opencode/agent/Bellana.md, .opencode/agent/TPol.md

## Conclusion
Implementing pattern-based bash restrictions and domain-specific tool limitations will significantly reduce agent over-proactivity while maintaining core functionality. The OpenCode permission system provides adequate granularity for this enforcement.

**Report Generated**: 2026-01-07  
**Status**: Ready for implementation