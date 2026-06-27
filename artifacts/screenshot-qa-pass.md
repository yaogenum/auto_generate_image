# 版本 0.3.13-SNAPSHOT 截图质检与操作动线（整体简化 + 自动动线巡检）

## 1) 交互节点覆盖清单

### 1.1 目标覆盖
- 家人页（拓扑+列表）：关系网络结构与横向列表
- 家人页交互状态（紧凑/展开）
- 家人页对方状态：真人在线/真人离线/本机模拟/对方在线
- 家人页通话控制：默认收起，点击后展开语音/视频
- 世界页（上海/东京/名古屋/大阪/香港）
- 世界页子状态：卡通/真实3D、地点/Moments/家人互动、地标焦点、UI收起
- 映射链路：记录页、分身控制台
- 地标与Moments映射：记录页生成 Moment 后进入地图地点、Moments、家人互动三处

### 1.2 关键截图与功能映射

| 节点 | 截图 | 覆盖能力 | 操作语义 |
|---|---|---|---|
| F-1 | `artifacts/screenshots/family_topology_compact.png` | 家人页-拓扑结构+紧凑聊天框 | 默认落地态。验证关系网络主视图与“收起/展开入口”布局。 |
| F-2 | `artifacts/screenshots/family_topology_expanded.png` | 家人页-拓扑+展开聊天 | 验证展开后聊天占满后的稳定性与按钮对齐。 |
| F-3 | `artifacts/screenshots/family_list.png` | 家人页-横向列表 | 验证“拓扑→列表”结构切换（第二展示形式）。 |
| F-4 | `artifacts/screenshots/family_human_offline_status.png` | 家人页-真人离线状态 | 验证对方未登录时以红色状态徽标区分，不再暴露“真人用户/线上Agent”实现文案。 |
| F-5 | `artifacts/screenshots/family_call_tray_expanded.png` | 家人页-通话栏展开 | 验证底部输入区默认收起，点击通话入口后才展示语音/视频。 |
| W-1 | `artifacts/screenshots/world_shanghai_real_compact.png` | 世界页-上海真实3D-地点（收起面板） | 验证地标聚焦、底栏紧凑态与城市HUD。 |
| W-2 | `artifacts/screenshots/world_shanghai_cartoon_compact.png` | 世界页-上海卡通世界-地点（面板展开） | 验证同一城市下不同渲染模式与地点面板内容一致。 |
| W-3 | `artifacts/screenshots/world_tokyo_real_explore.png` | 世界页-日本东京真实3D-地点（面板展开） | 验证城市切换、地标聚焦、地点统计与素材/Moments计数。 |
| W-4 | `artifacts/screenshots/world_tokyo_moments.png` | 世界页-东京Moments 面板（操作映射） | 验证点击地标后能看到Moments列表、热区切入、地标关联阅读路径。 |
| W-5 | `artifacts/screenshots/world_nagoya_explore.png` | 世界页-名古屋真实3D | 验证多城市内容扩充 + 地图素材/交互链路一致性。 |
| W-6 | `artifacts/screenshots/world_osaka_moments.png` | 世界页-大阪Moments | 验证“Moments 与地标内容”联动，含图片集合和互动条目。 |
| W-7 | `artifacts/screenshots/world_hk_relations.png` | 香港家人互动 | 验证当前地点关联家人、聊天摘要与去聊天入口。 |
| W-8 | `artifacts/screenshots/world_hk_moments_focus.png` | 香港Moments聚焦（操作切换回Moments） | 验证“地点→Moments”切换及对应地标焦点是否切到当前选中。 |
| W-9 | `artifacts/screenshots/world_ui_hidden.png` | 世界页-世界HUD收起 | 验证沉浸态可恢复（收起/展开）安全链路。 |
| W-10 | `artifacts/screenshots/world_ui_restored.png` | 世界页-世界HUD恢复 | 验证从收起恢复后仍保持当前地标焦点不漂移。 |
| U-1 | `artifacts/screenshots/upload.png` | 记录页 | 验证“照片/视频 → 地点 Moment → 融入地图”入口可见性。 |
| P-1 | `artifacts/screenshots/profile.png` | 分身控制台 | 验证当前回复方、代理策略、待确认 Issue 与身份档案。 |

