--- 属性相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local cloudDataMgr = require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr
local AttributeMapping = require(MainStorage.Code.Common.Icon.AttributeMapping) ---@type AttributeMapping
local BonusCalculator = require(ServerStorage.ServerUntils.BonusCalculator) ---@type BonusCalculator
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader)
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class StatCommand
local StatCommand = {}

-- 子命令处理器
StatCommand.handlers = {}

--- 计算基础值 - 新增核心逻辑
---@param inputValue number 输入的数值
---@param player MPlayer 玩家对象
---@param statName string 属性名称
---@return number 基础值
local function _calculateBaseValue(inputValue, player, statName)
    -- 如果输入值大于0，直接使用输入值作为基础值
    if inputValue > 0 then
        return inputValue
    end
    
    -- 输入值为0时，获取玩家当前属性值作为基础值
    local currentValue = player:GetStat(statName) or 0
    return currentValue
end




--- 新增属性值 - 优化版
---@param params table 参数表，包含属性名、数值等信息
---@param player MPlayer 玩家对象
---@return boolean 是否执行成功
function StatCommand.handlers.add(params, player)
    local statName = params["属性名"]
    local inputValue = tonumber(params["数值"])
    local playerStatBonuses = params["玩家属性加成"] or {}
    local playerVariableBonuses = params["玩家变量加成"] or {}
    local otherBonuses = params["其他加成"] or {}
    local finalMultiplier = tonumber(params["最终倍率"]) or 1.0

    -- 参数验证
    if not statName or not inputValue then
        gg.log("错误：缺少必要参数 '属性名' 或 '数值'")
        return false
    end
    
    if inputValue < 0 then
        gg.log("错误：数值不能为负数")
        return false
    end

    -- 计算基础值
    local baseValue = _calculateBaseValue(inputValue, player, statName)
    
    -- 计算所有加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(
        player, baseValue, playerStatBonuses, playerVariableBonuses, otherBonuses, statName,"属性计算")
    
    local valueToAdd = finalValue * finalMultiplier
    local oldValue = player:GetStat(statName)

    -- 新增 = 当前值 + 增加值
    player:AddStat(statName, valueToAdd, true)
    local newValue = player:GetStat(statName)

    gg.log(string.format("新增玩家 %s 属性 '%s': %s + %s = %s (基础: %s, 计算: %s, 倍率: %s) %s", 
        player.name, statName, tostring(oldValue), tostring(valueToAdd), tostring(newValue), 
        tostring(baseValue), tostring(finalValue), tostring(finalMultiplier), bonusInfo))
    
    return true
end

--- 设置属性值 - 优化版
---@param params table 参数表，包含属性名、数值等信息
---@param player MPlayer 玩家对象
---@return boolean 是否执行成功
function StatCommand.handlers.set(params, player)
    local statName = params["属性名"]
    local inputValue = tonumber(params["数值"])
    local playerStatBonuses = params["玩家属性加成"] or {}
    local playerVariableBonuses = params["玩家变量加成"] or {}
    local otherBonuses = params["其他加成"] or {}
    local finalMultiplier = tonumber(params["最终倍率"]) or 1.0
    
    -- 参数验证
    if not statName or not inputValue then
        gg.log("错误：缺少必要参数 '属性名' 或 '数值'")
        return false
    end
    
    if inputValue < 0 then
        gg.log("错误：数值不能为负数")
        return false
    end
    
    -- 计算基础值 - 核心逻辑改进
    local baseValue = _calculateBaseValue(inputValue, player, statName)
    
    -- 计算所有加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(
        player, baseValue, playerStatBonuses, playerVariableBonuses, otherBonuses, statName,"属性计算")
    
    local valueToSet = finalValue * finalMultiplier
    
    -- 执行设置
    player:SetStat(statName, valueToSet, true)
    local actualValue = player:GetStat(statName)
    
    -- 记录日志
    gg.log(string.format("设置玩家 %s 属性 '%s' = %s (基础: %s, 计算: %s, 倍率: %s) %s", 
        player.name, statName, tostring(actualValue), tostring(baseValue), 
        tostring(finalValue), tostring(finalMultiplier), bonusInfo))
    
    return true
end

