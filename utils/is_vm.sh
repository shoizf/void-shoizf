#!/usr/bin/env bash
# utils/is_vm.sh — Detect virtualized environment (runit-friendly)
# Sets IS_VM=true/false.
# Returns 0 if VM detected, 1 if not.

set -euo pipefail

IS_VM=false

# Prefer robust checks on /sys and /proc
# Check DMI product name and sys_vendor, if available.
dmi_prod="$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "")"
dmi_vendor="$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null || echo "")"
dmi_board="$(cat /sys/devices/virtual/dmi/id/board_vendor 2>/dev/null || echo "")"
cpu_flags="$(grep -m1 -E '^flags' /proc/cpuinfo 2>/dev/null || echo "")"
cpu_vendor="$(grep -m1 '^vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}' || echo "")"

# Common virtualization identifiers
if printf "%s\n" "$dmi_prod" "$dmi_vendor" "$dmi_board" | grep -Eiq 'qemu|kvm|virtualbox|vmware|xen|microsoft|bochs|bhyve|parallels|kvm'; then
  IS_VM=true
fi

# Another indicator: hypervisor flag in cpu flags
if printf "%s\n" "$cpu_flags" | grep -qi 'hypervisor'; then
  IS_VM=true
fi

# Export for other scripts that source this file
export IS_VM

# Do NOT echo or exit here. The parent script will read the variable.
