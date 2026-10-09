#!/usr/bin/env bash

echo "=== 1/4: Bulding System: Updating ==="
rm -rf ~/.config/zen/**/*.backup ~/.config/zen/*.backup 2>/dev/null || true
nh os switch

echo "=== 2/4: First Launch ==="
echo "-> Close the browser normally"
zen-beta &
ZEN_PID=$!
wait $ZEN_PID 2>/dev/null

echo "=== 3/4: Second Launch ==="
echo "-> Close the browser normally again"
zen-beta &
ZEN_PID=$!
wait $ZEN_PID 2>/dev/null

echo "=== 4/4: Injecting Containers, Workspaces, and Pins ==="
rm -rf ~/.config/zen/**/*.backup ~/.config/zen/*.backup 2>/dev/null || true
sudo systemctl restart home-manager-luka.service

echo "=== Zen was updated ==="
