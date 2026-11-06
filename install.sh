#!/usr/bin/env bash
# bili-sub 安装脚本
#   本地：./install.sh
#   在线：curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
#
# 默认装到 ~/.local/bin（用户自己的目录，不需要 sudo，也不依赖 Homebrew）。
# 想换地方：BILI_BIN=/你的/目录 ./install.sh
set -eu

REPO="${BILI_REPO:-https://github.com/Zhiyi1207/bili-sub}"
DEST="${BILI_DEST:-$HOME/.local/share/bili-sub}"
BIN_DIR="${BILI_BIN:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }

# 1. 先确认有 python3 3.8+
command -v python3 >/dev/null 2>&1 \
  || die "没找到 python3。macOS 可以跑 xcode-select --install；Linux 用发行版自带的包"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || die "python3 版本太老，需要 3.8 以上"

# 2. 找 bili 本体：脚本旁边有就用，没有就去仓库下载
#    （curl | bash 时 BASH_SOURCE 是空的，此时一律走下载，不会误用当前目录的文件）
SELF="${BASH_SOURCE[0]:-}"
HERE=""
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  HERE="$(cd "$(dirname "$SELF")" && pwd)"
fi

TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

if [ -n "$HERE" ] && [ -f "$HERE/bili" ]; then
  SRC="$HERE/bili"
else
  command -v git >/dev/null 2>&1 || die "需要 git，或者手动下载仓库 zip 解压后跑 ./install.sh"
  TMP="$(mktemp -d)"
  git clone --depth 1 "$REPO" "$TMP/src" >/dev/null 2>&1 || die "下载失败：$REPO"
  SRC="$TMP/src/bili"
fi

# 3. 安装：本体放固定位置，PATH 里放软链
mkdir -p "$DEST" "$BIN_DIR" || die "建不了目录：$DEST 或 $BIN_DIR"
cp "$SRC" "$DEST/bili"
chmod 755 "$DEST/bili"
ln -sfn "$DEST/bili" "$BIN_DIR/bili"

say "✅ 装好了：$BIN_DIR/bili"
say "   程序本体：$DEST/bili"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    say ""
    say "⚠️  $BIN_DIR 不在 PATH 里。把下面这行加到 ~/.zshrc（或 ~/.bashrc）末尾，再重开终端："
    say "    export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac
say ""
say "下一步：bili help"
say "要登录态的话：bili setcookie"
