# Version History

This file records product and implementation iterations for the Cartoon World iOS app.

## 0.3.14 - 2026-06-23

### Scope

修复家人页视觉重复和底部输入区拥挤问题。

### Changed

- 删除家人页右上角重复的家人管理工具栏入口，避免和当前家人 Tab/页面主入口语义重复。
- 增加紧凑聊天卡片与展开聊天卡片的底部间距，避免输入框和底部 TabBar 贴近或重叠。

### Verification

- `./scripts/build_ios.sh` 成功。
- 已安装到当前 Booted Simulator 并截图验证：
  - `artifacts/family-spacing-0.3.14-wait.png`
  - 顶部右侧重复家人入口已删除。
  - 底部输入框与 TabBar 已拉开间距。

## 0.3.13 - 2026-06-22

### Scope

补强功能巡检链路：在无法使用真实 Simulator 点击工具时，把自动动线做成可观察的阶段化巡检，确保每个核心页面都能被截图和人工复核。

### Changed

- 自动巡检增加 8 个阶段标记：
  - 家人关系网络
  - 分身代聊
  - 东京地点
  - 大阪 Moments
  - 香港家人互动
  - 记录 Moment
  - 分身控制台
  - 回到家人
- 自动巡检期间左上角显示 `巡检` 状态徽标，方便截图判断当前覆盖的功能动线。
- 世界页支持运行时响应巡检传入的城市、展示模式、面板、POI 状态，不再只依赖启动时初始值。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh && ./scripts/qa_verify_screenshots.sh` 成功：
  - `PASS_COUNT=17`
  - `FAIL_COUNT=0`
  - `RESULT=OK`
- 自动动线巡检通过：
  - 输出目录：`artifacts/function-check-0.3.13b/`
  - 拼图：`artifacts/function-check-0.3.13b/contact-sheet.png`
  - 覆盖家人关系网络、分身代聊、东京地点、大阪 Moments、香港家人互动、记录 Moment、分身控制台、回到家人。

## 0.3.12 - 2026-06-22

### Scope

围绕整体功能做全面简化：将产品动线收敛为“家人关系 → 地点世界 → Moment 记录 → 分身控制台”，减少世界页和身份页的信息混杂。

### Changed

- Tab 信息架构简化：
  - `上传` 改为 `记录`，聚焦创建地点 Moment。
  - `身份` 改为 `分身`，聚焦我的数字分身控制台。
- 世界页三面板收敛：
  - `探索` 改为 `地点`，只负责城市/渲染/POI/图片合集。
  - `Moments` 只负责地点时刻列表和城市热区。
  - `关系网络` 改为 `家人互动`，只负责当前地点关联家人、聊天摘要和去聊天入口。
- 上传/记录页闭环：
  - 上传照片/视频后同时创建地图素材和一条 `FamilyMoment`。
  - 按当前地点绑定到世界页，自动进入地图/Moments/家人互动链路。
- 分身页重排：
  - 代理策略与待确认 issue 前置。
  - 身份资料退到“身份档案”区域。
  - 新增最近代办/最近家人消息摘要，强化“我的分身控制台”定位。
- QA 参数兼容：
  - `CARTOON_INITIAL_WORLD_PANEL_SECTION` 兼容旧值 `探索/关系网络` 和新值 `地点/家人互动`。
  - 截图脚本同步使用新面板文案。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh` 成功。
- `./scripts/qa_verify_screenshots.sh` 成功：
  - `PASS_COUNT=17`
  - `FAIL_COUNT=0`
  - `RESULT=OK`

## 0.3.11 - 2026-06-21

### Scope

优化家人会话页红框区域：把对方路由文案改成可理解的在线状态，并把底部通话控制默认收起，减少聊天区遮挡和按钮噪音。

### Changed

- 家人状态展示：
  - 新增 `真人未登录` 状态，UI 显示为红色 `真人离线`。
  - `线上Agent` / `真人用户` 不再直接暴露为刻意标签，改为绿色 `对方在线` / `真人在线`。
  - `本机Agent` 改为 `本机模拟`，明确这是当前本机 Demo 能力。
- 家人页头部操作：
  - 原来的“路由/语音/视频/展开”一排按钮收敛为“展开/收起 + 更多”。
  - 更多菜单内承载状态切换、模拟来信、语音、视频。
- 聊天输入区：
  - 默认只展示输入框、通话入口、发送按钮。
  - 点击通话入口后再展开语音/视频，执行后自动收起。
