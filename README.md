# Mech Animation Demo

## Stick Figure Action Editor

The demo includes a `Stick Figure Editor` entry in the top toolbar. It opens a 12-segment stick-figure action editor for quickly blocking out poses and frame sequences.

- The figure is built from colored line segments: head, torso, left/right upper arms, left/right forearms, left/right thighs, left/right shins, and left/right feet.
- Drag an endpoint to stretch or shorten connected limbs. Shared joints stay connected, so moving a shoulder, hip, knee, elbow, ankle, or neck moves every segment attached to that joint.
- Drag a segment body to move that segment while keeping its connected endpoints synchronized.
- The top head joint is drawn as a larger circular head to match the traditional stick-figure silhouette.
- The left panel manages action frames: play/pause, previous/next frame, playback speed, duplicate current frame, add a template frame, delete, and reset the current frame.
- Clicking any frame in the action list loads it back into the editor, so earlier actions can be revised after new frames are created.
- `导出图片` exports the current pose to `.tmp/stick_figure_export.png`.

这是一个 Godot 4 的 2D 机甲动画 demo 项目，目标是用“参考帧动画 + 骨骼挂点 rig”的方式制作更接近人类动作的侧身机甲动画。

## 项目目标

- 机甲不是方块占位，而是参考用户提供的 5 张 Medabots/Tinpet 风格设计图制作。
- 机甲需要有人体体态：头、躯干、肩、肘、腕、手、髋、膝、踝、脚掌等关节要符合侧身人体动作逻辑。
- 动画不再靠主观目测，而是通过自动对比工具检查“骨骼动画”和“10 帧参考帧动画”的差异。
- 当前默认重点是走路动画，先把走路做准，再扩展跑步、射击、拳击、劈砍。

## 当前界面

顶部有三个主按钮：

- `骨骼绑定`
  - 显示静态 rig。
  - 可以拖动骨骼点微调绑定位置。
  - 可以拖动 mesh 微调部件位置。
  - 点击保存后，绑定数据写入 `user://male_tinpet_cutout_bind_pose.json`。

- `动画演示`
  - 显示当前走路骨骼动画。
  - 显示自动对比面板。
  - 点击 `自动对比` 后逐帧比较当前 rig 和参考走路帧动画。

- `贴图校准`
  - 显示 10 帧参考帧动画。
  - 可以逐帧选择机甲部件贴图，把部件直接摆到参考帧轮廓上。
  - 校准结果保存到 `user://walk_ref_part_poses.json`，作为本机人工真值，不会自动覆盖仓库文件。

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

- 部件语义点：
  - `assets/parts/male_tinpet/part_landmarks.json`
  - 描述每张贴图的本地语义锚点，例如头部的 `neck/head`、大腿的 `hip/knee`、脚掌的 `ankle/toe`。

## 当前脚本

- `scripts/main.gd`
  - 构建主界面。
  - 管理 `骨骼绑定` 和 `动画演示` 两个区域。

- `scripts/male_tinpet_cutout_rig.gd`
  - 当前核心 cutout 骨骼 rig。
  - 读取 `bind_pose.json` 建立站立绑定姿势、骨骼层级和部件贴图。
  - 走路动画由 `walk_ref_points.json` 的参考帧骨骼点驱动，旧手写 pose 只保留在历史 sprite rig 中。
  - 提供骨骼点、部件语义点、渲染快照、站立 pose、走路 pose 和对比点输出。

- `scripts/male_tinpet_sprite_rig.gd`
  - 旧版 sprite-placement rig，保留作历史参考，不再是主界面和评分脚本的默认实现。

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

- `scripts/semantic_pose_score.gd`
  - 贴图语义点误差分解工具。
  - 输出每个贴图语义点和参考帧目标点之间的误差，用于判断是头部、躯干、腿部还是脚掌锚点不准。

## 自动评分逻辑

当前评分由两部分组成：

