# TeleportService API 文档

**继承自：** `Service`

**描述：**
TeleportService 负责在不同的地点和服务器之间运送玩家。所有的传送功能都整合到一个 `TeleportService:Teleport()` 函数中，该函数用于：
1.  将玩家传送到另一个地方；
2.  将玩家传送到特定服务器；
3.  将玩家传送到保留的服务器。

---

## 函数 (Functions)

| 函数名 | 返回值 | 描述 |
| :--- | :--- | :--- |
| `Teleport(player, pos)` | `void` | 在当前地图内，将指定的玩家 `player` (类型为 `SandboxNode`) 传送到目标位置 `pos` (类型为 `Vector3`)。 |

---

## 事件 (Events)

| 事件名 | 参数 | 描述 |
| :--- | :--- | :--- |
| `TeleportSuccess` | `()` | 玩家传送成功时触发。 |
| `TeleportFail` | `()` | 玩家传送失败时触发。 |

---

## 代码示例

```lua
-- 获取 TeleportService 的实例
local TeleportService = game:GetService('TeleportService')

-- 假设 'player' 是一个有效的玩家节点 (SandboxNode)
local player = --[[ ... 获取玩家节点的代码 ... ]]

-- 定义目标位置
local targetPosition = Vector3.new(500, 700, 800)

-- 执行传送
TeleportService:Teleport(player, targetPosition)

-- 你也可以监听传送结果
TeleportService.TeleportSuccess:Connect(function()
    print("玩家传送成功！")
end)

TeleportService.TeleportFail:Connect(function()
    print("玩家传送失败！")
end)
``` 