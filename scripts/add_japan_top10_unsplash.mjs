import fs from "node:fs/promises";
import path from "node:path";
import { execFileSync } from "node:child_process";

const rootDir = "/Users/jiubao/Desktop/codex_workplace/auto_generate_image";
const sourceDir = path.join(rootDir, "images", "source");
const metadataPath = path.join(rootDir, "images", "素材元数据.json");
const htmlPath = path.join(sourceDir, "tokyo_assets.html");
const TARGET_TOTAL = 100;
const MIN_EDGE = 1200;

const plans = [
  { city: "大阪", scene: "地标", query: "Osaka Castle", desired: 10 },
  { city: "名古屋", scene: "地标", query: "Nagoya Castle", desired: 8 },
  { city: "京都", scene: "古都", query: "Kyoto Kiyomizu-dera", desired: 8 },
  { city: "札幌", scene: "景观", query: "Sapporo skyline", desired: 6 },
  { city: "福冈", scene: "地标", query: "Fukuoka tower", desired: 6 },
  { city: "横滨", scene: "港湾", query: "Yokohama Minato Mirai", desired: 6 },
  { city: "神户", scene: "港景", query: "Kobe Harborland", desired: 6 },
  { city: "仙台", scene: "城市景观", query: "Sendai city", desired: 4 },
  { city: "广岛", scene: "历史景观", query: "Hiroshima Peace Memorial", desired: 4 },
  { city: "那霸", scene: "海岸", query: "Naha Shuri Castle", desired: 4 },
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function run(cmd) {
  return execFileSync("bash", ["-lc", cmd], {
    encoding: "utf8",
    maxBuffer: 1024 * 1024 * 64,
  });
}

function normalizeText(input) {
  return String(input)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\u4e00-\u9fffA-Za-z0-9\s_.-]/g, "")
    .trim();
}

