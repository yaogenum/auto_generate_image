import fs from 'fs/promises';
import path from 'path';
import crypto from 'crypto';
import { execSync } from 'child_process';

const ROOT = process.cwd();
const sourceDir = path.join(ROOT, 'images', 'source');
const metadataPath = path.join(ROOT, 'images', '素材元数据.json');
const htmlPath = path.join(ROOT, 'images', 'source', 'tokyo_assets.html');

const TARGETS = [
  { city: '东京', en: 'Tokyo', minimum: 20 },
  { city: '大阪', en: 'Osaka', minimum: 8 },
  { city: '京都', en: 'Kyoto', minimum: 4 },
{ city: '名古屋', en: 'Nagoya', minimum: 3 },
  { city: '札幌', en: 'Sapporo', minimum: 3 },
  { city: '横滨', en: 'Yokohama', minimum: 3 },
  { city: '福冈', en: 'Fukuoka', minimum: 2 },
  { city: '神户', en: 'Kobe', minimum: 2 },
  { city: '广岛', en: 'Hiroshima', minimum: 2 },
  { city: '仙台', en: 'Sendai', minimum: 2 },
  { city: '香港', en: 'Hong Kong', minimum: 2 },
  { city: '新加坡', en: 'Singapore', minimum: 2 },
];

const SCENES = ['城市地标', '旅行热点', '花火大会', '夜景', '美食街景', '购物街景', '营销宣传'];
const WIKI_API = 'https://commons.wikimedia.org/w/api.php';

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function cityFromScene(scene = '') {
  if (!scene) return '日本其他';
  if (scene.includes(' · ')) return scene.split(' · ')[0].trim();
  const cities = TARGETS.map((i) => i.city);
  for (const c of cities) {
    if (scene.includes(c)) return c;
  }
  return '日本其他';
}

function getDimensions(filePath) {
  try {
    const out = execSync(`sips -g pixelWidth -g pixelHeight ${JSON.stringify(filePath)}`).toString();
    const w = out.match(/pixelWidth:\s*(\d+)/)?.[1];
    const h = out.match(/pixelHeight:\s*(\d+)/)?.[1];
    if (w && h) return `${w}x${h}`;
  } catch {}
  return '原图';
}

function sceneFor(city, i) {
  return `${city} · ${SCENES[i % SCENES.length]}`;
}

function featureFor(scene) {
  return scene.includes('花火大会') ? '花火夜景,节庆营销' : '城市旅行,营销宣传';
}

async function readMetadata() {
  try {
    const raw = await fs.readFile(metadataPath, 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed?.items) ? parsed.items : [];
  } catch {
    return [];
  }
}

function cityCounts(items) {
  const map = new Map();
  for (const item of items) {
    const c = cityFromScene(item['场景']);
    map.set(c, (map.get(c) || 0) + 1);
  }
  return map;
}

async function buildHashSet(items) {
  const set = new Set();
  for (const it of items) {
    const p = (it['本地文件'] || `./${it['图片名称']}`).replace(/^\.\//, '');
    const f = path.join(sourceDir, p);
    try {
      set.add(sha256(await fs.readFile(f)));
    } catch {}
  }
  return set;
}

async function queryImageUrls(cityEn, queryWord, limit = 40) {
  const q = `${cityEn} ${queryWord} japan`;
  const url = `${WIKI_API}?action=query&generator=search&gsrsearch=${encodeURIComponent(q)}&gsrnamespace=6&gsrlimit=${limit}&prop=imageinfo&iiprop=url&format=json&origin=*`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  const res = await fetch(url, { signal: controller.signal });
  clearTimeout(timeout);

  if (!res.ok) throw new Error(`wiki_api_${res.status}`);

  const payload = await res.json();
  const pages = payload?.query?.pages || {};
  return Object.values(pages)
    .map((p) => ({
      url: p?.imageinfo?.[0]?.url || '',
      source: `https://commons.wikimedia.org/wiki/${encodeURIComponent((p.title || '').replace(/ /g, '_'))}`,
    }))
    .filter((x) => x.url && x.url.includes('upload.wikimedia.org') && /\.(jpg|jpeg|png|webp|JPG|JPEG|PNG|WEBP)$/.test(x.url));
}

function shuffle(arr) {
  const out = [...arr];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

async function downloadImage(srcUrl) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const res = await fetch(srcUrl, { signal: controller.signal, redirect: 'follow' });
    if (!res.ok) throw new Error(`download_${res.status}`);
    const ctype = (res.headers.get('content-type') || '').toLowerCase();
    if (!ctype.startsWith('image/')) throw new Error(`ctype_${ctype}`);

    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length) throw new Error('empty');

    const nameBase = path.basename(new URL(srcUrl).pathname).replace(/[^a-zA-Z0-9._-]/g, '_').slice(0, 120);
    const suffix = nameBase && nameBase.includes('.') ? '' : '.jpg';
    const fileName = `${Date.now()}_${Math.random().toString(36).slice(2, 8)}_${nameBase}${suffix}`.replace(/_\.jpg$/, '.jpg');
    const filePath = path.join(sourceDir, fileName);

    await fs.writeFile(filePath, buf);
    return { fileName, filePath, finalUrl: res.url || srcUrl, buf, remote: srcUrl };
  } finally {
    clearTimeout(timeout);
  }
}