- QA 支撑：
  - 新增 `CARTOON_INITIAL_FAMILY_CALL_TRAY_EXPANDED` 与 `CARTOON_INITIAL_FAMILY_CONTACT_ENDPOINT` 启动参数，便于固定复现状态和截图。
  - `scripts/capture_screenshots.sh` 增加 `family_human_offline_status` 与 `family_call_tray_expanded`。
  - 名古屋截图增加额外等待，避免 MapKit/素材加载慢导致白屏快照。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh` 成功，生成 17 张关键截图。
- 自动截图质检发现并修复 `world_nagoya_explore.png` 白屏问题，复抓后恢复正常。

## 0.1.0 - 2026-06-13

### Scope

Initial playable SwiftUI prototype for a cartoon 3D world map app, starting from Shanghai.

### Added

- Created `CartoonWorld.xcodeproj` as the iOS app project.
- Added SwiftUI app entry and tab shell:
  - World map
  - Media upload
  - Digital person profile
- Built a Shanghai seed world using real coordinates:
  - The Bund
  - Lianhua Road life circle
  - Lujiazui
  - Xujiahui
  - People's Square
  - Century Park
- Added MapKit-based world map with realistic elevation style.
- Added cartoon 3D overlay with isometric ground tiles and stylized building clusters.
- Added place pins, place carousel, selected-place camera focus, and cartoon layer toggle.
- Added digital person model:
  - Random guest profile when unregistered
  - Editable registered profile
  - Avatar mood and energy state
  - Daily actions per place
- Added photo/video upload flow using `PhotosPicker`.
- Added local contribution pipeline:
  - Select media
  - Assign to a Shanghai place
  - Generate local thumbnail and color palette
  - Simulate queued, stylizing, and integrated states
- Added local persistence for profile and contributions through `UserDefaults`.
- Added README with project purpose, current features, build command, and next architecture steps.

### Verification

- Swift syntax parse passed for all app source files using `swiftc -parse`.
- Xcode project plist validation passed with `plutil`.
- Asset catalog JSON validation passed with `python3 -m json.tool`.

### Known Limitations

- Full iOS build and simulator launch were not run because the current machine only has Command Line Tools selected and no full Xcode/iOS SDK available.
- Cartoonization is currently a local simulated pipeline, not an AI/backend generation service.
- Media is stored locally in lightweight form; production storage should move to object storage or a database-backed asset service.
- The 3D city layer is SwiftUI-rendered; RealityKit/SceneKit city exploration is a future expansion.

### Next Candidates

- Add real backend account registration and sync.
- Add server-side cartoonization job API.
- Add persistent map asset service with geospatial indexing.
- Add RealityKit place-entry mode for true 3D walking exploration.
- Expand the Shanghai seed map with district-level chunks and POI categories.

## 0.1.1 - 2026-06-13

### Scope

Xcode verification and local developer workflow hardening.

### Changed

- Added an explicit shared Xcode scheme for `CartoonWorld`.
- Added explicit iOS/iOS Simulator supported platform settings to the Xcode project.
- Fixed the thumbnail border drawing call in `WorldModel`.
- Removed unnecessary `await` usage in local contribution status advancement.
- Added `scripts/build_ios.sh` for repeatable simulator builds.
- Added `scripts/run_ios_sim.sh` to build, create or reuse a simulator, install, and launch the app when an iOS Simulator runtime is available.
- Updated README build/run commands to use the scripts.
- Set Debug `ONLY_ACTIVE_ARCH` to `NO` so target-based simulator builds do not emit active-architecture warnings.

### Verification

- `xcodebuild -project CartoonWorld.xcodeproj -target CartoonWorld -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO` succeeded.
- Generated app path: `build/Debug-iphonesimulator/CartoonWorld.app`.

### Known Limitations

- Simulator launch could not be completed because no available iOS Simulator runtime is currently installed or registered in CoreSimulator; `xcrun simctl list runtimes available` returned no iOS runtimes.

## 0.1.2 - 2026-06-13

### Scope

Simulator runtime detection and launch workflow repair.

### Changed

- Fixed `scripts/run_ios_sim.sh` runtime parsing for Xcode 26.3 / iOS 26.3 output.
- Fixed booted simulator UDID parsing by stripping parentheses from `simctl` text output.
- Changed the run script to prefer an already booted `CartoonWorld-iPhone`, then any booted simulator, before creating a new simulator.
- Added pre-install cleanup in the run script:
  - Terminate existing `com.codex.CartoonWorld` process.
  - Uninstall existing `com.codex.CartoonWorld` app.
  - Install the freshly built app.
  - Launch the app.

### Verification

- `xcrun simctl list runtimes available` now detects `iOS 26.3`.
- `./scripts/run_ios_sim.sh` succeeded end to end.
- App launched on Simulator with process id `22937`.
- Captured simulator screenshot at `artifacts/cartoonworld-simulator.png` and verified the map, cartoon city overlay, digital avatar panel, and tab bar render correctly.

### Notes

- Earlier install hangs were caused by stale/multiple booted simulator state plus install coordination conflicts. Keeping one booted simulator and uninstalling the existing bundle before install resolved it.

## 0.2.0 - 2026-06-13

### Scope

Reworked the world page from a map-first prototype into a true 3D digital cartoon world.

### Changed

- Replaced the MapKit-first world surface with a SceneKit-powered 3D scene.
- Added `CartoonWorldSceneView` as the primary world renderer.
- Translated real Shanghai coordinate seed data into local 3D world positions.
- Added 3D world geometry:
  - Ground platform
  - River/water band
  - Road network
  - Stylized building clusters
  - Park trees
  - Transit hub geometry
  - Lifestyle district shapes
  - Animated digital avatar
  - Selected-place ring
  - Contribution beacon geometry
  - Ambient and directional lighting
- Enabled camera orbit controls through `SCNView`.
- Removed in-scene text labels after visual QA showed they cluttered and flattened the 3D world.
- Kept place chips and the avatar panel as the 2D control layer over the 3D world.
- Updated README wording to describe the app as a 3D digital cartoon world, not a map overlay.

### Verification

- `./scripts/run_ios_sim.sh` built, installed, and launched successfully.
- App launched successfully through `./scripts/run_ios_sim.sh`.
- Captured `artifacts/cartoonworld-3d-world-v2-wait.png`.
- Visual QA confirmed the world tab now shows a rendered 3D cartoon city scene rather than a 2D map background.

## 0.2.1 - 2026-06-13

### Scope

Redrew the 3D world after visual QA feedback that the first SceneKit version was too plain and unattractive.

### Changed

- Reworked the world art direction toward a stylized anime open-world diorama reference:
  - Larger floating island
  - Broad ocean backdrop
  - Mountain range
  - River and harbor zones
  - Warm paths and crosswalk highlights
  - Brighter clouds and glowing contribution beacons
- Replaced generic square place bases with octagonal place platforms.
- Added place-specific landmarks:
  - Bund fantasy street block
  - Lujiazui fantasy skyline with pearl tower silhouette
  - People's Square transit hub
  - Century Park pond and denser trees
- Added layered fantasy roofs, warmer lit windows, lanterns, piers, boats, and more varied city silhouettes.
- Adjusted camera orthographic scale and Shanghai coordinate scale so the world reads as one cohesive 3D cartoon scene on mobile.
- Expanded the ocean plane so its edge no longer appears as a large blue diamond in the camera view.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `./scripts/run_ios_sim.sh` built, installed, and launched successfully.
- Captured `artifacts/cartoonworld-3d-genshin-inspired-v2.png`.
- Visual QA confirmed the world is now a 3D floating cartoon city scene with terrain, harbor, mountain, landmark, avatar, and interaction overlays.

## 0.2.2 - 2026-06-13

### Scope

Shifted the world experience toward a stronger open-world interaction model and added a real 3D map fallback after the cartoon art direction still failed visual expectations.

### Changed

- Added `WorldCity` and expanded `WorldPlace` with explicit city ownership.
- Replaced the Shanghai-only seed with `WorldSeed`:
  - Shanghai expanded from 6 to 15 places.
  - Tokyo added with 12 initial places.
  - Total city nodes now cover landmarks, transport hubs, parks, neighborhoods, and lifestyle zones.
- Added world mode switching on the world screen:
  - `真实3D` uses MapKit hybrid realistic elevation.
  - `卡通沙盘` keeps the SceneKit fantasy cartoon world.
- Added city switching between Shanghai and Tokyo.
- Added open-world-inspired interaction structure:
  - Exploration progress
  - Current tracked objective
  - Place discovery chips
  - Tap-to-track map annotations
  - Quick action button for the selected place
- Updated profile stats from Shanghai-only wording to dual-city wording.

### Verification

- `./scripts/build_ios.sh` succeeded after the data model, MapKit, and UI changes.
- Simulator install/launch verification was attempted but blocked by CoreSimulator install service instability:
  - `simctl install` returned an InstallCoordination promise error on one booted device.
  - A second device attempt hung during install and was terminated.
  - The generated screenshot `artifacts/cartoonworld-real3d-shanghai.png` showed the Simulator home screen, not the app, so it is not accepted as visual QA evidence.

### Notes

- The code build is valid, but current local Simulator installation state needs cleanup before visual QA. Recommended cleanup path: quit Simulator, run `xcrun simctl shutdown all`, erase the target simulator from Simulator.app or `xcrun simctl erase <UDID>`, then retry `./scripts/run_ios_sim.sh`.

## 0.2.3 - 2026-06-13

### Scope

Made the world overlay collapsible after visual QA showed the expanded exploration controls blocked too much of the 3D map.

### Changed

- Added an expandable/collapsible bottom exploration panel on the world screen.
- Expanded mode keeps the full controls:
  - City switch
  - Display mode switch
  - Stats
  - World header
  - Quest tracker
  - Place carousel
  - Avatar panel
- Collapsed mode now shows only a compact status strip:
  - Current city
  - Selected place
  - Display mode
  - Exploration percentage
- Added a clear `展开` / `收起` button with chevron icon.
- Added animated bottom transition so the map becomes usable immediately after collapse.

### Verification

- `./scripts/build_ios.sh` succeeded.

## 0.2.4 - 2026-06-13

### Scope

Added Hong Kong as the third supported city and continued UI cleanup before another simulator run.

### Changed

- Added `香港` to `WorldCity`.
- Expanded `WorldSeed` with 12 Hong Kong places:
  - Central
  - Victoria Harbour
  - Victoria Peak
  - Tsim Sha Tsui
  - Mong Kok
  - Causeway Bay
  - Wan Chai
  - Hong Kong International Airport
  - Hong Kong Station
  - Lantau Island
  - West Kowloon Cultural District
  - Sha Tin
- Total seeded city nodes increased from 27 to 39.
- Changed the world exploration panel to default collapsed so the map is visible on first launch.
- Changed the world screen default city to Hong Kong for immediate verification of the new city.
- Added Hong Kong-specific real 3D map camera distance and heading.
- Updated upload copy and place menu labels to include city names.
- Updated profile stats from dual-city wording to three-city wording.
- Tightened the collapsed world panel height and hid the world navigation bar so the 3D map gets the full first screen.
- Hardened `scripts/run_ios_sim.sh` with timeout-protected `simctl` operations so simulator hangs do not block indefinitely.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `SIMCTL_TIMEOUT=20 ./scripts/run_ios_sim.sh` succeeded and launched the app in the booted iPhone 16e Simulator.
- Captured visual QA screenshot: `artifacts/cartoonworld-hongkong-open-v3.png`.

## 0.2.5 - 2026-06-14

### Scope

Reviewed the app shell and world-screen interaction after the three-city expansion, then improved first-screen controls and SwiftUI state handling.

### Changed

- Added a compact world HUD over the map so the hidden navigation bar no longer removes all screen identity.
- Added quick city selection from the HUD without requiring the exploration panel to expand.
- Added one-tap display-mode switching between `真实3D` and `卡通沙盘` from the HUD.
- Compressed the HUD after visual review so it keeps quick controls without covering as much of the map.
- Persisted the last selected city and display mode with `AppStorage`.
- Reduced repeated contribution filtering in the world screen by precomputing place contribution counts once per render.
- Kept the bottom exploration panel collapsed by default and reserved expanded mode for deeper controls, quest tracking, place chips, and avatar status.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `SIMCTL_TIMEOUT=20 ./scripts/run_ios_sim.sh` succeeded and launched the app in the booted iPhone Simulator.
- Initial screenshot immediately after launch was blank white while the app was still presenting its first frame, so it was rejected as QA evidence.
- Captured accepted visual QA screenshot after the map rendered: `artifacts/cartoonworld-025-hud-compact.png`.

## 0.2.6 - 2026-06-20

### Scope

Reduced persistent HUD occlusion by allowing full interface collapse after repeated user feedback about panel blocking.

### Changed

- Added a global map UI visibility toggle in `WorldMapView`:
  - `收起界面`: hides all top and bottom world overlay controls in one action.
  - `展开界面`: restores control layer from a compact floating button.
- Kept existing bottom panel expansion (`展开`/`收起`) and city/mode controls in normal mode.
- Reset expanded state when entering hidden mode to avoid stale panel transitions.

### Notes

- This change is a direct usability improvement requested from prior visual feedback about overlay obstruction.

## 0.3.0 - 2026-06-20

### Scope

Implemented family communication and social lifecycle features in the core iOS app flow.

### Changed

- Added family relationship models and persistence:
  - `FamilyMember` with contact, birthday, weekly cadence, and self identity.
  - `FamilyMessage` and `FamilyMoment` for per-family chat logs and mapped life moments.
  - New persisted state in `WorldModel` (`familyMembers`, `selectedFamilyMemberID`, `conversations`, `moments`).
- Added `FamilyHubView` as the default first tab:
  - Top horizontal contact ribbon (including `自己`) as the default entry context.
  - Chat panel for selected member with message input.
  - Family communication actions (语音/视频) using FaceTime when phone contact is configured.
  - Bottom segment panel for `Moments` and `地图` to browse logs and record shared travel events.
- Added family maintenance sheet:
  - Create/edit/remove family members.
  - Maintain relationship, contact, birthday, and weekly fixed-communication cadence.
- Added startup and periodic scene hints:
  - Birthday reminders and weekly communication reminders.
  - Added `refreshFamilyScenePrompts()` in bootstrap flow.
- Added app tab default switch so users open directly into family view.

### Verification

- `./scripts/build_ios.sh` succeeded.
- `./scripts/run_ios_sim.sh` succeeded and launched the app on the available iOS simulator.
- Captured visual artifact at `artifacts/cartoonworld-family-hub.png`.

## 0.3.1 - 2026-06-20

### Scope

迭代家庭中心体验的默认入口行为与鲁棒性，满足“默认进入自己的数字分身”与“稳定沟通”。

### Changed

- 在家庭能力首次启动时强制选中“自己”账号为默认联系人（`FamilyHub` 首屏始终进入自身数字分身），并持久记录该初始化标记，避免影响用户后续手动选中记忆。
- 加强空数据兜底：`selectedFamilyMember` 在异常情况下返回一个可用的自身成员模型，避免列表被损坏时产生崩溃。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/run_ios_sim.sh` 成功，并能在可用模拟器中安装启动。
- 最新联系人默认行为可通过 FamilyHub 打开截图验证。

