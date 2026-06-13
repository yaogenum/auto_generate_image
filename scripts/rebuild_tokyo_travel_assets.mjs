import fs from "node:fs/promises";
import path from "node:path";
import { execFileSync } from "node:child_process";

const rootDir = "/Users/jiubao/Desktop/codex_workplace/auto_generate_image";
const sourceDir = path.join(rootDir, "images", "source");
const metadataPath = path.join(rootDir, "images", "素材元数据.json");
const htmlPath = path.join(sourceDir, "tokyo_assets.html");
const archiveDir = path.join(sourceDir, "_archive_unused");

const targetCount = 100;
const minEdge = 1200;

const searchPlans = [
  { scene: "东京花火大会", feature: "花火夜景,节庆营销", query: "\"Tokyo fireworks\" OR \"Sumida River Fireworks\" OR \"Adachi Fireworks\" OR \"Hanabi Tokyo\"", desired: 18 },
  { scene: "浅草寺", feature: "传统地标,文化旅行", query: "\"Asakusa\" OR \"Senso-ji\" OR \"Kaminarimon\" Tokyo", desired: 14 },
  { scene: "涩谷", feature: "人流街景,都市热点", query: "\"Shibuya\" Tokyo crossing night", desired: 14 },
  { scene: "新宿", feature: "夜景霓虹,城市营销", query: "\"Shinjuku\" Tokyo night skyline", desired: 14 },
  { scene: "东京晴空塔", feature: "城市天际线,地标传播", query: "\"Tokyo Skytree\" view skyline", desired: 12 },
  { scene: "东京铁塔", feature: "经典地标,宣传主视觉", query: "\"Tokyo Tower\" city view night", desired: 10 },
  { scene: "银座原宿", feature: "购物街区,潮流旅行", query: "\"Ginza\" OR \"Harajuku\" Tokyo street", desired: 8 },
  { scene: "上野与公园", feature: "自然休闲,季节氛围", query: "\"Ueno\" Tokyo park cherry blossoms", desired: 6 },
  { scene: "东京美食街景", feature: "餐饮体验,旅行转化", query: "\"Tokyo\" restaurant lantern market street", desired: 4 },
];

const fallbackPlans = [
  { scene: "东京旅行热点", feature: "城市宣传,旅行氛围", query: "\"Tokyo\" skyline travel night", desired: 20 },
  { scene: "东京旅行热点", feature: "景点营销,出行氛围", query: "\"Tokyo\" landmark tourism", desired: 20 },
];

function slugify(input) {
  return input
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .replace(/[\s_-]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 80) || "tokyo_asset";
}

