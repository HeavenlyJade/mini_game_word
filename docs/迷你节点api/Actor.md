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

## 高级用法：实现自定义飞行 (悬浮/滑翔)

在开发中，常常需要实现比默认 `Jump()` 更复杂的空中移动，例如将玩家发射到空中并使其滑翔一段距离。这需要同时控制 `Actor` 的 **行为状态** 和 **物理属性**。

**核心概念:**
`Actor` 不仅仅是一个物理实体 (`Model`)，它还拥有一套内部的 **行为状态机** (`BehaviorState`)，例如 `Stand`, `Walk`, `Fly` 等。当 `Actor` 处于如 `Stand` 的地面状态时，引擎会使其主动抵抗外力以维持站立姿态，这会导致直接调用 `AddForce()` 或修改速度可能无效或效果不佳。

因此，实现自定义飞行的关键是：**先命令Actor进入空中状态，再控制其物理表现。**

**常见误区:**
- **误区:** 只设置 `actor.Gravity = 0` 并用 `AddForce()` 施力。
- **问题:** 如果 `Actor` 的行为状态仍是 `Stand`，它会"黏"在原地，抵抗你施加的力，导致无法移动。

**推荐实现步骤:**

1.  **强制进入空中状态:** 调用 `actor:Jump(true)`。这是最关键的一步，它会立刻将 `Actor` 的 `BehaviorState` 切换到 `Fly`，使其脱离地面状态的物理限制。
2.  **移除重力:** 立即设置 `actor.Gravity = 0`。这样 `Actor` 在进入飞行状态后就不会下坠。
3.  **施加持续推力:** 使用一个高频定时器（如 `RunService.Heartbeat` 或 `ScheduledTask.AddInterval`）来循环执行移动指令。
    -   `actor:Move(Vector3.new(0, 0, 1), true)`:  **推荐使用**。这会使 `Actor` 相对于相机朝前移动，操控感好且稳定。
    -   `actor:AddForce(force)`: 也可以使用，但 `Move()` 对于角色直接控制通常更可靠。
4.  **结束飞行并清理:**
    -   在飞行结束时（例如通过 `MoveStateChange` 检测到落地、或超时），必须恢复 `Actor` 的属性。
    -   恢复重力: `actor.Gravity = (默认值)`
    -   停止推力: 停止循环移动的定时器。
    -   停止移动: 调用 `actor:StopMove()` 清除所有移动指令。
    -   可以调用 `actor:Jump(false)` 来告知引擎跳跃动作结束。

**代码示例 (简化版):**
```lua
local actor = gg.getClientLocalPlayer()
local originalGravity = actor.Gravity -- 保存原始重力

-- 1. 进入空中状态
actor:Jump(true)
-- 2. 关闭重力
actor.Gravity = 0

-- 3. 持续施加向前的力
-- 注意：确保 ScheduledTask 模块已正确初始化
local pushTimer = ScheduledTask.AddInterval(0.1, "FlyPush", function()
    if actor then
        -- 相对于相机方向向前移动
        actor:Move(Vector3.new(0, 0, 1), true)
    end
end)

-- 4. 设定一个5秒后结束飞行的任务作为保护
ScheduledTask.AddDelay(5.0, "StopFly", function()
    if pushTimer then
        ScheduledTask.Remove(pushTimer)
        pushTimer = nil
    end

    if actor then
        actor.Gravity = originalGravity -- 恢复重力
        actor:StopMove()
        print("飞行结束！")
    end
end)
```
**关于 `MoveStateChange` 事件的注意事项:**
调用 `actor:Jump(true)` 会**立即**触发 `MoveStateChange` 事件（例如从 `Stand` -> `Fly`）。如果在该事件中直接编写落地或结束逻辑，可能会在起跳瞬间就错误地触发。建议在该事件的处理函数中加入一个短暂的延迟或状态判断（例如，一个 `isFlying` 标志位），以避免在起飞时就立即执行降落逻辑。

---

## 常见问题与开发陷阱 (FAQ & Pitfalls)

以下是在使用 `Actor` API，特别是进行自定义飞行等复杂操作时，根据开发经验总结的一些常见陷阱和解决方案。

### 1. 陷阱：如何安全地检查一个 Actor 是否已被销毁？
-   **问题描述**: 在异步操作（如定时器回调）中，如何确保我们引用的 `actor` 对象仍然有效，没有被游戏逻辑销毁？
-   **错误做法**: 使用 `if actor and not actor.isDestroyed then ...`。
-   **根本原因**: `Actor` 和 `SandboxNode` 对象 **没有** 名为 `isDestroyed` 的属性。直接访问它会出错或返回 `nil`，导致判断失效。
-   **正确做法**: **直接判断引用是否存在**。在 Lua 中，当一个引擎对象被销毁后，所有对它的引用都会失效。因此，最简单且正确的检查方式就是 `if actor then ... end`。如果 `actor` 变量仍然指向一个有效的对象，该判断为 `true`；如果对象已被销毁，该判断将为 `false`。

### 2. 陷阱：只修改物理属性，但角色不动

-   **问题描述**: 调用 `actor.Gravity = 0` 并通过 `actor:AddForce()` 施加一个力，但角色仍然"粘"在地面上或无法按预期移动。
-   **根本原因**: `Actor` 拥有一个内部的 **行为状态机** (`BehaviorState`)。当它处于 `Stand` 或 `Walk` 等地面状态时，引擎会使其主动抵抗外力以维持姿态。这会抵消你施加的物理效果。
-   **解决方案**: **"先切换行为，再控制物理"**。在施加任何持续的空中物理效果之前，必须先调用 `actor:Jump(true)` 来命令角色进入 `Fly` 状态，脱离地面行为的限制。

### 3. 陷阱：`MoveStateChange` 在起跳瞬间就触发落地逻辑

-   **问题描述**: `actor:Jump(true)` 之后，立即就触发了从 `Fly` 状态变回 `Stand` 的事件，导致飞行逻辑刚开始就被中断。
-   **根本原因**: 这是一个典型的竞态条件。`Jump(true)` 调用会立即改变状态并触发事件，如果你的落地检测逻辑（`if before == Fly and after == Stand then ...`）没有防备，就会在起跳的同一帧内被错误触发。
-   **解决方案**: 设置一个 **"起飞保护期"**。在 `MoveStateChange` 的处理函数中，不要立即执行落地逻辑。可以启动一个短暂的延迟（例如0.2-0.5秒），只有当玩家在空中停留超过这个保护期后，落地检测才真正生效。或者，使用一个 `isTakingOff` 的布尔标志位来跳过第一次状态变化检测。

### 4. 陷阱：使用 `AddForce` 控制飞行方向和速度不稳定

-   **问题描述**: 使用 `AddForce` 来实现持续的向前飞行时，角色的速度和方向难以精确控制，尤其是在有其他力（如玩家输入）干扰时。
-   **根本原因**: `AddForce` 是一个纯粹的物理作用，它会与其他力叠加，并且力的作用效果与物体的 `Mass`（质量）等属性有关，需要开发者手动进行复杂的计算来维持稳定速度。
-   **解决方案**: **使用 `actor:Move()` 进行角色控制**。`actor:Move(direction, relativeToCamera)` 是引擎提供的更高级别的移动指令。当 `relativeToCamera` 为 `true` 时，传入 `Vector3.new(0, 0, 1)` 就可以让角色稳定地朝镜头前方移动，这是实现"飞车"或"滑翔"等效果最推荐、最稳定的方法。它屏蔽了底层的物理计算，让意图更清晰。

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