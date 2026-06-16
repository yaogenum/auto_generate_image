import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { execSync, execFileSync } from "node:child_process";

const ROOT = process.cwd();
const sourceDir = path.join(ROOT, "images", "source");
const metadataPath = path.join(ROOT, "images", "素材元数据.json");
const htmlPath = path.join(sourceDir, "tokyo_assets.html");

const TARGET_TOTAL = 100;
const USER_AGENT = "Mozilla/5.0 (compatible; Codex/1.0)";

const TARGETS = [
  { city: "大阪", query: "Osaka", minimum: 12, scenes: ["旅行热点", "地标", "夜景", "营销宣传"], feature: "城市旅行,地标营销,景点宣传" },
  { city: "名古屋", query: "Nagoya", minimum: 8, scenes: ["旅行热点", "地标", "商业区", "夜景"], feature: "日本城市旅行,名古屋地标,营销素材" },
  { city: "京都", query: "Kyoto", minimum: 8, scenes: ["旅行热点", "花火大会", "古都景观", "营销宣传"], feature: "历史文化,景点宣传,花火活动" },
  { city: "札幌", query: "Sapporo", minimum: 6, scenes: ["旅行热点", "雪景", "城市景观", "冬季旅游"], feature: "都市旅行,四季景观,本地推广" },
  { city: "横滨", query: "Yokohama", minimum: 6, scenes: ["旅行热点", "港湾夜景", "城市景观", "商务旅行"], feature: "港口地标,城市夜景,营销传播" },
  { city: "福冈", query: "Fukuoka", minimum: 6, scenes: ["旅行热点", "地标", "美食街景", "城市景观"], feature: "城市旅行,本地美食,景点宣传" },
  { city: "神户", query: "Kobe", minimum: 5, scenes: ["旅行热点", "港湾", "夜景", "商业街景"], feature: "港城景观,景点推广,营销素材" },
  { city: "广岛", query: "Hiroshima", minimum: 5, scenes: ["旅行热点", "地标", "历史景观", "城市景观"], feature: "文化景观,历史背景,城市推广" },
  { city: "仙台", query: "Sendai", minimum: 5, scenes: ["旅行热点", "城区景观", "地标", "季节风光"], feature: "地方旅游,景点推荐,营销素材" },
  { city: "香港", query: "Hong Kong", minimum: 3, scenes: ["旅行热点", "城市景观", "夜景", "营销宣传"], feature: "都市旅游,地标营销,景点传播" },
  { city: "新加坡", query: "Singapore", minimum: 3, scenes: ["旅行热点", "城市夜景", "商业街景", "营销宣传"], feature: "城市旅游,景点宣传,营销传播" },
];

const BASE = "https://4kwallpapers.com";

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function getDimensions(filePath) {
  try {
    const out = execSync(`sips -g pixelWidth -g pixelHeight ${JSON.stringify(filePath)}`).toString();
    const w = out.match(/pixelWidth:\s*(\d+)/)?.[1];
    const h = out.match(/pixelHeight:\s*(\d+)/)?.[1];
    if (w && h) return `${w}x${h}`;
  } catch {}
  return "未知";
}

