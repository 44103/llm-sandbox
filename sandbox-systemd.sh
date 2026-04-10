#!/bin/bash

set -e

# Clean Windows environment variables (remove \r)
if [ -n "$WINHOME" ]; then
  WINHOME=$(echo "$WINHOME" | tr -d '\r')
fi

WORKING_DIR=$(pwd)

# 危険コマンドの実行拒否
if [ $# -gt 0 ]; then
  case "$(basename "$1")" in
    sudo|su|chroot)
      echo "ERROR: '$1' is not allowed in sandbox." >&2
      exit 1
      ;;
  esac
fi

# 設定ファイル: スクリプトと同じディレクトリの writable-paths.conf を参照
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$(dirname "${BASH_SOURCE[0]}")/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/writable-paths.conf"

# 旧ファイル名からの自動マイグレーション
OLD_CONFIG_FILE="$SCRIPT_DIR/paths.conf"
if [[ -f "$OLD_CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
    mv "$OLD_CONFIG_FILE" "$CONFIG_FILE"
    echo "Migrated config: paths.conf -> writable-paths.conf" >&2
fi

options=()

# privilege
options+=('-p' 'NoNewPrivileges=yes')

# Device Access
options+=('-p' 'PrivateDevices=yes')
options+=('-p' 'DevicePolicy=closed')
options+=('-p' 'DeviceAllow=/dev/null rw')
options+=('-p' 'DeviceAllow=/dev/random r')
options+=('-p' 'DeviceAllow=/dev/urandom r')

# User
options+=('-p' 'PrivateUsers=no')
options+=('-p' 'LockPersonality=yes')

# Mount
options+=('-p' 'PrivateMounts=yes')

# Network
options+=('-p' 'PrivateNetwork=no')
options+=('-p' 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_VSOCK')

# filesystem
options+=('-p' 'ProtectSystem=strict')
options+=('-p' 'ProtectHome=read-only')

# 基本の書き込み許可パス
options+=('-p' "ReadWritePaths=$WORKING_DIR")
options+=('-p' "ReadWritePaths=$HOME/.config")
options+=('-p' "ReadWritePaths=$HOME/.cache")
options+=('-p' "ReadWritePaths=$HOME/.local/share")
options+=('-p' "ReadWritePaths=$HOME/.kiro")
options+=('-p' "ReadWritePaths=$HOME/.aws")
options+=('-p' "ReadWritePaths=$HOME/.local/bin")
options+=('-p' "ReadWritePaths=$HOME/.npm")

# paths.conf から追加の書き込み許可パスを読み込み
while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    line="${line/#\~/$HOME}"
    [ -e "$line" ] && options+=('-p' "ReadWritePaths=$line")
done < "$CONFIG_FILE"

# explicit deny list
options+=('-p' "InaccessiblePaths=$HOME/.ssh")
options+=('-p' "InaccessiblePaths=$HOME/.gnupg")
options+=('-p' "InaccessiblePaths=$HOME/.config/gcloud")

# /tmp
options+=('-p' 'PrivateTmp=no')

# /proc
options+=('-p' 'ProtectProc=default')
options+=('-p' 'ProcSubset=pid')

# /sys/fs/cgroup
options+=('-p' 'ProtectControlGroups=yes')

options+=('-p' 'RestrictFileSystems=ext4 tmpfs proc sysfs')

# syscall
options+=('-p' 'SystemCallArchitectures=native')
options+=('-p' 'SystemCallFilter=@system-service')
options+=('-p' 'SystemCallFilter=~@privileged @debug')
options+=('-p' 'SystemCallErrorNumber=EPERM')

# other
options+=('-p' 'ProtectClock=yes')
options+=('-p' 'ProtectHostname=yes')
options+=('-p' 'ProtectKernelLogs=yes')
options+=('-p' 'ProtectKernelModules=yes')
options+=('-p' 'ProtectKernelTunables=yes')
options+=('-p' 'RestrictNamespaces=yes')
options+=('-p' 'RestrictRealtime=yes')
options+=('-p' 'RestrictSUIDSGID=yes')
options+=('-p' 'CapabilityBoundingSet=')
options+=('-p' 'AmbientCapabilities=')
options+=('-p' 'MemoryDenyWriteExecute=no')
options+=('-p' 'UMask=0077')
options+=('-p' 'CoredumpFilter=0')
options+=('-p' 'KeyringMode=private')
options+=('-p' 'NotifyAccess=none')

systemd-run \
  --user \
  --pty \
  --wait \
  --collect \
  --same-dir \
  -E PATH="$PATH" \
  "${options[@]}" \
  "$@"