- 已有贴图校准数据时：
  - 部件姿态误差：50%
  - 真实/代理轮廓匹配：25%
  - 骨骼点误差：25%
- 没有贴图校准数据、但存在部件语义点时：
  - 贴图语义点误差：40%
  - 真实/代理轮廓匹配：35%
  - 骨骼点误差：25%
- 尚未校准贴图时：
  - 真实/代理轮廓匹配：45%
  - 骨骼点误差：55%

对比流程：

1. 把参考走路图切成 10 帧。
2. 每帧读取人工标注的参考骨骼点。
3. 当前 rig 跑到对应走路时间点。
4. 读取 rig 的对应骨骼点。
5. 将 rig 点映射到参考帧包围盒坐标。
6. 根据 `part_landmarks.json` 把每张贴图的本地语义点对齐到参考帧目标点，自动求位置、旋转和缩放。
7. 如果存在 `user://walk_ref_part_poses.json` 或 `res://assets/animation/walk_ref_part_poses.json`，逐部件比较位置、角度、缩放。
8. 计算每个贴图语义点和关节点距离误差。
9. 生成最差帧误差图，显示参考点、当前点和误差线。

## 当前评分结果

最近一次按评分迭代后的结果：

- 平均总分：`96.4`
- 骨骼分：`100.0`
- 最差帧：第 3 帧
- `score_breakdown.gd` 输出所有关节平均误差为 `0.00`

注意：这组旧分数只说明骨骼点对齐，不能说明贴图部件位置和角度正确。当前自动对比已提高轮廓/部件姿态权重，在没有贴图校准数据时会暴露“骨骼满分但贴图堆叠”的问题。

本轮优化前的平均总分约为 `81.7`，主要误差来自 `neck` 和 `hand` 两个虚拟端点。现在参考帧驱动时会缓存正式骨骼比较点，手部贴图也会按“腕到手尖”的参考长度缩放，因此骨骼动画与参考帧标注可以完全对齐。

## 最新用户要求

后续开发要围绕以下方向继续：

1. 给参考帧动画标记上现有 rig 的骨骼点到对应位置。
   - 参考帧动画不只是图片，需要明确每帧每个关节点的位置。
   - 当前已有 `walk_ref_points.json`，后续要继续校准它，让点位更准确。

2. 根据参考帧动画生成骨骼动画。
   - 已切换到 cutout skeleton 主线：`male_tinpet_cutout_rig.gd` 会读取 `walk_ref_points.json`，走路动画优先由参考帧骨骼点驱动。
   - 每一帧的肩、肘、腕、髋、膝、踝、脚掌都以参考帧点位为目标。
   - 旧的手写角度走路表保留为 fallback，不再是默认驱动来源。

3. 增加贴图层级设计。
   - 已切换到 cutout skeleton 主线：`male_tinpet_cutout_rig.gd` 中的 `DRAW_ORDER` 为每个 mesh 设置明确 z-index / draw order。
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

2. 继续优化 `male_tinpet_cutout_rig.gd` 的参考骨骼点求解。
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

本机启动：

```powershell
.\launch_demo.bat
```

Godot 引擎路径按以下顺序动态读取，避免上传后覆盖不同电脑的本地路径：

1. 仓库根目录下被 `.gitignore` 忽略的 `godot_path.local.txt`。
2. 环境变量 `GODOT_EXE`。
3. PATH 中的 `godot` 命令。

当前已验证：

```powershell
$godot = Get-Content .\godot_path.local.txt
& $godot --headless --path . --script 'res://scripts/smoke_test.gd'
& $godot --headless --path . --script 'res://scripts/compare_smoke_test.gd'
& $godot --headless --path . --script 'res://scripts/score_breakdown.gd'
& $godot --headless --path . --script 'res://scripts/semantic_pose_score.gd'
```

## 2026-07-01 scoring update

The automatic compare path now uses real part texture snapshots in headless mode instead of a bone-line proxy. This makes the silhouette score respond to actual sprite placement, scale, rotation, and draw order.