function normalizeScene(city, sceneIndex) {
  const scene = (TARGETS.find((t) => t.city === city)?.scenes || ["旅行热点"])[sceneIndex % 4];
  return `${city} · ${scene}`;
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function httpText(url) {
  try {
    return execFileSync(
      "curl",
      [
        "-LfsS",
        "--max-time",
        "40",
        "--connect-timeout",
        "12",
        "-A",
        USER_AGENT,
        url,
      ],
      { encoding: "utf8", maxBuffer: 1024 * 1024 * 64 },
    );
  } catch {
    return "";
  }
}

async function httpBuffer(url) {
  try {
    return execFileSync(
      "curl",
      [
        "-LfsS",
        "--max-time",
        "60",
        "--connect-timeout",
        "12",
        "-A",
        USER_AGENT,
        url,
      ],
      { encoding: "buffer", maxBuffer: 1024 * 1024 * 128 },
    );
  } catch {
    return Buffer.alloc(0);
  }
}

function parseSearch(html) {
  const itemRegex =
    /class="[^"]*wallpapers__canvas_image[^"]*"[\s\S]*?href="([^"]+\.html)"[\s\S]*?<img[^>]*src="([^"]+\.jpg)"[^>]*alt="([^"]+)"/g;
  const out = [];
  let m;
  while ((m = itemRegex.exec(html)) !== null) {
    const detailUrl = m[1].startsWith("http") ? m[1] : `${BASE}${m[1]}`;
    const thumb = m[2];
    const title = m[3];
    out.push({ detailUrl, thumb, title });
  }
  const dedup = new Map();
  for (const it of out) {
    if (!dedup.has(it.detailUrl)) dedup.set(it.detailUrl, it);
  }
  return Array.from(dedup.values());
}

function absUrl(href) {
  if (!href) return "";
  if (href.startsWith("http://") || href.startsWith("https://")) return href;
  if (href.startsWith("//")) return `https:${href}`;
  if (href.startsWith("/")) return `${BASE}${href}`;
  return `${BASE}/${href}`;
}

function pickLargestWallUrlFromList(urls) {
  let best = "";
  let bestScore = 0;
  for (const href of urls) {
    const m = href.match(/-(\d+)x(\d+)-\d+\.jpg$/i);
    const area = m ? Number(m[1]) * Number(m[2]) : 0;
    if (area > bestScore) {
      bestScore = area;
      best = href;
    }
  }
  return best || urls[0] || "";
}

