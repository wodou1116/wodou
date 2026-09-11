---
name: asset-qa
description: 对游戏图片资产执行只读、分阶段、确定性的 T0-T4 Asset QA，并输出结构化 JSON 与 Markdown 报告；不修改原图或运行时代码。
---

# Asset QA

版本：`1.3`

本 Skill 定义 Demo 0.2 起可持续使用的最小 Asset QA 流程。审核器对 `assets/image/**` 只读，结果写入 `qa/reports/**`，不得修改原图、运行时代码或评分规则。

## 11 步执行顺序

严格按以下顺序执行，不得用自然语言“看起来不错”替代结构化输出：

1. 读取 `qa/asset_manifest.json`，确认资产路径在项目资产根目录内。
2. 判断资产类型，按下方 rubric 路由选择唯一主 rubric。
3. 判断当前 QA Stage；没有该 Stage 前置条件时停止，不降级伪造结果。
4. 运行 `scripts/alpha_bounds.py`、`scripts/image_metrics.py` 等确定性检查。
5. 若为 T1-T4，读取对应 `AssetReadabilityTestScene` 截图或运行时证据。
6. 执行对应 rubric 的视觉维度评分；无视觉证据时填 `null`，不得猜分。
7. 计算 `metric_score` 与（有视觉证据时）`final_score = vision_score * 0.7 + metric_score * 0.3`。
8. 检查全部 Hard Fail；Hard Fail 优先于分数。
9. 输出符合 `schemas/asset_qa_result.schema.json` 的固定 JSON。
10. 从分数、Hard Fail、置信度和当前 Gate 决定 `action`。
11. 写明 `next_gate`；生成汇总 JSON 与 Markdown，并保留确定性输入证据。

## 职责与阶段

- Skill：定义规则与 JSON 形状。
- `asset_qa`：只读执行者，只读取资产、计算指标、输出报告。
- Sol Review：处理视觉判断、低置信度和 Gate 争议。
- T0：源图导入前，检查尺寸、Alpha、主体边界、占画布比例、空图。
- T1：资产放入真实春季场景、使用接近实机尺寸并具备 Pivot/Sorting 基础。
- T2：真实移动/AI V1 已存在，能录制静态混排、移动、攻击、目标切换。
- T3：至少 5 个技能、Projectile、Buff、伤害数字、御令标记和危险区已存在。
- T4：Demo 0.7 春季 Vertical Slice，有完整 Run 与目标屏幕比例截图。

### T0-T4 可执行条件

| Stage | 可执行条件 | 核心输出 |
|---|---|---|
| T0 | manifest 有效且源图可读 | `T0_PASS` / `T0_FIX` / `T0_REGENERATE` |
| T1 | 有真实春季地图截图、实机尺寸、Pivot/Sorting 证据 | 场景分离与层级结果 |
| T2 | 有真实 Motion/AI V1 证据 | 混排与运动混淆结果 |
| T3 | 有技能/VFX/Projectile/Telegraph 压力截图 | 战斗压力结果 |
| T4 | 有完整 Run 的 4:3 至 21:9 截图和 Safe Area 证据 | Full Visual QA 结果 |

当前仓库只执行 T0；T1-T4 没有证据时必须 `PENDING_CAPTURE`，不得生成 PASS。QA 场景入口是 `scenes/qa/AssetReadabilityTestScene.lua`，capture planner 是 `scripts/qa/capture_asset_test_scene.lua`；同名 JSON 仅是 `metadata_only`，不是可执行场景。

### Rubric 路由

| `asset_type` | rubric |
|---|---|
| `character` | `rubrics/character.md` |
| `monster` | `rubrics/monster.md` |
| `elite` | `rubrics/elite.md` |
| `boss` | `rubrics/boss.md` |
| `scene` | `rubrics/scene.md` |
| `vfx` | `rubrics/vfx.md` |
| `telegraph` | `rubrics/telegraph.md` |
| `ui` | `rubrics/ui.md` |
| `icon` | `rubrics/icon.md` |
| `marketing` | `rubrics/marketing.md` |
| `wheel` | `rubrics/vfx.md` |

## Hard Fail 与确定性规则

以下语义来自 V1.2 总纲：`HF-01` 实机 1 秒不可识别；`HF-02` 普通怪高度混淆；`HF-03` 精英无法区别；`HF-04` Telegraph 与地图/VFX 混淆；`HF-05` Player 难定位；`HF-06` 关键目标被 VFX 遮挡；`HF-07` 主要依赖颜色；`HF-08` UI 目标尺寸不可读；`HF-09` Safe Area/点击区失败；`HF-10` Alpha/裁切导致主体缺失；`HF-11` 敌我危险效果语义相似；`HF-12` Boss 高危招式缺少前置提示。任一 Hard Fail 都不能 PASS。

- 普通主体 `subject_occupancy < 0.35`：Warning。
- 普通主体 `subject_occupancy < 0.20`：`T0_REGENERATE`，动作 `REGENERATE`。
- 需要 Alpha 的资产无 Alpha 或主体为空：Hard Fail `HF-10`，动作 `REGENERATE`。
- 场景可为 RGB，不因没有 Alpha 失败。
- 指标是机器证据，不替代轮廓、战斗语义和实机可读性的 Vision 判断。
- `compare_assets.py` 的 `metric_similarity_score` 只筛选 T1 视觉复核对象，禁止直接映射为返工或 PASS。
- `background_contrast.py` 只有使用 Maker 截图中的实体局部 ROI 时才具备 T1 判定资格；整图比较仅作参考。