function pickReplaceIndex(items, counts, mins) {
  const targetCityOrder = TARGETS.map((x) => x.city);
  for (let idx = items.length - 1; idx >= 0; idx--) {
    const c = cityFromScene(items[idx]['场景']);
    const min = mins[c] || 0;
    if ((counts.get(c) || 0) > min) return idx;
    if (!targetCityOrder.includes(c) && idx > 20) return idx;
  }
  return items.length - 1;
}

async function main() {
  const itemsRaw = await readMetadata();
  let items = [...itemsRaw];

  const counts = cityCounts(items);
  const hashSet = await buildHashSet(items);
  const minimumByCity = Object.fromEntries(TARGETS.map((i) => [i.city, i.minimum]));

  let added = 0;

  for (let i = 0; i < TARGETS.length; i++) {
    const target = TARGETS[i];
    const current = counts.get(target.city) || 0;
    let need = Math.max(0, target.minimum - current);
    if (!need) continue;

    const queries = [target.en, `${target.en} landmark`, `${target.en} travel`, `${target.en} festival`, `${target.en} city`];
    const urls = [];
    for (const q of queries) {
      try {
        const hit = await queryImageUrls(target.en, q, 50);
        urls.push(...hit.map((x) => x.url));
      } catch {}
    }
    const urlPool = shuffle(Array.from(new Set(urls)));

    for (let n = 0; n < need && urlPool.length; n++) {
      const remote = urlPool.shift();
      let downloaded;
      try {
        downloaded = await downloadImage(remote);
      } catch {
        continue;
      }

      const h = sha256(downloaded.buf);
      if (hashSet.has(h)) {
        await fs.unlink(downloaded.filePath);
        continue;
      }

      const scene = sceneFor(target.city, n);
      const item = {
        图片名称: downloaded.fileName,
        场景: scene,
        特点: featureFor(scene),
        尺寸: getDimensions(downloaded.filePath),
        来源: 'Wikimedia Commons',
        来源页面: `https://commons.wikimedia.org/wiki/Special:Redirect/file/${encodeURIComponent(downloaded.fileName)}`,
        图片URL: `./${downloaded.fileName}`,
        本地文件: `./${downloaded.fileName}`,
      };

      hashSet.add(h);

      const activeCounts = cityCounts(items);
      if (items.length >= 100) {
        const idx = pickReplaceIndex(items, activeCounts, minimumByCity);
        const removed = items.splice(idx, 1)[0];
        if (removed?.['来源'] !== '本地素材') {
          const rp = removed?.['本地文件']?.replace(/^\.\//, '');
          if (rp) await fs.unlink(path.join(sourceDir, rp)).catch(() => {});
        }
      }

      items.push(item);
      added += 1;
      counts.set(target.city, (counts.get(target.city) || 0) + 1);
    }
  }

  const finalItems = items.slice(-100).map((item, idx) => ({ ...item, 序号: idx + 1 }));

  await fs.writeFile(metadataPath, JSON.stringify({
    generatedAt: new Date().toISOString(),
    total: finalItems.length,
    note: '日本TOP10+港新素材库（Wikimedia补充，原图本地存储）',
    items: finalItems,
  }, null, 2), 'utf8');

  const cards = finalItems
    .map((item, idx) => {
      return `      <figure>\n        <img src="${item['图片URL']}" alt="素材${idx + 1}" loading="lazy"/>\n        <figcaption>\n          <strong>#${idx + 1} ${item['图片名称']}</strong><br/>\n          <span>场景：${item['场景']}</span><br/>\n          <span>特点：${item['特点']}</span><br/>\n          <span>尺寸：${item['尺寸']}</span><br/>\n          <span>来源：${item['来源']}</span><br/>\n          <span>图片URL：${item['图片URL']}</span><br/>\n          <span>来源页面：${item['来源页面']}</span>\n        </figcaption>\n      </figure>`;
    })
    .join('\n');

  const countsFinal = cityCounts(finalItems);
  const html = `<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n<meta charset=\"utf-8\"/>\n<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>\n<title>素材库</title>\n<style>body{font-family:Arial,Helvetica,sans-serif;margin:0;background:#090d1a;color:#e2e8f0;padding:20px;}h1{margin:0 0 10px;} .meta{color:#94a3b8;margin-bottom:14px;} .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px;} figure{margin:0;background:#111827;border:1px solid #1f2937;border-radius:10px;overflow:hidden;} img{width:100%;height:190px;object-fit:cover;display:block;background:#0b1120;} figcaption{font-size:12px;padding:8px;line-height:1.45;color:#cbd5e1;}strong{color:#38bdf8;} </style>\n</head>\n<body>\n  <h1>东京/日本TOP城市素材库（含香港、新加坡）</h1>\n  <div class=\"meta\">共 ${finalItems.length} 张，全部本地图片，点击浏览器可直接预览</div>\n  <section class=\"grid\">\n${cards}\n  </section>\n</body>\n</html>`;

  await fs.writeFile(htmlPath, html, 'utf8');

  console.log(JSON.stringify({
    status: 'ok',
    total: finalItems.length,
    added,
    counts: Object.fromEntries(TARGETS.map((x) => [x.city, countsFinal.get(x.city) || 0])),
  }));
}

main().catch(async (e) => {
  console.error(e);
  process.exit(1);
});
