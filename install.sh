#!/usr/bin/env bash
# bili-sub 安装脚本
#   本地运行：./install.sh
#   在线运行：curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
set -eu

REPO="${BILI_REPO:-https://github.com/Zhiyi1207/bili-sub}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.local/share/bili-sub"

say()  { printf '%s\n' "$*"; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }

# 1. 要有 python3 3.8+
command -v python3 >/dev/null 2>&1 || die "没找到 python3。macOS 可以先跑 xcode-select --install"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || die "python3 版本太老，需要 3.8 以上"

# 2. 拿到 bili 源码：本地就在旁边，否则从仓库拉
TMP=""
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

if [ -f "$HERE/bili" ]; then
  SRC="$HERE/bili"
else
  command -v git >/dev/null 2>&1 || die "没有 git，装一个再来（或者手动下载仓库 zip）"
  TMP="$(mktemp -d)"
  git clone --depth 1 "$REPO" "$TMP/src" >/dev/null 2>&1 || die "从 $REPO 下载失败"
  SRC="$TMP/src/bili"
fi

# 3. 拷到固定位置（不直接跑仓库里的文件，避免以后误删仓库）
mkdir -p "$DEST"
cp "$SRC" "$DEST/bili"
chmod 755 "$DEST/bili"

# 4. 找一个能写、又在 PATH 里的目录放命令
BIN=""
for d in "${BILI_BIN:-}" /usr/local/bin /opt/homebrew/bin "$HOME/.local/bin" "$HOME/bin"; do
  [ -n "$d" ] || continue
  if [ -d "$d" ] && [ -w "$d" ]; then BIN="$d"; break; fi
done
if [ -z "$BIN" ]; then
  mkdir -p "$HOME/.local/bin"
  BIN="$HOME/.local/bin"
fi
ln -sfn "$DEST/bili" "$BIN/bili"

say "✅ 装好了：$BIN/bili"
say "   程序本体：$DEST/bili"
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) say "⚠️  $BIN 不在 PATH 里，加一下："
     say "    echo 'export PATH=\"$BIN:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
esac
say ""
say "下一步：bili help"
say "需要登录态的话：bili setcookie"
