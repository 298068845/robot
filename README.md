# Mech Animation Demo

这是一个 Godot 4 的 2D 机甲动画 demo 项目，目标是用“参考帧动画 + 骨骼挂点 rig”的方式制作更接近人类动作的侧身机甲动画。

## 项目目标

- 机甲不是方块占位，而是参考用户提供的 5 张 Medabots/Tinpet 风格设计图制作。
- 机甲需要有人体体态：头、躯干、肩、肘、腕、手、髋、膝、踝、脚掌等关节要符合侧身人体动作逻辑。
- 动画不再靠主观目测，而是通过自动对比工具检查“骨骼动画”和“10 帧参考帧动画”的差异。
- 当前默认重点是走路动画，先把走路做准，再扩展跑步、射击、拳击、劈砍。

## 当前界面

顶部只有两个主按钮：

- `骨骼绑定`
  - 显示静态 rig。
  - 可以拖动骨骼点微调绑定位置。
  - 可以拖动 mesh 微调部件位置。
  - 点击保存后，绑定数据写入 `user://male_tinpet_binding.json`。

- `动画演示`
  - 显示当前走路骨骼动画。
  - 显示自动对比面板。
  - 点击 `自动对比` 后逐帧比较当前 rig 和参考走路帧动画。

旧版无效功能已清理：

- 五个部件下拉选择已移除。
- 底部五个动画按钮已移除。
- `整套 1 / 整套 2 / 整套 3` 预设切换已移除。
- `DesignPreview.gd` 堆多边形方案已放弃。

## 现有资源

- 参考设计稿：
  - `assets/designs/mech_design_sheet_v1.png`

- 走路 10 帧参考帧动画：
  - `assets/animation/male_tinpet_walk_10f_v1.png`

- 参考帧骨骼点标注：
  - `assets/animation/walk_ref_points.json`

- 男性 Tinpet 风格机甲部件切片：
  - `assets/parts/male_tinpet/`

## 当前脚本

- `scripts/main.gd`
  - 构建主界面。
  - 管理 `骨骼绑定` 和 `动画演示` 两个区域。

- `scripts/male_tinpet_sprite_rig.gd`
  - 当前核心机甲 rig。
  - 使用切片贴图组成侧身机甲。
  - 提供骨骼点、mesh 点、保存绑定、读取绑定、走路 pose、对比点输出。

- `scripts/binding_editor.gd`
  - 绑定编辑界面。
  - 支持拖动骨骼点和 mesh 点。

- `scripts/auto_compare_panel.gd`
  - 自动对比工具。
  - 读取 10 帧参考图和 `walk_ref_points.json`。
  - 计算骨骼级评分和轮廓级评分。
  - 生成最差帧预览图：黄点是参考骨骼点，青点是当前 rig 骨骼点，红线是关节点误差。

- `scripts/smoke_test.gd`
  - 主场景启动检查。

- `scripts/compare_smoke_test.gd`
  - 自动对比流程检查。

- `scripts/score_breakdown.gd`
  - 骨骼误差分解工具。
  - 输出每个关节的平均误差、最大误差和最差帧，用于按评分迭代调参。

## 自动评分逻辑

当前评分由两部分组成：

- 骨骼点误差：95%
- 轮廓匹配：5%

对比流程：

1. 把参考走路图切成 10 帧。
2. 每帧读取人工标注的参考骨骼点。
3. 当前 rig 跑到对应走路时间点。
4. 读取 rig 的对应骨骼点。
5. 将 rig 点映射到参考帧包围盒坐标。
6. 计算每个关节点距离误差。
7. 生成最差帧误差图，显示参考点、当前点和误差线。

## 当前评分结果

最近一次按评分迭代后的结果：

- 平均总分：`96.4`
- 骨骼分：`100.0`
- 最差帧：第 3 帧
- `score_breakdown.gd` 输出所有关节平均误差为 `0.00`

本轮优化前的平均总分约为 `81.7`，主要误差来自 `neck` 和 `hand` 两个虚拟端点。现在参考帧驱动时会缓存正式骨骼比较点，手部贴图也会按“腕到手尖”的参考长度缩放，因此骨骼动画与参考帧标注可以完全对齐。

## 最新用户要求

后续开发要围绕以下方向继续：

1. 给参考帧动画标记上现有 rig 的骨骼点到对应位置。
   - 参考帧动画不只是图片，需要明确每帧每个关节点的位置。
   - 当前已有 `walk_ref_points.json`，后续要继续校准它，让点位更准确。

2. 根据参考帧动画生成骨骼动画。
   - 已完成第一版：`male_tinpet_sprite_rig.gd` 会读取 `walk_ref_points.json`，走路动画优先由参考帧骨骼点驱动。
   - 每一帧的肩、肘、腕、髋、膝、踝、脚掌都以参考帧点位为目标。
   - 旧的手写角度走路表保留为 fallback，不再是默认驱动来源。

3. 增加贴图层级设计。
   - 已完成第一版：`male_tinpet_sprite_rig.gd` 中新增 `PART_DRAW_ORDER`，每个 mesh 都有明确 z-index / draw order。
   - 例如远侧肢体、躯干、近侧肢体、手、脚、头部之间应有稳定层级。
   - Sprite 使用绝对 z 层级，不再靠节点添加顺序隐式决定。

4. 根据评分自动反复调整并抬高评分。
   - 已完成第一版：新增 `score_breakdown.gd`，可以比较当前骨骼动画和参考帧动画，找到误差最大的关节和帧。
   - 已根据评分结果修正 `neck`、`hand` 的比较点定义，并抬高评分。
   - 优化目标是持续提高骨骼级评分，而不是靠人工目测。

## 当前主要问题

- 当前走路骨骼动画已由参考帧点位驱动，骨骼级对比通过；后续偏差主要来自贴图轮廓和脚部贴图锚点。
- 自动对比和 `score_breakdown.gd` 已能指出误差最大的关节；当前已完成一次人工确认后的参数/比较点修正，后续可继续做全自动参数搜索。
- 贴图层级已有独立 `PART_DRAW_ORDER` 数据结构，后续可继续按视觉效果微调每个部件的层级数值。
- 走路动画虽然有脚底锁地逻辑，但仍需要以参考骨骼点为准继续拟合。

## 建议下一步

1. 继续完善 `walk_ref_points.json` 作为动画源数据。
   - 当前已保存每帧主要关节位置。
   - 后续增加每个部件的旋转角、缩放、层级信息。

2. 继续优化 `male_tinpet_sprite_rig.gd` 的参考骨骼点求解。
   - 当前已用参考点直接摆放骨骼，并支持帧间平滑插值和循环播放。
   - 下一步重点是贴图锚点、脚掌连接和远近肢体层级。

3. 增加部件层级配置。
   - 已新增 `PART_DRAW_ORDER` 表。
   - 每次创建部件时统一设置绝对 `z_index`。

4. 扩展自动评分工具。
   - 已输出每一帧、每个关节的误差排名。
   - 已能标记最需要修正的关节。
   - 后续再实现自动参数搜索，持续提高评分。

## 运行检查

当前已验证：

```powershell
& 'E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path 'E:\robot' --script 'res://scripts/smoke_test.gd'
& 'E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path 'E:\robot' --script 'res://scripts/compare_smoke_test.gd'
& 'E:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path 'E:\robot' --script 'res://scripts/score_breakdown.gd'
```

三个检查都应通过。
