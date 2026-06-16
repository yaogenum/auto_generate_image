import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { execFileSync } from "node:child_process";

const ROOT = process.cwd();
const sourceDir = path.join(ROOT, "images", "source");
const metadataPath = path.join(ROOT, "images", "素材元数据.json");
const htmlPath = path.join(sourceDir, "tokyo_assets.html");

const TARGET_TOTAL = 100;
const MIN_EDGE = 1200;

const TARGETS = [
  { city: "大阪", query: "Osaka city castle", minimum: 12, scene: "地标", feature: "城市旅行,营销宣传", localeWords: ["osaka", "\u5927\u962a"] },
  { city: "名古屋", query: "Nagoya city", minimum: 8, scene: "地标", feature: "城市旅行,景点宣传", localeWords: ["nagoya", "\u540d\u53e4\u5c4b"] },
  { city: "京都", query: "Kyoto city", minimum: 8, scene: "古都景观", feature: "历史文化,景点宣传", localeWords: ["kyoto", "\u4eac\u90fd"] },
  { city: "札幌", query: "Sapporo city", minimum: 6, scene: "城市景观", feature: "季节景观,旅行热点", localeWords: ["sapporo", "\u672d\u677e"] },
  { city: "横滨", query: "Yokohama city", minimum: 6, scene: "港湾夜景", feature: "商务景观,城市夜景", localeWords: ["yokohama", "\u6a2a\u6ca7"] },
  { city: "福冈", query: "Fukuoka city", minimum: 6, scene: "地标", feature: "城市地标,旅游推广", localeWords: ["fukuoka", "\u798f\u5ca9"] },
  { city: "神户", query: "Kobe city", minimum: 5, scene: "港湾", feature: "港口风光,景区推广", localeWords: ["kobe", "\u795e\u6236"] },
  { city: "广岛", query: "Hiroshima city", minimum: 5, scene: "城市景观", feature: "历史城市,文化传播", localeWords: ["hiroshima", "\u5e7f\u5c9b"] },
  { city: "仙台", query: "Sendai city", minimum: 5, scene: "城市景观", feature: "旅游景观,城市宣传", localeWords: ["sendai", "\u4ed9\u53f0"] },
  { city: "香港", query: "Hong Kong city", minimum: 3, scene: "城市夜景", feature: "都市景观,景点宣传", localeWords: ["hong kong", "hongkong", "\u9999\u6e2f"] },
  { city: "新加坡", query: "Singapore city", minimum: 3, scene: "城市夜景", feature: "都市景观,营销素材", localeWords: ["singapore", "\u65b0\u52a0\u5761", "\u65b0\u52a0\u62ff\u5927"] },
];

function normalizeCityKey(sceneText) {
  return String(sceneText || "")
    .split("·")[0]
    .trim();
}

function cityNameCounts(items) {
  const map = new Map();
  for (const item of items) {
    const key = normalizeCityKey(item?.["场景"] || "");
    map.set(key, (map.get(key) || 0) + 1);
  }
  return map;
}

function sha256(buf) {
  return crypto.createHash("sha256").update(buf).digest("hex");
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function slugify(input) {
  return String(input)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\u4e00-\u9fffA-Za-z0-9._-]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 64) || "travel";
}

function absUrl(url) {
  if (!url) return "";
  if (url.startsWith("http://") || url.startsWith("https://")) return url;
  return url;
}

function getSize(filePath) {
  try {
    const output = execFileSync("sips", ["-g", "pixelWidth", "-g", "pixelHeight", filePath], {
      encoding: "utf8",
      maxBuffer: 1024 * 512,
    });
    const width = Number(output.match(/pixelWidth:\s+(\d+)/)?.[1] || 0);
    const height = Number(output.match(/pixelHeight:\s+(\d+)/)?.[1] || 0);
    if (!width || !height) return null;
    return `${width}x${height}`;
  } catch {
    return null;
  }
}

function fileExt(url) {
  const p = absUrl(String(url).split("?")[0]).toLowerCase();
  if (p.endsWith(".png")) return ".png";
  if (p.endsWith(".webp")) return ".webp";
  if (p.endsWith(".jpeg")) return ".jpeg";
  if (p.endsWith(".gif")) return ".gif";
  return ".jpg";
}

