# ROADMAP.md  
## Project Roadmap — void-shoizf  
A structured, versioned roadmap detailing the development direction of the **void-shoizf** project.  
This roadmap focuses on installation stability, runtime polish, service reliability, developer UX, and final release maturity.

---

# 🟦 v0.3 — Core Stabilization (Current Focus)

### 🎯 Goals  
Stabilize the essential runtime components and fix core blockers that affect the daily workflow.

### ✅ Tasks  
- Debug `shoizf-lock`  
- Fix `hyprlock.sh`  
- Fix `awww.sh`  
- Move all runtime helper binaries to `/bin/`  
- Logging polish across installers  
- General installer consistency and cleanup  

---

# 🟩 v0.4 — Desktop & Runtime Polish

### 🎯 Goals  
Smoothen the user experience and tighten the graphical desktop environment.

### ✅ Tasks  
- Integrate wallpaper engine cleanly  
- Ensure consistent Hyprlock behavior  
- Improve Waybar configuration  
- Enforce GPU behavior consistency (Intel primary, NVIDIA on-demand)  
- Improve service reliability for runtime components  

---

# 🟧 v0.5 — Runtime Verification & Service Architecture

### 🎯 Goals  
Strengthen system reliability, catch misconfigurations early, and finalize service layout.

### ✅ Tasks  
- Introduce **runsvidr** (system/service verification tool)  
- Complete runtime service consistency under **runsvdir**  
- Improve installation logs and validation  
- Harden startup sequence for Niri, Waybar, Mako, Hyprlock, and supporting binaries  

---

# 🟨 v0.6 — Documentation & Contributor Experience

### 🎯 Goals  
Prepare the project for external contributors and future maintainers.

### ✅ Tasks  
- Add `docs/` folder for extended references  
- Set up foundational GitHub Wiki structure  
- Add architecture diagrams (installer flow, component mapping)  
- Add installation flow diagrams  
- Improve and refine `CONTRIBUTING.md`  
- Align all documentation format and tone  

---

# 🟪 v0.7 — Pre-Release Polish

### 🎯 Goals  
Final cleanup before the first stable release milestone.

### ✅ Tasks  
- Large-scale cleanup  
- Hardening of installers and configs  
- Performance improvements  
- Fix any remaining bugs  
- Perform structured test builds  

---

# 🟫 v1.0 — Stable Daily-Driver Release

### 🎯 Goals  
First fully stable, daily-driver ready release of the **void-shoizf** system.

### ✅ Requirements  
- Stable installer pipeline  
- Stable desktop environment (Niri, Waybar, Hyprlock, Mako)  
- All runtime components working reliably  
- Verified system health via **runsvidr**  
- Verified package and config tracking (foundation for future `shoipkg`)  
- Complete and consistent documentation  

---

# END OF ROADMAP.md