When no manual `walk_ref_part_poses.json` exists, the final score is semantic-first:
- part semantic landmarks: 78%
- skeleton points: 17%
- texture silhouette: 5%

This weighting intentionally avoids the old failure mode where stacked or semantically wrong sprites could still pass because the skeleton points were correct. The latest verified headless score is:
- average: `91.3`
- worst frame: `04`
- worst-frame score: `91.0`
- skeleton point error: `0.00`

## 2026-07-01 part score update

The compare tool now also reports a per-part score. Each scored part is evaluated by:
- landmark position
- part angle
- connection quality at joints
- length/scale consistency

The semantic compare branch now uses this part score as the main score source. Latest verified results:
- total average: `94.6`
- worst total frame: `02`
- minimum part score: `90.4`
- worst part: `torso_mesh`
- worst part frame: `06`

Run the detailed part report with:

```powershell
$godot = Get-Content .\godot_path.local.txt
& $godot --headless --path . --script 'res://scripts/part_score_report.gd'
```

## 2026-07-01 structure score update

The part score now includes a structure sub-score so local visual mistakes are not hidden by a high total score. This was added after finding cases where:
- the rear hand/joint chain could visually drift into the leg area while endpoint landmarks still scored well
- the foot ankle landmark was placed on the foot side/dorsum instead of the upper ankle connector
- an unrelated rear-side part could appear near the thigh because draw order and whole-sprite locality were not checked

New checks:
- sprite-center locality against the expected body segment
- foot-specific ankle/toe direction checks instead of using the generic limb corridor
- far-arm regional consistency for far upper arm, forearm, and hand
- rear arm draw order moved behind the torso/near-side body stack

Latest verified results:
- total average: `94.1`
- minimum part score: `90.2`
- near foot worst score: `91.2`
- far foot worst score: `94.1`

## 2026-07-01 strict 100-point part gate

The part report now requires `MIN_PART_SCORE=100.0` to pass. A score of 100 means every checked local constraint is inside its acceptable tolerance, not that every rendered pixel is identical to the reference sheet.

Additional fixes:
- point-joint sprites are now scored by mapping their `center` landmark to the corresponding shoulder/knee/ankle reference point
- near and far feet no longer share the same flip direction; the near foot is flipped, while the far foot uses `foot_mesh_far`
- the foot ankle anchor remains on the upper ankle connector, so the foot no longer uses the foot side/dorsum as the connection point
- the overall compare pass threshold is now `100.0`; silhouette remains visible as a diagnostic line but no longer pulls down the semantic/structural score

Latest strict verification:
- total average: `100.0`
- minimum part score: `100.0`
- skeleton point error: `0.00`

## 2026-07-01 dynamic foot direction fix

The foot sprite is no longer treated as a fixed near/far flipped limb segment. The source `foot_side.png` points left, so the runtime now flips each foot per frame based on the target `ankle -> toe` direction:
- toe left of ankle: use the source direction
- toe right of ankle: flip the sprite horizontally

This fixes the case where one foot faced backward or both feet rotated toward a near-vertical pose while walking. Landmark scoring now also reads the runtime `Sprite2D.flip_h` value, so the score follows the actual rendered foot orientation instead of a static landmark assumption.

## 2026-07-01 cutout skeleton rewrite plan

The sprite-placement rig is being replaced by a cutout skeleton rig:

1. Rest pose first
   - Build a side-view standing bind pose from the design sheet.
   - Keep every texture as a child of a stable part bone node.
   - Store local anchors in `part_landmarks.json`.

2. Bone-driven animation
   - Move and rotate part bones, not loose top-level sprites.
   - Use the walk reference points to drive bones only after the rest pose is stable.
   - Keep near/far depth as alpha and draw order, not as shortened limb lengths.