async function existingState() {
  let items = [];
  try {
    const raw = await fs.readFile(metadataPath, "utf8");
    const payload = JSON.parse(raw);
    items = Array.isArray(payload?.items) ? payload.items : [];
  } catch {
    items = [];
  }

  const hashSet = new Set();
  const urlSet = new Set();
  const titleSet = new Set();
  for (const it of items) {
    const local = String(it?.["本地文件"] || "").replace(/^\.\//, "");
    if (!local) continue;
    const p = path.join(sourceDir, local);
    try {
      const b = await fs.readFile(p);
      hashSet.add(sha256(b));
    } catch {}
    if (it?.["图片URL"]) urlSet.add(String(it["图片URL"]));
    if (it?.["图片名称"]) titleSet.add(String(it["图片名称"]).toLowerCase());
  }
  return { items, hashSet, urlSet, titleSet };
}

async function wikiSearch(query, offset = 0) {
  const base = "https://commons.wikimedia.org/w/api.php";
  const params = new URLSearchParams({
    action: "query",
    format: "json",
    generator: "search",
    gsrnamespace: "6",
    gsrlimit: "20",
    gsroffset: String(offset),
    gsrsearch: `${query} filetype:bitmap`,
    prop: "imageinfo",
    iiprop: "url|size",
  });
  const url = `${base}?${params.toString()}`;
  const raw = execFileSync("curl", ["-LfsS", "-k", "--http1.1", "--retry", "2", "--retry-delay", "2", "--connect-timeout", "12", "--max-time", "50", "-A", "Mozilla/5.0 (compatible; Codex/1.0)", url], {
    encoding: "utf8",
    maxBuffer: 1024 * 1024 * 8,
  });
  const payload = JSON.parse(raw);
  const pages = Object.values(payload?.query?.pages || {});
  const out = [];
  for (const p of pages) {
    const info = p?.imageinfo?.[0];
    const title = String(p?.title || "").replace(/^File:/, "");
    if (!info?.url || !title || !info.width || !info.height) continue;
    if (info.width < MIN_EDGE || info.height < MIN_EDGE) continue;
    if (info.width > 10000 || info.height > 10000) continue;
    out.push({ title, imageUrl: absUrl(info.url), sourcePage: `https://commons.wikimedia.org/wiki/${encodeURIComponent(String(p.title || "")).replace(/%3A/g, ":")}` });
  }
  return out;
}

function isDuplicateByMetadata(candidate, cityPlan, existingTitleSet, existingUrlSet) {
  if (!candidate?.title || !candidate?.imageUrl) return true;
  if (existingUrlSet.has(candidate.imageUrl)) return true;
  if (existingTitleSet.has(candidate.title.toLowerCase())) return true;

  const cityText = [cityPlan.city, ...cityPlan.localeWords, cityPlan.query].join("|").toLowerCase();
  const t = candidate.title.toLowerCase();
  const url = candidate.imageUrl.toLowerCase();
  const hasCityWord = cityText.split("|").some((w) => w && (t.includes(w) || url.includes(w)));
  if (!hasCityWord) return true;

  return false;
}

function pickRemoveIndex(items, counts, minMap) {
  for (let i = items.length - 1; i >= 0; i--) {
    const c = normalizeCityKey(items[i]?.["场景"] || "");
    const min = minMap.get(c) || 0;
    const surplus = (counts.get(c) || 0) - min;
    if (surplus > 0) return i;
  }
  return -1;
}

function buildHtml(items) {
  const cards = items
    .map((item, idx) => `
      <figure>
        <img src="${escapeHtml(item["本地文件"] || item["图片URL"])}" alt="素材${idx + 1}" loading="lazy"/>
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
  <title>日本TOP城市素材库（含港台）</title>
  <style>
    body { font-family: Arial, Helvetica, sans-serif; background: #0b1022; color: #e5edf7; margin: 0; padding: 18px; }
    .meta { color: #9db0c8; margin-bottom: 14px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill,minmax(250px,1fr)); gap: 12px; }
    figure { margin: 0; background: #101a2d; border: 1px solid #1f2a44; border-radius: 10px; overflow: hidden; }
    img { width: 100%; height: 180px; object-fit: cover; display: block; background: #090f1a; }
    figcaption { font-size: 12px; color: #c7d3e8; line-height: 1.4; padding: 8px 10px; }
    strong { color: #7ecbff; }
  </style>
</head>
<body>
  <h1>日本 TOP10/港台城市 OTA 素材库（原图补充）</h1>
  <div class="meta">共 ${items.length} 张，可在当前目录直接预览</div>
  <section class="grid">${cards}</section>
</body>
</html>`;
}

async function main() {
  const state = await existingState();
  const items = state.items;
  const counts = cityNameCounts(items);
  const minByCity = new Map(TARGETS.map((t) => [t.city, t.minimum]));

  const hashSet = state.hashSet;
  const urlSet = state.urlSet;
  const titleSet = state.titleSet;

  let added = 0;
  let addedImages = 0;

  for (const target of TARGETS) {
    const need = Math.max(0, target.minimum - (counts.get(target.city) || 0));
    if (need <= 0) continue;

    let localNeed = need;
    let offset = 0;

    while (localNeed > 0 && offset <= 40) {
      let candidates = [];
      try {
        candidates = await wikiSearch(target.query, offset);
      } catch {
        break;
      }

      if (!candidates.length) break;
      for (const c of candidates) {
        if (localNeed <= 0) break;
        if (isDuplicateByMetadata(c, target, titleSet, urlSet)) continue;

        const localName = `${String(items.length + added + 1).padStart(3, "0")}_${slugify(target.city)}_${slugify(c.title)}${fileExt(c.imageUrl)}`;
        const localPath = path.join(sourceDir, localName);

        try {
          execFileSync("curl", [
            "-LfsS",
            "-k",
            "--http1.1",
            "--retry",
            "2",
            "--retry-delay",
            "2",
            "--connect-timeout",
            "12",
            "--max-time",
            "90",
            "-A",
            "Mozilla/5.0 (compatible; Codex/1.0)",
            "-o",
            localPath,
            c.imageUrl,
          ], { maxBuffer: 1024 * 1024 * 256 });

          const dims = getSize(localPath);
          if (!dims) {
            await fs.rm(localPath, { force: true });
            continue;
          }
          const fileBuf = await fs.readFile(localPath);
          const fileHash = sha256(fileBuf);
          if (hashSet.has(fileHash)) {
            await fs.rm(localPath, { force: true });
            continue;
          }

          const item = {
            "图片名称": c.title,
            "场景": `${target.city} · ${target.scene}`,
            "特点": `${target.feature}`,
            "尺寸": dims,
            "来源": "Wikimedia Commons",
            "来源页面": c.sourcePage,
            "图片URL": `./${localName}`,
            "本地文件": `./${localName}`,
          };

          const removeIdx = pickRemoveIndex(items, counts, minByCity);
          if (removeIdx >= 0) {
            const removed = items.splice(removeIdx, 1)[0];
            const ckey = normalizeCityKey(removed?.["场景"] || "");
            counts.set(ckey, Math.max(0, (counts.get(ckey) || 1) - 1));
            const removedFile = removed["本地文件"] ? path.join(sourceDir, String(removed["本地文件"]).replace(/^\.\//, "")) : "";
            if (removedFile && removed["来源"] !== "本地素材") await fs.rm(removedFile, { force: true }).catch(() => {});
          }

          items.push(item);
          hashSet.add(fileHash);
          urlSet.add(c.imageUrl);
          titleSet.add(c.title.toLowerCase());
          counts.set(target.city, (counts.get(target.city) || 0) + 1);
          localNeed -= 1;
          added += 1;
          addedImages += 1;
          await new Promise((resolve) => setTimeout(resolve, 250));
        } catch {
          await fs.rm(localPath, { force: true }).catch(() => {});
          continue;
        }
      }

      offset += 20;
    }
    await new Promise((resolve) => setTimeout(resolve, 800));
  }

  const finalItems = items.slice(-TARGET_TOTAL).map((item, index) => ({
    ...item,
    序号: index + 1,
  }));

  await fs.writeFile(
    metadataPath,
    JSON.stringify({
      generatedAt: new Date().toISOString(),
      total: finalItems.length,
      note: "4K Wallpapers + Wikimedia 补齐日本 TOP10（含港/新）素材库，保留原图文件。",
      items: finalItems,
    }, null, 2),
    "utf8",
  );

  await fs.writeFile(htmlPath, buildHtml(finalItems), "utf8");

  console.log(JSON.stringify({ status: "ok", total: finalItems.length, added, citySummary: Object.fromEntries([...counts.entries()]) }, null, 2));
}

main().catch((error) => {
  console.error("WIKI_FILL_ERROR", error.message || error);
  process.exit(1);
});