## 0.3.2 - 2026-06-20

### Scope

家庭页优化（你当前反馈）：

- 联系人区域从单行布局改为两种结构视图：拓扑图与横向列表切换。
- 家人关系拓扑增加“新增家人”入口，并展示关系标签。
- 中间对话框加入简略/展开态：
  - 简略态只展示核心信息与最近消息，界面更紧凑。
  - 点击“展开”后，对话面板进入放大态，占满家人页面主体。
  - 仍保留语音/视频发起入口，并在展开态补充身份关系与沟通提醒信息。

### Changed

- 更新 `CartoonWorld/FamilyHubView.swift`：
  - 新增 `contactLayout` 状态与 `FamilyContactLayout` 枚举，驱动 `Picker` 切换。
  - 重构 `body`：`isChatExpanded` 为 true 时隐藏联系人区块，专注渲染全屏聊天面板。
  - 新增 `compactChatPanel` 与 `expandedChatPanel`，并统一消息显示策略（简略显示最近 4 条，展开显示全部）。
  - 修复 `topologyLayout` 的编译稳定性问题，改为显式构建布局字典，避免类型推断超时。
- 切换联系人时自动重置展开态，保证行为一致。

### Verification

- `./scripts/build_ios.sh` 成功。
- 在 Booted 模拟器（`EFCBDF14-657B-4C89-BF09-9E896E0C27AB`）上安装并启动：
  - `xcrun simctl install ... build/Debug-iphonesimulator/CartoonWorld.app`
  - `xcrun simctl launch ... com.codex.CartoonWorld`
