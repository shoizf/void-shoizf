# Void Linux Niri Desktop Automation

A personal, fully-automated setup for quickly bootstrapping a **workable, user-friendly Niri environment** on Void Linux—from scratch to daily-driver in minutes.

This repo is the toolkit and documentation I use to standardize and  streamline my Void Linux installs, with an emphasis on a reliable [Niri](https://github.com/YaLTeR/niri) Wayland compositor experience. Documentation around Void and Niri can  be hard to piece together—this repo aims to be a reproducible,  well-documented reference both for myself and for anyone else struggling to get a modern desktop running on Void.

------

## Main Components of this Setup

- **Display Manager:** [SDDM](https://github.com/sddm/sddm) (with Astronaut theme)
- **Compositor:** [Niri](https://github.com/YaLTeR/niri) Wayland compositor
- **Status Bar:** [Waybar](https://github.com/Alexays/Waybar)
- **Application Launcher / Picker:** [Walker](https://github.com/abenz1267/walker)
- **Terminal Emulator:** [Alacritty](https://github.com/alacritty/alacritty)
- **Editor:** [Neovim](https://github.com/neovim) (nvim)
- **Browser:** [Ungoogled Chromium](https://github.com/ungoogled-software/ungoogled-chromium)
- **Terminal Multiplexer:** [tmux](https://github.com/tmux/tmux/wiki)

------

## Minimal manual steps, maximum repeatability

The only manual setup required (outside this repo) is having a bootable USB created with [Ventoy](https://github.com/ventoy/Ventoy/releases/) or an equivalent tool, containing the official Void Linux minimal **glibc live ISO image** downloaded from [voidlinux.org/download](https://voidlinux.org/download/).

The manual installation process assumes Windows+Void dual boot users have manually created a Windows boot partition sized **at least 1 GiB** (1024 MiB) to avoid the Windows automatic smaller boot partition issue. See the [Arch Wiki Dual Boot with Windows](https://wiki.archlinux.org/title/Dual_boot_with_Windows) for detailed partition layout guidance.

------

## Zero to functional Niri desktop

After the minimal Void installation, the rest of the environment setup including Niri is fully automated via `install.sh` and related scripts.

------

## Built and tested for real-world use

Scripts reflect an actual, working daily setup—no partial configs or abandoned dotfiles.

------

## Self-documenting

Organized configs and scripts demonstrate best practices; works as a learning resource for users new to Void or Niri.

------

## Features

- Consistent Void Linux environment ready for daily development and desktop use.
- Fully configured ([Niri](https://github.com/YaLTeR/niri)) Wayland compositor with all major dependencies.
- Sensible scripting for SDDM, networking, display, font, backlight/RGB device rules, and more.
- Step-by-step, plain-English documentation in this repo, augmented by the detailed partition setup guidance in Arch Wiki.

------

## Who Should Use This Repo?

Anyone who:

- Wants to replicate a stable Niri-based Wayland desktop on Void Linux, either from scratch or for rapid migration.
- Is dual booting with Windows and wants consistent guidance on boot partition setup.
- Is tired of piecing together outdated forum posts and missing config fragments.
- Prefers automation, clarity, and ongoing maintainability—especially for their *own* systems, but also for friends or colleagues.

------

## How to Use

**Do not follow this README for step-by-step instructions!**
 Please see [`INSTALLATION.md`](https://www.perplexity.ai/search/INSTALLATION.md) for comprehensive installation and configuration steps.

Everything you need beyond the minimal OS install and partition setup is automated and handled through scripts in this repo.

------

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/shoizf/void-shoizf/blob/main/LICENSE) file for details.