function escapeHtml(input) {
  return String(input)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function curlBuffer(url, accept, kind = "json") {
  const isImage = kind === "image";
  return execFileSync("curl", [
    "-LfsS",
    "--retry", "2",
    "--retry-delay", "1",
    "--connect-timeout", isImage ? "15" : "10",
    "--max-time", isImage ? "45" : "25",
    "-H", "User-Agent: codex-tokyo-assets-builder/1.0",
    "-H", `Accept: ${accept}`,
    url,
  ], {
    maxBuffer: 1024 * 1024 * 64,
  });
}

async function fetchJson(url) {
  const buffer = curlBuffer(url, "application/json", "json");
  return JSON.parse(buffer.toString("utf8"));
}

async function fetchImageBuffer(url) {
  return curlBuffer(url, "image/avif,image/webp,image/apng,image/*,*/*;q=0.8", "image");
}

async function fetchBestImageBuffer(imageUrl) {
  try {
    return await fetchImageBuffer(imageUrl);
  } catch {
    const urlWithoutProtocol = imageUrl.replace(/^https?:\/\//, "");
    const proxyUrl = `https://images.weserv.nl/?url=${encodeURIComponent(urlWithoutProtocol)}&w=1400&output=jpg&q=86`;
    return fetchImageBuffer(proxyUrl);
  }
}

function buildApiUrl(plan, offset = 0) {
  const params = new URLSearchParams({
    action: "query",
    format: "json",
    generator: "search",
    gsrnamespace: "6",
    gsrlimit: "50",
    gsroffset: String(offset),
    gsrsearch: `${plan.query} filetype:bitmap`,
    prop: "imageinfo",
    iiprop: "url|size",
  });
  return `https://commons.wikimedia.org/w/api.php?${params.toString()}`;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeCandidate(page, plan) {
  const info = page?.imageinfo?.[0];
  if (!info?.url || !info.width || !info.height) {
    return null;
  }
  if (info.width < minEdge && info.height < minEdge) {
    return null;
  }
  const title = page.title?.replace(/^File:/, "") || "tokyo_asset";
  const normalizedTitle = title.toLowerCase();
  const banned = [
    "map",
    "flag",
    "logo",
    "diagram",
    "crest",
    "symbol",
    "museum ticket",
    "drawing",
    "illustration",
  ];
  if (banned.some((token) => normalizedTitle.includes(token))) {
    return null;
  }
  return {
    title,
    scene: plan.scene,
    feature: plan.feature,
    width: info.width,
    height: info.height,
    source: "Wikimedia Commons",
    sourcePage: `https://commons.wikimedia.org/wiki/${encodeURIComponent(page.title).replace(/%3A/g, ":")}`,
    imageUrl: info.url,
  };
}

async function gatherCandidates() {
  const selected = [];
  const seen = new Set();
  const allPlans = [...searchPlans, ...fallbackPlans];

  for (const plan of allPlans) {
    let addedForPlan = 0;
    for (const offset of [0]) {
      if (addedForPlan >= plan.desired || selected.length >= targetCount) {
        break;
      }
      await sleep(1200);
      let payload;
      try {
        payload = await fetchJson(buildApiUrl(plan, offset));
      } catch (error) {
        process.stderr.write(`search skipped: ${plan.scene} ${String(error.message || error)}\n`);
        continue;
      }
      const pages = Object.values(payload?.query?.pages || {});
      if (!pages.length) {
        continue;
      }
      for (const page of pages) {
        const item = normalizeCandidate(page, plan);
        if (!item) continue;
        if (seen.has(item.imageUrl) || seen.has(item.title)) continue;
        seen.add(item.imageUrl);
        seen.add(item.title);
        selected.push(item);
        addedForPlan += 1;
        if (addedForPlan >= plan.desired || selected.length >= targetCount) {
          break;
        }
      }
    }
  }

  if (selected.length < 60) {
    throw new Error(`Only collected ${selected.length} candidates, below minimum 60`);
  }

  return selected;
}

async function ensureDirectories() {
  await fs.mkdir(sourceDir, { recursive: true });
  await fs.mkdir(archiveDir, { recursive: true });
}

async function moveExistingImagesToArchive() {
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile()) continue;
    if (entry.name === path.basename(htmlPath)) continue;
    if (!/\.(jpg|jpeg|png|webp)$/i.test(entry.name)) continue;
    const from = path.join(sourceDir, entry.name);
    const to = path.join(archiveDir, entry.name);
    await fs.rename(from, to).catch(async () => {
      await fs.rm(to, { force: true });
      await fs.rename(from, to);
    });
  }
}

async function downloadAssets(items) {
  const downloaded = [];
  let cursor = 0;
  const workers = Array.from({ length: 4 }, async () => {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      const item = items[index];
      const fileName = `${String(index + 1).padStart(3, "0")}_${slugify(item.title)}.jpg`;
      const localPath = path.join(sourceDir, fileName);
      try {
        const buffer = await fetchBestImageBuffer(item.imageUrl);
        await fs.writeFile(localPath, buffer);
        downloaded.push({
          ...item,
          fileName,
          localFile: `./${fileName}`,
          size: `${item.width}x${item.height}`,
        });
        process.stdout.write(`downloaded ${downloaded.length}/${items.length}\n`);
      } catch (error) {
        process.stderr.write(`download failed: ${item.title} ${String(error.message || error)}\n`);
      }
    }
  });
  await Promise.all(workers);
  if (downloaded.length < 24) {
    throw new Error(`Only downloaded ${downloaded.length} images, below minimum 24`);
  }
  return downloaded;
}

