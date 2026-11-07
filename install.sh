#!/usr/bin/env bash
# bili-sub 安装脚本（macOS / Linux）
#   本地：./install.sh
#   在线：curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
#
# 全自动：挑一个合适的目录、把 bili 拷进去、必要时配好 PATH、最后自检一遍。
# 不问你任何问题。想干预：
#   BILI_BIN=/你的/目录 ./install.sh     指定装到哪
#   ./install.sh --no-modify-path        别动我的 shell 配置
set -eu

# 双击运行时文件名以 .command 结尾，自动进入“装完切成可用终端”的模式
case "${0##*/}" in
  *.command) BILI_LAUNCHER=1 ;;
esac
export BILI_LAUNCHER="${BILI_LAUNCHER:-0}"

REPO="${BILI_REPO:-https://github.com/Zhiyi1207/bili-sub}"
BIN_DIR="${BILI_BIN:-}"
MODIFY_PATH=1
[ "${BILI_NO_MODIFY_PATH:-0}" = "1" ] && MODIFY_PATH=0
for a in "$@"; do
  case "$a" in
    --no-modify-path) MODIFY_PATH=0 ;;
    -h|--help)
      echo "用法: ./install.sh [--no-modify-path]"
      echo "  BILI_BIN=<目录>  指定安装位置（默认自动挑一个可写目录）"
      exit 0 ;;
  esac
done

say() { printf '%s\n' "$*"; }
die() { printf '❌ %s\n' "$*" >&2; exit 1; }

# ---------- 1. 检查 python3 ----------
command -v python3 >/dev/null 2>&1 \
  || die "没找到 python3。macOS 可以跑 xcode-select --install；Linux 用发行版自带的包"
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
  || die "python3 版本太老，需要 3.8 以上"

# ---------- 2. 找到 bili 本体 ----------
# curl | bash 时 BASH_SOURCE 为空，一律走下载，不会误用当前目录的文件
SELF="${BASH_SOURCE[0]:-}"
HERE=""
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
  HERE="$(cd "$(dirname "$SELF")" && pwd)"
fi

TMP=""
cleanup() { if [ -n "$TMP" ]; then rm -rf "$TMP"; fi; return 0; }
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
  die "需要 git 或 curl 其中一个才能下载"
fi

in_path() {
  case ":$PATH:" in
    *":$1:"*) return 0 ;;
  esac
  return 1
}

# ---------- 3. 挑安装目录 ----------
# 只装自己的目录：不碰 /usr/local/bin（要 sudo）、也不碰 /opt/homebrew/bin（那是 brew 的地盘）
[ -n "$BIN_DIR" ] || BIN_DIR="$HOME/.local/bin"

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

# 覆盖前先看装过没有。只打印，不询问、不拦截、不影响结果
ver_of() {
  if [ -x "$1" ]; then
    "$1" -v </dev/null 2>/dev/null
  else
    python3 "$1" -v </dev/null 2>/dev/null
  fi | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^v[0-9]/) { print $i; exit } }'
}
sha_of() {
  python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1" 2>/dev/null
}
OLD_VER=""
OLD_SHA=""
if [ -x "$BIN_DIR/bili" ]; then
  OLD_VER="$(ver_of "$BIN_DIR/bili")"
  OLD_SHA="$(sha_of "$BIN_DIR/bili")"
fi
NEW_VER="$(ver_of "$SRC")"
NEW_SHA="$(sha_of "$SRC")"

rm -f "$BIN_DIR/bili"
cp "$SRC" "$BIN_DIR/bili"
chmod 755 "$BIN_DIR/bili"

say "✅ 已装到：$BIN_DIR/bili"
if [ -n "$OLD_VER" ] && [ -n "$NEW_VER" ]; then
  if [ "$OLD_VER" != "$NEW_VER" ]; then
    say "   检测到已装 ${OLD_VER}，已升级到 ${NEW_VER}"
  elif [ "$OLD_SHA" != "$NEW_SHA" ]; then
    say "   检测到已装 ${OLD_VER}，同版本修正，已覆盖成最新的一版"
  else
    say "   检测到已装 ${OLD_VER}，同一个版本，重新覆盖了一遍"
  fi
fi