### 1.3 质检结论
- 覆盖率：17/17 关键节点截图均已覆盖。
- 主要功能链路（家人→世界地点→Moments→家人互动→记录→分身）可被逐步复现。
- 图像级别重复性：本轮脚本复拍后未出现重复哈希（基于 md5）。
- 最新质检结果：`PASS_COUNT=17`，`FAIL_COUNT=0`，结果 `RESULT=OK`（见 `artifacts/screenshots/screenshot-qa-assertion.txt`）。
- 自动动线巡检：`artifacts/function-check-0.3.13b/contact-sheet.png` 已覆盖家人关系网络、分身代聊、东京地点、大阪 Moments、香港家人互动、记录 Moment、分身控制台、回到家人。

### 关键执行修正
- 将截图脚本等待时长参数化，并从 3.8 秒提升为可配置 5.0 秒默认值，降低 `Map` 未绘制完成导致的空白快照误报。
- 降低截图文件最小尺寸下限为 `60000`，避免由于透明区域较高导致的 Map 场景首帧误检；重复率与尺寸/像素完整性校验仍在保留。
- 名古屋地图场景复拍发现资源就绪慢导致白屏快照，已对 `world_nagoya_explore` 增加额外等待并复拍通过。

## 2) 优化观测（第五轮）

### 通过项
- 世界页初始参数注入链路在多城市场景稳定。
- 面板状态（展开/收起）与城市/模式切换可独立复现。
- 关系网络与Moments链路在截图级别可闭环。
- 自动截图与验收脚本在当前环境下稳定通过；家庭页按钮尺寸/拓扑折线布局优化后没有触发坐标重叠告警（主观视检）。
- 家人页头部从四个显性按钮收敛为“展开/更多”，状态改为徽标表达，信息密度下降。
- 底部输入区通话按钮默认收起，展开态与输入框分层，避免语音/视频按钮长期挤压文本输入。
- 世界页从“探索大杂烩”收敛为三面板：地点、Moments、家人互动。
- 记录页上传后同步创建 Moment，产品动线从入口到地图展示更闭环。
- 分身页前置代理控制和待确认队列，弱化普通资料页感。
- 自动巡检阶段徽标能帮助区分当前操作节点；第二轮动态截图确认“记录 Moment”页面没有被跳过。

### 继续优化建议（第五轮）

- 当前无阻断级别问题。  
- 待下轮低优先级观察项：
  - 按手机真实宽度对 `F-1` `F-2` 的头像节点尺寸做一次 4.0" / 5.5" 自适应抽样。

## 3) 操作动线（截图节点连线）

```mermaid
flowchart TD
    A[启动 App] --> B[F-1 拓扑紧凑]
    B -->|点展开| C[F-2 拓扑展开]
    C -->|切换视图| D[F-3 横向列表]
    D -->|联系人真人未登录| D2[F-4 真人离线状态]
    D2 -->|点通话入口| D3[F-5 通话栏展开]

    D3 -->|切换Tab 到 世界| E[W-1 上海真实3D·地点·收起]
    E -->|切换模式（real/cartoon）| F[W-2 上海卡通3D·地点·展开]
    F -->|切换城市为东京| G[W-3 东京真实3D·地点]
    G -->|点击“Moments”| H[W-4 东京Moments]
    H -->|切换城市为名古屋| I[W-5 名古屋地点]
    I -->|切换城市为大阪，面板Moments| J[W-6 大阪Moments]
    J -->|切换城市为香港，家人互动| K[W-7 香港家人互动]
    K -->|切Moments并聚焦地标| L[W-8 香港Moments聚焦]
    L -->|收起HUD| M[W-9 世界HUD收起]
    M -->|点击恢复| N[W-10 世界HUD恢复]

    N -->|返回查看| W-2[W-2 上海卡通3D·地点·展开]

    N -->|切tab 记录页| O[U-1 记录 Moment]
    O -->|切tab 分身页| P[P-1 分身控制台]
    P -->|返回| A
```

## 4) 产出文件

- 新截图目录：`artifacts/screenshots/`
- 质检文档：`artifacts/screenshot-qa-pass.md`
