#!/usr/bin/env bash
# bili-sub 安装脚本
#   本地：./install.sh
#   在线：curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
#
# 会把 bili 装到你指定的一个目录（默认 ~/.local/bin），不写别的文件，不需要 sudo，
# 也不依赖 Homebrew。想跳过询问：BILI_BIN=/你的/目录 ./install.sh
set -eu

REPO="${BILI_REPO:-https://github.com/Zhiyi1207/bili-sub}"
BIN_DIR="${BILI_BIN:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }

# 1. 要有 python3 3.8+
command -v python3 >/dev/null 2>&1 \
  || die "没找到 python3。macOS 可以跑 xcode-select --install；Linux 用发行版自带的包"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || die "python3 版本太老，需要 3.8 以上"

# 2. 找 bili 本体：脚本旁边有就直接用，否则去仓库取
#    （curl | bash 时 BASH_SOURCE 是空的，一律走下载，不会误用当前目录的文件）
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
elif command -v git >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  git clone --depth 1 "$REPO" "$TMP/src" >/dev/null 2>&1 || die "从 $REPO 下载失败"
  SRC="$TMP/src/bili"
elif command -v curl >/dev/null 2>&1; then
  TMP="$(mktemp -d)"
  curl -fsSL "$REPO/archive/refs/heads/main.tar.gz" -o "$TMP/src.tgz" || die "下载失败：$REPO"
  tar xzf "$TMP/src.tgz" -C "$TMP" || die "解压失败"
  SRC="$(find "$TMP" -maxdepth 2 -name bili -type f | head -1)"
  [ -n "$SRC" ] || die "下载的包里没找到 bili"
else
  die "需要 git 或 curl 其中一个才能下载，或者手动把 bili 放进你要的目录"
fi

# 3. 问用户装到哪（非交互场景跳过，用默认值）
if [ "${BILI_NOPROMPT:-0}" != "1" ] && [ -t 0 ]; then
  say "bili 会被拷到下面这个目录里，不用 sudo，也不会装到系统目录。"
  printf '装到哪个目录？[回车用默认：%s] ' "$BIN_DIR"
  read -r ans || ans=""
  if [ -n "$ans" ]; then BIN_DIR="$ans"; fi
fi
case "$BIN_DIR" in
  "~") BIN_DIR="$HOME" ;;
  "~/"*) BIN_DIR="$HOME/${BIN_DIR#\~/}" ;;
esac
case "$BIN_DIR" in
  /*) ;;
  *) die "要写绝对路径，或者以 ~/ 开头。收到：$BIN_DIR" ;;
esac

mkdir -p "$BIN_DIR" || die "建不了这个目录：$BIN_DIR"
[ -w "$BIN_DIR" ] || die "这个目录不可写：$BIN_DIR"
rm -f "$BIN_DIR/bili"
cp "$SRC" "$BIN_DIR/bili"
chmod 755 "$BIN_DIR/bili"

say ""
say "✅ 已安装：$BIN_DIR/bili"
case ":$PATH:" in
  *":$BIN_DIR:"*)
    say "   现在就能用：bili help" ;;
  *)
    say ""
    say "⚠️  $BIN_DIR 不在 PATH 里。把下面这行加到 ~/.zshrc（或 ~/.bashrc）末尾，再重开终端："
    say "    export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
say ""
say "下一步：bili help"
say "需要登录态的话：bili setcookie"
