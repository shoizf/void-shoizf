## 🧭 CONTRIBUTING.md — void-shoizf

### 👋 Welcome

Thanks for contributing to **void-shoizf**!
This project provides a modular installation framework for Void Linux setups — emphasizing **clarity, consistency, and re-run safety**.
Contributions should maintain those standards.

---

## 🪜 1. Branching Model

| Type         | Prefix            | Example                       | Purpose                                        |
| ------------ | ----------------- | ----------------------------- | ---------------------------------------------- |
| **Main**     | `main`            | —                             | Stable, production-ready branch                |
| **Feature**  | `feature/<name>`  | `feature/dev-tools-expansion` | New functionality or module                    |
| **Fix**      | `fix/<name>`      | `fix/logging-header-format`   | Bug or regression fix                          |
| **Refactor** | `refactor/<name>` | `refactor/hyprlock-cleanup`   | Internal improvements without behavior changes |
| **Docs**     | `docs/<name>`     | `docs/contributing-guide`     | Documentation-only updates                     |

**Rules:**

* Always branch from `main`.
* Keep branches focused — one logical change per branch.
* Rebase frequently; use **squash-and-merge** when merging to `main`.

---

## 🧩 2. Commit Message Guidelines

Each commit should follow this format:

```
<type>: <short summary>

<optional detailed description>
```

### Accepted Types

| Type       | Description                                  | Example                                      |
| ---------- | -------------------------------------------- | -------------------------------------------- |
| `feat`     | New feature or addition                      | `feat: add eget integration to dev-tools.sh` |
| `fix`      | Bug or regression fix                        | `fix: correct log timestamp output`          |
| `refactor` | Internal improvement without behavior change | `refactor: unify installer headers`          |
| `docs`     | Documentation change                         | `docs: add contributing guide`               |
| `build`    | Build or dependency-related changes          | `build: update installer path detection`     |
| `chore`    | Maintenance, cleanup, or small adjustments   | `chore: remove unused temp files`            |
| `test`     | Adding or modifying tests                    | `test: verify hyprlock setup in VM`          |

**Guidelines:**

* Use **lowercase** for type.
* Keep the **summary ≤ 72 characters**.
* Write in **imperative mood** (“add” not “added”).
* Group related changes in one commit; avoid multi-purpose commits.

---

## ⚙️ 3. Installer Style Guide

All scripts under `installers/` must follow these conventions:

1. **Standard log header:**

   ```bash
   log_path="$HOME/.local/log/void-shoizf/<name>.log"
   echo "[$(date '+%F %T')] Starting <Name> setup..." | tee -a "$log_path"
   echo "------------------------------------------------------------" | tee -a "$log_path"
   ```

2. **Write all key actions to the log**, not just stdout.

3. **Support re-run safety** — check for existing files and back them up if needed.

4. **Handle errors gracefully:**
   Never `exit 1` silently. Print clear error messages with timestamps.

5. **Keep installers quiet** unless interaction is necessary.

6. **Avoid hard dependencies** — check and install as needed.

7. Use **pure POSIX shell** or **bash**, no distro-specific assumptions.

---

## 🧪 4. Testing & Verification

### Bare-Metal Test

* Run the installer from `install.sh` on a clean Void Linux system.
* Verify logs are generated in `~/.local/log/void-shoizf/`.
* Confirm no idle timeout or DPMS triggers mid-run.

### VM Test

* Validate re-execution safety and idempotency.
* Confirm correct handling when target files already exist.

---

## 🔍 5. Contribution Workflow

1. **Fork** the repository.
2. **Create a branch** from `main`:

   ```bash
   git checkout -b feature/my-new-installer
   ```
3. **Make changes** following the installer and logging standards.
4. **Test** locally — logs, re-runs, and behavior.
5. **Commit** with a clean, clear message.
6. **Push** your branch and open a **Pull Request**.

Pull request titles should mirror your first commit message.

---

## ✅ 6. Review Checklist

Before opening a PR, ensure:

* [ ] Script follows standard log header format.
* [ ] Logs are written to `~/.local/log/void-shoizf/`.
* [ ] No unnecessary prompts or pauses.
* [ ] Script can be re-run safely.
* [ ] Dependencies are handled gracefully.
* [ ] `set -euo pipefail` or equivalent safety guard included.
* [ ] README or relevant docs updated if behavior changes.

---

## 💡 7. Guiding Principles

> “Every installer should explain itself.”

* Prioritize **clarity over cleverness**.
* Maintain **consistency** across scripts.
* **Transparency** in logging is as important as the install itself.
* **Composable automation:** each installer works standalone, but integrates cleanly under `install.sh`.

---

## 🙏 Thanks

Your contributions help keep **void-shoizf** clean, consistent, and maintainable — a reliable foundation for reproducible setups.
Respect code style, write clear logs, and keep things simple.

---
