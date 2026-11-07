#!/usr/bin/env bash
# 双击运行的安装入口：会打开一个终端窗口，跑完停住，方便看结果。
set -eu
cd "$(dirname "$0")"

echo "bili-sub 安装"
echo

export BILI_LAUNCHER=1
if [ -f "./install.sh" ]; then
  bash ./install.sh "$@"
else
  curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
fi

# 装完把当前窗口直接换成一个新 shell：这样 PATH 已生效，回车就能用 bili
echo
echo "切换到一个可用的终端…"
exec "${SHELL:-/bin/zsh}" -i