3. Foot handling
   - Feet are special cutout parts, not stretchable limb tubes.
   - Runtime foot flip follows the current `ankle -> toe` direction.
   - The score reads the runtime flip state when evaluating foot landmarks.

4. Verification
   - `render_cutout_pose_preview.gd` exports `cutout_stand_preview.png` and `cutout_walk_preview_01.png`.
   - `part_score_report.gd` verifies local anchors, connections, angles, and structure.
   - `compare_smoke_test.gd` verifies the walk reference pose path.

Implemented files:
- `scripts/male_tinpet_cutout_rig.gd`
- `scripts/render_cutout_pose_preview.gd`

The UI now has a `站立展示` button for checking the design-driven rest pose separately from the walk animation.

三个检查都应通过。

## 2026-07-01 cutout skeleton implementation status

The new mainline is now data-driven by `assets/parts/male_tinpet/bind_pose.json`.

Implemented:
- `bind_pose.json` stores the design-rest-pose points, logical skeleton hierarchy, and part-to-texture mapping.
- `male_tinpet_cutout_rig.gd` loads the bind pose at runtime and builds the logical cutout skeleton from that data.
- Stand pose uses the design bind points first; walk pose is sampled only after the rest pose exists.
- Torso placement uses multi-point fitting from the landmark set instead of a two-point-only transform.
- Feet use runtime flip from the current `ankle -> toe` direction, so left/right foot direction is evaluated from the actual frame.
- `rest_pose_score.gd` is a dedicated design-rest-pose gate and does not depend on the old walk silhouette score.

Latest verified checks:

```powershell
$godot = Get-Content .\godot_path.local.txt
& $godot --headless --path . --check-only --script 'res://scripts/male_tinpet_cutout_rig.gd'
& $godot --headless --path . --check-only --script 'res://scripts/rest_pose_score.gd'
& $godot --headless --path . --script 'res://scripts/rest_pose_score.gd'
& $godot --headless --path . --script 'res://scripts/part_score_report.gd'
& $godot --headless --path . --script 'res://scripts/compare_smoke_test.gd'
```

Results:
- `REST_POSE_SCORE=100.0 points=100.0 hierarchy=100.0 parts=100.0`
- `MIN_PART_SCORE=100.0`
- walk compare average: `100.0`

## 2026-07-01 shape score update

The 100-point gate was too weak because it only proved that sparse landmarks, joints, and part existence were correct. A large torso texture could still pass when its anchor points matched the skeleton.

The score definition now includes rendered part shape checks:
- per-part rendered alpha bbox
- width ratio against the design/rest-pose axis
- height ratio against the design/rest-pose axis
- area ratio against the design/rest-pose axis

The shape targets live in `assets/parts/male_tinpet/bind_pose.json` under `shape_constraints`. They are read by both:
- `scripts/rest_pose_score.gd`
- `scripts/auto_compare_panel.gd`

The part report now prints `shape=...` for every part, so local size errors are visible instead of being hidden by good landmark scores.

Current expected result after enabling this stricter scoring:
- rest pose fails because torso, head, and feet shape constraints expose oversized rendered parts
- `torso_mesh` is no longer allowed to score 100 just because `neck/shoulder/torso/hip` landmarks are aligned
- `compare_smoke_test.gd` now exits with failure when the compare label says failure

Follow-up fixes:
- `torso_mesh` is now driven by the shape constraint, so a wide chest plate is corrected by rendered bbox width/height/area instead of only by sparse anchor points.
- Feet use oriented shape scoring. Their size is measured in the part's own transformed axes, not by the screen-axis bounding box that grows when the foot rotates.
- Head and feet remain scored by shape constraints, but only `torso_mesh` currently uses shape as an automatic corrective driver.

Latest verified output after the fixes:
- `REST_POSE_SCORE=100.0 points=100.0 hierarchy=100.0 parts=100.0 shape=100.0`
- `MIN_PART_SCORE=100.0`
- walk compare average: `100.0`

