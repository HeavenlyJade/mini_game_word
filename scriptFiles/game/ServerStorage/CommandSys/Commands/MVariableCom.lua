--- 变量相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local cloudDataMgr = require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr
local VariableNameConfig = require(MainStorage.Code.Common.Config.VariableNameConfig) ---@type VariableNameConfig
local BaseUntils = require(ServerStorage.ServerUntils.BaseUntils) ---@type BaseUntils
local BonusManager = require(ServerStorage.BonusManager.BonusManager) ---@type BonusManager

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

--- 计算所有类型的加成（玩家变量加成 + 宠物/伙伴携带加成）
---@param player MPlayer 玩家对象
---@param baseValue number 基础数值
---@param playerVariableBonuses table 玩家变量加成列表
---@param otherBonuses table 其他加成类型列表 ["宠物", "伙伴", "尾迹", "翅膀"]
---@param targetVariable string 目标变量名（用于匹配携带效果）
---@return number, string finalValue, bonusInfo
local function CalculateAllBonuses(player, baseValue, playerVariableBonuses, otherBonuses, targetVariable)
    local totalBonus = 0
    local bonusDescriptions = {}
    
    -- 1. 计算玩家变量加成
    if playerVariableBonuses and type(playerVariableBonuses) == "table" and #playerVariableBonuses > 0 then
        local variableBonus, variableInfo = BonusManager.CalculatePlayerVariableBonuses(player, baseValue, playerVariableBonuses)
        if variableBonus > baseValue then
            totalBonus = totalBonus + (variableBonus - baseValue)
            table.insert(bonusDescriptions, "玩家变量加成")
        end
    end
    
    -- 2. 计算宠物和伙伴的携带加成（需要匹配目标变量）
    if otherBonuses and type(otherBonuses) == "table" then
        for _, bonusType in ipairs(otherBonuses) do
            if bonusType == "宠物" then
                local petBonuses = BonusManager.GetPetItemBonuses(player)
                ----gg.log("[VariableCommand调试] 宠物加成数据:", petBonuses)
                
                for itemName, bonusData in pairs(petBonuses) do
                    ----gg.log(string.format("[VariableCommand调试] 检查宠物加成: itemName=%s, targetVariable=%s, itemTarget=%s, 指令目标=%s", tostring(itemName), tostring(bonusData.targetVariable), tostring(bonusData.itemTarget), tostring(targetVariable)))
                    
                    -- 检查目标变量匹配
                    local isMatch = bonusData.targetVariable == targetVariable or (not bonusData.targetVariable and bonusData.itemTarget == targetVariable)
                    ----gg.log(string.format("[VariableCommand调试] 宠物加成匹配结果: %s", tostring(isMatch)))
                    
                    if isMatch then
                        if bonusData.fixed and bonusData.fixed > 0 then
                            totalBonus = totalBonus + bonusData.fixed
                            table.insert(bonusDescriptions, string.format("宠物携带加成(%s, +%d)", itemName, bonusData.fixed))
                            ----gg.log(string.format("[VariableCommand调试] 应用宠物固定加成: %s +%d", itemName, bonusData.fixed))
                        end
                        if bonusData.percentage and bonusData.percentage > 0 then
                            local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                            totalBonus = totalBonus + percentageBonus
                            table.insert(bonusDescriptions, string.format("宠物携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                            ----gg.log(string.format("[VariableCommand调试] 应用宠物百分比加成: %s +%d%% (计算值: %d)", itemName, bonusData.percentage, percentageBonus))
                        end
                    end
                end
            elseif bonusType == "伙伴" then
                local partnerBonuses = BonusManager.GetPartnerItemBonuses(player)
                ----gg.log("[VariableCommand调试] 伙伴加成数据:", partnerBonuses)
                
                for itemName, bonusData in pairs(partnerBonuses) do
                    ----gg.log(string.format("[VariableCommand调试] 检查伙伴加成: itemName=%s, targetVariable=%s, itemTarget=%s, 指令目标=%s", tostring(itemName), tostring(bonusData.targetVariable), tostring(bonusData.itemTarget), tostring(targetVariable)))
                    
                    -- 检查目标变量匹配
                    local isMatch = bonusData.targetVariable == targetVariable or (not bonusData.targetVariable and bonusData.itemTarget == targetVariable)
                    ----gg.log(string.format("[VariableCommand调试] 伙伴加成匹配结果: %s", tostring(isMatch)))
                    
                    if isMatch then
                        if bonusData.fixed and bonusData.fixed > 0 then
                            totalBonus = totalBonus + bonusData.fixed
                            table.insert(bonusDescriptions, string.format("伙伴携带加成(%s, +%d)", itemName, bonusData.fixed))
                            ----gg.log(string.format("[VariableCommand调试] 应用伙伴固定加成: %s +%d", itemName, bonusData.fixed))
                        end
                        if bonusData.percentage and bonusData.percentage > 0 then
                            local percentageBonus = math.floor(baseValue * bonusData.percentage / 100)
                            totalBonus = totalBonus + percentageBonus
                            table.insert(bonusDescriptions, string.format("伙伴携带加成(%s, +%d%%)", itemName, bonusData.percentage))
                            ----gg.log(string.format("[VariableCommand调试] 应用伙伴百分比加成: %s +%d%% (计算值: %d)", itemName, bonusData.percentage, percentageBonus))
                        end
                    end
                end
            elseif bonusType == "尾迹" then
                -- TODO: 实现尾迹加成计算
                table.insert(bonusDescriptions, "尾迹加成(待实现)")
            elseif bonusType == "翅膀" then
                -- TODO: 实现翅膀加成计算
                table.insert(bonusDescriptions, "翅膀加成(待实现)")
            end
        end
    end
    
    local finalValue = baseValue + totalBonus
    local bonusInfo = ""
    if #bonusDescriptions > 0 then
        bonusInfo = string.format("\n> 加成来源: %s.\n> 基础值: %s, 总加成: %s, 最终值: %s.",
            table.concat(bonusDescriptions, ", "),
            tostring(baseValue),
            tostring(totalBonus),
            tostring(finalValue)
        )
    end
    
    return finalValue, bonusInfo
end

--- 同步并保存玩家数据
---@param player MPlayer
local function syncAndSave(player)
    ----gg.log("syncAndSave", player.variables)
    if player and player.variableSystem then
        player.variables = player.variableSystem.variables
        cloudDataMgr.SavePlayerData(player.uin, true)

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
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not (variableName and value) then
        player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end
    if not isValidVariableName(variableName) then
        player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    local variableSystem = player.variableSystem

    -- 使用新的加成计算函数
    local finalValue, bonusInfo = CalculateAllBonuses(player, value, playerVariableBonuses, otherBonuses, variableName)
    local valueToAdd = finalValue

    variableSystem:AddVariable(variableName, valueToAdd)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为 %s 的变量 '%s' 新增 %s, 新值为: %s.%s", player.name, variableName, tostring(valueToAdd), tostring(newValue), bonusInfo)
    -- player:SendHoverText(msg)
    gg.log(msg)
    syncAndSave(player)
    return true
end

--- 设置变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.set(params, player)
    local variableName = params["变量名"]
    local value = tonumber(params["数值"])

    if not (variableName and value) then
        player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end

    if not isValidVariableName(variableName) then
        player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    local variableSystem = player.variableSystem
    variableSystem:SetVariable(variableName, value)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功将玩家 %s 的变量 '%s' 设置为: %s", player.name, variableName, newValue)
    player:SendHoverText(msg)
    ----gg.log(msg)
    syncAndSave(player)
    return true
end

--- 减少变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.reduce(params, player)
    local variableName = params["变量名"]
    local value = tonumber(params["数值"])
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    if not (variableName and value) then
        player:SendHoverText("缺少 '变量名' 或 '数值' 字段。")
        return false
    end

    if not isValidVariableName(variableName) then
        player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，请确认是否正确。")
    end

    local variableSystem = player.variableSystem

    -- 使用新的加成计算函数
    local finalValue, bonusInfo = CalculateAllBonuses(player, value, playerVariableBonuses, otherBonuses, variableName)
    local valueToReduce = finalValue

    variableSystem:SubtractVariable(variableName, valueToReduce)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为玩家 %s 的变量 '%s' 减少 %s，新值为: %s.%s", player.name, variableName, tostring(valueToReduce), tostring(newValue), bonusInfo)
    --gg.log(msg)
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
            player:SendHoverText("警告：变量名 '" .. variableName .. "' 不在推荐列表中，但仍会尝试查询。")
        end
        local details = variableSystem:GetVariableSources(variableName)
        if not details then
            local msg = string.format("玩家 %s 没有名为 '%s' 的变量。", player.name, variableName)
            player:SendHoverText(msg)
            ----gg.log(msg)
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
        player:SendHoverText(fullMessage)
        ----gg.log(fullMessage)
    else
        -- 查看所有变量的最终值
        local allVars = variableSystem:GetAllVariables()
        local response = {
            string.format("--- 玩家 %s 的所有变量 ---", player.name)
        }
        local count = 0
        for k, v in pairs(allVars) do
            table.insert(response, string.format("  %s = %s", k, tostring(v)))
            count = count + 1
        end

        if count == 0 then
            table.insert(response, "  (该玩家无任何变量)")
        end

        local fullMessage = table.concat(response, "\n")
        player:SendHoverText(fullMessage)
        ----gg.log(fullMessage)
    end
    return true
end

--- 测试加成计算
---@param params table
---@param player MPlayer
function VariableCommand.handlers.testbonus(params, player)
    local baseValue = tonumber(params["基础值"]) or 100
    local playerVariableBonuses = params["玩家变量加成"]
    local otherBonuses = params["其他加成"]

    local finalValue, bonusInfo = CalculateAllBonuses(player, baseValue, playerVariableBonuses, otherBonuses, "测试变量")
    
    local msg = string.format("加成测试结果:\n基础值: %s\n最终值: %s%s", 
        tostring(baseValue), tostring(finalValue), bonusInfo)
    
    ----gg.log(msg)
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["设置"] = "set",
    ["减少"] = "reduce",
    ["查看"] = "view",
    ["测试加成"] = "testbonus"
}

--- 变量操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function VariableCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '设置', '减少', '查看', '测试加成'")
        return false
    end

    local handlerName = operationMap[operationType]
    if not handlerName then
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '设置', '减少', '查看', '测试加成'")
        return false
    end

    if not player.variableSystem then
        player:SendHoverText("错误：找不到玩家的变量系统实例。")
        ----gg.log("错误：玩家 " .. player.name .. " 的variableSystem为空。")
        return false
    end

    local handler = VariableCommand.handlers[handlerName]
    if handler then
        ----gg.log("变量命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- This case should not be reached due to the handlerName check above
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
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
--   "玩家变量加成": [
--     {
--       "名称": "加成_百分比_金币加成",
--       "作用类型": "单独相加",
--       "目标变量": "金币"
--     }
--   ]
-- }
--
-- 2. 包含宠物和伙伴携带加成的变量操作
-- {
--   "操作类型": "新增",
--   "变量名": "金币",
--   "数值": 100,
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
-- 3. 测试加成计算
-- {
--   "操作类型": "测试加成",
--   "基础值": 100,
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
