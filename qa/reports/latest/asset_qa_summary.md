# Asset QA T0

## Demo 0.2 V1.3 Gate 状态

- Runtime、六节气组合、确定性 Capture、QA 工具与三档压力测试已完成。
- A-10～A-15 的 T1 当前为 `PENDING_CAPTURE`，不能以旧截图或低分辨率侧栏截图判定 PASS。
- 九尾狐旧版运行时 ROI 触发背景分离风险；已完成 Shadow 运行时修复，等待原生比例复核，暂不修改源资产。
- A-11～A-15 的 10 组全配对机器混淆矩阵已生成，全部保留 `PENDING_VISION_REVIEW`。
- 结论：`DEMO_0_2_GATE_FAIL_PENDING_EVIDENCE`；不得启动 Demo 0.3。

- Total: 34
- Hard Fail Count: 0

## Actions

- PASS: 34

## Lowest Scores

| Asset | Final Score |
|---|---:|
| A-03 | 100 |
| A-04 | 100 |
| A-07-03 | 100 |
| A-07-05 | 100 |
| A-08-01 | 100 |

## Spring Confusion Matrix

```json
{
  "metric_only": true,
  "pairs": [
    {
      "left": "enemies/bifang.png",
      "right": "enemies/jiuweihu.png",
      "metric_similarity_score": 89.54,
      "risk_band": "high",
      "requires_vision_review": true,
      "vision_confusion_score": null,
      "decision": "PENDING_VISION_REVIEW",
      "evidence": {
        "luminance_similarity": 0.8026,
        "saturation_similarity": 0.9682,
        "edge_similarity": 0.9466,
        "occupancy_similarity": 0.898
      },
      "left_asset_id": "A-11",
      "right_asset_id": "A-12"
    },
    {
      "left": "enemies/bifang.png",
      "right": "enemies/kui.png",
      "metric_similarity_score": 97.22,
      "risk_band": "high",
      "requires_vision_review": true,
      "vision_confusion_score": null,
      "decision": "PENDING_VISION_REVIEW",
      "evidence": {
        "luminance_similarity": 0.9928,
        "saturation_similarity": 0.9672,
        "edge_similarity": 0.9874,
        "occupancy_similarity": 0.914
      },
      "left_asset_id": "A-11",
      "right_asset_id": "A-13"
    },
    {
      "left": "enemies/jiuweihu.png",
      "right": "enemies/kui.png",
      "metric_similarity_score": 91.25,
      "risk_band": "high",
      "requires_vision_review": true,
      "vision_confusion_score": null,
      "decision": "PENDING_VISION_REVIEW",
      "evidence": {
        "luminance_similarity": 0.7954,
        "saturation_similarity": 0.999,
        "edge_similarity": 0.934,
        "occupancy_similarity": 0.984
      },
      "left_asset_id": "A-12",
      "right_asset_id": "A-13"
    }
  ],
  "next_action": "T1_VISION_REVIEW"
}
```
