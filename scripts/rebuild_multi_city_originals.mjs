import fs from "node:fs/promises";
import path from "node:path";
import { execFileSync } from "node:child_process";

const rootDir = "/Users/jiubao/Desktop/codex_workplace/auto_generate_image";
const sourceDir = path.join(rootDir, "images", "source");
const metadataPath = path.join(rootDir, "images", "素材元数据.json");
const htmlPath = path.join(sourceDir, "tokyo_assets.html");
const targetCount = 100;
const minEdge = 1200;

const plans = [
  { city: "大阪", scene: "地标", feature: "城市场景,文化传播", query: "\"Osaka Castle\" skyline" , desired: 6 },
  { city: "大阪", scene: "城市夜景", feature: "夜景霓虹,城市营销", query: "\"Osaka\" city skyline night", desired: 6 },
  { city: "名古屋", scene: "地标", feature: "城市地标,旅行宣传", query: "\"Nagoya Castle\" city", desired: 5 },
  { city: "名古屋", scene: "商业街景", feature: "购物街区,城市热点", query: "\"Nagoya\" street shopping", desired: 4 },
  { city: "京都", scene: "古都景观", feature: "文化旅行,历史地标", query: "\"Kyoto\" Kiyomizu-dera", desired: 6 },
  { city: "京都", scene: "庭园与街景", feature: "传统氛围,景点宣传", query: "\"Kyoto\" Gion Arashiyama", desired: 5 },
  { city: "札幌", scene: "城市地标", feature: "城市旅行,北境景观", query: "\"Sapporo\" skyline", desired: 5 },
  { city: "福冈", scene: "景观", feature: "城市地标,旅游推广", query: "\"Fukuoka\" tower skyline", desired: 5 },
  { city: "横滨", scene: "港湾夜景", feature: "海湾地标,商务出行", query: "\"Yokohama\" Minato Mirai skyline", desired: 5 },
  { city: "神户", scene: "观景", feature: "港口夜景,旅行热点", query: "\"Kobe\" Harborland skyline", desired: 4 },
  { city: "仙台", scene: "城市景观", feature: "城市旅游,地标宣传", query: "\"Sendai\" skyline", desired: 4 },
  { city: "广岛", scene: "城市地标", feature: "纪念地标,历史城市", query: "\"Hiroshima\" skyline", desired: 5 },
  { city: "那霸", scene: "海岸景观", feature: "度假城市,海景宣传", query: "\"Naha\" Okinawa skyline", desired: 5 },
];

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function slugify(input) {
  return String(input)
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/[\s_-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 96) || "travel_asset";
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function curlBuffer(url, accept) {
  return execFileSync("curl", [
    "-LfsS",
    "--retry", "2",
    "--retry-delay", "1",
    "--connect-timeout", "12",
    "--max-time", "45",
    "-H", "User-Agent: codex-multi-city-originals/1.0",
    "-H", `Accept: ${accept}`,
    url,
  ], {
    maxBuffer: 1024 * 1024 * 64,
  });
}

function fetchJson(url) {
  return JSON.parse(curlBuffer(url, "application/json").toString("utf8"));
}

function fetchImage(imageUrl, localPath) {
  execFileSync("curl", [
    "-LfsS",
    "--retry", "2",
    "--retry-delay", "1",
    "--connect-timeout", "12",
    "--max-time", "60",
    "-H", "User-Agent: codex-multi-city-originals/1.0",
    "-o", localPath,
    imageUrl,
  ], {
    maxBuffer: 1024 * 1024 * 64,
  });
}

function getDimensions(filePath) {
  const output = execFileSync("sips", ["-g", "pixelWidth", "-g", "pixelHeight", filePath], {
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
  });
  const width = Number(output.match(/pixelWidth:\s+(\d+)/)?.[1] || 0);
  const height = Number(output.match(/pixelHeight:\s+(\d+)/)?.[1] || 0);
  return {
    width,
    height,
    text: width && height ? `${width}x${height}` : "未知",
  };
}

function buildApiUrl(plan, offset = 0) {
  const params = new URLSearchParams({
    action: "query",
    format: "json",
    generator: "search",
    gsrnamespace: "6",
    gsrlimit: "20",
    gsroffset: String(offset),
    gsrsearch: `${plan.query} filetype:bitmap`,
    prop: "imageinfo",
    iiprop: "url|size",
  });
  return `https://commons.wikimedia.org/w/api.php?${params.toString()}`;
}

function fileExtensionFromUrl(url) {
  const clean = url.split("?")[0].toLowerCase();
  if (clean.endsWith(".png")) return ".png";
  if (clean.endsWith(".webp")) return ".webp";
  if (clean.endsWith(".jpeg")) return ".jpeg";
  return ".jpg";
}

function normalizeCandidate(page, plan) {
  const info = page?.imageinfo?.[0];
  if (!info?.url || !info.width || !info.height) return null;
  if (info.width < minEdge && info.height < minEdge) return null;

  const title = page.title?.replace(/^File:/, "") || "travel_asset";
  const normalized = title.toLowerCase();
  const banned = [
    "map",
    "flag",
    "logo",
    "diagram",
    "symbol",
    "drawing",
    "illustration",
    "coat of arms",
    "route",
  ];
  if (banned.some((token) => normalized.includes(token))) return null;

  return {
    city: plan.city,
    scene: plan.scene,
    feature: plan.feature,
    title,
    source: "Wikimedia Commons",
    sourcePage: `https://commons.wikimedia.org/wiki/${encodeURIComponent(page.title).replace(/%3A/g, ":")}`,
    imageUrl: info.url,
    width: info.width,
    height: info.height,
  };
}

async function gatherCandidates(existingNames) {
  const candidates = [];
  const seen = new Set(existingNames);

  for (const plan of plans) {
    let added = 0;
    for (const offset of [0, 20]) {
      if (added >= plan.desired) break;
      await sleep(1200);
      let payload;
      try {
        payload = fetchJson(buildApiUrl(plan, offset));
      } catch (error) {
        process.stderr.write(`search skipped: ${plan.scene} ${String(error.message || error)}\n`);
        continue;
      }
      const pages = Object.values(payload?.query?.pages || {});
      for (const page of pages) {
        const item = normalizeCandidate(page, plan);
        if (!item) continue;
        const key = slugify(item.title).toLowerCase();
        if (seen.has(key)) continue;
        seen.add(key);
        candidates.push(item);
        added += 1;
        if (added >= plan.desired) break;
      }
    }
  }

  return candidates;
}

function loadExistingItems() {
  const payload = JSON.parse(execFileSync("cat", [metadataPath], { encoding: "utf8", maxBuffer: 1024 * 1024 * 8 }));
  const items = Array.isArray(payload.items) ? payload.items : [];
  return items.filter((item) => {
    const filePath = path.join(sourceDir, String(item["本地文件"] || "").replace(/^\.\//, ""));
    return filePath && filePath !== sourceDir && filePath !== "." && filePath !== "..";
  });
}

async function downloadNewItems(startIndex, candidates) {
  const newItems = [];

  for (const candidate of candidates) {
    if (startIndex + newItems.length >= targetCount) break;
    const nextIndex = startIndex + newItems.length + 1;
    const fileName = `${String(nextIndex).padStart(3, "0")}_${slugify(candidate.city)}_${slugify(candidate.title)}${fileExtensionFromUrl(candidate.imageUrl)}`;
    const localPath = path.join(sourceDir, fileName);

    try {
      fetchImage(candidate.imageUrl, localPath);
      const dims = getDimensions(localPath);
      if (!dims.width || !dims.height) {
        await fs.rm(localPath, { force: true });
        continue;
      }
      newItems.push({
        "序号": nextIndex,
        "图片名称": candidate.title,
        "场景": `${candidate.city} · ${candidate.scene}`,
        "特点": candidate.feature,
        "尺寸": dims.text,
        "来源": candidate.source,
        "来源页面": candidate.sourcePage,
        "图片URL": candidate.imageUrl,
        "本地文件": `./${fileName}`,
      });
    } catch (error) {
      await fs.rm(localPath, { force: true }).catch(() => {});
      process.stderr.write(`download skipped: ${candidate.title} ${String(error.message || error)}\n`);
    }
  }

  return newItems;
}

function updateExistingItems(items) {
  return items.map((item, index) => {
    const localFile = String(item["本地文件"] || "");
    const filePath = path.join(sourceDir, localFile.replace(/^\.\//, ""));
    const dims = getDimensions(filePath);
    const scene = String(item["场景"] || "东京旅行热点");
    return {
      "序号": index + 1,
      "图片名称": String(item["图片名称"] || path.basename(filePath)),
      "场景": scene.includes("东京") ? scene : `东京 · ${scene}`,
      "特点": String(item["特点"] || "城市旅行,营销宣传"),
      "尺寸": dims.text,
      "来源": String(item["来源"] || "本地素材"),
      "来源页面": String(item["来源页面"] || ""),
      "图片URL": String(item["图片URL"] || ""),
      "本地文件": localFile,
    };
  });
}

function buildHtml(items) {
  const citySet = new Set(
    items
      .map((item) => String(item["场景"] || "") .split(" · ")[0]?.trim())
      .filter((city) => city.length > 0),
  );
  const cityList = Array.from(citySet);
  const heroCityText = cityList.join("、");

  const counts = {};
  for (const item of items) counts[item["场景"]] = (counts[item["场景"]] || 0) + 1;

  const cards = items.map((item) => `
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
      </article>`).join("");

  const rows = items.map((item) => `
      <tr>
        <td>${item["序号"]}</td>
        <td>${escapeHtml(item["场景"])}</td>
        <td>${escapeHtml(item["特点"])}</td>
        <td>${escapeHtml(item["尺寸"])}</td>
        <td>${escapeHtml(item["来源"])}</td>
        <td>${item["图片URL"] ? `<a href="${escapeHtml(item["图片URL"])}" target="_blank" rel="noreferrer">查看</a>` : "-"}</td>
      </tr>`).join("");

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${heroCityText || "日本重点城市"}旅行原图库</title>
  <style>
    :root{--bg:#fff8ef;--panel:rgba(255,255,255,.86);--line:rgba(148,85,0,.12);--text:#2e2016;--muted:#725f4f;--accent:#c2410c;--accent2:#ea580c;--shadow:0 18px 50px rgba(66,32,6,.12);font-family:"Noto Sans SC","PingFang SC",Arial,sans-serif}
    *{box-sizing:border-box}
    body{margin:0;color:var(--text);background:radial-gradient(circle at top,rgba(255,196,87,.32),transparent 28%),radial-gradient(circle at 20% 16%,rgba(255,114,94,.18),transparent 20%),linear-gradient(180deg,#2f140c 0,#7a2615 18%,#f7ebdd 18.2%,#fff8ef 100%)}
    .shell{width:min(1380px,calc(100vw - 32px));margin:0 auto;padding:28px 0 64px}
    .hero{padding:32px;border-radius:28px;color:#fff7ed;background:linear-gradient(135deg,rgba(38,12,6,.92),rgba(124,45,18,.74));box-shadow:var(--shadow)}
    .kicker{display:inline-block;padding:6px 12px;border-radius:999px;background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.18);font-size:12px;letter-spacing:.08em;text-transform:uppercase}
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
      <h1>${heroCityText || "日本重点城市"}旅行原图库</h1>
      <p>保留唯一原图，不做额外尺寸裁剪。当前库覆盖 ${cityList.length} 个城市的旅行营销素材，图片均存储在本地 <code>images/source</code> 并可直接预览。</p>
      <div class="stats">
        <div class="stat"><strong>${items.length}</strong><span>原图总数</span></div>
        <div class="stat"><strong>${citySet.size}</strong><span>覆盖城市</span></div>
        <div class="stat"><strong>0</strong><span>额外裁剪图</span></div>
      </div>
    </section>
    <section class="section">
      <h2>场景分布</h2>
      <ul class="tags">${Object.entries(counts).map(([label, count]) => `<li>${escapeHtml(label)} ${count} 张</li>`).join("")}</ul>
    </section>
    <section class="section">
      <h2>原图预览</h2>
      <div class="grid">${cards}
      </div>
    </section>
    <section class="section">
      <h2>素材清单</h2>
      <div style="overflow:auto;max-height:70vh">
        <table>
          <thead>
            <tr><th>序号</th><th>场景</th><th>特点</th><th>尺寸</th><th>来源</th><th>图片URL</th></tr>
          </thead>
          <tbody>${rows}
          </tbody>
        </table>
      </div>
    </section>
  </main>
</body>
</html>`;
}

async function main() {
  const existing = updateExistingItems(loadExistingItems());
  const existingNames = new Set(existing.map((item) => slugify(item["图片名称"]).toLowerCase()));
  const candidates = await gatherCandidates(existingNames);
  const downloaded = await downloadNewItems(existing.length, candidates);
  const items = [...existing, ...downloaded].slice(0, targetCount).map((item, index) => ({ ...item, "序号": index + 1 }));

  if (items.length < targetCount) {
    throw new Error(`Only prepared ${items.length} images, below target ${targetCount}`);
  }

  await fs.writeFile(metadataPath, `${JSON.stringify({
    generatedAt: new Date().toISOString(),
    total: items.length,
    note: "东京 / 香港 / 新加坡旅行原图库，已去重，仅保留原图，不含额外裁剪版型。",
    items,
  }, null, 2)}\n`, "utf8");

  await fs.writeFile(htmlPath, buildHtml(items), "utf8");

  console.log(JSON.stringify({
    status: "ok",
    total: items.length,
    added: downloaded.length,
    html: htmlPath,
    metadata: metadataPath,
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