- 已抓图：`/tmp/cartoonworld-family.png`。

## 0.3.3 - 2026-06-21

### Scope

扩充世界多城市地标内容，并把本地东京、大阪、名古屋、香港素材真正融合到地图详情与 Moments / 家人互动链路中。

### Changed

- 世界种子扩展：
  - `WorldSeed` 新增 `大阪` 与 `名古屋` 两座城市。
  - 现已覆盖 `上海 / 东京 / 大阪 / 名古屋 / 香港` 五城。
  - 为大阪补充 10 个地标与生活节点，包括大阪城、梅田空中庭园、道顿堀、大阪站城等。
  - 为名古屋补充 10 个地标与生活节点，包括名古屋城、名古屋站、荣商圈、大须、热田神宫等。
- 资源接入改造：
  - 将整个 `images` 目录加入 iOS app bundle。
  - 新增 `素材元数据.json` 解析与城市 / 地标关键字映射。
  - 启动时自动把本地素材清单导入为地图贡献素材，并按 POI 归位。
- 地图详情增强：
  - 世界页点击地标后会自动展开探索面板。
  - 新增“当前地标详情”区块，按顺序展示：
    - 图片合集（左图右文列表）
    - 该地标关联 Moments
    - 与家人的互动 / 聊天 demo
  - 城市切换控件改为横向滚动胶囊条，避免五城后分段控件过挤。
