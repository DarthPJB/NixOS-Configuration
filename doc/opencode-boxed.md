# OpenCode-Boxed Sandbox Documentation

## Overview
OpenCode-Boxed (v1.0.1+) provides a sandboxed environment for running OpenCode operations with enhanced isolation and safety features.

## Features
- **Sandbox Isolation**: Uses bwrap mounts for secure access to repository and agent files
- **Dynamic UID/GID**: Ensures user ownership within the sandbox
- **Debug Tracing**: OPCODE_DEBUG environment variable for operational tracing
- **Git Integration**: Automatic patch application to sandbox/$PROJECT/$TIMESTAMP branches on exit
- **No Auto-Cleanup**: External /tmp handling; no internal removal of temporary files

## Usage Examples
- Direct command: `opencode-boxed "agent list"`
- Debug mode: `OPCODE_DEBUG=1 opencode-boxed "use task Bellana-Drone Fix this issue"`

## Integration Notes
Run commands in repository root. Changes are automatically patched to dedicated sandbox branches.

## External Cleanup
Use cron for orphan cleanup: `find /tmp -name 'agent-orphan-*' -mtime +1h -exec rm -rf {} \;`

## Best Practices
- Use for safe LLM operations
- Test functionality with `opencode-boxed "agent list"`
- Delegate tasks via structured prompts