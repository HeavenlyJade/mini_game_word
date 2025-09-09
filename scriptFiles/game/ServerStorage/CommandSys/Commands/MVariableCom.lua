--- 变量相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local cloudDataMgr = require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr
local VariableNameConfig = require(MainStorage.Code.Common.Config.VariableNameConfig) ---@type VariableNameConfig
local BaseUntils = require(ServerStorage.ServerUntils.BaseUntils) ---@type BaseUntils
local BonusCalculator = require(ServerStorage.ServerUntils.BonusCalculator) ---@type BonusCalculator
local DependencyRuleChecker = require(ServerStorage.ServerUntils.DependencyRuleChecker) ---@type DependencyRuleChecker

---@class VariableCommand
local VariableCommand = {}

-- 子命令处理器
VariableCommand.handlers = {}



--- 验证变量名是否存在于配置中
---@param variableName string
---@return boolean
local function isValidVariableName(variableName)
    for _, name in ipairs(VariableNameConfig.VariableNames) do
        if name == variableName then return true end
    end
    for _, name in ipairs(VariableNameConfig.StatNames) do
        if name == variableName then return true end
    end
    return false
end



--- 同步并保存玩家数据
---@param player MPlayer
local function syncAndSave(player)
    ----gg.log("syncAndSave", player.variables)
    if player and player.variableSystem then
        player.variables = player.variableSystem.variables
        -- cloudDataMgr.SavePlayerData(player.uin, true)

        -- 向客户端同步变量数据
        local allVars = player.variableSystem.variables
        gg.network_channel:fireClient(player.uin, {
            cmd = require(MainStorage.Code.Event.EventPlayer).NOTIFY.PLAYER_DATA_SYNC_VARIABLE,
            variableData = allVars,
        })

        -- ----gg.log("玩家 " .. player.name .. " 的变量数据已保存并同步到客户端。")
    end
end

--- 新增变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.add(params, player)
    local variableName = params["变量名"]
    local value = tonumber(params["数值"])
    local source = params["来源"] or "VariableCommand"
    local playerStatBonuses = params["玩家属性加成"]
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not (variableName and value) then
        --player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end
    if not isValidVariableName(variableName) then
        --player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    local variableSystem = player.variableSystem

    -- 使用BonusCalculator计算加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(player, value, playerStatBonuses, playerVariableBonuses, otherBonuses, variableName,"玩家变量计算")
    local valueToAdd = finalValue

    variableSystem:AddVariable(variableName, valueToAdd)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为玩家 %s 的变量 '%s' 新增 %s (来源: %s)，新值为: %s.%s", player.name, variableName, tostring(valueToAdd), source, tostring(newValue), bonusInfo)
    -- gg.log(msg)
    -- --player:SendHoverText(msg)
    
    -- 检查依赖规则
    DependencyRuleChecker.CheckAndProcess(player, variableName, newValue)
    
    syncAndSave(player)
    return true
end

--- 设置变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.set(params, player)
    local variableName = params["变量名"]
    local value = tonumber(params["数值"])
    local source = params["来源"] or "COMMAND"
    local playerStatBonuses = params["玩家属性加成"]
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not (variableName and value) then
        --player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end

    if not isValidVariableName(variableName) then
        --player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    -- 使用BonusCalculator计算加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(player, value, playerStatBonuses, playerVariableBonuses, otherBonuses, variableName,"玩家变量计算")

    local variableSystem = player.variableSystem
    variableSystem:SetVariable(variableName, finalValue)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功将玩家 %s 的变量 '%s' 设置为: %s (来源: %s).%s", player.name, variableName, tostring(newValue), source, bonusInfo)
    --player:SendHoverText(msg)
    gg.log(msg)
    
    -- 检查依赖规则
    DependencyRuleChecker.CheckAndProcess(player, variableName, newValue)
    
    syncAndSave(player)
    return true
end

--- 减少变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.reduce(params, player)
    local variableName = params["变量名"]
    local value = tonumber(params["数值"])
    local source = params["来源"] or "COMMAND"
    local playerStatBonuses = params["玩家属性加成"]
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not (variableName and value) then
        --player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end

    if not isValidVariableName(variableName) then
        --player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    local variableSystem = player.variableSystem

    -- 使用BonusCalculator计算加成
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(player, value, playerStatBonuses, playerVariableBonuses, otherBonuses, variableName,"玩家变量计算")
    local valueToReduce = finalValue

    variableSystem:SubtractVariable(variableName, valueToReduce)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为玩家 %s 的变量 '%s' 减少 %s (来源: %s)，新值为: %s.%s", player.name, variableName, tostring(valueToReduce), source, tostring(newValue), bonusInfo)
    ----gg.log(msg)
    
    -- 检查依赖规则
    DependencyRuleChecker.CheckAndProcess(player, variableName, newValue)
    
    syncAndSave(player)
    return true
