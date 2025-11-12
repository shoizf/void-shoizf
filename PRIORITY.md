# 🧭 `void-shoizf` — Project Priority Roadmap

### 🎯 **Core Objective**

Achieve a **reproducible, fully-automated Void Linux installation and environment**, including desktop setup, developer tooling, and intelligent source management utilities — all maintained under the `void-shoizf` ecosystem.

---

## 🥇 Phase 1 — Core Installation & Stabilization
> **Goal:** Achieve flawless, repeatable setup of Void Linux and Niri desktop environment.

### **Tasks**
- [x] Modularize `install.sh` into structured sub-installers (`install-base.sh`, `install-desktop.sh`, `install-utils.sh`).
- [x] Implement standardized flags: `--clean`, `--debug`, `--force`, and consistent log styling.
- [x] Clean up Git branch tracking and outdated remotes.
- [x] Ensure idempotent execution (scripts safe for multiple runs).
- [x] Improve unified logging format with `[INFO]`, `[WARN]`, `[ERROR]` prefixes.
- [ ] Validate dependency installation across Void repos and mirrors.
- [ ] Verify **bare-metal**, **VM**, and **minimal ISO** test installs.
- [ ] Automate AppImage-based Obsidian installation (non-Flatpak, from official release).

**Output:** Fully working desktop environment on Void Linux via a single install pipeline.

---

## 🥈 Phase 2 — Developer Tooling Integration
> **Goal:** Provide consistent developer environment and workflow standardization.

### **Tasks**
- [ ] Integrate:
  - LazyVim setup  
  - Oh My Tmux configuration  
  - Obsidian installation (via AppImage)
- [ ] Extend `installers/dev-tools.sh` for unified developer environment setup.
- [ ] Add standardized logging to all sub-installers (`/var/log/void-shoizf/`).
- [ ] Introduce `/etc/void-shoizf/manifest.json` for version tracking.
- [ ] Add Rust toolchain setup (for future utilities: `shoipkg`, `shoizf-obman`).
- [ ] Create `runsvidr` prototype for post-install service validation.

---

## 🥈.5 Phase 2.5 — Obsidian Manager (`shoizf-obman`)
> **Goal:** Develop a **Rust-based CLI + background daemon** that intelligently manages Obsidian vaults.

### **Concept**
- **Binary:** `shoizf-obman`  
- **Path:** `/usr/bin/shoizf-obman`

### **Core Features**
- Detect vault type:
  - **Permanent:** user-created Obsidian vaults  
  - **Temporary:** automatically created by manager  
- Maintain vault state file:  
  `~/.local/share/shoizf-obman/state.json`
- Automatic cleanup of temporary vaults after session close.
- Integration with **Walker launcher** and **file double-click** behavior.
- Persistent logs in `~/.local/log/shoizf-obman.log`.
- CLI Flags:
  - `--status` → List vaults and states  
  - `--clean` → Remove temporary vaults  
  - `--debug` → Verbose output  

### **Implementation Plan**
1. Prototype logic in Bash for validation.  
2. Port final version to **Rust** for stability and daemonization.  
3. Integrate with `installers/dev-tools.sh`.

---

## 🥉 Phase 3 — `shoipkg` (Source Package Manager)
> **Goal:** Create a **Rust-based package manager** for tracking and updating manually built/source-installed software.

### **Concept**
- **Command:** `shoipkg register <repo_url>`

### **Core Functions**
- Track GitHub/GitLab/Codeberg repositories.
- Detect version/release changes.
- Notify or auto-update when new releases appear.
- Store state in `~/.shoipkg/state.json`.
- Optional hooks for rebuild automation.

### **CLI Commands**
- `shoipkg check-updates`  
- `shoipkg rebuild <package>`  
- `shoipkg sync --all`

### **Integration**
- Requires Rust toolchain (Phase 2).  
- Will interface with `runsvidr` for health reporting.

---

## 🧩 Phase 4 — `runsvidr` (System & Service Verifier)
> **Goal:** Verify system health, configuration integrity, and post-install consistency.

### **Concept**
- **Binary:** `runsvidr`  
- **Role:** Passive verifier & boot-time service check tool.

### **Checks**
- Validate:
  - SDDM, Niri, Waybar, NetworkManager, and other critical services.
  - Config files under `/etc` and `$HOME/.config/`.
  - File permissions and ownership.
- Generate reports to `/var/log/runsvidr-report.log`.
- Support plugin system (future).

---

## 🪜 Phase 5 — Documentation & Collaboration
> **Goal:** Improve project maintainability and contributor experience.

### **Tasks**
- [x] Add `CONTRIBUTING.md` (branching rules, commit style, PR guide).
- [x] Link contributing guide in `README.md`.
- [ ] Create architecture diagrams (install flow, dependencies, component map).
- [ ] Add `docs/` folder for dev notes, architecture, and integration examples.
- [ ] Include badges for verified installation builds.

---

## 🧠 Phase 6 — Long-Term / Experimental Ideas
> **Goal:** Explore advanced automation, packaging, and GUI integrations.

### **Ideas**
- GUI frontend for `shoipkg` (GTK/Qt).
- Hybrid source + XBPS package tracking.
- Automated ISO builder for preconfigured Void setups.
- Power optimization profiles (CPU/GPU tuning).
- Plugin API for `runsvidr` and `shoipkg`.
- Workspace tracking integration with `shoizf-obman`.

---

## ✅ **Summary of Execution Flow**
1. **Core Installer Stabilization** — Solidify `installers/*` and ensure idempotent, repeatable installs.  
2. **Developer Tool Integration** — LazyVim, Oh My Tmux, Obsidian AppImage, Rust toolchain.  
3. **shoizf-obman (Vault Manager)** — Rust CLI + daemon managing temporary and permanent vaults.  
4. **shoipkg (Source Package Manager)** — Rust-based manager to track/update source-installed packages.  
5. **runsvidr (Verifier)** — Validate system/service health post-install.  
6. **Documentation & Collaboration** — docs, diagrams, and contributor workflow.  
7. **Long-term Enhancements** — GUI frontends, ISO builder, power tuning, plugin APIs.

---

> 🧩 **Note:**  
> All new utilities (`shoizf-obman`, `shoipkg`, `runsvidr`) are planned as **Rust-based** binaries installed system-wide under `/usr/bin/`.  
> Initial prototypes for validation will be implemented in **Bash** under the `installers/` tree before porting.

---

© `shoizf` | Project: `void-shoizf` | Maintainer: `shoizf`

