---
name: asset-qa
description: 对游戏图片资产执行只读、分阶段、确定性的 T0-T4 Asset QA，并输出结构化 JSON 与 Markdown 报告；不修改原图或运行时代码。
---

# Asset QA

版本：`1.0`

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
