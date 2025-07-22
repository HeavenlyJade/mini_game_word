# VariableSystem 完整使用文档

## 目录

- [概述](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#概述)
- [核心概念](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#核心概念)
- [数据结构](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#数据结构)
- [API 接口](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#api-接口)
- [使用场景](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#使用场景)
- [最佳实践](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#最佳实践)
- [注意事项](https://claude.ai/chat/a448d0f5-4481-4be7-a5db-9183b4d27015#注意事项)

------

## 概述

`VariableSystem` 是专门用于处理**复杂业务逻辑变量**的系统，与 `StatSystem` 分工明确：

- **StatSystem**：处理战斗属性（攻击、防御、生命等），简单累加，实时影响游戏表现
- **VariableSystem**：处理业务逻辑（经验倍率、解锁状态、计数等），支持基础值+百分比混合计算

### 核心特性

- ✅ **多来源支持**：一个变量可由多个来源贡献数值
- ✅ **来源可消耗**：单独移除特定来源的影响
- ✅ **混合计算**：基础值 + 固定值累加 + 百分比增幅
- ✅ **向后兼容**：保持原有接口可用
- ✅ **三段式解析**：自动识别变量名格式并应用

------

## 核心概念

### 变量组成

每个变量由以下部分组成：

- **基础值 (base)**：百分比计算的基准值
- **来源集合 (sources)**：多个独立的数值贡献源

### 计算公式

```
最终值 = 基础值 + 所有固定值来源之和 + 基础值 × (所有百分比来源之和 ÷ 100)
```

### 来源类型

- **固定值**：直接加到最终结果上
- **百分比**：基于基础值计算增幅

------

## 数据结构

### 内部存储格式

```lua
self.variables = {
    ["经验倍率"] = {
        base = 100,  -- 基础100%
        sources = {
            ["VIP特权"] = {value = 50, type = "百分比"},    -- +50%
            ["活动BUFF"] = {value = 100, type = "百分比"},  -- +100%
            ["道具效果"] = {value = 25, type = "百分比"}     -- +25%
        }
    },
    ["攻击力加成"] = {
        base = 0,    -- 基础0点
        sources = {
            ["装备_武器"] = {value = 30, type = "固定值"},    -- +30点
            ["装备_戒指"] = {value = 15, type = "固定值"},    -- +15点
            ["BUFF_力量"] = {value = 20, type = "百分比"}     -- +20%基础值
        }
    }
}
```

### 类型定义

```lua
---@class VariableData
---@field base number 基础值（百分比计算基准）
---@field sources table<string, SourceValue> 来源值映射

---@class SourceValue
---@field value number 数值
---@field type string 类型："固定值" | "百分比"
```

------

## API 接口

### 基础值管理

#### SetBaseValue(key, baseValue)

设置变量的基础值

```lua
-- 设置经验倍率基础为100%
player.variableSystem:SetBaseValue("经验倍率", 100)
```

#### GetBaseValue(key) → number

获取变量的基础值

```lua
local base = player.variableSystem:GetBaseValue("经验倍率") -- 100
```

### 来源值管理

#### SetSourceValue(key, source, value, valueType)

设置特定来源的值

```lua
-- 设置VIP特权提供50%经验加成
player.variableSystem:SetSourceValue("经验倍率", "VIP特权", 50, "百分比")

-- 设置武器提供30点攻击力
player.variableSystem:SetSourceValue("攻击力", "装备_武器", 30, "固定值")
```

#### AddSourceValue(key, source, value, valueType)

在现有来源基础上累加值

```lua
-- 第一次设置任务奖励为500金币
player.variableSystem:AddSourceValue("金币", "任务奖励", 500, "固定值")
-- 再次累加200金币，总共700金币
player.variableSystem:AddSourceValue("金币", "任务奖励", 200, "固定值")
```

#### RemoveSource(key, source)

移除特定来源

```lua
-- 移除活动BUFF的经验加成
player.variableSystem:RemoveSource("经验倍率", "活动BUFF")
```

#### RemoveSourcesByPattern(pattern)

批量移除匹配的来源

```lua
-- 移除所有BUFF相关的来源
player.variableSystem:RemoveSourcesByPattern("BUFF_")

-- 移除所有装备相关的来源
player.variableSystem:RemoveSourcesByPattern("装备_")
```

### 变量获取

#### GetVariable(key, defaultValue) → number

获取变量的最终计算值

```lua
-- 获取最终经验倍率
local expRate = player.variableSystem:GetVariable("经验倍率") -- 计算后的最终值

-- 获取金币，不存在时返回0
local coins = player.variableSystem:GetVariable("金币", 0)
```

#### GetAllVariables() → table<string, number>

获取所有变量的最终值

```lua
local allVars = player.variableSystem:GetAllVariables()
-- 返回: {["经验倍率"] = 270, ["攻击力"] = 95, ["金币"] = 1500}
```

#### GetVariableSources(key) → table|nil

获取变量的详细信息

```lua
local details = player.variableSystem:GetVariableSources("经验倍率")
--[[
返回:
{
    base = 100,
    sources = {
        ["VIP特权"] = {value = 50, type = "百分比"},
        ["活动BUFF"] = {value = 100, type = "百分比"}
    },
    finalValue = 270
}
--]]
```

### 条件判断

#### CheckCondition(variableName, requiredValue) → boolean

检查变量是否满足条件（>= 比较）

```lua
-- 检查等级是否达到10级
if player.variableSystem:CheckCondition("等级", 10) then
    print("等级足够！")
end
```

#### CheckConditions(conditions) → boolean

批量检查多个条件（全部满足才返回true）

```lua
local conditions = {
    {"等级", 10},
    {"金币", 1000},
    {"声望", 50}
}
if player.variableSystem:CheckConditions(conditions) then
    print("所有条件都满足！")
end
```

#### CheckVariableCondition(key, operator, value) → boolean

使用指定操作符检查条件

```lua
-- 支持的操作符: ">", "<", ">=", "<=", "==", "!="
if player.variableSystem:CheckVariableCondition("经验倍率", ">", 200) then
    print("经验倍率超过200%！")
end
```

### 兼容性接口

#### SetVariable(key, value)

设置变量（兼容旧版本，等价于SetBaseValue）

```lua
player.variableSystem:SetVariable("金币", 1000)
```

#### AddVariable(key, value) → number

增加变量基础值（兼容旧版本）

```lua
local newValue = player.variableSystem:AddVariable("金币", 500)
```

#### SubtractVariable(key, value, minValue) → number

减少变量基础值（兼容旧版本）

```lua
local newValue = player.variableSystem:SubtractVariable("金币", 200, 0)
```

### 三段式变量名

#### ApplyVariableValue(variableName, value, source)

智能解析三段式变量名并应用

```lua
-- 格式：操作类型_加成方式_变量名称
player.variableSystem:ApplyVariableValue("加成_百分比_攻击力", 20, "装备_武器")
-- 自动解析为百分比类型，累加操作

player.variableSystem:ApplyVariableValue("解锁_固定值_关卡5", 1, "任务完成")
-- 自动解析为固定值类型，设置操作
```

### 工具方法

#### HasVariable(key) → boolean

检查变量是否存在

```lua
if player.variableSystem:HasVariable("特殊道具") then
    print("拥有特殊道具")
end
```

#### GetVariableCount() → number

获取变量总数

```lua
local count = player.variableSystem:GetVariableCount()
```

#### ClearAllVariables()

清空所有变量

```lua
player.variableSystem:ClearAllVariables()
```

### 序列化

#### SerializeVariables() → string

序列化变量数据为JSON字符串

```lua
local jsonData = player.variableSystem:SerializeVariables()
```

#### DeserializeVariables(data)

从JSON字符串恢复变量数据

```lua
player.variableSystem:DeserializeVariables(jsonData)
```

------

## 使用场景

### 场景1：经验倍率系统

```lua
-- 初始化
player.variableSystem:SetBaseValue("经验倍率", 100)  -- 基础100%

-- 各种加成
player.variableSystem:SetSourceValue("经验倍率", "VIP等级", 50, "百分比")      -- +50%
player.variableSystem:SetSourceValue("经验倍率", "双倍经验卡", 100, "百分比")   -- +100%
player.variableSystem:SetSourceValue("经验倍率", "公会加成", 20, "百分比")      -- +20%

-- 计算最终倍率：100 + 0 + 100×(50+100+20)/100 = 270%
local finalRate = player.variableSystem:GetVariable("经验倍率")

-- 应用到实际经验计算
local baseExp = 100
local actualExp = math.floor(baseExp * finalRate / 100)  -- 270经验
```

### 场景2：装备系统集成

```lua
-- 穿戴装备
function EquipItem(player, item)
    local source = "装备_" .. item.slot
    
    -- 应用装备属性加成
    for statName, value in pairs(item.stats) do
        local valueType = item.isPercent[statName] and "百分比" or "固定值"
        player.variableSystem:SetSourceValue(statName, source, value, valueType)
    end
    
    print(string.format("装备 %s 已穿戴", item.name))
end

-- 卸下装备
function UnequipItem(player, slotName)
    local source = "装备_" .. slotName
    
    -- 移除该装备的所有影响
    player.variableSystem:RemoveSourcesByPattern(source)
    
    print(string.format("已卸下 %s 装备", slotName))
end
```

### 场景3：BUFF系统

```lua
-- BUFF数据结构
local buffData = {
    id = "力量药剂",
    duration = 300,  -- 5分钟
    effects = {
        ["攻击力加成"] = {value = 25, type = "百分比"},
        ["攻击速度"] = {value = 10, type = "固定值"}
    }
}

-- 应用BUFF
function ApplyBuff(player, buff)
    local source = "BUFF_" .. buff.id
    
    for statName, effect in pairs(buff.effects) do
        player.variableSystem:SetSourceValue(statName, source, effect.value, effect.type)
    end
    
    -- 设置BUFF过期时间（需要配合其他系统）
    ScheduleBuff(player, buff.id, buff.duration)
end

-- 移除BUFF
function RemoveBuff(player, buffId)
    local source = "BUFF_" .. buffId
    player.variableSystem:RemoveSourcesByPattern(source)
end
```

### 场景4：成就系统

```lua
-- 成就配置
local achievementConfig = {
    id = "力量大师",
    name = "力量大师",
    description = "永久增加20%攻击力",
    effects = {
        {statName = "攻击力加成", value = 20, type = "百分比"},
        {statName = "暴击率", value = 5, type = "百分比"}
    }
}

-- 解锁成就
function UnlockAchievement(player, achievementId)
    local achievement = GetAchievementConfig(achievementId)
    local source = "成就_" .. achievementId
    
    -- 应用成就效果
    for _, effect in ipairs(achievement.effects) do
        player.variableSystem:SetSourceValue(effect.statName, source, effect.value, effect.type)
    end
    
    print(string.format("成就【%s】已解锁！", achievement.name))
end
```

### 场景5：商店系统价格计算

```lua
-- 商店折扣系统
player.variableSystem:SetBaseValue("商店折扣", 100)  -- 基础100%价格

-- 各种折扣来源
player.variableSystem:SetSourceValue("商店折扣", "VIP折扣", -20, "百分比")      -- VIP 8折
player.variableSystem:SetSourceValue("商店折扣", "节日活动", -15, "百分比")      -- 节日85折
player.variableSystem:SetSourceValue("商店折扣", "会员卡", -10, "百分比")       -- 会员卡9折

-- 计算最终价格倍率：100 + 0 + 100×(-20-15-10)/100 = 55%
local priceRate = player.variableSystem:GetVariable("商店折扣")

-- 应用到商品价格
local originalPrice = 1000
local finalPrice = math.floor(originalPrice * priceRate / 100)  -- 550金币
```

------

## 最佳实践

### 1. 来源命名规范

使用清晰的来源命名约定：

```lua
-- ✅ 推荐的命名方式
"装备_武器"      -- 装备类型_具体部位
"BUFF_力量药剂"  -- BUFF_具体名称
"成就_力量大师"  -- 成就_具体成就
"VIP_等级5"     -- VIP_等级信息
"活动_双倍经验"  -- 活动_活动名称

-- ❌ 不推荐的命名方式
"buff1"         -- 不清楚具体是什么
"temp"          -- 太模糊
"equipment"     -- 不够具体
```

### 2. 类型选择指南

- **固定值**：用于直接数值加成（+10攻击力、+500金币）
- **百分比**：用于比例增幅（+20%经验、+15%移动速度）

### 3. 基础值设置原则

```lua
-- ✅ 合理的基础值设置
player.variableSystem:SetBaseValue("经验倍率", 100)    -- 100%作为基础
player.variableSystem:SetBaseValue("移动速度", 5)      -- 5m/s作为基础
player.variableSystem:SetBaseValue("金币", 1000)       -- 1000作为初始金币

-- ❌ 不合理的基础值设置
player.variableSystem:SetBaseValue("攻击力加成", 0)    -- 如果只用百分比加成，基础值为0会导致百分比无效
```

### 4. 批量操作建议

```lua
-- ✅ 高效的批量移除
player.variableSystem:RemoveSourcesByPattern("装备_")   -- 一次移除所有装备影响

-- ❌ 低效的单个移除
player.variableSystem:RemoveSource("攻击力", "装备_武器")
player.variableSystem:RemoveSource("攻击力", "装备_护甲")
player.variableSystem:RemoveSource("攻击力", "装备_戒指")
-- ... 需要逐个移除
```

### 5. 条件检查优化

```lua
-- ✅ 批量检查多个条件
local unlockConditions = {
    {"玩家等级", 20},
    {"金币", 5000},
    {"声望", 100}
}
if player.variableSystem:CheckConditions(unlockConditions) then
    UnlockNewFeature(player)
end

-- ❌ 单独检查每个条件
if player.variableSystem:CheckCondition("玩家等级", 20) and
   player.variableSystem:CheckCondition("金币", 5000) and
   player.variableSystem:CheckCondition("声望", 100) then
    UnlockNewFeature(player)
end
```

------

## 注意事项

### 1. 数据类型限制

- 所有数值必须是 `number` 类型
- 来源标识必须是 `string` 类型
- 类型参数只接受 `"固定值"` 或 `"百分比"`

### 2. 百分比计算说明

- 百分比基于**基础值**计算，不是基于当前总值
- 如果基础值为0，百分比加成将无效果
- 负百分比可用于实现减益效果

### 3. 来源覆盖行为

```lua
-- 同一来源的后设置会覆盖前设置
player.variableSystem:SetSourceValue("攻击力", "武器", 30, "固定值")
player.variableSystem:SetSourceValue("攻击力", "武器", 50, "固定值")  -- 覆盖为50

-- 如需累加，请使用AddSourceValue
player.variableSystem:AddSourceValue("攻击力", "武器", 30, "固定值")
player.variableSystem:AddSourceValue("攻击力", "武器", 20, "固定值")  -- 累加为50
```

### 4. 性能考虑

- 每次 `GetVariable()` 都会重新计算，适合数值变化频繁的场景
- 如需频繁获取同一变量，考虑在业务层缓存结果
- 大量变量时，优先使用 `GetAllVariables()` 批量获取

### 5. 序列化注意

- 序列化包含完整的内部数据结构
- 反序列化会完全替换现有数据
- 跨版本兼容性需要考虑数据格式变化

### 6. 事件系统

系统会自动触发变量变化事件：

```lua
-- 监听变量变化事件（需要配合ServerEventManager）
ServerEventManager.Subscribe("VariableSystemEvent", function(evt)
    if evt.eventType == "VariableChanged" then
        print(string.format("变量 %s 从 %s 变为 %s", evt.key, evt.oldValue, evt.newValue))
    end
end)
```

------

## 总结

`VariableSystem` 提供了强大的多来源变量管理能力，特别适合处理复杂的游戏业务逻辑。通过合理使用基础值、固定值加成和百分比增幅的组合，可以实现灵活多样的数值计算需求。

记住核心原则：

- **基础值** = 百分比计算的基准
- **固定值** = 直接加到结果上
- **百分比** = 基于基础值的增幅
- **来源** = 独立可管理的数值贡献者

合理运用这些概念，就能构建出功能强大且易于维护的变量系统。