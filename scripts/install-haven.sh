#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TARGET_ID="/dev/disk/by-id/nvme-Samsung_SSD_980_500GB_S64DNX0T106227L"
EXPECTED_REALDEV="/dev/nvme1n1"
FLAKE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}       NixOS Haven (Headless Server) Installer        ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Root check
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] This script must be run as root (use sudo).${NC}"
  exit 1
fi

# 2. Disk ID existence check
if [ ! -e "$TARGET_ID" ]; then
  echo -e "${RED}[ERROR] Target disk '$TARGET_ID' not found!${NC}"
  echo -e "${RED}Is the target NVMe SSD connected?${NC}"
  exit 1
fi

# 3. Realpath resolution
REAL_DEV="$(readlink -f "$TARGET_ID")"
echo -e "Target disk by-id: ${YELLOW}$TARGET_ID${NC}"
echo -e "Resolved block dev: ${YELLOW}$REAL_DEV${NC}"

if [ "$REAL_DEV" != "$EXPECTED_REALDEV" ]; then
  echo -e "${RED}[CRITICAL ERROR] Resolved device '$REAL_DEV' does not match expected '$EXPECTED_REALDEV'!${NC}"
  echo -e "${RED}Aborting immediately to protect system drives.${NC}"
  exit 1
fi

# 4. Strict blacklist check
CURRENT_ROOT="$(findmnt -n -o SOURCE /)"
echo -e "Current root source: $CURRENT_ROOT"

if [[ $CURRENT_ROOT == *"$REAL_DEV"* ]]; then
  echo -e "${RED}[FATAL ERROR] $REAL_DEV is part of the running root filesystem! ABORTING!${NC}"
  exit 1
fi

# Also protect nvme0n1 and nvme2n1 explicitly
if [ "$REAL_DEV" == "/dev/nvme0n1" ] || [ "$REAL_DEV" == "/dev/nvme2n1" ]; then
  echo -e "${RED}[FATAL ERROR] $REAL_DEV is a protected PC host drive! ABORTING!${NC}"
  exit 1
fi

# 5. Check if /mnt has existing mounts
if mountpoint -q /mnt; then
  echo -e "${YELLOW}Unmounting existing mounts under /mnt...${NC}"
  umount -R /mnt || true
fi

echo -e "${GREEN}[PASS] Drive safety checks passed!${NC}"
echo -e "${GREEN}Target drive is verified as Samsung 980 500GB (S64DNX0T106227L) on $REAL_DEV.${NC}\n"

# 6. Execute Disko partition & format & mount
echo -e "${BLUE}==> [1/4] Running Disko to partition and format target drive...${NC}"
disko_script="$(nix build "$FLAKE_DIR#nixosConfigurations.haven.config.system.build.diskoScript" --no-link --print-out-paths)"
echo -e "Disko script path: $disko_script"
"$disko_script"

echo -e "\n${BLUE}==> [2/4] Verifying mountpoints under /mnt...${NC}"
findmnt /mnt
findmnt /mnt/boot

echo -e "\n${BLUE}==> [3/4] Installing NixOS (haven) onto /mnt...${NC}"
nixos-install --flake "$FLAKE_DIR#haven" --no-root-password --no-channel-copy

echo -e "\n${BLUE}==> [4/4] Deploying Sops Age decryption key to haven...${NC}"
AGE_SOURCE="/home/luka/.config/sops/age/keys.txt"
AGE_DEST_DIR="/mnt/home/luka/.config/sops/age"
if [ -f "$AGE_SOURCE" ]; then
  mkdir -p "$AGE_DEST_DIR"
  cp "$AGE_SOURCE" "$AGE_DEST_DIR/keys.txt"
  chmod 700 /mnt/home/luka/.config /mnt/home/luka/.config/sops "$AGE_DEST_DIR"
  chmod 600 "$AGE_DEST_DIR/keys.txt"
  chown -R 1000:100 /mnt/home/luka
  echo -e "${GREEN}[OK] Age key successfully copied and permissions secured (0600, luka:users).${NC}"
else
  echo -e "${RED}[WARNING] Age key not found at $AGE_SOURCE! Sops secrets might fail to decrypt on first boot.${NC}"
fi

echo -e "\n${BLUE}==> Unmounting /mnt cleanly...${NC}"
umount -R /mnt

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}      🎉 HAVEN INSTALLATION COMPLETED SUCCESSFULLY!     ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "You can now safely shut down this PC, remove the NVMe SSD ($REAL_DEV),"
echo -e "and insert it into your new Mini-PC server ('haven')."
echo -e ""
echo -e "When powered on with an Ethernet cable connected:"
echo -e "  - It will boot into NixOS Headless Server."
echo -e "  - SSH is enabled for user 'luka' with your ed25519 keys."
echo -e "  - Connect with:  ssh luka@haven.local"
echo -e "  - Sudo is passwordless for 'wheel' so you can run 'sudo' without issues."
echo -e "  - All server services (Caddy, Vaultwarden, Immich, Arr, etc.) will start automatically."
echo -e "======================================================\n"