- 叙事 demo：
  - 若本地没有家人样本，会自动注入 `妈妈 / 姐姐` demo 角色。
  - 为上海、东京、大阪、名古屋、香港各补一组地标 Moments 与聊天映射示例。
- 其他修正：
  - 为大阪 / 名古屋补充真实 3D 地图相机参数。
  - 更新上传页文案，覆盖五城。
  - 清理 `FamilyHubView` 中一条未使用变量 warning。

### Verification

- `./scripts/build_ios.sh` 成功。
- `SIMCTL_TIMEOUT=30 ./scripts/run_ios_sim.sh` 成功，并在当前 booted simulator 启动 app。
- 启动后首屏截图有效：`artifacts/cartoonworld-multicity-current-v2.png`。
- 尝试自动切换到世界 Tab 做补充截图，但当前本机模拟器点击自动化未稳定切换 Tab，因此未将世界页截图记为本轮验收证据。

## 0.3.4 - 2026-06-21

### Scope

围绕“真人控制自己的数字分身，分身之间先社交，遇到问题再回流给本人确认”的主链路，完成家人页与身份页的一轮体验和性能优化。

### Changed

- 数字分身社交链路落地：
  - 新增 `ContactConversationEndpoint`，支持 `本机Agent / 线上Agent / 真人用户` 三种联系人接入方式。
  - 新增 `SelfProxyMode`，支持 `分身代答 / 本人处理 / 待本人确认` 三种本人分身策略。
  - 新增 `AgentIssue` 与状态流转，支持分身把待确认问题记录下来，再由本人确认发送或接管。
