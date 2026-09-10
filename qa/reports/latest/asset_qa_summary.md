# Asset QA T0

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
