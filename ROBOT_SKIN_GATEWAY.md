# Robot Skin Gateway

机器人皮肤出图不能直接保存到项目目录，必须先走网关：

```powershell
python .\scripts\robot_skin_gateway.py preflight ...
python .\scripts\robot_skin_gateway.py audit ...
```

`robot_design.skill` 是规则源，`scripts/robot_skin_gateway.py` 是流程闸门。新需求只允许增加约束，不能绕过 skill 里已有的来源、颜色、形状、方向端点、内外侧、掌心/手背、关节归属、禁止直接裁剪等硬约束。

## 阶段

- `design`: 整机设计图阶段，只能保存到 `assets/designs`。
- `binding_parts_confirmation`: 绑定用部件表确认稿阶段，只能保存到 `assets/designs`。
- `final_parts`: 最终部件 PNG 阶段，必须有已确认的绑定部件表，并且用户明确确认后才能进入 `assets/skins`。

## 绑定部件表确认稿

示例：

```powershell
python .\scripts\robot_skin_gateway.py preflight `
  --name sport_robot_binding_v2 `
  --stage binding_parts_confirmation `
  --reference .\assets\designs\robot_design_sport_hand_variants_front_side.png
```

生成图之后，先保存到 `assets/designs`，再审计：

```powershell
python .\scripts\robot_skin_gateway.py audit `
  --preflight .\.tmp\robot_skin_gateway\sport_robot_binding_v2_preflight.json `
  --candidate .\assets\designs\sport_robot_binding_parts_confirmation_v2.png `
  --fail "inner_hand wrist/finger direction is wrong"
```

有任何硬失败时，不允许加 `--approve`。

## 最终部件 PNG

最终拆件必须先有通过网关 audit 且用户确认过的绑定部件表：

```powershell
python .\scripts\robot_skin_gateway.py preflight `
  --name sport_robot_skin_v2 `
  --stage final_parts `
  --reference .\assets\designs\robot_design_sport_hand_variants_front_side.png `
  --approved-binding-sheet .\assets\designs\sport_robot_binding_parts_confirmation_v2.png `
  --approved-binding-audit .\.tmp\robot_skin_gateway\sport_robot_binding_v2_audit_YYYYMMDD_HHMMSS.json `
  --user-confirmed
```

输出目录必须包含所有固定尺寸 PNG 和 `skin.json`。审计会检查最终部件尺寸：

```powershell
python .\scripts\robot_skin_gateway.py audit `
  --preflight .\.tmp\robot_skin_gateway\sport_robot_skin_v2_preflight.json `
  --candidate .\assets\skins\sport_robot_v2 `
  --pass-item "No unapproved colors were introduced" `
  --pass-item "All endpoint directions match Sport Robot baseline" `
  --pass-item "Top-down joint ownership is obeyed" `
  --approve
```

`--approve` 只能在自动检查和人工检查都通过后使用。

## 目录边界

- 候选图、失败稿、确认稿：`assets/designs`
- 最终可绑定皮肤：`assets/skins`
- 网关记录：`.tmp/robot_skin_gateway`

没有对应 preflight 和 approved audit 的产物，不能称为合格最终皮肤。