# ---------- 4. PATH ----------
MARK_BEGIN="# >>> bili-sub >>>"
MARK_END="# <<< bili-sub <<<"
case "$BIN_DIR" in
  "$HOME"/*) EXPORT_LINE="export PATH=\"\$HOME${BIN_DIR#$HOME}:\$PATH\"" ;;
  *)         EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

add_to_profile() {
  # $1 = rc 文件, $2 = 要写进去的那行
  rc="$1"; line="$2"
  replaced=0
  if [ -f "$rc" ] && grep -qF "$MARK_BEGIN" "$rc" 2>/dev/null; then
    cur="$(awk -v a="$MARK_BEGIN" -v b="$MARK_END" '$0==a{f=1;next} $0==b{f=0} f' "$rc" | head -1)"
    if [ "$cur" = "$line" ]; then
      say "   $rc 里的配置已经是对的，跳过"
      return 0
    fi
    awk -v a="$MARK_BEGIN" -v b="$MARK_END" '$0==a{skip=1;next} $0==b{skip=0;next} !skip{print}' \
      "$rc" > "$rc.tmp.$$" && mv "$rc.tmp.$$" "$rc" || die "改不动 $rc"
    replaced=1
    say "   旧配置指向了别处，已替换成：$line"
  fi
  if [ "$replaced" = "0" ]; then
    if [ ! -f "$rc" ]; then
      : > "$rc" 2>/dev/null || return 1
    fi
  fi
  {
    printf '\n%s\n' "$MARK_BEGIN"
    printf '%s\n' "$line"
    printf '%s\n' "$MARK_END"
  } >> "$rc" || die "写不进 $rc"
  CHANGED_RC="$rc"
}

# 先算清楚该改哪个 shell 配置文件（即使用不到，后面提示也要用）
case "${SHELL:-}" in
  *fish) PROFILE="$HOME/.config/fish/config.fish" ;;
  *zsh)  PROFILE="$HOME/.zshrc" ;;
  *bash)
    # macOS 的 bash 登录终端读 .bash_profile / .profile，不读 .bashrc
    if [ -f "$HOME/.bash_profile" ]; then
      PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.profile" ]; then
      PROFILE="$HOME/.profile"
    else
      PROFILE="$HOME/.bashrc"
    fi ;;
  *)
    if [ -f "$HOME/.zshrc" ]; then PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.bash_profile" ]; then PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.profile" ]; then PROFILE="$HOME/.profile"
    else PROFILE="$HOME/.bashrc"; fi ;;
esac

CHANGED_RC=""
if in_path "$BIN_DIR"; then
  say "   PATH 里已经有了，不用改配置"
elif [ "$MODIFY_PATH" = "1" ]; then
  case "$PROFILE" in
    *fish) add_to_profile "$PROFILE" "fish_add_path $BIN_DIR" || PROFILE="" ;;
    *)     add_to_profile "$PROFILE" "$EXPORT_LINE" || PROFILE="" ;;
  esac
  if [ -n "$PROFILE" ] && [ -n "$CHANGED_RC" ]; then
    say "   已把 PATH 写进：${CHANGED_RC}"
    if [ "${BILI_LAUNCHER:-0}" != "1" ]; then
      say "   重开终端，或者先跑一句：source \"$CHANGED_RC\""
    fi
  fi
else
  say "   按你的要求没动 shell 配置。要让命令生效，把这行加到 ~/.zshrc 或 ~/.bashrc："
  say "   $EXPORT_LINE"
fi

# ---------- 5. 自检 ----------
if "$BIN_DIR/bili" -v >/dev/null 2>&1; then
  say "   自检通过：$("$BIN_DIR/bili" -v)"
else
  say "   ⚠️ 自检没通过，跑一下 \"$BIN_DIR/bili\" -v 看看报什么错"
fi

# 当前窗口认不认识 bili？认到的是不是刚装的这个？
found="$(command -v bili 2>/dev/null || true)"
if [ -z "$found" ] && [ "${BILI_LAUNCHER:-0}" = "1" ]; then
  say ""
  say "👉 装好了。这个窗口可以直接关掉（不会弹提示），新开一个终端就能敲 bili。"
elif [ -z "$found" ]; then
  say ""
  say "👉 现在这个窗口还敲不出 bili，这是正常的：PATH 只在开终端时读一次。"
  say "   做下面任意一件就行："
  say "   1) 关掉这个窗口，重新开一个终端；"
  if [ -n "${PROFILE:-}" ]; then
    say "   2) 或者在这里运行：source \"$PROFILE\""
  fi
  say "   3) 或者先用完整路径：\"$BIN_DIR/bili\" help"
elif [ "$found" != "$BIN_DIR/bili" ]; then
  say ""
  say "⚠️  你的 PATH 里先找到的是另一个 bili：$found"
  say "   刚装好的是：$BIN_DIR/bili"
  say "   把旧的那个删掉（rm \"$found\"），或者把它从 PATH 里去掉，再重开终端。"
fi

say ""
say "下一步：新开一个终端，敲 bili help"
say "要登录态的话：bili setcookie"
say "卸载方法：bili status 底部会写出要删的文件"

