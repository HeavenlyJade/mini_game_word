# Area API 文档

**继承自：** `SandboxNode`

**描述：**
区域节点。这是一个纯粹的、高性能的逻辑区域，专门用于在服务端检测其他节点的进入和离开。与依赖物理引擎的`TriggerBox`不同，`Area`节点不参与任何物理计算，是实现区域检测逻辑（如安全区、任务触发区、场景切换）最推荐、最可靠的工具。

它的功能由 `EnterNode` 和 `LeaveNode` 两个核心事件驱动。

---

## 属性 (Properties)

| 属性名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `Beg` | `Vector3` | 区域的起始世界坐标（长方体的一个角）。 |
| `End` | `Vector3` | 区域的结束世界坐标（长方体的对角）。 |
| `EffectWidth`| `int` | 效果宽度（可能是用于线状或面状区域的额外参数）。 |
| `Show` | `bool` | 是否在编辑器或游戏中显示此区域的边界，便于调试。 |
| `ShowMode`| `SceneEffectFrameShowMode`| 区域边界的显示模式。 |
| `Color` | `ColorQuad` | 当 `Show` 为 `true` 时，区域边界显示的颜色。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `EnterNode` | `(SandboxNode node)` | 当另一个**节点**的中心点进入此区域时触发。`node` 是进入了此区域的对象。 |
| `LeaveNode` | `(SandboxNode node)` | 当另一个**节点**的中心点离开此区域时触发。`node` 是离开了此区域的对象。 |

---

## 代码示例

下面的示例演示了如何创建一个`Area`节点，并在有其他节点进入或离开时打印日志。

```lua
-- 1. 获取一个父节点，例如场景的根节点
local part = Workspace 

-- 2. 创建一个新的 Area 节点实例，并将其作为 part 的子节点
local area = SandboxNode.new('Area', part) 
area.Name = "MyLogicArea"

-- 3. 设置区域的位置和范围
-- 注意：Area节点使用 Beg 和 End 两个点来定义一个长方体区域
area.Beg = Vector3.new(0, 0, 0)
area.End = Vector3.new(100, 100, 100)

-- 4. 你也可以选择显示这个区域的边界，便于调试
area.Show = true
area.Color = Color.new(0, 1, 1, 0.5) -- 设置一个半透明的青色

-- 5. 连接(订阅)它的事件
area.EnterNode:Connect(function(enteredNode)
	-- enteredNode 是进入这个区域的那个节点
    if enteredNode and enteredNode.Name then
	    print(string.format("'%s' 进入了区域 '%s'！", enteredNode.Name, area.Name))
    end
end)

area.LeaveNode:Connect(function(leftNode)
	-- leftNode 是离开这个区域的那个节点
    if leftNode and leftNode.Name then
	    print(string.format("'%s' 离开了区域 '%s'。", leftNode.Name, area.Name))
    end
end)

print("成功创建并初始化了一个 Area 节点: " .. area.Name)
``` 