## 2026-07-01 strict scoring redesign after false-positive 100

The previous scoring system produced a false-positive 100.0 because the animation was driven from `walk_ref_points.json` and then scored primarily against the same reference points. This proved that the labels matched themselves, not that the rendered animation matched the reference frame animation.

Failure lessons:
- skeleton points are useful diagnostics, but they are not independent evidence when the rig is driven by those same points
- part semantic landmarks can also self-confirm when endpoints are used both to place and score a part
- weighted averages allowed high skeleton/semantic scores to hide a very low rendered silhouette score
- `part_score_report.gd` looked authoritative while excluding the full-frame visual mismatch
- stand/rest pose validity did not prove that the walk pose kept the same visual character

New scoring rules:
- final walk score is shortboard-based: per-frame score is `min(visual, skeleton, structure)`
- pass/fail uses separate hard gates, not only an average:
  - average score must be at least `85.0`
  - worst frame score must be at least `75.0`
  - minimum visual score must be at least `70.0`
  - minimum skeleton score must be at least `95.0`
  - minimum structure score must be at least `85.0`
- visual silhouette is an independent hard gate and can no longer be ignored
- `part_score_report.gd` now also reports `MIN_VISUAL_SCORE` and fails when the full-frame visual score is below threshold

Current strict result after enabling the redesigned gate:
- `compare_smoke_test.gd` fails as expected
- strict average: `45.3`
- worst frame: `02`
- `MIN_VISUAL_SCORE=39.9`
- skeleton and structure still report `100.0`, which is now correctly treated as insufficient because the rendered animation visibly does not match the reference frames

## 2026-07-02 reference-frame contour skeleton update

The standalone `跑步骨骼` view is now driven by reference-frame contour data instead of procedural sine/cosine motion.

Implemented changes:
- `assets/animation/run_skeleton_20f.json` now defines 14 contour groups: head, torso, left/right upper arm, left/right forearm, left/right hand, left/right thigh, left/right shin, and left/right foot.
- Every contour group has exactly 20 ordered outline points. The hand is no longer folded into the forearm.
- `assets/animation/run_skeleton_keyframes.json` stores 10 side-view gait frames based on the supplied contact/down/passing/up/contact reference sheet.
- `scripts/run_skeleton_animation.gd` reads contour points and keyframe joint coordinates separately, interpolates between the keyframes, and locks the lowest foot outline to the ground line.
- The visible point radius was reduced so the dots behave as outline samples instead of large blobs that hide the contour.
- `scripts/render_run_skeleton_preview.gd` validates the data in headless mode by checking group counts, keyframe count, and per-frame ground contact.

Verified with:

```powershell
$godot = Get-Content .\godot_path.local.txt
& $godot --headless --path . --check-only --script 'res://scripts/run_skeleton_animation.gd'
& $godot --headless --path . --script 'res://scripts/render_run_skeleton_preview.gd'
& $godot --headless --path . --script 'res://scripts/smoke_test.gd'
```

Latest validation:
- contour groups: `14`
- keyframes: `10`
- every group point count: `20`
- every sampled keyframe lowest outline y: `0.00`

## 2026-07-02 reference silhouette trace correction

The previous contour keyframes still approximated the gait instead of tracing the supplied side-view character silhouette. The `跑步骨骼` view now loads `assets/animation/walk_contact_reference.png` as a translucent reference underlay, so outline-point placement can be checked directly against the character.

Corrections:
- frame 01 and frame 25 were re-marked from the supplied contact-pose silhouette
- rear-side arm hangs down beside the body; front-side arm reaches forward
- rear leg extends backward and front leg extends forward with a narrow side-view stride
- keyframe x coordinates are scaled to the reference silhouette width instead of using the previous oversized stride
- visible contour point radius was reduced from `2.2` to `1.2`

Latest validation still reports:
- contour groups: `14`
- every group point count: `20`
- every sampled keyframe lowest outline y: `0.00`
