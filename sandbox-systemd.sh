#!/usr/bin/env zsh

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
SCRIPT_PATH="${0}"
while [ -L "$SCRIPT_PATH" ]; do
  LINK_TARGET="$(readlink "$SCRIPT_PATH")"
  [[ "$LINK_TARGET" != /* ]] && LINK_TARGET="$(dirname "$SCRIPT_PATH")/$LINK_TARGET"
  SCRIPT_PATH="$LINK_TARGET"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/writable-paths.conf"

# 旧ファイル名からの自動マイグレーション
OLD_CONFIG_FILE="$SCRIPT_DIR/paths.conf"
if [[ -f "$OLD_CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
  mv "$OLD_CONFIG_FILE" "$CONFIG_FILE"
  echo "Migrated config: paths.conf -> writable-paths.conf" >&2
fi

run_opts=()

# privilege
run_opts+=('-p' 'NoNewPrivileges=yes')

# Device Access
run_opts+=('-p' 'PrivateDevices=yes')
run_opts+=('-p' 'DevicePolicy=closed')
run_opts+=('-p' 'DeviceAllow=/dev/null rw')
run_opts+=('-p' 'DeviceAllow=/dev/random r')
run_opts+=('-p' 'DeviceAllow=/dev/urandom r')

# User
run_opts+=('-p' 'PrivateUsers=no')
run_opts+=('-p' 'LockPersonality=yes')

# Mount
run_opts+=('-p' 'PrivateMounts=yes')

# Network
run_opts+=('-p' 'PrivateNetwork=no')
run_opts+=('-p' 'RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6 AF_VSOCK')

# filesystem
run_opts+=('-p' 'ProtectSystem=strict')
run_opts+=('-p' 'ProtectHome=read-only')

# 基本の書き込み許可パス
run_opts+=('-p' "ReadWritePaths=$WORKING_DIR")
run_opts+=('-p' "ReadWritePaths=$HOME/.config")
run_opts+=('-p' "ReadWritePaths=$HOME/.cache")
run_opts+=('-p' "ReadWritePaths=$HOME/.local/share")
run_opts+=('-p' "ReadWritePaths=$HOME/.kiro")
run_opts+=('-p' "ReadWritePaths=$HOME/.aws")
run_opts+=('-p' "ReadWritePaths=$HOME/.local/bin")
run_opts+=('-p' "ReadWritePaths=$HOME/.npm")

# paths.conf から追加の書き込み許可パスを読み込み
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  line="${line/#\~/$HOME}"
  [ -e "$line" ] && run_opts+=('-p' "ReadWritePaths=$line")
done < "$CONFIG_FILE"

# explicit deny list
run_opts+=('-p' "InaccessiblePaths=$HOME/.ssh")
run_opts+=('-p' "InaccessiblePaths=$HOME/.gnupg")
run_opts+=('-p' "InaccessiblePaths=$HOME/.config/gcloud")

# /tmp
run_opts+=('-p' 'PrivateTmp=no')

# /proc
run_opts+=('-p' 'ProtectProc=default')
run_opts+=('-p' 'ProcSubset=pid')

# /sys/fs/cgroup
run_opts+=('-p' 'ProtectControlGroups=yes')

run_opts+=('-p' 'RestrictFileSystems=ext4 tmpfs proc sysfs')

# syscall
run_opts+=('-p' 'SystemCallArchitectures=native')
run_opts+=('-p' 'SystemCallFilter=@system-service')
run_opts+=('-p' 'SystemCallFilter=~@privileged @debug')
run_opts+=('-p' 'SystemCallErrorNumber=EPERM')

# other
run_opts+=('-p' 'ProtectClock=yes')
run_opts+=('-p' 'ProtectHostname=yes')
run_opts+=('-p' 'ProtectKernelLogs=yes')
run_opts+=('-p' 'ProtectKernelModules=yes')
run_opts+=('-p' 'ProtectKernelTunables=yes')
run_opts+=('-p' 'RestrictNamespaces=yes')
run_opts+=('-p' 'RestrictRealtime=yes')
run_opts+=('-p' 'RestrictSUIDSGID=yes')
run_opts+=('-p' 'CapabilityBoundingSet=')
run_opts+=('-p' 'AmbientCapabilities=')
run_opts+=('-p' 'MemoryDenyWriteExecute=no')
run_opts+=('-p' 'UMask=0077')
run_opts+=('-p' 'CoredumpFilter=0')
run_opts+=('-p' 'KeyringMode=private')
run_opts+=('-p' 'NotifyAccess=none')

systemd-run \
  --user \
  --pty \
  --wait \
  --collect \
  --same-dir \
  -E PATH="$PATH" \
  "${run_opts[@]}" \
  "$@"
