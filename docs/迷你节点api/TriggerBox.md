# TriggerBox API 文档

**继承自：** `Transform`

**描述：**
触发器包围盒。这是一个特殊的、通常不可见的逻辑区域，专门用于在服务端检测其他物理对象（如玩家、NPC）的“进入”和“离开”事件。它不参与刚体碰撞（即不会挡住任何物体），是实现区域触发逻辑（如自动开门、进入陷阱、开始比赛）最理想、最可靠的工具。

它的核心功能由 `Touched` 和 `TouchEnded` 两个事件驱动。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `Size` | `Vector3` | 触发器包围盒的尺寸（长、宽、高）。 |
| `KinematicAble` | `bool` | 运动能力。如果为`true`，它可以通过脚本移动；如果为`false`，它会保持静止。通常建议保持为 `false`。 |
| `GravityAble` | `bool` | 重力能力。如果为`true`，它会受重力影响下落。作为静态的触发区域，此项应始终为 `false`。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `Touched` | `(SandboxNode node, Vector3 arg1, Vector3 arg2)` | 当另一个对象的物理碰撞体首次**进入并重叠**此包围盒时触发。`node` 是触碰了此触发器的对象。`arg1` 和 `arg2` 可能是触碰点、法线等物理信息，具体取决于引擎实现。 |
| `TouchEnded` | `(SandboxNode node)` | 当另一个对象的物理碰撞体**完全离开**此包围盒的重叠区域时触发。`node` 是离开了此触发器的对象。 |

---

## 代码示例

下面的示例演示了如何创建一个触发器，并在玩家进入或离开时打印日志。

```lua
-- 1. 创建一个新的 TriggerBox 实例
local trigger = SandboxNode.New('TriggerBox')

-- 2. 设置其父节点，将其放入场景中
trigger:SetParent(Workspace)

-- 3. 设置一个清晰的名字，便于在编辑器和日志中识别
trigger.Name = "MyFirstTrigger"

-- 4. 设置它的位置和大小
trigger.LocalPosition = Vector3.new(100, 50, 100)
trigger.Size = Vector3.new(200, 100, 200) -- 创建一个 2x1x2 米的区域

-- 5. 确保它不受物理影响
trigger.KinematicAble = false
trigger.GravityAble = false

-- 6. 连接(订阅)它的事件
trigger.Touched:Connect(function(touchedNode)
    -- touchedNode 是进入这个区域的那个节点，比如玩家的Actor
    if touchedNode and touchedNode.Name then
        print(string.format("'%s' 进入了触发区域 '%s'！", touchedNode.Name, trigger.Name))
    end
end)

trigger.TouchEnded:Connect(function(touchedNode)
    -- touchedNode 是离开这个区域的那个节点
    if touchedNode and touchedNode.Name then
        print(string.format("'%s' 离开了触发区域 '%s'。", touchedNode.Name, trigger.Name))
    end
end)

print("成功创建并初始化了一个 TriggerBox: " .. trigger.Name)

```