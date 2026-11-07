#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""离线测试：不联网，把假数据喂给 bili 里的函数，检查逻辑对不对。

跑法：python3 tests/offline_test.py
"""

import importlib.machinery
import importlib.util
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
BILLI = os.path.join(HERE, os.pardir, "bili")
spec = importlib.util.spec_from_loader("bilisub", importlib.machinery.SourceFileLoader("bilisub", BILLI))
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

fails = []
count = 0


def check(name, got, want):
    global count
    count += 1
    if got == want:
        print(f"✅ {name}")
    else:
        print(f"❌ {name}\n   得到：{got!r}\n   期望：{want!r}")
        fails.append(name)


def lan(subs):
    s = b.pick(subs)
    return s["lan"] if s else None


print("— 选字幕优先级 —")
check("只有中英 AI → 取中文", lan([{"lan": "ai-zh"}, {"lan": "ai-en"}]), "ai-zh")
check("英文原 + 中文 AI → 取中文 AI", lan([{"lan": "ai-zh"}, {"lan": "en-US"}]), "ai-zh")
check("中文原 + 中文 AI → 取原字幕", lan([{"lan": "ai-zh"}, {"lan": "zh-Hans"}]), "zh-Hans")
check("繁体原 + 英文原 → 取繁体", lan([{"lan": "en-US"}, {"lan": "zh-Hant"}]), "zh-Hant")
check("英文原 + 英文 AI → 取原字幕", lan([{"lan": "ai-en"}, {"lan": "en-US"}]), "en-US")
check("只有英文原 → 取英文", lan([{"lan": "en-US"}]), "en-US")
check("只有英文 AI → 取它", lan([{"lan": "ai-en"}]), "ai-en")
check("没有字幕 → None", lan([]), None)

print("— 完整性判定 —")
body = [{"from": 0, "to": 7.0, "content": "a"}]
check("空内容 → fail", b.check([], 100)[0], "fail")
check("被截断（100/469 秒）→ fail", b.check(body * 1, 469)[0], "fail")
check("差 15 秒 → warn", b.check([{"from": 0, "to": 85, "content": "a"}], 100)[0], "warn")
check("覆盖到结尾 → 通过", b.check([{"from": 0, "to": 99, "content": "a"}], 100)[0], None)
check("没有时长信息 → 不判", b.check(body, 0)[0], None)

print("— SRT 格式 —")
srt = b.to_srt([{"from": 0, "to": 1.5, "content": "第一句"},
                {"from": 1.5, "to": 3.0, "content": "第二句"}])
check("两条字幕的序号", srt.count("-->"), 2)
check("时间戳格式", "00:00:01,500 --> 00:00:03,000" in srt, True)
check("正文在里面", "第二句" in srt, True)

print("— TXT 格式 —")
meta = {"title": "标题", "up": "某UP", "url": "https://www.bilibili.com/video/BV1xxx",
        "pub": "2026-11-06 09:30", "dur": "01:00", "kind": "AI 字幕", "lan": "ai-zh"}
txt = b.to_txt([{"from": 0, "to": 1, "content": "一"},
                {"from": 1, "to": 2, "content": "二"},
                {"from": 30, "to": 31, "content": "三"}], meta)
check("带 UP 主", "- UP 主：某UP" in txt, True)
check("带链接", "- 链接：https://www.bilibili.com/video/BV1xxx" in txt, True)
check("带发布时间", "- 发布时间：2026-11-06 09:30" in txt, True)
check("正文分段（停顿处断开）", txt.count("\n\n") >= 3, True)

print("— 已下载判定 —")
tmp = tempfile.mkdtemp()
base = os.path.join(tmp, "up", "标题.ai-zh")
check("没有文件 → None", b.existing(base, "https://x"), None)
os.makedirs(os.path.dirname(base), exist_ok=True)
open(base + ".srt", "w").close()
check("只有 srt → partial", b.existing(base, "https://x"), "partial")
open(base + ".txt", "w", encoding="utf-8").write("- 链接：https://x\n")
check("srt+txt 链接一致 → same", b.existing(base, "https://x"), "same")
check("srt+txt 链接不一致 → other", b.existing(base, "https://y"), "other")

print("— 文件名与路径 —")
check("非法字符被替换", b.clean('a/b:c*d?"e'), "a_b_c_d__e")
check("超长被截断", len(b.clean("字" * 200)), 60)
check("视频文件夹名截短到 16", len(b.video_folder("字" * 100)), 16)
check("短标题原样用", b.video_folder("标题"), "标题")
check("分P 文件夹带 P 号", b.video_folder("标题", 3), "标题.p03")
home = os.path.expanduser("~")
check("家目录缩成 ~", b.pretty(os.path.join(home, "x")), "~/x")
check("可粘贴路径带引号", b.shell_path(os.path.join(home, "a b")).startswith('"$HOME/'), True)

print("— 参数解析 —")
urls, out, psel, force, delay = b.parse(["--delay", "1.5", "--force", "BV1xxxxxxxxx"])
check("--delay 生效", delay, 1.5)
check("--force 生效", force, True)
check("链接被收下", urls, ["BV1xxxxxxxxx"])

shutil.rmtree(tmp, ignore_errors=True)

print(f"\n共 {count} 项，失败 {len(fails)} 项")
if fails:
    print("失败项：" + "、".join(fails))
    sys.exit(1)