function slugify(input) {
  return normalizeText(input).replace(/\s+/g, "_").slice(0, 80) || "travel_asset";
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function getSize(filePath) {
  const output = execFileSync("sips", ["-g", "pixelWidth", "-g", "pixelHeight", filePath], {
    encoding: "utf8",
  });
  const width = Number(output.match(/pixelWidth:\s+(\d+)/)?.[1] || 0);
  const height = Number(output.match(/pixelHeight:\s+(\d+)/)?.[1] || 0);
  return {
    width,
    height,
    text: width && height ? `${width}x${height}` : "未知",
  };
}

function detectExt(fileName) {
  const p = String(fileName).toLowerCase();
  if (p.endsWith(".png")) return ".png";
  if (p.endsWith(".webp")) return ".webp";
  if (p.endsWith(".jpeg")) return ".jpeg";
  return ".jpg";
}

function inferCityAndScene(fileName) {
  const name = String(fileName).toLowerCase();
  const cityRules = [
    { city: "东京", keys: ["tokyo", "東京", "shibuya", "asakusa", "shinjuku", "sensoji", "ueno", "skytree", "toshima"] },
    { city: "大阪", keys: ["osaka", "\u5927\u962a", "osaka" ] },
    { city: "名古屋", keys: ["nagoya", "\u540d\u53e4\u5c4b", "_\u540d\u53e4\u5c4b_"] },
    { city: "京都", keys: ["kyoto", "\u4eac\u90fd", "kiyomizu", "kinkaku"] },
    { city: "札幌", keys: ["sapporo", "\u672d\u677e"] },
    { city: "福冈", keys: ["fukuoka", "\u798f\u5ca9"] },
    { city: "横滨", keys: ["yokohama", "\u6a2a\u6ca7"] },
    { city: "神户", keys: ["kobe", "\u795e\u6236", "\u795e\u6236"] },
    { city: "仙台", keys: ["sendai", "\u4ed9\u53f0"] },
    { city: "广岛", keys: ["hiroshima", "\u5e7f\u5c9b"] },
    { city: "那霸", keys: ["naha", "\u90a3\u8eb8", "okinawa", "\u6ea2\u7d0a"] },
    { city: "香港", keys: ["hongkong", "hong kong", "\u9999\u6e2f"] },
    { city: "新加坡", keys: ["singapore", "\u65b0\u52a0\u62ff\u5927"] },
  ];

  let city = "日本其他";
  for (const rule of cityRules) {
    if (rule.keys.some((k) => name.includes(k.toLowerCase()))) {
      city = rule.city;
      break;
    }
  }

  let scene = "旅行热点";
  const scenes = [
    { scene: "地标", keys: ["castle", "\u57ce\u5899", "\u5854", "tower", "\u5854"] },
    { scene: "夜景", keys: ["night", "\u591c\u666f", "nightview", "midnight", "evening"] },
    { scene: "景观", keys: ["skyline", "sky", "view", "街景", "\u8857\u666f"] },
    { scene: "海岸", keys: ["harbor", "港", "beach", "coast", "seaport", "\u6d77\u6ee5"] },
    { scene: "景点", keys: ["temple", "\u5bae", "shrine", "park", "\u516c\u56ed", "\u5317\u95f4"] },
  ];

  for (const rule of scenes) {
    if (rule.keys.some((k) => name.includes(k))) {
      scene = rule.scene;
      break;
    }
  }

  return `${city} · ${scene}`;
}

function isLikelyDimensionText(input) {
  return /^\d{2,5}x\d{2,5}$/.test(String(input || ""));
}

function sanitizePage(value) {
  if (!value) return "";
  const trimmed = String(value).trim();
  return isLikelyDimensionText(trimmed) ? "" : trimmed;
}

function buildApiUrl(query, offset = 0) {
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
  return `https://commons.m.wikimedia.org/w/api.php?${params.toString()}`;
}

async function fetchJson(url) {
  const raw = run(`curl -k -LfsS --http1.1 --retry 2 --retry-delay 3 --connect-timeout 18 --max-time 90 -H 'User-Agent: codex-japan-library/1.0' '${url}'`);
  return JSON.parse(raw);
}

async function searchCandidates(query) {
  const list = [];
  const seen = new Set();
  const offsets = [0, 20, 40];

  for (const offset of offsets) {
    let payload;
    try {
      payload = await fetchJson(buildApiUrl(query, offset));
    } catch (error) {
      process.stderr.write(`search failed: ${query} offset ${offset} ${String(error.message || error)}\n`);
      await sleep(800);
      continue;
    }

    const pages = Object.values(payload?.query?.pages || {});
    for (const page of pages) {
      const info = page?.imageinfo?.[0];
      const title = String(page?.title || "").replace(/^File:/, "");
      if (!info?.url || !title || !info.width || !info.height) continue;
      if (info.width < MIN_EDGE || info.height < MIN_EDGE) continue;
      if (info.width > 18000 || info.height > 18000) continue;
      const key = title.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      list.push({
        title,
        imageUrl: info.url,
        sourcePage: `https://commons.m.wikimedia.org/wiki/${encodeURIComponent(page?.title || "").replace(/%3A/g, ":")}`,
      });
    }

    await sleep(700);
  }

  return list;
}

async function downloadImage(imageUrl, localPath) {
  for (let i = 0; i < 2; i++) {
    try {
      run(`curl -k -LfsS --http1.1 --retry 1 --retry-delay 4 --connect-timeout 18 --max-time 120 -H 'User-Agent: codex-japan-library/1.0' -o '${localPath}' '${imageUrl}'`);
      return;
    } catch (error) {
      process.stderr.write(`download retry ${i + 1}/2: ${String(error.message || error)}\n`);
      await sleep(1000 * (i + 1));
    }
  }
  throw new Error(`download failed after retry: ${imageUrl}`);
}

async function listSourceFiles() {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .filter((name) => /\.(jpe?g|png|webp|bmp)$/i.test(name))
    .filter((name) => name !== path.basename(htmlPath) && !name.includes("_archive_"));
}

function buildFromLocal(existingMap, files) {
  const results = [];
  const seen = new Set();

  for (const file of files.sort()) {
    if (seen.has(file)) continue;
    seen.add(file);

    const existing = existingMap.get(`./${file}`) || existingMap.get(file) || {};
    const size = getSize(path.join(sourceDir, file));
    const scene = existing["场景"] || inferCityAndScene(file);
    const pictureUrl = existing["图片URL"] && existing["图片URL"].trim().startsWith("http")
      ? existing["图片URL"].trim()
      : `./${file}`;

    results.push({
      序号: 0,
      图片名称: String(existing["图片名称"] || file),
      场景: scene,
      特点: String(existing["特点"] || "城市旅行,营销宣传"),
      尺寸: size.text || "未知",
      来源: String(existing["来源"] || "本地素材"),
      来源页面: sanitizePage(existing["来源页面"] || ""),
      图片URL: pictureUrl,
      本地文件: `./${file}`,
    });
  }

  return results;
}

function buildHtml(items) {
  const counts = {};
  const citySet = new Set();

  for (const item of items) {
    const scene = String(item["场景"] || "日本旅行");
    counts[scene] = (counts[scene] || 0) + 1;
    citySet.add((scene.split(" · ")[0] || "").trim());
  }

  const cityList = Array.from(citySet).filter(Boolean);

  const cards = items
    .map(
      (item) => `
      <article class="card">
        <img loading="lazy" src="${escapeHtml(item["本地文件"])}" alt="${escapeHtml(item["图片名称"])}">
        <div class="card-body">
          <div class="badge">${escapeHtml(item["场景"])}</div>
          <h2>${escapeHtml(item["图片名称"])}</h2>
          <p>${escapeHtml(item["特点"])}</p>
          <dl>
            <div><dt>尺寸</dt><dd>${escapeHtml(item["尺寸"])}</dd></div>
            <div><dt>来源</dt><dd>${escapeHtml(item["来源"])}</dd></div>
          </dl>
          <div class="links">${item["来源页面"] ? `<a href="${escapeHtml(item["来源页面"])}" target="_blank" rel="noreferrer">来源页面</a>` : ""}${item["图片URL"] ? `<a href="${escapeHtml(item["图片URL"])}" target="_blank" rel="noreferrer">图片URL</a>` : ""}</div>
        </div>
      </article>`,
    )
    .join("");

  const rows = items
    .map(
      (item) => `
      <tr>
        <td>${item["序号"]}</td>
        <td>${escapeHtml(item["场景"])}</td>
        <td>${escapeHtml(item["特点"])}</td>
        <td>${escapeHtml(item["尺寸"])}</td>
        <td>${escapeHtml(item["来源"])}</td>
        <td>${item["图片URL"] ? `<a href="${escapeHtml(item["图片URL"])}" target="_blank" rel="noreferrer">查看</a>` : "-"}</td>
      </tr>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${cityList.length ? cityList.join(" / ") : "日本重点城市"}旅行原图库</title>
  <style>
    :root{--bg:#fff8ef;--panel:rgba(255,255,255,.86);--line:rgba(148,85,0,.12);--text:#2e2016;--muted:#725f4f;--accent:#c2410c;--accent2:#ea580c;--shadow:0 18px 50px rgba(66,32,6,.12);font-family:"Noto Sans SC","PingFang SC",Arial,sans-serif}
    *{box-sizing:border-box}
    body{margin:0;color:var(--text);background:radial-gradient(circle at top,rgba(255,196,87,.32),transparent 28%),radial-gradient(circle at 20% 16%,rgba(255,114,94,.18),transparent 20%),linear-gradient(180deg,#2f140c 0,#7a2615 18%,#f7ebdd 18.2%,#fff8ef 100%)}
    .shell{width:min(1380px,calc(100vw - 32px));margin:0 auto;padding:28px 0 64px}
    .hero{padding:32px;border-radius:28px;color:#fff7ed;background:linear-gradient(135deg,rgba(38,12,6,.92),rgba(124,45,18,.74));box-shadow:var(--shadow)}
    .kicker{display:inline-block;padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.12);border:1px solid rgba(255,256,255,.18);font-size:12px;letter-spacing:.08em;text-transform:uppercase}
    h1{margin:16px 0 12px;font-size:clamp(30px,4vw,54px);line-height:1.02}
    .hero p{max-width:760px;margin:0;color:rgba(255,247,237,.9);font-size:16px;line-height:1.7}
    .stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin-top:22px}
    .stat{padding:14px 16px;border-radius:18px;background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.14)}
    .stat strong{display:block;font-size:24px;margin-bottom:4px}
    .section{margin-top:28px;padding:22px;background:var(--panel);border:1px solid var(--line);border-radius:26px;box-shadow:var(--shadow)}
    .section h2{margin:0 0 14px;font-size:22px}
    .tags{display:flex;flex-wrap:wrap;gap:10px;margin:0;padding:0;list-style:none}
    .tags li{padding:10px 14px;border-radius:999px;background:#fff;border:1px solid #fed7aa;color:#9a3412;font-size:13px}
    .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px}
    .card{overflow:hidden;border-radius:22px;background:#fffdfa;border:1px solid #fde2cf;box-shadow:0 12px 30px rgba(86,42,10,.08)}
    .card img{width:100%;aspect-ratio:4/3;object-fit:cover;display:block;background:#f3f4f6}
    .card-body{padding:16px}
    .badge{display:inline-block;margin-bottom:10px;padding:6px 10px;border-radius:999px;background:#ffedd5;color:var(--accent);font-size:12px;font-weight:700}
    .card h2{margin:0 0 8px;font-size:16px;line-height:1.4;word-break:break-word}
    .card p{margin:0 0 12px;color:var(--muted);line-height:1.6;font-size:14px}
    dl{margin:0;display:grid;gap:8px}
    dl div{display:flex;justify-content:space-between;gap:12px;font-size:13px;color:#6b4f3d}
    dt{font-weight:700}
    dd{margin:0;text-align:right}
    .links{display:flex;flex-wrap:wrap;gap:10px;margin-top:14px}
    a{color:var(--accent2);text-decoration:none}
    a:hover{text-decoration:underline}
    table{width:100%;border-collapse:collapse;border-radius:18px;background:#fff}
    th,td{padding:12px 14px;border-bottom:1px solid #ffedd5;text-align:left;font-size:13px;vertical-align:top}
    th{background:#9a3412;color:#fff7ed;position:sticky;top:0}
    @media(max-width:720px){.shell{width:min(100vw - 20px,1380px);padding-top:18px}.hero,.section{padding:18px;border-radius:22px}th,td{font-size:12px;padding:10px}}
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <span class="kicker">Multi City Original Library</span>
      <h1>${cityList.length ? cityList.join(" / ") : "日本重点城市"}旅行原图库</h1>
      <p>保留唯一原图，不做额外尺寸裁剪。当前库覆盖 ${cityList.length} 个城市的旅行营销素材，图片均存储在本地 <code>images/source</code> 并可直接预览。</p>
      <div class="stats">
        <div class="stat"><strong>${items.length}</strong><span>原图总数</span></div>
        <div class="stat"><strong>${cityList.length}</strong><span>覆盖城市</span></div>
        <div class="stat"><strong>0</strong><span>额外裁剪图</span></div>
      </div>
    </section>
    <section class="section"><h2>场景分布</h2><ul class="tags">${Object.entries(counts).map(([label, count]) => `<li>${escapeHtml(label)} ${count} 张</li>`).join("")}</ul></section>
    <section class="section"><h2>原图预览</h2><div class="grid">${cards}</div></section>
    <section class="section"><h2>素材清单</h2><div style="overflow:auto;max-height:70vh"><table><thead><tr><th>序号</th><th>场景</th><th>特点</th><th>尺寸</th><th>来源</th><th>图片URL</th></tr></thead><tbody>${rows}</tbody></table></div></section>
  </main>
</body>
</html>`;
}

async function loadExisting() {
  try {
    const payload = JSON.parse(await fs.readFile(metadataPath, "utf8"));
    const items = Array.isArray(payload.items) ? payload.items : [];
    const map = new Map();
    for (const item of items) {
      const key = String(item["本地文件"] || "").trim();
      if (key) map.set(key, item);
      const short = key.replace(/^\./, "");
      if (short) map.set(short, item);
    }
    return map;
  } catch {
    return new Map();
  }
}

async function extendByOnline(items, need) {
  if (need <= 0) return [];

  const urlSet = new Set(items.map((item) => String(item["图片URL"] || "")));
  const titleSet = new Set(items.map((item) => String(item["图片名称"] || "").toLowerCase()));
  const nextIndex = { value: items.length + 1 };
  const additions = [];

  for (const plan of plans) {
    if (additions.length >= need) break;
    const candidates = await searchCandidates(plan.query);
    for (const item of candidates) {
      if (additions.length >= need) break;
      const title = String(item.title || "").trim().toLowerCase();
      if (!item.imageUrl || urlSet.has(item.imageUrl) || titleSet.has(title)) continue;
      const localName = `${String(nextIndex.value).padStart(3, "0")}_${slugify(plan.city)}_${slugify(item.title)}${detectExt(item.imageUrl)}`;
      const localPath = path.join(sourceDir, localName);
      try {
        await downloadImage(item.imageUrl, localPath);
        const size = getSize(localPath);
        if (!size.width || !size.height) {
          await fs.rm(localPath, { force: true });
          continue;
        }
        additions.push({
          序号: 0,
          图片名称: item.title,
          场景: `${plan.city} · ${plan.scene}`,
          特点: "城市旅行,营销宣传",
          尺寸: size.text,
          来源: "Wikimedia Commons",
          来源页面: item.sourcePage,
          图片URL: item.imageUrl,
          本地文件: `./${localName}`,
        });
        urlSet.add(item.imageUrl);
        titleSet.add(title);
        nextIndex.value += 1;
      } catch {
        await fs.rm(localPath, { force: true }).catch(() => {});
      }
      await sleep(800);
    }
  }

  return additions;
}

async function main() {
  const existingMap = await loadExisting();
  const sourceFiles = await listSourceFiles();
  const localItems = buildFromLocal(existingMap, sourceFiles);

  const need = Math.max(0, TARGET_TOTAL - localItems.length);
  const onlineItems = await extendByOnline(localItems, need);
  const merged = [...localItems, ...onlineItems].slice(0, TARGET_TOTAL);

  merged.forEach((item, index) => {
    item["序号"] = index + 1;
  });

  const payload = {
    generatedAt: new Date().toISOString(),
    total: merged.length,
    note: "日本TOP10城市素材扩展版，保留原图，不额外裁剪。",
    items: merged,
  };

  await fs.writeFile(metadataPath, `${JSON.stringify(payload, null, 2)}\n`, "utf8");
  await fs.writeFile(htmlPath, buildHtml(merged), "utf8");

  console.log(JSON.stringify({ status: "ok", total: merged.length, added: onlineItems.length }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