function parseDetail(html, detailUrl) {
  const candidates = [];

  const exactCandidates = [
    html.match(/<a[^>]*\bid=["']resolution["'][^>]*\shref=["']([^"']+)["']/i),
    html.match(/<a[^>]*\bclass=["'][^"']*\bcurrent\b[^"']*["'][^>]*\shref=["']([^"']+)["']/i),
    html.match(/<a[^>]*\bclass=["'][^"']*["'][^>]*\shref=["']([^"']*\/images\/wallpapers\/[^"']+)["'][^>]*\b(Desktop|Original|resolution|Download)/i),
    html.match(/<a[^>]*\bhref=["']([^"']+\/images\/wallpapers\/[^"']+)["'][^>]*\b(?:Original|Download|resolution|1920x1080|2560x1440)/i),
    html.match(/<meta\s+itemprop=["']contentUrl["']\s+href=["']([^"']+)["']/i),
  ];

  for (const m of exactCandidates) {
    if (m?.[1]) candidates.push(absUrl(m[1]));
  }

  const listMatches = [
    ...html.matchAll(/href=["']([^"']*\/images\/wallpapers\/[^"']+)["']/gi),
    ...html.matchAll(/href=["']([^"']*\/images\/walls\/[^"']+)["']/gi),
  ];
  for (const m of listMatches) {
    candidates.push(absUrl(m[1]));
  }

  const wallCandidates = candidates
    .filter((it) => /\/images\/wallpapers\//.test(it))
    .filter((it, i, arr) => arr.indexOf(it) === i);
  const wallUrl = pickLargestWallUrlFromList(wallCandidates);
  const fallback = candidates.filter((it) => /4kwallpapers\.com\/images\/walls\//i.test(it))[0];
  const fullUrl = wallUrl || fallback || "";
  const alt = html.match(/meta\s+itemprop="keywords"\s+content="([^"]+)"/i)?.[1] || "";
  const title = (alt || html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1] || "").split(",")[0]?.trim() || "";
  return { fullUrl, title, keywords: alt, detailUrl };
}

async function parseMetadata() {
  try {
    const raw = await fs.readFile(metadataPath, "utf8");
    const parsed = JSON.parse(raw);
    const items = Array.isArray(parsed?.items) ? parsed.items : [];
    return items;
  } catch {
    return [];
  }
}

function cityKey(item) {
  const scene = String(item?.["场景"] || "");
  const prefix = scene.split("·")[0]?.trim();
  return prefix || "日本其他";
}

function buildCityCount(items) {
  const map = new Map();
  for (const item of items) {
    const c = cityKey(item);
    map.set(c, (map.get(c) || 0) + 1);
  }
  return map;
}

async function existingHashSet() {
  const items = await parseMetadata();
  const set = new Set();
  for (const it of items) {
    const local = String(it["本地文件"] || "");
    if (!local) continue;
    const p = path.join(sourceDir, local.replace(/^\.\//, ""));
    try {
      const buf = await fs.readFile(p);
      set.add(sha256(buf));
    } catch {}
  }
  return { set, items };
}

async function pickFileName(url, city, idx) {
  const ext = path.extname(new URL(url).pathname).toLowerCase() || ".jpg";
  const safe = city.replace(/[^\u4e00-\u9fffA-Za-z0-9_-]/g, "").slice(0, 12) || "city";
  return `${String(idx).padStart(3, "0")}_${safe}_4k_${Date.now()}_${Math.random().toString(16).slice(2, 8)}${ext}`;
}

function pickRemoveIndex(items, targetMinimums, counts) {
  const protectCities = new Set(TARGETS.map((t) => t.city));
  for (let i = items.length - 1; i >= 0; i--) {
    const c = cityKey(items[i]);
    const min = targetMinimums.get(c) || 0;
    const surplus = (counts.get(c) || 0) - min;
    if (surplus > 0) return i;
    if (!protectCities.has(c)) return i;
  }
  return items.length - 1;
}

function buildHtml(items) {
  const cards = items
    .map((item, idx) => `
      <figure>
        <img src="${item["图片URL"]}" alt="素材${idx + 1}" loading="lazy"/>
        <figcaption>
          <strong>#${idx + 1} ${escapeHtml(item["图片名称"])}</strong><br/>
          <div>场景：${escapeHtml(item["场景"])}</div>
          <div>特点：${escapeHtml(item["特点"])}</div>
          <div>尺寸：${escapeHtml(item["尺寸"])}</div>
          <div>来源：${escapeHtml(item["来源"])}</div>
          <div>图片URL：${escapeHtml(item["图片URL"])}</div>
          <div>来源页面：${escapeHtml(item["来源页面"] || "")}</div>
        </figcaption>
      </figure>`)
    .join("\n");

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>东京/日本TOP城市素材库（含港/新）</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; background: #0b1022; color: #e5edf7; margin: 0; padding: 18px; }
    h1 { margin: 0 0 10px; }
    .meta { color: #9db0c8; margin-bottom: 14px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill,minmax(250px,1fr)); gap: 12px; }
    figure { margin: 0; background: #101a2d; border: 1px solid #1f2a44; border-radius: 10px; overflow: hidden; }
    img { width: 100%; height: 180px; object-fit: cover; display: block; background: #090f1a; }
    figcaption { font-size: 12px; color: #c7d3e8; line-height: 1.4; padding: 8px 10px; }
    strong { color: #7ecbff; }
  </style>
</head>
<body>
  <h1>东京及日本TOP10城市 OTA 素材库（含香港、新加坡）</h1>
  <div class="meta">共 ${items.length} 张，可直接在本文件预览（相对路径优先，支持场景/特点/尺寸/来源/图片URL）</div>
  <section class="grid">
${cards}
  </section>
</body>
</html>`;
}

async function main() {
  const data = await existingHashSet();
  let items = data.items;
  const hashSet = data.set;
  const counts = buildCityCount(items);
  const minimumByCity = new Map(TARGETS.map((t) => [t.city, t.minimum]));

  let added = 0;
  const maxAddedPerCity = 40;

  for (const target of TARGETS) {
    console.log(`CITY ${target.city} start, current=${counts.get(target.city) || 0} target=${target.minimum}`);
    let need = Math.max(0, target.minimum - (counts.get(target.city) || 0));
    if (!need) continue;
    const candidatesAll = [];
    const querySet = [
      target.query,
      `${target.query} Japan`,
      `${target.query} travel`,
      `${target.query} landmark`,
      `${target.query} night`,
      `${target.query} fireworks`,
    ];

    for (const q of querySet) {
      try {
        const searchUrl = `${BASE}/search/?q=${encodeURIComponent(q)}`;
        const html = await httpText(searchUrl);
        const list = parseSearch(html).slice(0, 40);
        for (const item of list) candidatesAll.push(item);
      } catch {}
    }

    const seen = new Set();
    for (const c of candidatesAll) seen.add(c.detailUrl);
    const candidates = Array.from(seen).map((u) => ({ detailUrl: u })).slice(0, maxAddedPerCity);
    let localNeed = need;
    let tryIdx = 0;

    while (localNeed > 0 && tryIdx < candidates.length) {
      const page = candidates[tryIdx++];
      try {
        const detailHtml = await httpText(page.detailUrl);
        const detail = parseDetail(detailHtml, page.detailUrl);
        if (!detail?.fullUrl) continue;
        const fullUrl = detail.fullUrl;
        const buf = await httpBuffer(fullUrl);
        const hash = sha256(buf);
        if (hashSet.has(hash)) continue;

        const fileName = await pickFileName(fullUrl, target.city, items.length + added + 1);
        const filePath = path.join(sourceDir, fileName);
        await fs.writeFile(filePath, buf);

        let dims = getDimensions(filePath);
        if (!dims || dims === "未知") {
          await fs.unlink(filePath).catch(() => {});
          continue;
        }

        const currentCount = counts.get(target.city) || 0;
        const scene = normalizeScene(target.city, currentCount);
        const feature = target.feature;
        const item = {
          "图片名称": fileName,
          "场景": scene,
          "特点": feature,
          "尺寸": dims,
          "来源": "4K Wallpapers",
          "来源页面": page.detailUrl,
          "图片URL": `./${fileName}`,
          "本地文件": `./${fileName}`,
        };

        hashSet.add(hash);
        if (items.length >= TARGET_TOTAL) {
          const removeIdx = pickRemoveIndex(items, minimumByCity, counts);
          if (removeIdx >= 0) {
            const removed = items.splice(removeIdx, 1)[0];
            const c = cityKey(removed);
            counts.set(c, Math.max(0, (counts.get(c) || 1) - 1));
            const removedPath = removed["本地文件"] ? path.join(sourceDir, String(removed["本地文件"]).replace(/^\.\//, "")) : "";
            if (removed["来源"] !== "本地素材" && removedPath) await fs.unlink(removedPath).catch(() => {});
          }
        }

        items.push(item);
        counts.set(target.city, (counts.get(target.city) || 0) + 1);
        added += 1;
        localNeed -= 1;
        console.log(`+1 ${target.city} => ${fileName} (${dims}, ${fullUrl})`);
        await sleep(450);
      } catch {
        continue;
      }
    }
  }

  const finalItems = items.slice(-TARGET_TOTAL).map((item, idx) => ({ ...item, 序号: idx + 1 }));
  await fs.writeFile(
    metadataPath,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        total: finalItems.length,
        note: "4K Wallpapers 补充日本TOP城市素材库（原图保存本地）",
        items: finalItems,
      },
      null,
      2,
    ),
    "utf8",
  );
  await fs.writeFile(htmlPath, buildHtml(finalItems), "utf8");

  const citySummary = {};
  for (const t of TARGETS) citySummary[t.city] = (buildCityCount(finalItems).get(t.city) || 0);

  console.log(
    JSON.stringify({
      status: "ok",
      total: finalItems.length,
      added,
      citySummary,
    }),
  );
}

main().catch(async (err) => {
  console.error("ENRICH_ERROR", err.message);
  process.exit(1);
});
