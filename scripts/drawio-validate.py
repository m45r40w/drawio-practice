#!/usr/bin/env python3
""".drawio ファイルの構造とルールをチェックする。

  python3 scripts/drawio-validate.py a.drawio [b.drawio ...]

ERROR があると終了コード 1。WARN は表示のみ。
チェック内容:
  - XML として読めるか / 必須セル (id=0, id=1) があるか
  - id の重複、parent・source・target の参照先が存在するか
  - 矢印がつなぎ先を持っているか (source/target 未指定は WARN)
  - 文字を持つすべての要素に fontFamily があるか (ルール: 各要素に明示)
  - 同じ親の中で、矢印が図形より先に書かれているか (ルール: 矢印は最背面)
  - whiteSpace=wrap の要素で、文字が幅に収まりそうか (日本語は 1 文字 = fontSize で概算)
"""
import base64
import re
import sys
import unicodedata
import urllib.parse
import xml.etree.ElementTree as ET
import zlib


def parse_style(s):
    out = {}
    for part in (s or "").split(";"):
        if not part:
            continue
        k, _, v = part.partition("=")
        out[k] = v if _ else ""
    return out


def plain_text(value):
    v = re.sub(r"<br\s*/?>", "\n", value or "", flags=re.I)
    return re.sub(r"<[^>]+>", "", v)


def text_width(line, font_size):
    w = 0.0
    for ch in line:
        w += font_size if unicodedata.east_asian_width(ch) in ("W", "F") else font_size * 0.6
    return w


def load_models(path):
    root = ET.parse(path).getroot()
    if root.tag == "mxGraphModel":
        return [("(no page)", root)]
    models = []
    for d in root.iter("diagram"):
        m = d.find("mxGraphModel")
        if m is None and (d.text or "").strip():  # 圧縮形式
            raw = zlib.decompress(base64.b64decode(d.text.strip()), -15).decode()
            m = ET.fromstring(urllib.parse.unquote(raw))
        if m is not None:
            models.append((d.get("name") or d.get("id"), m))
    return models


def check(path):
    errors, warns = [], []
    try:
        models = load_models(path)
    except Exception as e:  # noqa: BLE001
        return [f"cannot parse: {e}"], []
    if not models:
        return ["no <diagram>/<mxGraphModel> found"], []

    for page, model in models:
        p = f"[{page}]"
        rootel = model.find("root")
        if rootel is None:
            errors.append(f"{p} <root> missing")
            continue
        cells = list(rootel)
        ids = {}
        for c in cells:
            i = c.get("id")
            if i in ids:
                errors.append(f"{p} duplicate id: {i}")
            ids[i] = c
        if "0" not in ids or "1" not in ids:
            errors.append(f'{p} cells id="0" and id="1" are required')
        if not model.get("defaultFontFamily"):
            warns.append(f"{p} mxGraphModel has no defaultFontFamily")

        order = {}  # parent -> list of ("edge"|"vertex", id)
        for c in cells:
            i, parent = c.get("id"), c.get("parent")
            if i == "0":
                continue
            if parent not in ids:
                errors.append(f"{p} {i}: parent '{parent}' not found")
            is_edge = c.get("edge") == "1"
            if is_edge:
                for end in ("source", "target"):
                    ref = c.get(end)
                    if ref is None:
                        warns.append(f"{p} {i}: edge has no {end} (not connected)")
                    elif ref not in ids:
                        errors.append(f"{p} {i}: {end} '{ref}' not found")
            if is_edge or c.get("vertex") == "1":
                order.setdefault(parent, []).append(("edge" if is_edge else "vertex", i))

            style = parse_style(c.get("style"))
            text = plain_text(c.get("value"))
            if text.strip() and "fontFamily" not in style:
                errors.append(f"{p} {i}: text element without fontFamily ({text.strip()[:20]!r})")

            if c.get("vertex") == "1" and text.strip() and style.get("whiteSpace") == "wrap":
                g = c.find("mxGeometry")
                if g is not None and g.get("width"):
                    fs = float(style.get("fontSize", 12))
                    need = max(text_width(line, fs) for line in text.split("\n"))
                    have = float(g.get("width")) - 8
                    if need > have and "shape=mxgraph.aws4.group" not in (c.get("style") or ""):
                        warns.append(f"{p} {i}: text may wrap (needs ~{need:.0f}px, width {have + 8:.0f}px)")

        for parent, items in order.items():
            first_vertex = next((n for n, (k, _) in enumerate(items) if k == "vertex"), None)
            if first_vertex is None:
                continue
            late = [i for k, i in items[first_vertex:] if k == "edge"]
            if late:
                errors.append(f"{p} edges must come before vertices under parent '{parent}' (z-order): {', '.join(late)}")
    return errors, warns


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    failed = False
    for path in argv[1:]:
        errors, warns = check(path)
        for w in warns:
            print(f"WARN  {path}: {w}")
        for e in errors:
            print(f"ERROR {path}: {e}")
        if errors:
            failed = True
        else:
            print(f"OK    {path}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
