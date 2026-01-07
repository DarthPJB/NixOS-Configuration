# TODO Scan Master Index
**Scan Date**: 2026-01-07T01:00:00+00:00  
**Git Revision**: 65dbf71ddd7708cab89205b2ce2e213b525cff55  
**Total Tasks Found**: 14

## Purpose
This index catalogs all TODO items found in .nix files during the systematic codebase scan. Each task has its own folder containing detailed analysis in `task.json` format.

## Task Folder Structure
- Location: `./llm/shared/tasks/task_[sanitized_filename]_[line]/`
- Contents: `task.json` with complete task details and context

## Processing Instructions for Agents
1. **Load Task List**: Read this index to identify relevant tasks
2. **Access Details**: Navigate to task folders for full context
3. **Priority Processing**: Start with High priority tasks in core areas
4. **Effort Estimation**: Use estimated_effort to plan implementation time
5. **Context Review**: Examine before_lines/after_lines for code understanding
6. **Resolution Tracking**: Update git_revision to track progress over time

## Field Explanations
- **filename/line_number**: Exact location of TODO
- **todo_text**: Raw TODO content  
- **context**: Surrounding code for understanding
- **priority_assessment**: Urgency based on codebase impact
- **estimated_effort**: Rough time estimate for completion
- **scan_metadata**: Tracking information for progress monitoring

## Task List

### High Priority Tasks
- [task_machines_cortex_alpha_default_nix_22](tasks/task_machines_cortex_alpha_default_nix_22/task.json) - IPv6 forwarding configuration
- [task_machines_cortex_alpha_default_nix_68](tasks/task_machines_cortex_alpha_default_nix_68/task.json) - Hard-coded IP address security
- [task_machines_cortex_alpha_default_nix_138](tasks/task_machines_cortex_alpha_default_nix_138/task.json) - Port proxy module development
- [task_flake_nix_268](tasks/task_flake_nix_268/task.json) - New machine integration
- [task_README_md_9](tasks/task_README_md_9/task.json) - Implement GPG-based SSH authentication

### Medium Priority Tasks
- [task_flake_nix_94](tasks/task_flake_nix_94/task.json) - Nixinate documentation
- [task_server_services_klipper_nix_4](tasks/task_server_services_klipper_nix_4/task.json) - Prometheus monitoring
- [task_server_services_klipper_nix_255](tasks/task_server_services_klipper_nix_255/task.json) - LDAP authentication
- [task_services_prometheus_nix_12](tasks/task_services_prometheus_nix_12/task.json) - Scraper automation
- [task_machines_LINDA_hardware_configuration_nix_51](tasks/task_machines_LINDA_hardware_configuration_nix_51/task.json) - Storage optimization
- [task_server_services_syncthing_server_nix_124](tasks/task_server_services_syncthing_server_nix_124/task.json) - TLS certificate setup
- [task_README_md_12](tasks/task_README_md_12/task.json) - Continue library-splitting efforts

### Low Priority Tasks
- [task_machines_remote_builder_default_nix_14](tasks/task_machines_remote_builder_default_nix_14/task.json) - Connectivity method decision
- [task_lib_make_storeless_image_nix_183](tasks/task_lib_make_storeless_image_nix_183/task.json) - Filesystem support expansion