普通主体不包括大范围 `telegraph`/`vfx`/`wheel` 底材；这些资产按对应 rubric 判断。

## 分数、动作与 next_gate

- Rubric 门槛：普通怪 80、Elite 85、Player 85、Boss 88、Telegraph 90、Skill/VFX 82、核心 UI 90；Scene 由实机场景评分决定。
- 等级：S 90–100、A 85–89、B 78–84、C 70–77、D 60–69、F `<60`。
- `final_score`：有 Vision 评分时为 `vision_score * 0.7 + metric_score * 0.3`；T0 无 Vision 证据时使用确定性 `metric_score` 作为临时分数，并明确 `vision_score=null`。
- `hard_fail=true` 或 `confidence < 0.70`：`ESCALATE`，除非 T0 已确定为 HF-10/主体过小并应 `REGENERATE`。
- 达到类型门槛：`PASS`；低于门槛但 `>=78`：`RUNTIME_FIX`；`70–77`：`ASSET_EDIT`；`<70`：`REGENERATE`。
- Hard Fail 的 `next_gate` 为 `T0_RETEST` 或当前 Stage 重测；普通通过的 `next_gate` 为下一个 Stage；T1-T4 无截图时为 `PENDING_CAPTURE`。

## 输出动作

只能使用：`PASS`、`RUNTIME_FIX`、`ASSET_EDIT`、`REGENERATE`、`ESCALATE`。

T0/T1 结果的最小固定字段：

```json
{
  "asset_id": "A-12",
  "asset_name": "九尾狐",
  "asset_type": "monster",
  "season": "spring",
  "qa_stage": "T0",
  "status": "T0_PASS",
  "action": "PASS",
  "vision_score": null,
  "metric_score": 100,
  "final_score": 100,
  "grade": "S",
  "confidence": 1.0,
  "hard_fail": false,
  "hard_fail_codes": [],
  "metrics": {},
  "issues": [],
  "recommended_fixes": [],
  "next_gate": "T1"
}
```

T1 的 `status` 在没有真实截图时固定为 `PENDING_CAPTURE`，不得根据 T0 指标冒充 T1 通过。

## V1.3 QA tooling contract

V1.3 只扩展证据采集与确定性工具链，不改变现有 rubric、Hard Fail 语义、分数权重或门槛。

### 截图预算

截图预算是上限/范围约束，不是 PASS 条件；预算外的截图不得被当作额外视觉证据累计：

| Stage | 截图预算 |
|---|---|
| T0 | `0`；只做确定性源图检查，使用 `SKIP_CAPTURE` |
| T1 | 每资产 `1–2` 张；优先覆盖实体局部 ROI、实机尺寸和层级关系 |
| T2 | 每个 Motion 最多 `3` 张；使用确定性的 Keyframe Sampling |
| T3 | 每场景 `4–6` 张；覆盖压力状态、Projectile/VFX/Telegraph 共存 |
| T4 | 关键状态 × 比例抽样；不要求每个时间点和每个比例全量录制 |

### Deterministic Case

每个 capture 或确定性检查必须有可复现的 Case 描述，至少包含 `case_id`、`stage`、`mode`、`ratio`、`state`、资产引用和场景配置引用。Case 字段必须使用稳定顺序序列化；相同输入必须得到相同 `qa_case_hash`。不得把截图文件名或运行时间作为 Case 输入。

工具链统一保留以下 provenance 字段：

- `asset_hash`：源资产文件内容的 SHA-256；不使用文件名或 mtime 代替。
- `scene_config_hash`：场景 JSON/配置的规范化内容哈希；非 JSON 配置使用原始字节哈希。
- `qa_case_hash`：规范化 Case JSON 的 SHA-256。

`qa_tooling.py` 提供上述哈希、缓存、ROI、Contact Sheet 和 Keyframe Sampling；Hash Cache 只能缓存确定性结果，命中条件必须包含文件大小与 `mtime_ns`，失效后重新计算。

### ROI、Contact Sheet 与 Keyframe Sampling

- T1+ 的背景分离 ROI 必须来自 Maker 运行时实体所在的局部背景，ROI 的宽高应为主体边界的 `1.5–2.0x`，并记录 `roi_scale`、`roi` 和 `t1_eligible=true`。整图比较只能标记为参考，不能用于 T1 判定。
- Contact Sheet 只用于批量核对捕获覆盖、Case 和文件命名；它不是视觉评分，也不能替代原始截图。
- Keyframe Sampling 必须按固定、均匀的索引选择帧；T2 每个 Motion 不得超过 3 张。采样索引和 `qa_case_hash` 必须写入证据元数据。

### Skip 状态

- `SKIP_CAPTURE`：该 Case 根据截图预算明确不采集，例如 T0；它不是 PASS，也不能清除 T1-T4 的必需证据。
- `SKIP_VISION_REVIEW`：该 Case 仅有确定性检查且策略明确不需要视觉复核；它不是视觉通过，不得用于绕过 T1-T4 必需的 Sol Review。

planner 应显式输出 `skip_status`、预算、ROI 政策和 Case 描述；哈希由 Python 工具根据实际输入计算。缺少上述 provenance 时，结果应保持 `PENDING_CAPTURE` 或 `PENDING_VISION_REVIEW`，不得猜分。