--- 减少属性值 - 优化版
---@param params table 参数表，包含属性名、数值等信息
---@param player MPlayer 玩家对象
---@return boolean 是否执行成功
function StatCommand.handlers.reduce(params, player)
    local statName = params["属性名"]
    local inputValue = tonumber(params["数值"])
    local playerStatBonuses = params["玩家属性加成"] or {}
    local playerVariableBonuses = params["玩家变量加成"] or {}
    local otherBonuses = params["其他加成"] or {}
    local finalMultiplier = tonumber(params["最终倍率"]) or 1.0

    -- 参数验证
    if not statName or not inputValue then
        gg.log("错误：缺少必要参数 '属性名' 或 '数值'")
        return false
    end
    
    if inputValue < 0 then
        gg.log("错误：数值不能为负数")
        return false
    end

    -- 计算基础值
    local baseValue = _calculateBaseValue(inputValue, player, statName)
    
    -- 计算所有加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(
        player, baseValue, playerStatBonuses, playerVariableBonuses, otherBonuses, statName,"属性计算")
    
    local valueToReduce = finalValue * finalMultiplier
    local oldValue = player:GetStat(statName)

    -- 减少 = 当前值 - 减少值
    player:AddStat(statName, -valueToReduce, true)
    local newValue = player:GetStat(statName)

    gg.log(string.format("减少玩家 %s 属性 '%s': %s - %s = %s (基础: %s, 计算: %s, 倍率: %s) %s", 
        player.name, statName, tostring(oldValue), tostring(valueToReduce), tostring(newValue), 
        tostring(baseValue), tostring(finalValue), tostring(finalMultiplier), bonusInfo))
    
    return true
end


--- 仅应用加成（不包含基础数值）- 优化版
---@param params table 参数表，包含属性名、加成信息等
---@param player MPlayer 玩家对象
---@return boolean 是否执行成功
function StatCommand.handlers.bonusonly(params, player)
    local statName = params["属性名"]
    local playerStatBonuses = params["玩家属性加成"] or {}
    local playerVariableBonuses = params["玩家变量加成"] or {}
    local otherBonuses = params["其他加成"] or {}
    local finalMultiplier = tonumber(params["最终倍率"]) or 1.0

    -- 参数验证
    if not statName then
        gg.log("错误：缺少必要参数 '属性名'")
        return false
    end

    -- 使用BonusCalculator计算加成，基础值设为0
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(player, 0, playerStatBonuses, playerVariableBonuses, otherBonuses, statName,"属性计算")
    
    -- 只应用加成部分，不包含基础值
    local bonusValue = finalValue - 0  -- 减去基础值0，得到纯加成值
    
    -- 应用最终倍率
    local finalBonusValue = bonusValue * finalMultiplier
    
    if finalBonusValue ~= 0 then
        player:AddStat(statName, finalBonusValue, true)
        local newValue = player:GetStat(statName)
        
        gg.log(string.format("成功为玩家 %s 的属性 '%s' 应用加成 %s (最终倍率: %s)，新值为: %s %s", 
            player.name, statName, tostring(finalBonusValue), tostring(finalMultiplier), tostring(newValue), bonusInfo))
    else
        gg.log(string.format("玩家 %s 的属性 '%s' 没有可应用的加成，保持原值 %s", 
            player.name, statName, bonusInfo))
    end
    
    return true
end

--- 查看属性值 - 简化版
---@param params table
---@param player MPlayer
function StatCommand.handlers.view(params, player)
    local statName = params["属性名"]

    if statName then
        -- 查看单个属性
        local value = player:GetStat(statName)
        local initialValue = player:GetInitialStat(statName)
        
        gg.log(string.format("--- 属性 '%s' (玩家: %s) ---\n当前值: %s\n初始值: %s", 
            statName, player.name, tostring(value), tostring(initialValue)))
    else
        -- 查看所有属性
        local allStats = player:GetAllStats()
        local response = {string.format("--- 玩家 %s 所有属性 ---", player.name)}
        
        local count = 0
        for statName, value in pairs(allStats) do
            if value ~= 0 then
                local initialValue = player:GetInitialStat(statName)
                table.insert(response, string.format("%s: %s (初始: %s)", statName, tostring(value), tostring(initialValue)))
                count = count + 1
            end
        end
        
        if count == 0 then
            table.insert(response, "(无非零属性)")
        end
        
        gg.log(table.concat(response, "\n"))
    end
    
    return true
end