- `WorldModel` 代理逻辑增强：
  - 持久化保存分身模式、联系人路由、待确认 issue、最近本人接管时间。
  - 新增“长时间未登录后进入全托管”的判断逻辑。
  - 新增模拟来信、批准 issue、本人接管、忽略 issue 等行为。
- 家人页重构：
  - 聊天头部显示当前分身模式或对方接入方式。
  - 紧凑态与展开态都支持 issue 队列展示。
  - 展开态将“模拟来信”下沉到策略横幅，顶部按钮收缩为更稳定的控制组。
  - 底部聊天输入区的语音/视频按钮压缩为与输入框同高的方形操作位。
  - 家人管理页新增联系人接入方式配置。
- 拓扑图视觉优化：
  - 将“新增家人”节点移出中心区，避免压住自己节点。
  - 关系线改为更稳定的折线锚点，避免直接穿过中心节点。
  - 自己节点的名称增加白底标签，降低连线与文字重叠带来的脏乱感。
- 首屏渲染性能优化：
- 启动时导入种子素材不再同步解码原图数据，避免家人页启动阶段出现长时间白屏。
- 素材仍保留 `mediaURL`，需要展示时再走按需读取。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/run_ios_sim.sh` 成功，并在当前 booted simulator 启动 app。
- 启动后 `3s` 即可抓到有效家人页首屏，不再需要等待十几秒：
  - `artifacts/startup-3s.png`
  - `artifacts/final-family-pass.png`

## 0.3.6 - 2026-06-21

### Scope

补齐“每个界面与关键操作”截图质检链路，并形成可追踪的操作动线文档（含世界节点联动）。

### Changed

- 截图流水线增强：
  - `scripts/capture_screenshots.sh` 改为参数化场景脚本，支持同一 App 实例自动生成家人/世界/上传/身份截图。
  - 对世界场景补充卡通/真实 3D、城市切换、地标聚焦、Panel 展开态等参数组合。
  - 统一采用 `SIMCTL_CHILD_` + `--KEY=value` 双路径注入，降低参数不入参导致脚本漂移风险。
- 调试参数读取增强：
  - `ContentView` 的 `debugValue` 在环境变量基础上增加 `--KEY=value` 启动参数解析。
  - 保持现网启动逻辑不变，仅在调试流程注入初始化态。
- 质检闭环：
  - 新增一轮截图覆盖并落库至 `artifacts/screenshots/`，形成“家人（紧凑、展开、列表） / 世界（多城） / 上传 / 身份”链路。

### Verification

- `./scripts/build_ios.sh` 成功。
- 截图脚本成功执行：`./scripts/capture_screenshots.sh`
- 截图产物覆盖：
  - `artifacts/screenshots/family_topology_compact.png`
  - `artifacts/screenshots/family_topology_expanded.png`
  - `artifacts/screenshots/family_list.png`
  - `artifacts/screenshots/world_shanghai_cartoon_compact.png`
  - `artifacts/screenshots/world_tokyo_real_explore.png`
  - `artifacts/screenshots/world_nagoya_explore.png`
  - `artifacts/screenshots/world_osaka_moments.png`
  - `artifacts/screenshots/world_hk_relations.png`
  - `artifacts/screenshots/upload.png`
  - `artifacts/screenshots/profile.png`
- `world_tokyo_real_explore.png`、`world_osaka_moments.png` 目前与基础帧重复，列为后续优化点（优先排查参数注入与目标地标渲染入口）。

### Next

- 下一步继续补齐东京/大阪世界态差异化截图（包括按钮动作后的下一跳状态），并在质检中闭环“点击地图 -> 进详情 -> 打开 Moments -> 发起聊天”动作链。

## 0.3.7 - 2026-06-21

### Scope

继续按“无法再发现可优化点”原则执行可视化收口：修复截图质检脚本并完成一轮家庭页细节优化验证。

### Changed

- 家人页交互收口优化：
  - 顶部展开/收起与语音视频按钮在紧凑态与展开态统一压缩为更小尺寸，避免遮挡。
  - 关系拓扑连接线采用稳定折线路径，减少线性排列下节点堆叠和重叠感。
  - 联系人节点标签与自己节点视觉层级保持不变，但更强调“关系文本/身份标签”读取。
- 质检脚本完善：
  - 修复 `scripts/qa_verify_screenshots.sh` 在不同 shell 下兼容性问题（去除 `declare -A`、修复尺寸解析、清理临时文件）。
  - 确保同一张截图重复检测和 PASS/FAIL 统计稳定输出。
- 截图闭环推进：
  - 增补并锁定世界与家人链路全量 15 张关键截图输出（新增 `world_ui_restored`）。
  - `artifacts/screenshots/screenshot-qa-assertion.txt` 记录本轮 PASS 结果，覆盖所有关键状态。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/run_ios_sim.sh` 成功，并在当前 booted simulator 安装/启动 app。