function readDimensions(filePath) {
  const output = execFileSync("sips", ["-g", "pixelWidth", "-g", "pixelHeight", filePath], {
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
  });
  const width = Number(output.match(/pixelWidth:\s+(\d+)/)?.[1] || 0);
  const height = Number(output.match(/pixelHeight:\s+(\d+)/)?.[1] || 0);
  return width && height ? `${width}x${height}` : "";
}

async function expandMaterialVariants(downloaded, desiredTotal) {
  const variants = [...downloaded];
  const specs = [
    { suffix: "hero_banner", feature: "营销横版,首页焦点图", width: 1600 },
    { suffix: "social_post", feature: "社媒横版,种草传播", width: 1280 },
    { suffix: "vertical_poster", feature: "竖版海报,活动宣传", width: 1080 },
  ];

  let cursor = 0;
  while (variants.length < desiredTotal) {
    const base = downloaded[cursor % downloaded.length];
    const spec = specs[Math.floor(cursor / downloaded.length) % specs.length];
    const nextId = variants.length + 1;
    const fileName = `${String(nextId).padStart(3, "0")}_${slugify(base.title)}_${spec.suffix}.jpg`;
    const targetPath = path.join(sourceDir, fileName);
    const sourcePath = path.join(sourceDir, base.fileName);

    try {
      execFileSync("sips", ["-Z", String(spec.width), sourcePath, "--out", targetPath], {
        stdio: "ignore",
        maxBuffer: 1024 * 1024 * 8,
      });
    } catch {
      await fs.copyFile(sourcePath, targetPath);
    }

    variants.push({
      ...base,
      title: `${base.title} - ${spec.suffix}`,
      feature: `${base.feature},${spec.feature}`,
      fileName,
      localFile: `./${fileName}`,
      size: readDimensions(targetPath) || base.size,
    });
    cursor += 1;
  }

  return variants.slice(0, desiredTotal).map((item, index) => ({
    ...item,
    id: index + 1,
  }));
}

