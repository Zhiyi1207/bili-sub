# bili-sub

只做一件事：把 B 站视频的字幕（原字幕或 AI 字幕）下载成 SRT 文件。

零第三方依赖，单文件 Python，不需要编译。

## 为什么重做一个

之前用的是 BBDown + 一层包装脚本。BBDown 已于 2026-05 归档，且它在字幕这块出了两个问题：

1. **下不全**：同一个视频，服务端明明有 259 条（0 → 7:46 全片），它两次分别只写出 30 条、12 条，退出码还是 0，看起来像成功。
2. **下错片**：某次它写出的文件是 581 条、到 13:20，内容跟目标视频毫无关系——抓到了别的视频的字幕。

这两个问题都无声无息。没有源码，我们连它错在哪都只能猜。所以重写成一版自己看得懂、改得动的。

## 环境

- Python 3.8+（macOS 自带、Linux 一般自带），不装任何第三方包
- 能访问 `api.bilibili.com` 和 `aisubtitle.hdslb.com`

## 安装

```bash
git clone <本仓库地址> ~/code/bili-sub
chmod +x ~/code/bili-sub/bili
ln -sf ~/code/bili-sub/bili /usr/local/bin/bili   # 或者任何在 PATH 里的目录
```

## 用法

```bash
bili BV1xxxxxxxxx                 # 单个视频（完整链接也行）
bili 链接1 链接2 链接3             # 多个
bili -f 列表.txt                  # 批量，每行一个链接，# 开头是注释
bili -p 3 BV1xxxxxxxxx            # 只下第 3 个分P
bili -o ~/字幕 BV1xxxxxxxxx       # 换输出根目录
bili status                       # 检查 cookie 还有没有效
bili setcookie                    # 设置/覆盖 cookie
```

输出结构：按 UP 主分目录，文件名带语言标记。

```
~/Downloads/B站字幕/
└── 某个UP主/
    ├── 视频标题.ai-zh.srt     # AI 字幕
    └── 视频标题.zh-CN.srt     # 原字幕（人工上传）
```

多分P 的视频，文件名会带 `.p01`、`.p02`。

## cookie（可选，但建议设置）

没登录也能拿到一部分 AI 字幕；原字幕、部分受限视频需要登录态。

1. Chrome 打开 `bilibili.com`，确认右上角是你自己的头像
2. `Cmd + Option + I` 打开开发者工具（Mac 上 F12 是音量键）
3. 「应用 / Application」→「Cookie」→ `https://www.bilibili.com`
4. 找到 `SESSDATA`，双击 Value 全选复制
5. 回来运行 `bili setcookie`，粘进去回车

cookie 存在 `~/.config/bili-sub/cookie`，权限 600，不会进仓库、不会上传。

## 完整性校验

这是重写的主要目的。抓到字幕内容后会做两道检查：

- 字幕条数不能是 0；
- 最后一条字幕的时间要覆盖到视频结尾（容差 10 秒）。

任一不通过就**报错并且不写文件**，不会留下一个"看起来成功"的残片。

## 已知限制

- 只下字幕，不下载视频/音频/弹幕/封面。
- 依赖 B 站非公开接口。接口改结构或加签名（wbi）时需要跟着改代码。
- 字幕文件的命名和内容由 B 站决定，AI 字幕会有识别错误。

## 许可

[MIT](LICENSE)：个人、商业都能免费用，也可以改、可以再发布。

唯一的要求是保留版权声明和许可声明。代码按"现状"提供，不承诺不出问题。

## 免责

仅供个人学习、备份自己需要的字幕使用。请遵守 B 站用户协议，不要用于大规模抓取或再分发。
