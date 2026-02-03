# Documentation Index

**All documentation for the Jellyfin SRGAN Pipeline**

---

## 🚀 Quick Start

**New users start here:**
- **[QUICK_START_API.md](QUICK_START_API.md)** - 5-minute setup guide (RECOMMENDED)

---

## 📖 Core Documentation

### Setup & Installation
- **[API_BASED_WATCHDOG.md](API_BASED_WATCHDOG.md)** - Complete setup guide using Jellyfin API (RECOMMENDED)
- **[FIX_DOCKER_CANNOT_FIND_FILE.md](FIX_DOCKER_CANNOT_FIND_FILE.md)** - Fix volume mount issues

### Architecture & How It Works
- **[ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md)** - Simple architecture overview
- **[WEBHOOK_TO_CONTAINER_FLOW.md](WEBHOOK_TO_CONTAINER_FLOW.md)** - Detailed technical flow
- **[COMPARISON_TEMPLATE_VS_API.md](COMPARISON_TEMPLATE_VS_API.md)** - Why API approach is better

### System Administration
- **[SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)** - Managing the watchdog service
- **[scripts/README.md](scripts/README.md)** - Scripts documentation

---

## 🎯 By Use Case

### "I want to set this up"
→ [QUICK_START_API.md](QUICK_START_API.md)

### "Container can't find my media files"
→ [FIX_DOCKER_CANNOT_FIND_FILE.md](FIX_DOCKER_CANNOT_FIND_FILE.md)

### "How does this work?"
→ [ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md)

### "Should I use template or API approach?"
→ [COMPARISON_TEMPLATE_VS_API.md](COMPARISON_TEMPLATE_VS_API.md) (Use API!)

### "Service management commands"
→ [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)

---

## 📝 File Reference

| Document | Purpose | Status |
|----------|---------|--------|
| **QUICK_START_API.md** | 5-minute setup | ✅ Current |
| **API_BASED_WATCHDOG.md** | Complete API setup guide | ✅ Current |
| **COMPARISON_TEMPLATE_VS_API.md** | Template vs API comparison | ✅ Current |
| **ARCHITECTURE_SIMPLE.md** | System architecture | ✅ Current |
| **WEBHOOK_TO_CONTAINER_FLOW.md** | Technical flow details | ✅ Current |
| **FIX_DOCKER_CANNOT_FIND_FILE.md** | Volume mount troubleshooting | ✅ Current |
| **SYSTEMD_SERVICE.md** | Service management | ✅ Current |
| **scripts/README.md** | Scripts documentation | ✅ Current |

---

## 🗑️ Removed Documentation

The following files have been removed as they contain outdated information:

- All `FIX_*` guides for template-based approach (deprecated)
- All `INSTALLATION_*` troubleshooting guides (issues resolved)
- All `COMPLETE_*` step-by-step fixes (no longer needed)
- All `WEBHOOK_*_FIX` build error guides (issues resolved)
- All `BUILD_ERROR_*` guides (issues resolved)

**Why removed?**
- Template-based approach is deprecated (use API instead)
- Issues documented were fixed in current codebase
- Outdated instructions that would confuse new users
- Redundant with current documentation

---

## 💡 Getting Help

1. **Start here:** [QUICK_START_API.md](QUICK_START_API.md)
2. **Troubleshooting:** Check specific guides above
3. **Architecture questions:** [ARCHITECTURE_SIMPLE.md](ARCHITECTURE_SIMPLE.md)
4. **Service issues:** [SYSTEMD_SERVICE.md](SYSTEMD_SERVICE.md)

---

**Last updated:** 2026-02-01
