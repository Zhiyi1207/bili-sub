#!/usr/bin/env bash
# 双击运行的安装入口：会打开一个终端窗口，跑完停住，方便看结果。
set -eu
cd "$(dirname "$0")"

echo "bili-sub 安装"
echo

if [ -f "./install.sh" ]; then
  bash ./install.sh "$@"
else
  curl -fsSL https://raw.githubusercontent.com/Zhiyi1207/bili-sub/main/install.sh | bash
fi

echo
printf '安装结束，按任意键关掉这个窗口…'
read -n 1 -s -r || true
echo
