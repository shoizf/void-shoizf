# ARCHITECTURE.md  
## Overview  
This document provides a complete, structured breakdown of the internal architecture of the **void-shoizf** project. It describes how the installer pipeline works, how configuration files are organized, and how runtime components interact in the final system. It exists to give contributors and future maintainers a clear, high-level view of how the system is designed.

This document works together with:  
- **README.md** → High-level introduction & quickstart  
- **INSTALLATION.md** → Installation workflow for users  
- **ROADMAP.md** → Project priorities, milestones, and long-term goals  
- **CONTRIBUTING.md** → Contributor guidelines  
- **CHANGELOG.md** → Versioned historical changes  
- **ARCHITECTURE.md (this)** → Internal structural and technical design

---

# 1. High-Level System Architecture  

The system is built around a **layered installer framework** that deploys a fully customized Void Linux environment optimized for:  
- Hybrid GPU (Intel primary, NVIDIA via prime-run)  
- Niri window manager  
- Clean separation of root vs user operations  
- Safety, reproducibility, modularity, and maintainability  

All installers follow strict boundaries:  
- **ROOT_INSTALLERS** → run entirely as root  
- **USER_INSTALLERS** → never invoke sudo  
- **HYBRID_INSTALLERS** → may use sudo *only where explicitly allowed*  

The architecture ensures no sudoers pollution, no privilege surprises, and a predictable environment.

---

# 2. Repository Structure  
Below is the architectural meaning of each major directory and its role in the system.

```
void-shoizf/
│
├── assets/
├── bin/
├── configs/
├── installers/
├── utils/
│
├── install.sh
├── README.md
├── INSTALLATION.md
├── ARCHITECTURE.md
├── ROADMAP.md
├── CONTRIBUTING.md
├── CHANGELOG.md
└── LICENSE
```

---

## 2.1 assets/  
Contains static, non-executable resources.

### Structure  
```
assets/
 └── fonts/
      ├── metropolis/
      ├── sf-pro-display/
      └── stange/
```

### Purpose  
- UI fonts for Niri, Waybar, Hyprlock  
- Contains *only* static data  
- No scripts or configs belong here  

---

## 2.2 bin/  
Executable runtime scripts used by the system **after installation**, during everyday use.

### Contents  
- `shoizf-lock`  
  - Unified lock wrapper for Niri + Hyprlock  
- `wallpaper-cycler.sh`  
  - Provides fresh wallpaper lists for awww  
- `music-info.sh`  
  - Provides current media metadata for Hyprlock  
- `music-progress.sh`  
  - Shows media progress bar for Hyprlock integration  
- `battery-status.sh`  
  - Provides battery percentage + charging state to Hyprlock  

All five scripts define **runtime behavior** and are tightly integrated with Niri/Hyprlock/Waybar.

These scripts do **not** belong to installers, and they are not configuration files — they are part of the active runtime system.

---

## 2.3 configs/  
Configuration directories for desktop components and user environment.

```
configs/
 ├── hypr/
 ├── niri/
 ├── mako/
 └── waybar/
```

### 2.3.1 configs/hypr/  
Contains configuration files for:  
- `hyprlock.conf`  
- `hypridle.conf.template`  
- Background image assets  

No executables remain here — all runtime helper scripts live in `/bin/`.

### 2.3.2 configs/niri/  
Contains the core window-manager configuration:  
- `config.kdl` → All bindings, layouts, startup processes, rules.

### 2.3.3 configs/mako/  
Contains configuration for the Mako notification daemon:
- `config`

### 2.3.4 configs/waybar/  
Contains Waybar configuration and theming:
- `config.jsonc`  
- `style.css`  
- icons under `images/`

---

## 2.4 installers/  
Contains *all installer logic*, executed by `install.sh`.

Installers are modular, isolated scripts following a strict structure.  
No runtime logic belongs here.

### Categories  
- **Graphics & GPU**:  
  - `intel.sh`, `nvidia.sh`, `vulkan-intel.sh`
- **Desktop Environment Components**:  
  - `niri.sh`, `hyprlock.sh`, `mako.sh`, `waybar.sh`
- **System Services & Tools**:  
  - `networkman.sh`, `audio-integration.sh`, `dev-tools.sh`
- **Bootloader / Display Manager**:  
  - `grub.sh`, `sddm_astronaut.sh`
- **AWWW Wallpaper System**:  
  - `awww.sh`
- **Package Installer**:  
  - `install-packages.sh`

### installer/template  
Defines the gold standard for new installer scripts:  
- structured logging  
- safe sudo use  
- error handling  
- naming convention  
- reproducibility guarantees  

---

## 2.5 utils/  
Small helper utilities used *only during installation*, not at runtime.

Current:
- `is_vm.sh` → Detects if installation is running inside a VM  

These scripts should remain minimal and installation-focused.

---

# 3. install.sh — Master Orchestrator  

`install.sh` coordinates all installers and controls the entire system setup.

### Responsibilities  
1. Detect VM environment  
2. Load installer lists (root/user/hybrid)  
3. Execute installers in proper order  
4. Enforce strict sudo boundaries  
5. Maintain logs at:  
   ```
   ~/.local/log/void-shoizf/
   ```  
6. Provide top-level logging for debugging and reproducibility  

### Philosophy  
- Root tasks always start under root  
- User tasks stay strictly non-root  
- Hybrid tasks maintain controlled access  
- No temporary or permanent sudoers modifications  
- Every step is logged  

This produces a reproducible and audit-friendly installation process.

---

# 4. Logging Architecture  

### Per-installer logs  
Each installer generates a timestamped log file.

### Master log  
`install.sh` writes a global summary log capturing:  
- installer order  
- durations  
- success/failure state  
- environment metadata  
- timestamps  

This allows systematic debugging without guesswork.

---

# 5. GPU Architecture  

### Default GPU Policy  
- Intel iGPU = **primary renderer**  
- NVIDIA dGPU = **on-demand renderer** via `prime-run`  

### Rationale  
- Power efficiency  
- Lower heat output  
- Predictable performance behavior  
- More stable Wayland/Niri experience  

GPU installers configure Mesa, Vulkan, device preferences, environment variables, and consistency.

---

# 6. Runtime Service Architecture  

The system follows strict discipline:  
### **Only user-level services run under the user’s runsvdir.**  
Root never pollutes user services.

Expected user services:  
- Waybar  
- Mako  
- Wallpaper cycler  
- Media info providers  
- Hyprlock’s dynamic components  
- Niri session  

This structure ensures clarity, security, and maintainability.

---

# 7. Document Relationships  

To avoid confusion, this repository uses a layered documentation model:

### **ARCHITECTURE.md (this file)**  
Describes the **internal structure** and system design.

### **ROADMAP.md**  
Describes **project goals**, priorities, and future plans.

### **INSTALLATION.md**  
Explains how to install the system.  
User-facing.

### **CONTRIBUTING.md**  
Explains development guidelines.  
Contributor-facing.

### **CHANGELOG.md**  
Records versioned evolution.  
Historical reference.

### **README.md**  
Intro + quickstart + project overview.

This separation keeps each file focused and prevents documentation overlap.

---

# 8. Future Architectural Directions  

- Add deeper docs/ folder with technical breakdowns  
- Introduce snapshot/rollback mechanism for testing  
- Create GPU diagnostic tools  
- Expand wallpaper automation  
- Add service self-healing  
- Write full GitHub Wiki for advanced understanding  

---

# END OF ARCHITECTURE.md