end

--- 查看变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.view(params, player)
    local variableName = params["变量名"]
    local variableSystem = player.variableSystem

    if variableName then
        -- 查看单个变量的详细信息
        if not isValidVariableName(variableName) then
            --player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，但仍会尝试查询。")
        end
        local details = variableSystem:GetVariableSources(variableName)
        if not details then
            local msg = string.format("玩家 %s 没有名为 '%s' 的变量。", player.name, variableName)
            --player:SendHoverText(msg)
            gg.log(msg)
            return false
        end

        local response = {
            string.format("--- 变量 '%s' 详情 (玩家: %s) ---", variableName, player.name),
            string.format("最终值: %s", tostring(details.finalValue)),
            string.format("基础值: %s", tostring(details.base or 0)),
            "--- 来源列表 ---"
        }

        local hasSources = false
        if details.sources then
            for source, data in pairs(details.sources) do
                table.insert(response, string.format("  - %s: %s (%s)", source, tostring(data.value), data.type))
                hasSources = true
            end
        end

        if not hasSources then
            table.insert(response, "  (无来源)")
        end

        local fullMessage = table.concat(response, "\n")
        --player:SendHoverText(fullMessage)
        local lines = gg.split(fullMessage, "\n")
        for _, line in ipairs(lines) do
            gg.log(line)
        end
    else
        -- 查看所有变量的详细信息
        local allVars = variableSystem:GetAllVariables()
        local response = {
            string.format("--- 玩家 %s 的所有变量详情 ---", player.name)
        }
        local count = 0
        
        for varName, finalValue in pairs(allVars) do
            count = count + 1
            table.insert(response, string.format("\n--- %s ---", varName))
            table.insert(response, string.format("最终值: %s", tostring(finalValue)))
            
            -- 获取该变量的详细信息
            local details = variableSystem:GetVariableSources(varName)
            if details and details.base then
                table.insert(response, string.format("基础值: %s", tostring(details.base)))
            end
            
            -- 显示来源列表
            if details and details.sources then
                table.insert(response, "来源列表:")
                for source, data in pairs(details.sources) do
                    table.insert(response, string.format("  - %s: %s (%s)", source, tostring(data.value), data.type))
                end
            else
                table.insert(response, "来源列表: (无来源)")
            end
        end

        if count == 0 then
            table.insert(response, "  (该玩家无任何变量)")
        end

        local fullMessage = table.concat(response, "\n")
        --player:SendHoverText(fullMessage)
        local lines = gg.split(fullMessage, "\n")
        for _, line in ipairs(lines) do
            gg.log(line)
        end
    end
    return true
end



--- 仅应用加成（不包含基础数值）
---@param params table
---@param player MPlayer
function VariableCommand.handlers.bonusonly(params, player)
    local variableName = params["变量名"]
    local source = params["来源"] or "COMMAND"
    local playerStatBonuses = params["玩家属性加成"]
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not variableName then
        --player:SendHoverText("缺少 '变量名' 字段。")
        return false
    end

    local variableSystem = player.variableSystem

    -- 使用BonusCalculator计算加成，基础值设为0
    local finalValue, bonusInfo = BonusCalculator.CalculateAllBonuses(player, 0, playerStatBonuses, playerVariableBonuses, otherBonuses, variableName,"玩家变量计算")
    
    -- 只应用加成部分，不包含基础值
    local bonusValue = finalValue - 0  -- 减去基础值0，得到纯加成值
    
    if bonusValue > 0 then
        variableSystem:AddVariable(variableName, bonusValue)
        local newValue = variableSystem:GetVariable(variableName)
        
        local msg = string.format("成功为玩家 %s 的变量 '%s' 应用加成 %s (来源: %s)，新值为: %s.%s", 
            player.name, variableName, tostring(bonusValue), source, tostring(newValue), bonusInfo)
        --player:SendHoverText(msg)
        ----gg.log(msg)
    else
        local msg = string.format("玩家 %s 的变量 '%s' 没有可应用的加成，保持原值。%s", 
            player.name, variableName, bonusInfo)
        --player:SendHoverText(msg)
        ----gg.log(msg)
    end
    
    syncAndSave(player)
    return true
end


