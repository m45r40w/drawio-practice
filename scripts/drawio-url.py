#!/usr/bin/env python3
""".drawio ファイルから、app.diagrams.net でそのまま開ける URL を作る。

  python3 scripts/drawio-url.py a.drawio           # URL を表示
  python3 scripts/drawio-url.py a.drawio -o a.url  # ファイルに書き出す

形式: https://app.diagrams.net/#R + base64(raw deflate(encodeURIComponent(xml)))
"""
import base64
import sys
import urllib.parse
import zlib


def to_url(xml: str) -> str:
    c = zlib.compressobj(9, zlib.DEFLATED, -15)
    raw = c.compress(urllib.parse.quote(xml, safe="-_.!~*'()").encode()) + c.flush()
    return "https://app.diagrams.net/#R" + base64.b64encode(raw).decode()


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    url = to_url(open(argv[1], encoding="utf-8").read())
    if len(argv) >= 4 and argv[2] == "-o":
        with open(argv[3], "w", encoding="utf-8") as f:
            f.write(url + "\n")
    else:
        print(url)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
