# Actor 节点 API 文档

**继承自：** `Model`

**描述：**
模型角色节点，是 `Model` 的子类，专门用于表示具有生命、行为和基本AI（如寻路）的实体，例如玩家、怪物、NPC等。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `Movespeed` | `float` | 生物的移动速度。 |
| `MaxHealth` | `float` | 生物的最大血量。 |
| `Health` | `float` | 生物的当前血量。 |
| `AutoRotate` | `bool` | 移动时是否自动面向前方。 |
| `UserId` | `int` | **[只读]** 如果该Actor由玩家控制，此属性为该玩家的迷你号。 |
| `NoPath` | `bool` | **[只读]** Actor是否具有有效的寻路路径。 |
| `Gravity` | `float` | Actor受到的重力大小。 |
| `StepOffset` | `float` | Actor可以迈上的最大台阶高度。 |
| `CanAutoJump` | `bool` | 在寻路时是否可以自动跳跃以越过障碍。 |
| `SkinId` | `int` | **[只读]** 如果该Actor由玩家控制，此属性为该玩家的皮肤ID。 |
| `SlopeLimit` | `float` | Actor可以正常行走的最大坡度。 |
| `JumpBaseSpeed` | `float` | 执行跳跃时的初始向上速度。 |
| `JumpContinueSpeed`| `float` | 持续按住跳跃键时，用于减缓下落速度的力。 |
| `RunSpeedFactor` | `float` | 跑步状态下对 `Movespeed` 的乘数因子。 |
| `RunState` | `bool` | 是否为跑步状态。 |
| `PhysXRoleType` | `PhysicsRoleType` | 物理角色类型。 |

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `StopMove()` | `void` | 停止由 `Move()` 或 `MoveTo()` 发起的移动。 |
| `StopNavigate()` | `void` | 停止由 `NavigateTo()` 发起的自动寻路。 |
| `BindCustomPlayerSkin()`| `void` | 将玩家的自定义皮肤绑定并应用到此Actor上。 |
| `GetCurMoveState()`| `BehaviorState` | 获取当前的行为状态（如站立、行走、跳跃等）。 |
| `SetMoveEndTime(endtime)`| `void` | 设定移动结束的时间。 |
| `MoveTo(target)` | `void` | 命令Actor移动到世界空间中的某个目标位置。 |
| `Move(dir, relativeToCamera)`| `void` | 命令Actor朝指定方向持续移动。`relativeToCamera`为`true`时，方向是相对于摄像机的。 |
| `Jump(jump)` | `void` | 命令Actor执行一次跳跃。参数设为 `true` 时生效。 |
| `SetJumpInfo(baseSpeed, continueSpeed)`| `void` | 设置跳跃参数，动态修改 `JumpBaseSpeed` 和 `JumpContinueSpeed`。 |
| `NavigateTo(target)`| `void` | 命令Actor自动寻路至指定位置，引擎会自动计算最佳路径。 |
| `JumpCDTime(time)` | `void` | 设置跳跃的冷却时间。 |
| `SetEnableContinueJump(enable)`| `void` | 设置是否能够连续跳跃。 |
| `UseDefaultAnimation(use)`| `void` | 设置是否使用引擎为Actor提供的默认动画（如行走、待机等）。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `Walking` | `(bool isWalking)` | 开始或结束行走状态时触发。 |
| `Standing` | `(bool isStanding)` | 开始或结束站立状态时触发。 |
| `Jumping` | `(bool isJumping)` | 开始或结束跳跃状态时触发。 |
| `Flying` | `(bool isFlying)` | 开始或结束飞行状态时触发。 |
| `Died` | `(bool isDied)` | 当Actor死亡时触发。 |
| `MoveStateChange`| `(BehaviorState before, BehaviorState after)` | 当Actor的移动状态发生变化时触发。 |
| `NavigateFinished`| `(bool isFinished)` | 自动寻路成功到达目的地或失败时触发。 |
| `MoveFinished` | `(bool isMoveFinished)`| 调用 `MoveTo` 的移动结束时触发。 |

---

## 代码示例

```lua
-- 创建一个Actor实例
local newActor = SandboxNode.New('Actor')

-- 设置名字
newActor.Name = "my_actor"

-- 设置模型资源 (与Model节点相同)
newActor.ModelId = string.format("sandboxAsset://entity/%s/body.omod", "100010")

-- 设置位置
newActor.Position = Vector3.new(500, 700, 500)

-- 设置父节点，将其添加到场景中
newActor:SetParent(Workspace)

-- 设置基础属性
newActor.Movespeed = 5.0
newActor.MaxHealth = 100
newActor.Health = 100

-- 连接(订阅)事件
newActor.MoveFinished:Connect(function(isMoveFinished)
    if isMoveFinished then
        print("Actor 成功到达目的地！")
    end
end)

newActor.Walking:Connect(function(isWalking)
    if isWalking then
        print("Actor 开始行走了...")
    else
        print("Actor 停止了行走。")
    end
end)

-- 命令Actor移动
local targetPosition = Vector3.new(600, 700, 500)
newActor:MoveTo(targetPosition)
``` 