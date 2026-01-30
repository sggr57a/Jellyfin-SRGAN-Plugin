# Documentation Index

Complete guide to all documentation in this project.

## Documentation Structure

The documentation is organized by purpose to avoid redundancy and confusion:

```
📚 Documentation
├── README.md              ⭐ START HERE - Project overview and quick start
├── GETTING_STARTED.md     📖 Complete installation guide
├── WEBHOOK_SETUP.md       🔗 Webhook configuration reference
├── SYSTEMD_SERVICE.md     ⚙️  Service management guide
├── TROUBLESHOOTING.md     🔧 Problem solving and diagnostics
├── scripts/README.md      📜 Script reference
└── CHANGELOG.md           📋 Change history
```

## Which Document Should I Read?

### I'm New Here → Start with [README.md](README.md)

**Purpose**: Project overview, features, and quick start
**Contains**:
- What this project does
- How it works (architecture diagram)
- System requirements
- Quick start command
- Links to other documentation

**Read this first** to understand the project.

### I Want to Install → [GETTING_STARTED.md](GETTING_STARTED.md)

**Purpose**: Complete step-by-step installation guide
**Contains**:
- Prerequisites checklist
- Quick start (automated installation)
- Manual installation (step-by-step)
- Verification checklist
- Environment variables
- Common installation issues
- Uninstallation

**Follow this** for installation.

### I Need to Configure the Webhook → [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)

**Purpose**: Jellyfin webhook configuration reference
**Contains**:
- Step-by-step webhook setup
- JSON template (copy-paste ready)
- Visual form layout
- Testing methods
- Webhook troubleshooting
- Quick reference card

**Use this** after installation to configure Jellyfin.

### I Want to Manage the Service → [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)

**Purpose**: Systemd service management and reference
**Contains**:
- Service management commands
- Log viewing
- Service configuration
- Auto-start setup
- Advanced configuration
- Service troubleshooting

**Refer to this** for day-to-day service operations.

### Something Isn't Working → [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

**Purpose**: Comprehensive problem-solving guide
**Contains**:
- Quick diagnostics
- Common issues with solutions
- Error message explanations
- Advanced debugging
- Test commands
- Log locations

**Check this** when you encounter problems.

### I Want Script Details → [scripts/README.md](scripts/README.md)

**Purpose**: Reference for all scripts
**Contains**:
- Script descriptions
- Usage examples
- Command reference
- Environment variables

**Use this** to understand what each script does.

### What Changed Recently? → [CHANGELOG.md](CHANGELOG.md)

**Purpose**: History of changes and improvements
**Contains**:
- Feature additions
- Bug fixes
- Breaking changes
- Migration guides

**Read this** to see what's new.

## Common Workflows

### First-Time Setup

1. Read [README.md](README.md) for overview
2. Follow [GETTING_STARTED.md](GETTING_STARTED.md) for installation
3. Configure webhook using [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)
4. Test and verify

### Daily Operations

- Manage service: [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)
- Fix issues: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Check logs: `./scripts/manage_watchdog.sh logs`

### Reference Lookups

- Script usage: [scripts/README.md](scripts/README.md)
- Webhook template: [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md)
- Error messages: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Configuration options: [GETTING_STARTED.md](GETTING_STARTED.md)

## Quick Command Reference

### Installation
```bash
./scripts/install_all.sh              # One-shot installer
python3 scripts/verify_setup.py       # Verify prerequisites
```

### Service Management
```bash
./scripts/manage_watchdog.sh status   # Check status
./scripts/manage_watchdog.sh logs     # View logs
./scripts/manage_watchdog.sh restart  # Restart service
./scripts/manage_watchdog.sh health   # Health check
```

### Testing
```bash
python3 scripts/test_webhook.py       # Test webhook
curl http://localhost:5000/health     # Quick health check
```

### Troubleshooting
```bash
./scripts/manage_watchdog.sh recent   # Recent logs
sudo journalctl -u srgan-watchdog.service -f  # System logs
docker compose logs -f srgan-upscaler # Container logs
```

## Documentation Principles

This documentation follows these principles:

1. **No Redundancy**: Each topic covered in one place only
2. **Clear Purpose**: Each document has a specific purpose
3. **Easy Navigation**: Cross-links between related topics
4. **Progressive Disclosure**: Quick start → Details → Advanced
5. **Task-Oriented**: Organized by what you want to accomplish

## Deprecated Files

- **INSTALLATION.md** - Replaced by [GETTING_STARTED.md](GETTING_STARTED.md)
  - Now contains redirect message only

## File Relationships

```
README.md (Overview)
    ↓
GETTING_STARTED.md (Installation)
    ↓
WEBHOOK_SETUP.md (Configuration)
    ↓
SYSTEMD_SERVICE.md (Management)
    ↓
TROUBLESHOOTING.md (When issues occur)
```

All documents cross-reference each other for easy navigation.

## Documentation Standards

### File Naming

- **Uppercase .md** - Main documentation
- **lowercase .md** - Internal/secondary docs
- **README.md** - Index/overview in each directory

### Cross-References

All documents use relative links for easy navigation:
```markdown
See [GETTING_STARTED.md](GETTING_STARTED.md) for installation.
```

### Code Examples

All examples use:
- Bash code blocks with syntax highlighting
- Copy-paste ready commands
- Comments explaining complex steps
- Expected output when helpful

## Contributing to Documentation

When updating documentation:

1. **Find the right file** using this index
2. **Check for redundancy** - Is it already documented elsewhere?
3. **Add cross-references** to related content
4. **Follow the structure** of the existing document
5. **Test all commands** before documenting them
6. **Update this index** if adding new documentation

## Quick Reference: Where Is...?

| Looking for... | Found in... |
|---------------|-------------|
| Installation steps | [GETTING_STARTED.md](GETTING_STARTED.md) |
| Webhook JSON template | [WEBHOOK_SETUP.md](WEBHOOK_SETUP.md) |
| Service commands | [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md) |
| Error messages | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Script usage | [scripts/README.md](scripts/README.md) |
| Environment variables | [GETTING_STARTED.md](GETTING_STARTED.md) |
| System requirements | [README.md](README.md) |
| How it works | [README.md](README.md) |
| Log locations | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Testing | [GETTING_STARTED.md](GETTING_STARTED.md) |
| Uninstallation | [GETTING_STARTED.md](GETTING_STARTED.md) |
| Performance tips | [README.md](README.md) |
| Configuration options | [GETTING_STARTED.md](GETTING_STARTED.md) |
| Recent changes | [CHANGELOG.md](CHANGELOG.md) |

## Need Help?

1. **Check this index** to find the right document
2. **Search the documentation** (Ctrl+F in GitHub)
3. **Run diagnostics**: `python3 scripts/verify_setup.py`
4. **Check logs**: `./scripts/manage_watchdog.sh logs`
5. **Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)**

## Documentation Hierarchy

```
Level 1: Overview
  └── README.md

Level 2: Getting Started
  └── GETTING_STARTED.md

Level 3: Configuration & Management
  ├── WEBHOOK_SETUP.md
  └── SYSTEMD_SERVICE.md

Level 4: Reference & Troubleshooting
  ├── TROUBLESHOOTING.md
  ├── scripts/README.md
  └── CHANGELOG.md

Level 5: Internal Documentation
  └── (Code comments, docstrings)
```

Read top-down for learning, bottom-up for troubleshooting.
