#!/usr/bin/env node
// .drawio を PNG に変換する（draw.io 公式ビューア + ヘッドレス Chromium）。
// 外部への通信はすべて遮断し、ビューアのファイルは $DRAWIO_VIEWER_DIR から読み込む。
//
//   node scripts/drawio-render.js input.drawio [output.png] [--scale 2] [--page 0] [--transparent]
//
// 出力先を省略すると input.drawio.png に書き出す。
// 事前に scripts/setup-drawio-viewer.sh でビューアを用意しておくこと。
'use strict';
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = { scale: 2, page: 0, transparent: false };
const files = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === '--scale') opt.scale = Number(args[++i]);
  else if (a === '--page') opt.page = Number(args[++i]);
  else if (a === '--transparent') opt.transparent = true;
  else if (a === '-h' || a === '--help') { console.log(fs.readFileSync(__filename, 'utf8').split('\n').slice(1, 8).join('\n')); process.exit(0); }
  else files.push(a);
}
if (files.length < 1) { console.error('usage: drawio-render.js input.drawio [output.png] [--scale 2] [--page 0] [--transparent]'); process.exit(2); }
const input = path.resolve(files[0]);
const output = path.resolve(files[1] || files[0] + '.png');

const VIEWER_DIR = process.env.DRAWIO_VIEWER_DIR || '/opt/drawio-viewer';
if (!fs.existsSync(path.join(VIEWER_DIR, 'js', 'viewer-static.min.js'))) {
  console.error(`drawio viewer not found in ${VIEWER_DIR}. Run: bash scripts/setup-drawio-viewer.sh`);
  process.exit(3);
}

let chromium;
try { ({ chromium } = require('playwright')); }
catch (e) { console.error('playwright is not available: ' + e.message); process.exit(3); }

const BASE = 'http://drawio.local';
const TYPES = { '.js': 'application/javascript', '.xml': 'application/xml', '.png': 'image/png', '.svg': 'image/svg+xml', '.gif': 'image/gif', '.css': 'text/css', '.html': 'text/html', '.txt': 'text/plain' };

const PAGE_HTML = `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:${opt.transparent ? 'transparent' : '#ffffff'}} #c{position:relative}</style>
<script>
  window.DRAWIO_BASE_URL='${BASE}'; window.DRAWIO_VIEWER_URL='${BASE}/js/viewer-static.min.js';
  window.STENCIL_PATH='${BASE}/stencils'; window.SHAPES_PATH='${BASE}/shapes';
  window.IMAGE_PATH='${BASE}/images'; window.GRAPH_IMAGE_PATH='${BASE}/img';
  window.STYLE_PATH='${BASE}/styles'; window.mxLoadResources=false; window.mxLoadStylesheets=false;
  window.DRAW_MATH_URL='${BASE}/math';
</script>
<script src="${BASE}/js/viewer-static.min.js"></script>
</head><body><div id="c"></div></body></html>`;

(async () => {
  const xml = fs.readFileSync(input, 'utf8');
  const browser = await chromium.launch();
  const blocked = new Set();
  try {
    const page = await browser.newPage({ deviceScaleFactor: opt.scale, viewport: { width: 1600, height: 1200 } });
    const errors = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await page.route('**/*', async (route) => {
      const url = route.request().url();
      if (url === BASE + '/' ) return route.fulfill({ contentType: 'text/html', body: PAGE_HTML });
      if (url.startsWith(BASE + '/')) {
        const rel = decodeURIComponent(new URL(url).pathname).replace(/^\/+/, '');
        const file = path.resolve(VIEWER_DIR, rel);
        if (file.startsWith(path.resolve(VIEWER_DIR) + path.sep) && fs.existsSync(file) && fs.statSync(file).isFile()) {
          return route.fulfill({ contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) });
        }
        return route.fulfill({ status: 404, body: '' });
      }
      if (url.startsWith('data:') || url.startsWith('blob:')) return route.continue();
      blocked.add(new URL(url).host);
      return route.abort();
    });
    await page.goto(BASE + '/', { waitUntil: 'load' });
    await page.waitForFunction(() => typeof window.GraphViewer === 'function', null, { timeout: 30000 });

    const info = await page.evaluate(({ xml, pageIndex }) => {
      const doc = mxUtils.parseXml(xml);
      const root = doc.documentElement;
      const pages = root.nodeName === 'mxfile' ? root.getElementsByTagName('diagram').length : 1;
      const container = document.getElementById('c');
      window.__viewer = new GraphViewer(container, root, { highlight: 'none', page: pageIndex });
      return { pages };
    }, { xml, pageIndex: opt.page });

    // 図形・フォントの読み込み完了を待つ
    await page.waitForLoadState('networkidle');
    await page.evaluate(() => document.fonts && document.fonts.ready);
    await page.waitForTimeout(300);

    // 図の範囲（余白 20px）だけを切り出す
    const box = await page.evaluate(() => {
      const g = window.__viewer.graph;
      const b = g.getGraphBounds();
      const r = g.container.getBoundingClientRect();
      const m = 20;
      return { x: Math.max(0, r.left + b.x - m), y: Math.max(0, r.top + b.y - m), width: b.width + 2 * m, height: b.height + 2 * m };
    });
    if (!(box.width > 2 * 20 && box.height > 2 * 20)) throw new Error('diagram is empty or failed to render');
    await page.setViewportSize({ width: Math.ceil(box.x + box.width) + 1, height: Math.ceil(box.y + box.height) + 1 });
    await page.screenshot({ path: output, clip: box, omitBackground: opt.transparent });
    if (errors.length) console.error('page errors:\n  ' + errors.join('\n  '));
    if (blocked.size) console.error('blocked external requests: ' + [...blocked].join(', '));
    console.log(`rendered ${path.relative(process.cwd(), input)} (page ${opt.page + 1}/${info.pages}) -> ${path.relative(process.cwd(), output)}`);
  } finally {
    await browser.close();
  }
})().catch((e) => { console.error(e.stack || String(e)); process.exit(1); });