- `./scripts/capture_screenshots.sh` 成功，产出：
  - `artifacts/screenshots/family_topology_compact.png`
  - `artifacts/screenshots/family_topology_expanded.png`
  - `artifacts/screenshots/family_list.png`
  - `artifacts/screenshots/world_shanghai_real_compact.png`
  - `artifacts/screenshots/world_shanghai_cartoon_compact.png`
  - `artifacts/screenshots/world_tokyo_real_explore.png`
  - `artifacts/screenshots/world_tokyo_moments.png`
  - `artifacts/screenshots/world_nagoya_explore.png`
  - `artifacts/screenshots/world_osaka_moments.png`
  - `artifacts/screenshots/world_hk_relations.png`
  - `artifacts/screenshots/world_hk_moments_focus.png`
  - `artifacts/screenshots/world_ui_hidden.png`
  - `artifacts/screenshots/world_ui_restored.png`
  - `artifacts/screenshots/upload.png`
  - `artifacts/screenshots/profile.png`
- `./scripts/qa_verify_screenshots.sh` 成功：
  - `PASS_COUNT=15`
  - `FAIL_COUNT=0`
  - `RESULT=OK`

### 结论

- 本轮关键链路已闭环；当前脚本和截图结果可作为下一轮“无可优化”判断输入。

## 0.3.7 - 2026-06-21

### Scope

完成“每个界面/操作的截图复核闭环”，修复截图重复问题并持续输出操作动线。

### Changed

- 截图脚本与启动参数能力收敛：
  - `scripts/capture_screenshots.sh` 增加统一等待时长 3.8 秒，避免首屏时序抖动。
  - 世界页、家人页、上传页、身份页全部基于脚本注入参数重拍。
- Debug 参数解析鲁棒性增强（`ContentView.swift`）：
  - `CARTOON_INITIAL_WORLD_MODE` 支持 `real3D/real3d/real/3d` 等同义。
  - `CARTOON_INITIAL_WORLD_PANEL_SECTION` 支持大小写/同义词匹配，`Moments` 可稳定落图。
  - `AppTab` 改为 `CaseIterable`，支持 tab 的宽松匹配。
