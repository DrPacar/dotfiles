#!/usr/bin/env bash
set -e

case " $* " in
*" -Y sign "*) ;;
*) exec ssh-keygen "$@" ;;
esac

KEY_PUB=""
for ((i = 1; i <= $#; i++)); do
  if [[ ${!i} == "-f" ]]; then
    next_idx=$((i + 1))
    KEY_PUB="${!next_idx}"
    break
  fi
done

if [ -z "$KEY_PUB" ]; then
  KEY_PUB="$(git config --get user.signingkey 2>/dev/null || true)"
fi

KEY_PUB="${KEY_PUB/#\~/$HOME}"
KEY_PRIV="${KEY_PUB%.pub}"

if [[ $KEY_PUB == *.pub ]] && [ -f "$KEY_PUB" ] && [ -f "$KEY_PRIV" ]; then
  FINGERPRINT="$(ssh-keygen -l -f "$KEY_PUB" 2>/dev/null | cut -d' ' -f2 || true)"
  LOADED="$(ssh-add -l 2>/dev/null || true)"
  if [ -n "$FINGERPRINT" ] && ! grep -qF "$FINGERPRINT" <<<"$LOADED"; then
    ssh-add "$KEY_PRIV"
  fi
fi

exec ssh-keygen "$@"
