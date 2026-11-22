#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""离线测试：不联网，把假数据喂给 bili 里的函数，检查逻辑对不对。

跑法：python3 tests/offline_test.py
"""

import contextlib
import importlib.machinery
import importlib.util
import io
import json
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

print("— 风控处理 —")


class _Resp:
    def __init__(self, payload):
        self.payload = payload

    def read(self):
        return json.dumps(self.payload).encode()

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


_real_urlopen = b.urllib.request.urlopen
b.REQ_GAP = 0
b.BLOCK_WAIT = 0
b.RETRY = 1
b.urllib.request.urlopen = lambda req, timeout=0: _Resp({"code": -352, "message": "风控"})
try:
    with contextlib.redirect_stdout(io.StringIO()):
        b.http_json("https://api.bilibili.com/x/test")
    got = "没报错"
except RuntimeError as e:
    got = str(e)
check("风控会被拦下并说清原因", "风控" in got, True)

b.RETRY = 0
b.urllib.request.urlopen = lambda req, timeout=0: _Resp({"code": 0, "data": {"ok": 1}})
check("正常返回原样给出", b.http_json("https://api.bilibili.com/x/test"), {"code": 0, "data": {"ok": 1}})
b.urllib.request.urlopen = _real_urlopen

print("— 已下载判定 —")
tmp = tempfile.mkdtemp()
path = os.path.join(tmp, "up", "标题.txt")
check("没有文件 → None", b.existing(path, "https://x"), None)
os.makedirs(os.path.dirname(path), exist_ok=True)
open(path, "w", encoding="utf-8").write("- 链接：https://x\n")
check("链接一致 → same", b.existing(path, "https://x"), "same")
check("链接不一致 → other", b.existing(path, "https://y"), "other")
open(os.path.join(tmp, "up", "旧的.srt"), "w").close()
check("老 srt 不再参与判断", b.existing(os.path.join(tmp, "up", "旧的.txt"), "https://x"), None)

print("— 文件名与路径 —")
check("非法字符被替换", b.clean('a/b:c*d?"e'), "a_b_c_d__e")
check("超长被截断", len(b.clean("字" * 200)), 60)
check("短标题原样用", b.short_name("标题"), "标题")
check("刚好 10 个字不截", b.short_name("一二三四五六七八九十"), "一二三四五六七八九十")
check("超过 10 个字加省略号", b.short_name("一二三四五六七八九十十一"), "一二三四五六七八九十…")
check("长标题也只留 11 个字符", len(b.short_name("字" * 100)), 11)
check("文件名里的非法字符照样处理", b.short_name('a/b:c'), "a_b_c")
check("普通链接不做跳转", b.resolve_url("https://www.bilibili.com/video/BV1xx411c7mD"),
      "https://www.bilibili.com/video/BV1xx411c7mD")
check("链接里的 p 认得出", b.page_of("https://www.bilibili.com/video/BV1xx411c7mD?p=3"), "3")
home = os.path.expanduser("~")
check("家目录缩成 ~", b.pretty(os.path.join(home, "x")), "~/x")
check("可粘贴路径带引号", b.shell_path(os.path.join(home, "a b")).startswith('"$HOME/'), True)

print("— 参数解析 —")
urls, out, psel, force, delay = b.parse(["--delay", "1.5", "--force", "BV1xxxxxxxxx"])
check("--delay 生效", delay, 1.5)
check("--force 生效", force, True)
check("链接被收下", urls, ["BV1xxxxxxxxx"])

print("— 下载落盘 —")
out2 = tempfile.mkdtemp(dir=tmp)
fake = {"aid": 1, "bvid": "BV1xx411c7mD", "title": "某个视频标题", "up": "某个UP主",
        "pubdate": 0, "duration": 100, "pages": [{"page": 1, "cid": 1, "part": ""}]}
b.video = lambda pair: fake
b.subtitles = lambda aid, cid: [{"lan": "ai-zh", "subtitle_url": "https://example.invalid"}]
b.body_of = lambda sub: [{"from": 0, "to": 100, "content": "一句话"}]
with contextlib.redirect_stdout(io.StringIO()):
    code = b.run(["-o", out2, "BV1xx411c7mD"])
check("第一次下载成功", code, 0)
vdir = os.path.join(out2, "某个UP主")
check("不再有视频文件夹", os.path.isdir(os.path.join(vdir, "某个视频标题")), False)
check("只有一个 txt", sorted(os.listdir(vdir)), ["某个视频标题.txt"])
with contextlib.redirect_stdout(io.StringIO()):
    code = b.run(["-o", out2, "BV1xx411c7mD"])
check("第二次自动跳过", code, 0)
check("没有重复下载", len(os.listdir(vdir)), 1)

out3 = tempfile.mkdtemp(dir=tmp)
b.video = lambda pair: dict(fake, title="一二三四五六七八九十甲乙")
with contextlib.redirect_stdout(io.StringIO()):
    b.run(["-o", out3, "BV1xx411c7mD"])
check("长标题只留前 10 字 + 省略号", os.listdir(os.path.join(out3, "某个UP主")),
      ["一二三四五六七八九十….txt"])

out4 = tempfile.mkdtemp(dir=tmp)
b.video = lambda pair: dict(fake, title="多集视频",
                            pages=[{"page": 1, "cid": 1, "part": "一"},
                                   {"page": 2, "cid": 2, "part": "二"}])
with contextlib.redirect_stdout(io.StringIO()):
    b.run(["-o", out4, "BV1xx411c7mD"])
check("分P 文件名带 P 号", sorted(os.listdir(os.path.join(out4, "某个UP主"))),
      ["多集视频.p01.txt", "多集视频.p02.txt"])

out5 = tempfile.mkdtemp(dir=tmp)
b.video = lambda pair: dict(fake)
with contextlib.redirect_stdout(io.StringIO()):
    b.run(["-o", out5, "BV1xx411c7mD"])
b.video = lambda pair: dict(fake, bvid="BV1yy411c7mD")
with contextlib.redirect_stdout(io.StringIO()):
    b.run(["-o", out5, "BV1yy411c7mD"])
check("同名不同视频另存", sorted(os.listdir(os.path.join(out5, "某个UP主"))),
      ["某个视频标题.BV1yy411c7mD.txt", "某个视频标题.txt"])

out6 = tempfile.mkdtemp(dir=tmp)
b.subtitles = lambda aid, cid: []
b.cookie = lambda: "SESSDATA=x"
b.login_state = lambda: False
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    code = b.run(["-o", out6, "BV1xx411c7mD"])
check("cookie 失效时说清是登录问题", "SESSDATA 已失效" in buf.getvalue(), True)
check("cookie 失效时算失败", code, 1)

shutil.rmtree(tmp, ignore_errors=True)

print(f"\n共 {count} 项，失败 {len(fails)} 项")
if fails:
    print("失败项：" + "、".join(fails))
    sys.exit(1)