- 世界页注入时序优化（`WorldMapView.swift`）：
  - 将参数注入后再做 `ensureSelection`，降低“启动参数未注入但先选中旧城市”的概率。
- 质检文档升级：
  - 重新生成并更新 `artifacts/screenshot-qa-pass.md`，加入 W1-W5/F1-F3/U1/P1 全量状态表。
  - 附带操作动线 `mermaid flowchart`，用于每次迭代前后的闭环追踪。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh` 成功（每个目标状态均已产出截图）。
- 世界态重复帧问题已闭环：
  - `world_tokyo_real_explore.png` 与 `world_osaka_moments.png` 的 MD5 不同，说明参数注入链路恢复。

### Known Issue Tracker

- 当前版本仍以“截图状态快照”覆盖交互回溯，真实点击链路（如直接从 world 地标进入聊天）仍建议在后续加入自动化触发脚本补齐。

## 0.3.8 - 2026-06-21

### Scope

补齐“每个界面和关键操作”的截图质检闭环，补充可追踪的操作流动节点，并修正世界截图参数链路中的无效地标引用。

### Changed

- 截图流水线再次扩展为 12 个关键节点（`artifacts/screenshots/`）：
  - 家人：拓扑紧凑、拓扑展开、列表。
  - 世界：上海真实3D/卡通3D、东京探索+Moments、名古屋探索、大阪Moments、香港关系网络/Moments、世界UI收起。
  - 上传、身份。
- 补上世界操作链中的“操作映射”节点：
  - `world_hk_moments_focus` 与 `world_tokyo_moments` 明确用于验证“探索→Moments”切换后的聚焦一致性。
- 修正截图参数：
  - `world_hk_moments_focus` 的默认地标从不存在的 `central-harbour` 改为有效 `victoria-harbour`，避免回退首选地标导致状态误判。
- `artifacts/screenshot-qa-pass.md` 迭代为“质检+动线”同文档结构，加入操作链 Mermaid 连线。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh` 成功执行，生成 12 张截图（MD5 全量去重）。
- 文档更新：`artifacts/screenshot-qa-pass.md`。
- 当前可复现操作链：
  - 家人拓扑紧凑 → 扩张 → 列表。
  - 世界上海→东京→名古屋→大阪→香港的链路逐级切换。
  - 世界 HUD 收起与恢复。

## 0.3.10 - 2026-06-21

### Scope

继续执行“可见问题无阻断级优化”闭环：修复截图链路抖动导致的误报，并将版本历史更新与验收记录同步到最新状态。

### Changed

- `scripts/capture_screenshots.sh`：
  - 增加截图等待时间环境变量 `CARTOON_SCREENSHOT_DELAY_SECONDS`，默认 5.0 秒，提升 MapKit 场景就绪稳定性。
- `scripts/qa_verify_screenshots.sh`：
  - 调整最小文件阈值到 `60000`，避免对大量透明区域场景的误报。
- `artifacts/screenshot-qa-pass.md`：
  - 更新为版本 `0.3.10-SNAPSHOT`，补充截图等待参数化与本轮修复说明。

### Verification

- `./scripts/build_ios.sh` 成功。
- `./scripts/capture_screenshots.sh` 成功，恢复到 15 张关键截图，`world_hk_relations.png` 回归到正常体积（3.6MB）。
- `./scripts/qa_verify_screenshots.sh` 成功：
  - `PASS_COUNT=15`
  - `FAIL_COUNT=0`
  - `RESULT=OK`

## 0.3.5 - 2026-06-21

### Scope

基于你最后的反馈继续优化家人拓扑与头部交互，减少“线条凌乱”和“按钮跳动”的信息噪音。

### Changed

- 关系拓扑连线改为统一折线策略（`topologyFoldedPath`）：
  - 每条关系都保持“先下折线再横向再下行”的结构，即使几何上接近平行也有明显折点。
  - 新增家人入口连线也沿用同一折线规则，避免突兀直线刺穿节点。
- 拓扑起点与排列参数细化：
  - 适度下调拓扑中心高度与行距，让节点在有限高度内按层级落位，维持块状秩序。
- 头部控制压缩与对齐收口：
  - 顶部右侧按钮组高度统一并更小。
  - “收起”改为图标按钮保持和“三个行为按钮”视觉一致。
  - 非本人模式顶部按钮宽度统一，减少顶端抬高感。
- 继续保持：底部语音/视频仍保持与输入框同高的方形压缩样式。