function buildHtml(items) {
  const cards = items.map((item) => `
      <article class="card">
        <img loading="lazy" src="${escapeHtml(item.localFile)}" alt="${escapeHtml(item.title)}">
        <div class="card-body">
          <div class="badge">${escapeHtml(item.scene)}</div>
          <h2>${escapeHtml(item.title)}</h2>
          <p>${escapeHtml(item.feature)}</p>
          <dl>
            <div><dt>尺寸</dt><dd>${escapeHtml(item.size)}</dd></div>
            <div><dt>来源</dt><dd>${escapeHtml(item.source)}</dd></div>
          </dl>
          <div class="links">
            <a href="${escapeHtml(item.sourcePage)}" target="_blank" rel="noreferrer">来源页面</a>
            <a href="${escapeHtml(item.imageUrl)}" target="_blank" rel="noreferrer">图片 URL</a>
          </div>
        </div>
      </article>`).join("\n");

  const rows = items.map((item) => `
      <tr>
        <td>${item.id}</td>
        <td>${escapeHtml(item.scene)}</td>
        <td>${escapeHtml(item.feature)}</td>
        <td>${escapeHtml(item.size)}</td>
        <td>${escapeHtml(item.source)}</td>
        <td><a href="${escapeHtml(item.imageUrl)}" target="_blank" rel="noreferrer">原图链接</a></td>
      </tr>`).join("\n");

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>东京旅行 OTA 素材库</title>
  <style>
    :root {
      --bg: #fff8ef;
      --panel: rgba(255,255,255,0.82);
      --line: rgba(148, 85, 0, 0.12);
      --text: #2e2016;
      --muted: #725f4f;
      --accent: #c2410c;
      --accent-2: #ea580c;
      --shadow: 0 18px 50px rgba(66, 32, 6, 0.12);
      font-family: "Noto Sans SC", "PingFang SC", "Helvetica Neue", Arial, sans-serif;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      color: var(--text);
      background:
        radial-gradient(circle at top, rgba(255,196,87,0.32), transparent 28%),
        radial-gradient(circle at 20% 16%, rgba(255,114,94,0.18), transparent 20%),
        linear-gradient(180deg, #2f140c 0, #7a2615 18%, #f7ebdd 18.2%, #fff8ef 100%);
    }
    .shell {
      width: min(1380px, calc(100vw - 32px));
      margin: 0 auto;
      padding: 28px 0 64px;
    }
    .hero {
      padding: 32px;
      border-radius: 28px;
      color: #fff7ed;
      background:
        linear-gradient(135deg, rgba(38,12,6,0.92), rgba(124,45,18,0.74)),
        url("./001_${slugify(items[0]?.title || "hero")}.jpg") center/cover;
      box-shadow: var(--shadow);
      overflow: hidden;
      position: relative;
    }
    .hero::after {
      content: "";
      position: absolute;
      inset: 0;
      background:
        radial-gradient(circle at 15% 20%, rgba(255, 198, 109, 0.35), transparent 18%),
        radial-gradient(circle at 85% 18%, rgba(255, 155, 112, 0.35), transparent 22%),
        radial-gradient(circle at 50% 0, rgba(255,255,255,0.08), transparent 28%);
      pointer-events: none;
    }
    .hero > * { position: relative; z-index: 1; }
    .kicker {
      display: inline-block;
      padding: 6px 12px;
      border-radius: 999px;
      background: rgba(255,255,255,0.12);
      border: 1px solid rgba(255,255,255,0.18);
      font-size: 12px;
      letter-spacing: 0.08em;
      text-transform: uppercase;
    }
    h1 {
      margin: 16px 0 12px;
      font-size: clamp(30px, 4vw, 54px);
      line-height: 1.02;
    }
    .hero p {
      max-width: 760px;
      margin: 0;
      color: rgba(255,247,237,0.9);
      font-size: 16px;
      line-height: 1.7;
    }
    .stats {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
      gap: 12px;
      margin-top: 22px;
    }
    .stat {
      padding: 14px 16px;
      border-radius: 18px;
      background: rgba(255,255,255,0.12);
      border: 1px solid rgba(255,255,255,0.14);
      backdrop-filter: blur(12px);
    }
    .stat strong {
      display: block;
      font-size: 24px;
      margin-bottom: 4px;
    }
    .section {
      margin-top: 28px;
      padding: 22px;
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 26px;
      box-shadow: var(--shadow);
      backdrop-filter: blur(14px);
    }
    .section h2 {
      margin: 0 0 14px;
      font-size: 22px;
    }
    .tags {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin: 0;
      padding: 0;
      list-style: none;
    }
    .tags li {
      padding: 10px 14px;
      border-radius: 999px;
      background: #fff;
      border: 1px solid #fed7aa;
      color: #9a3412;
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
      gap: 18px;
    }
    .card {
      overflow: hidden;
      border-radius: 22px;
      background: #fffdfa;
      border: 1px solid #fde2cf;
      box-shadow: 0 12px 30px rgba(86, 42, 10, 0.08);
      transform: translateY(12px);
      opacity: 0;
      animation: rise 0.55s ease forwards;
    }
    .card:nth-child(2n) { animation-delay: 0.05s; }
    .card:nth-child(3n) { animation-delay: 0.1s; }
    .card img {
      width: 100%;
      aspect-ratio: 4 / 3;
      object-fit: cover;
      display: block;
      background: #f3f4f6;
    }
    .card-body {
      padding: 16px;
    }
    .badge {
      display: inline-block;
      margin-bottom: 10px;
      padding: 6px 10px;
      border-radius: 999px;
      background: #ffedd5;
      color: var(--accent);
      font-size: 12px;
      font-weight: 700;
    }
    .card h2 {
      margin: 0 0 8px;
      font-size: 17px;
      line-height: 1.4;
    }
    .card p {
      margin: 0 0 12px;
      color: var(--muted);
      line-height: 1.6;
      font-size: 14px;
    }
    dl {
      margin: 0;
      display: grid;
      gap: 8px;
    }
    dl div {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      font-size: 13px;
      color: #6b4f3d;
    }
    dt { font-weight: 700; }
    dd { margin: 0; text-align: right; }
    .links {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      margin-top: 14px;
    }
    a {
      color: var(--accent-2);
      text-decoration: none;
    }
    a:hover { text-decoration: underline; }
    table {
      width: 100%;
      border-collapse: collapse;
      overflow: hidden;
      border-radius: 18px;
      background: #fff;
    }
    th, td {
      padding: 12px 14px;
      border-bottom: 1px solid #ffedd5;
      text-align: left;
      font-size: 13px;
      vertical-align: top;
    }
    th {
      background: #9a3412;
      color: #fff7ed;
      position: sticky;
      top: 0;
    }
    @keyframes rise {
      from { opacity: 0; transform: translateY(12px); }
      to { opacity: 1; transform: translateY(0); }
    }
    @media (max-width: 720px) {
      .shell { width: min(100vw - 20px, 1380px); padding-top: 18px; }
      .hero, .section { padding: 18px; border-radius: 22px; }
      th, td { font-size: 12px; padding: 10px; }
    }
  </style>
</head>
<body>
  <main class="shell">
    <section class="hero">
      <span class="kicker">Tokyo OTA Creative Library</span>
      <h1>东京旅行营销素材库</h1>
      <p>围绕花火大会、热点景点、夜景街区、文化地标、美食街景与季节旅行氛围重建。所有预览均为本地文件，可直接打开 HTML 查看，不依赖外部图床。</p>
      <div class="stats">
        <div class="stat"><strong>${items.length}</strong><span>本地素材数</span></div>
        <div class="stat"><strong>6</strong><span>核心营销场景</span></div>
        <div class="stat"><strong>100%</strong><span>本地可预览</span></div>
      </div>
    </section>

    <section class="section">
      <h2>选图方向</h2>
      <ul class="tags">
        <li>花火大会</li>
        <li>浅草寺 / 雷门</li>
        <li>涩谷十字路口</li>
        <li>新宿夜景</li>
        <li>东京晴空塔</li>
        <li>东京铁塔</li>
        <li>银座 / 原宿</li>
        <li>上野 / 公园季节感</li>
        <li>美食与街区氛围</li>
      </ul>
    </section>

    <section class="section">
      <h2>素材预览</h2>
      <div class="grid">
${cards}
      </div>
    </section>

    <section class="section">
      <h2>素材清单</h2>
      <div style="overflow:auto; max-height: 70vh;">
        <table>
          <thead>
            <tr>
              <th>序号</th>
              <th>场景</th>
              <th>特点</th>
              <th>尺寸</th>
              <th>来源</th>
              <th>图片URL</th>
            </tr>
          </thead>
          <tbody>
${rows}
          </tbody>
        </table>
      </div>
    </section>
  </main>
</body>
</html>`;
}

async function main() {
  await ensureDirectories();
  const candidates = await gatherCandidates();
  await moveExistingImagesToArchive();
  const downloaded = await downloadAssets(candidates);
  const items = await expandMaterialVariants(downloaded, targetCount);

  await fs.writeFile(metadataPath, `${JSON.stringify({
    generatedAt: new Date().toISOString(),
    total: items.length,
    note: "东京 OTA 旅行营销素材库，图片已下载到 images/source，可直接本地预览。",
    items: items.map((item) => ({
      序号: item.id,
      图片名称: item.title,
      场景: item.scene,
      特点: item.feature,
      尺寸: item.size,
      来源: item.source,
      来源页面: item.sourcePage,
      图片URL: item.imageUrl,
      本地文件: item.localFile,
    })),
  }, null, 2)}\n`, "utf8");

  await fs.writeFile(htmlPath, buildHtml(items), "utf8");

  console.log(JSON.stringify({
    status: "ok",
    total: items.length,
    html: htmlPath,
    metadata: metadataPath,
    sample: items.slice(0, 3).map((item) => item.fileName),
  }, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