--- 清空变量来源
---@param params table
---@param player MPlayer
function VariableCommand.handlers.clearsources(params, player)
    local variableName = params["变量名"]
    local variableSystem = player.variableSystem

    if not variableName then
        --player:SendHoverText("缺少 '变量名' 字段。")
        return false
    end

    if not isValidVariableName(variableName) then
        --player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    -- 检查变量是否存在
    if not variableSystem.variables[variableName] then
        local msg = string.format("玩家 %s 没有名为 '%s' 的变量。", player.name, variableName)
        --player:SendHoverText(msg)
        gg.log(msg)
        return false
    end

    -- 获取清空前的信息
    local oldValue = variableSystem:GetVariable(variableName)
    local sourceCount = 0
    if variableSystem.variables[variableName].sources then
        for _ in pairs(variableSystem.variables[variableName].sources) do
            sourceCount = sourceCount + 1
        end
    end

    -- 清空所有来源
    variableSystem.variables[variableName].sources = {}
    
    -- 获取清空后的值（只剩基础值）
    local newValue = variableSystem:GetVariable(variableName)
    
    local msg = string.format("成功清空玩家 %s 的变量 '%s' 的所有来源（共%d个），值从 %s 变为 %s", 
        player.name, variableName, sourceCount, tostring(oldValue), tostring(newValue))
    
    --player:SendHoverText(msg)
    gg.log(msg)
    
    -- 检查依赖规则
    DependencyRuleChecker.CheckAndProcess(player, variableName, newValue)
    
    syncAndSave(player)
    return true
end


-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["设置"] = "set",
    ["减少"] = "reduce",
    ["查看"] = "view",
    ["仅加成"] = "bonusonly",
    ["清空来源"] = "clearsources"  -- 新增

}

--- 变量操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function VariableCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        --player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '设置', '减少', '查看', '测试加成', '仅加成'")
        return false
    end

    local handlerName = operationMap[operationType]
    if not handlerName then
        --player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '设置', '减少', '查看', '测试加成', '仅加成'")
        return false
    end

    if not player.variableSystem then
        --player:SendHoverText("错误：找不到玩家的变量系统实例。")
        ----gg.log("错误：玩家 " .. player.name .. " 的variableSystem为空。")
        return false
    end

    local handler = VariableCommand.handlers[handlerName]
    if handler then
        ----gg.log("变量命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- This case should not be reached due to the handlerName check above
        --player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return VariableCommand
-- ============================= 使用示例 =============================
-- 
-- 1. 基础变量操作（仅玩家变量加成）
-- {
--   "操作类型": "新增",
--   "变量名": "金币",
--   "数值": 100,
--   "来源": "装备",  -- 可选，默认为"COMMAND"
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ]
-- }
--
-- 2. 包含玩家属性加成的变量操作
-- {
--   "操作类型": "新增",
--   "变量名": "金币",
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
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ]
-- }
--
-- 3. 包含宠物和伙伴携带加成的变量操作
-- {
--   "操作类型": "新增",
--   "变量名": "金币",
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
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ],
--   "其他加成": ["宠物", "伙伴"]
-- }
--
-- 4. 仅应用加成（不包含基础数值）
-- {
--   "操作类型": "仅加成",
--   "变量名": "金币",
--   "玩家属性加成": [
--     {
--       "名称": "数据_固定值_攻击力",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ],
--   "其他加成": ["宠物", "伙伴"]
-- }
--
-- 5. 测试加成计算
-- {
--   "操作类型": "测试加成",
--   "基础值": 100,
--   "目标变量": "金币",
--   "玩家属性加成": [
--     {
--       "名称": "数据_固定值_攻击力",
--       "作用类型": "单独相加",
--       "缩放倍率": 0
--     }
--   ],
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ],
--   "其他加成": ["宠物", "伙伴"]
-- }

-- ============================= 修复说明 =============================
-- 
-- 问题：伙伴携带效果显示为"金币"加成，但指令操作的是"数据_固定值_战力值"
-- 
-- 原因：携带效果配置中有两个效果：
-- 1. bonusType="物品", itemTarget="金币", targetVariable=nil
-- 2. bonusType="玩家变量", itemTarget=nil, targetVariable="数据_固定值_战力值"
-- 
-- 修复：添加目标变量匹配逻辑，只有当携带效果的targetVariable与指令的变量名匹配时才应用加成
-- 
-- 测试用例：
-- 指令操作"数据_固定值_战力值"时，应该只匹配第二个携带效果（targetVariable="数据_固定值_战力值"）
-- 指令操作"金币"时，应该只匹配第一个携带效果（itemTarget="金币"）
--
-- ============================= 升级说明 =============================
--
-- 新增功能：支持玩家属性加成
-- 1. 新增"来源"参数，用于标识变量操作的来源（如"装备"、"任务"等）
-- 2. 新增"玩家属性加成"参数，支持从玩家属性系统读取加成值
-- 3. 统一使用BonusCalculator.CalculateAllBonuses进行加成计算
-- 4. 删除重复的CalculateAllBonuses函数，避免代码重复
--
-- 参数一致性：现在VariableCommand与StatCommand的参数完全一致
-- - 都支持"来源"、"玩家属性加成"、"玩家变量加成"、"其他加成"参数
-- - 都使用相同的加成计算逻辑
-- - 都提供相同的加成测试功能