--- 恢复属性到初始值 - 简化版
---@param params table
---@param player MPlayer
function StatCommand.handlers.restore(params, player)
    local statName = params["属性名"]
    
    if statName then
        -- 恢复指定属性
        local initialValue = player:RestoreStatToInitial(statName)
        gg.network_channel:fireClient(player.uin, {
            cmd = EventPlayerConfig.NOTIFY.PLAYER_STAT_SYNC,
            uin = player.uin,
            statName = statName,
            initialValue = initialValue
        })
    else
        -- 恢复所有属性
        local count = player:RestoreAllStatsToInitial()
        gg.log(string.format("玩家 %s 共恢复 %d 个属性到初始值", player.name, count))
    end
    
    return true
end

--- 刷新属性 - 简化版
---@param params table
---@param player MPlayer
function StatCommand.handlers.refresh(params, player)
    player:RefreshStats()
    gg.log(string.format("玩家 %s 属性已刷新", player.name))
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["设置"] = "set", 
    ["减少"] = "reduce",
    ["查看"] = "view",
    ["恢复"] = "restore",
    ["刷新"] = "refresh",
    ["仅加成新增"] = "bonusonly"
}

--- 属性操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function StatCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        gg.log("缺少'操作类型'字段。有效类型: '新增', '设置', '减少', '查看', '恢复', '刷新', '测试加成', '仅加成新增'")
        --player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '设置', '减少', '查看', '恢复', '刷新', '测试加成', '仅加成新增'")
        return false
    end

    local handlerName = operationMap[operationType]
    if not handlerName then
        gg.log("位置的操作",operationType)
        --player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '设置', '减少', '查看', '恢复', '刷新', '测试加成', '仅加成新增'")
        return false
    end

    local handler = StatCommand.handlers[handlerName]
    if handler then
        gg.log("属性命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        --player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return StatCommand

-- ============================= 使用示例 =============================
-- 
-- 1. 基础属性操作
-- {
--   "操作类型": "新增",
--   "属性名": "攻击",
--   "数值": 10,
--   "来源": "装备"  -- 可选，默认为"COMMAND"
-- }
--
-- 2. 包含玩家属性加成的操作
-- {
--   "操作类型": "新增",
--   "属性名": "战力值",
--   "数值": 100,
--   "玩家属性加成": [
--     {
--       "名称": "数据_固定值_攻击力",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ]
-- }
--
-- 3. 包含玩家变量加成的操作
-- {
--   "操作类型": "新增",
--   "属性名": "战力值",
--   "数值": 100,
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_奖杯加成",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ]
-- }
--
-- 4. 包含其他加成的操作
-- {
--   "操作类型": "新增",
--   "属性名": "战力值",
--   "数值": 100,
--   "其他加成": ["伙伴"]
-- }
--
-- 5. 完整加成配置示例（包含伙伴属性加成）
-- {
--   "操作类型": "新增",
--   "属性名": "战力值",
--   "数值": 100,
--   "玩家属性加成": [
--     {
--       "名称": "数据_固定值_攻击力",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_奖杯加成",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "其他加成": ["伙伴"]
-- }
-- 
-- 注意：当配置"其他加成": ["伙伴"]时，玩家属性加成中的"数据_固定值_攻击力"
-- 不仅会读取玩家当前的属性值，还会从伙伴携带效果中读取同名的属性配置
-- 例如：如果伙伴携带了"数据_固定值_攻击力"的固定值或百分比加成，
-- 这些加成也会被计算到玩家属性加成中
--
-- 6. 仅应用加成（不包含基础数值）
-- {
--   "操作类型": "仅加成新增",
--   "属性名": "战力值",
--   "玩家属性加成": [
--     {
--       "名称": "数据_固定值_攻击力",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_奖杯加成",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "其他加成": ["伙伴"]
-- }
--
-- 7. 测试加成计算
-- {
--   "操作类型": "测试加成",
--   "基础值": 100,
--   "目标属性": "战力值",
--   "玩家属性加成": [...],
--   "玩家变量加成": [...],
--   "其他加成": [...]
-- }
--
-- 8. 其他操作
-- {
--   "操作类型": "查看"  -- 查看属性
-- }
-- {
--   "操作类型": "恢复"  -- 恢复属性到初始值
-- }
-- {
--   "操作类型": "刷新"  -- 刷新属性
-- }
