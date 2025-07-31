--- 变量相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer
local cloudDataMgr = require(ServerStorage.CloundDataMgr.MCloudDataMgr) ---@type MCloudDataMgr
local VariableNameConfig = require(MainStorage.Code.Common.Config.VariableNameConfig) ---@type VariableNameConfig

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
    gg.log("syncAndSave", player.variables)
    if player and player.variableSystem then
        player.variables = player.variableSystem.variables
        cloudDataMgr.SavePlayerData(player.uin, true)
        -- gg.log("玩家 " .. player.name .. " 的变量数据已保存。")
    end
end

--- 新增变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.add(params, player)
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
    variableSystem:AddVariable(variableName, value)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为玩家 %s 的变量 '%s' 新增 %s，新值为: %s", player.name, variableName, value, newValue)
    player:SendHoverText(msg)
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
    gg.log(msg)
    syncAndSave(player)
    return true
end

--- 减少变量值
---@param params table
---@param player MPlayer
function VariableCommand.handlers.reduce(params, player)
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
    variableSystem:SubtractVariable(variableName, value)
    local newValue = variableSystem:GetVariable(variableName)

    local msg = string.format("成功为玩家 %s 的变量 '%s' 减少 %s，新值为: %s", player.name, variableName, value, newValue)
    player:SendHoverText(msg)
    gg.log(msg)
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
        player:SendHoverText(fullMessage)
        gg.log(fullMessage)
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
        gg.log(fullMessage)
    end
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["设置"] = "set",
    ["减少"] = "reduce",
    ["查看"] = "view"
}

--- 变量操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function VariableCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '设置', '减少', '查看'")
        return false
    end

    local handlerName = operationMap[operationType]
    if not handlerName then
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '设置', '减少', '查看'")
        return false
    end

    if not player.variableSystem then
        player:SendHoverText("错误：找不到玩家的变量系统实例。")
        gg.log("错误：玩家 " .. player.name .. " 的variableSystem为空。")
        return false
    end

    local handler = VariableCommand.handlers[handlerName]
    if handler then
        gg.log("变量命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- This case should not be reached due to the handlerName check above
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return VariableCommand
