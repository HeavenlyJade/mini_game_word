# Model 节点 API 文档

**继承自：** `Transform`

**描述：**
模型节点，是游戏中所有可见实体（如角色、道具、场景物件）的基础。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `DimensionUnit` | `DimensionUnit` | 模型尺寸。 |
| `MaterialTemplate` | `MaterialType` | 材料类型。 |
| `ModelAssetType` | `TextureId` | 设置模型的材质，即资源ID。 |
| `ColorQuad` | `Color` | 模型的颜色。 |
| `ModelAssetType` | `ModelId` | 模型ID，即资源ID。 |
| `Gravity` | `float` | 模型重力。 |
| `Friction` | `float` | 模型摩擦力。 |
| `Restitution` | `float` | 模型反弹力，比如物体撞击在地面上会根据此值来计算反弹高度。 |
| `Mass` | `float` | 模型质量。 |
| `Velocity` | `Vector3` | **[只读]** 模型移动速度。 |
| `AngleVelocity` | `Vector3` | **[只读]** 模型角速度。 |
| `Size` | `Vector3` | **[只读]** 模型的包围盒大小。 |
| `Center` | `Vector3` | **[只读]** 模型的中心点所在世界坐标。 |
| `EnableGravity` | `bool` | 模型是否支持重力。 |
| `Anchored` | `bool` | 锚定状态。为true时此物体不受外部物理影响，但会给外部提供物理输入。 |
| `PhysXType` | `PhysicsType` | 物理类型。 |
| `EnablePhysics` | `bool` | 开启此物体的物理状态。为true时物体的物理属性可以使用。 |
| `CanCollide` | `bool` | 是否可以碰撞。设为`false`时为Trigger状态，不会产生物理碰撞但能触发`Touched`事件。 |
| `CanTouch` | `bool` | 是否触发碰撞回调函数：`Touched`和`TouchEnded`事件。 |
| `CollideGroupID` | `int` | 碰撞组ID。可以通过`PhysXService:SetCollideInfo`函数设置任意两个组之间是否会产生碰撞。 |
| `CullLayer` | `CullLayer` | 消隐层。 |
| `IgnoreStreamSync` | `bool` | 忽略流同步。 |
| `TextureOverride` | `bool` | 材质贴图覆盖。 |
| `CastShadow` | `bool` | 是否打开阴影投射。 |
| `ReceiveShadow` | `bool` | 是否接受来自其他物体的投影。 |
| `CanRideOn` | `bool` | 其他物体能否站在此物体上并跟随移动。 |
| `DrawPhysicsCollider`| `bool` | 是否在编辑器中显示物理包围盒，便于调试。 |
| `CanBePushed` | `bool` | 是否能被其他物体推动。 |

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `GetAnimationIDs()` | `table` | 获取该模型所有动画的ID列表。 |
| `GetBones()` | `table` | 获取动画骨骼列表。 |
| `GetLegacyAnimation()`| `SandboxNode` | 获取旧版的骨骼动画控制器。 |
| `GetAnimation()` | `SandboxNode` | 获取模型动画控制器。 |
| `GetAttributeAnimation()`| `SandboxNode` | 获取属性动画控制器。 |
| `GetSkeletonAnimation()`| `SandboxNode` | 获取骨骼动画控制器。 |
| `GetHumanAnimation()` | `SandboxNode` | 获取人形动画控制器。 |
| `GetAnimator()` | `SandboxNode` | 获取动画制作器。 |
| `IsLoadFinish()` | `bool` | 判断模型资源是否已加载完成。 |
| `GetRenderPosition()` | `Vector3` | 获取渲染位置。 |
| `GetRenderRotation()` | `Quaternion`| 获取渲染旋转（四元数）。 |
| `GetRenderEuler()` | `Vector3` | 获取渲染旋转（欧拉角）。 |
| `GetLoadedResType()` | `int` | 获取已经加载的资源类型。 |
| `EnableAnimationEvent(enable)` | `void` | 开启或关闭动画事件。 |
| `SetAnimationPriority(seqid, value)`| `void` | 设置指定动画的优先级。 |
| `SetAnimationWeight(seqid, value)`| `void` | 设置指定动画的权重。 |
| `SetBoneRotate(boneName, qua, scale)`| `void` | 设置骨骼动画旋转。 |
| `AddForce(force)` | `void` | 对模型施加一个力。 |
| `AddTorque(torque)` | `void` | 对模型施加一个扭矩。 |
| `AddForceAtPosition(force, position, mode)`| `void` | 在模型的指定位置施加一个力。 |
| `SetMaterial(skinMeshRenderCompName, materialid, index)`| `void` | 设置材质。 |
| `SetMaterialByNameOrIndex(...)`| `void` | 根据名字或索引设置材质。 |
| `SetMaterialResId(materialResId)`| `void` | 设置材质资源实例。 |
| `PlayAnimation(id, speed, loop)`| `bool` | 播放动画。`loop`为0表示无限循环。 |
| `PlayAnimationEx(...)`| `bool` | 播放动画（扩展版），可设置优先级和权重。 |
| `StopAnimation(id)` | `bool` | 停止指定的动画。 |
| `StopAnimationEx(id, reset)`| `bool` | 停止指定的动画（扩展版），可选择是否重置到第一帧。 |
| `StopAllAnimation(reset)`| `bool` | 停止所有正在播放的动画。 |
| `GetAnimationPriority(seqid)`| `int` | 获取指定动画的优先级。 |
| `GetAnimationWeight(seqid)`| `float` | 获取指定动画的权重。 |
| `AnchorWorldPos(id, offset)`| `Vector3` | 获取锚点在世界空间中的坐标（仅脚本可用）。 |
| `IsBinded(set)` | `bool` | 是否绑定。 |
| `SetMaterialNew(...)`| `int` | 设置材质（新版）。 |
| `GetMaterialByNameOrIndex(...)`| `SandboxNode`| 获取材质节点。 |
| `GetMaterialInstance(ids, idx)`| `SandboxNode`| 获取材质实例。 |
| `GetBoneNodeChildByName(...)`| `SandboxNode`| 通过节点名查询该骨骼节点的子节点对象。 |
| `GetBoneNodeByName(name)`| `SandboxNode`| 按名称获取骨骼节点。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `Touched` | `(SandboxNode node, Vector3 pos, Vector3 normal)` | 模型被其他模型碰撞时触发。 |
| `TouchEnded` | `(SandboxNode node)` | 模型与其他模型的碰撞结束时触发。 |
| `AnimationEvent` | `(int a, int b)` | 模型触发动画事件时发送。 |
| `AnimationFrameEvent`| `(int a, constchar* b, int c)`| 动画帧事件触发。 |
| `LoadFinish` | `(bool isFinish)` | 模型资源加载完成时触发。 |

---

## 代码示例

```lua
-- 创建实例
local newModel = SandboxNode.new('Model')

-- 设置名字，以便在场景中查找
newModel.Name = "my_model"

-- 设置模型资源ID
newModel.ModelId = string.format("sandboxAsset://entity/%s/body.omod", "100010")

-- 设置位置
newModel.Position = Vector3.new(500, 700, 500)

-- 设置父节点，将其添加到场景的Workspace中使其可见
newModel:SetParent(Workspace)


-- 获取玩家模型并播放动画
local player = game:GetService("Players").LocalPlayer.Character

-- 播放ID为 "100114" 的动画 (吃的动作)，速度为1.0，不循环(0)，优先级为1，权重为1.0
player:PlayAnimationEx("100114", 1.0, 0, 1, 1.0) 

-- 停止播放指定的动画
player:StopAnimation("100114")
``` 