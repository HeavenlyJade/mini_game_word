local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class LevelExpCommand
local LevelExpCommand = {}

--- 主命令处理函数
---@param params table 命令参数
---@param player MPlayer 目标玩家
function LevelExpCommand.main(params, player)
    if not player then
        gg.log("错误：未指定目标玩家")
        return false
    end

    local operation = params["操作类型"]
    local level = params["等级"]
    local exp = params["经验"]

    if not operation then
        gg.log("错误：未指定操作类型")
        return false
    end

    -- 验证参数
    if level and (not tonumber(level) or tonumber(level) < 1) then
        gg.log("错误：等级必须是大于0的数字")
        return false
    end

    if exp and (not tonumber(exp) or tonumber(exp) < 0) then
        gg.log("错误：经验值必须是非负数")
        return false
    end

    -- 执行操作
    if operation == "新增" then
        return LevelExpCommand.addLevelExp(player, level, exp)
    elseif operation == "设置" then
        return LevelExpCommand.setLevelExp(player, level, exp)
    elseif operation == "减小" then
        return LevelExpCommand.reduceLevelExp(player, level, exp)
    else
        gg.log("错误：不支持的操作类型，支持的类型：新增、设置、减小")
        return false
    end
end

--- 新增等级和经验
---@param player MPlayer 目标玩家
---@param level number|nil 要增加的等级
---@param exp number|nil 要增加的经验
function LevelExpCommand.addLevelExp(player, level, exp)
    local success = true
    local message = ""

    -- 增加等级
    if level then
        local currentLevel = player.level or 1
        local newLevel = currentLevel + level
        player:SetLevel(newLevel)
        message = message .. string.format("等级从 %d 增加到 %d", currentLevel, newLevel)
    end

    -- 增加经验
    if exp then
        local currentExp = player.exp or 0
        player:AddExp(exp)
        message = message .. string.format("，经验从 %d 增加到 %d", currentExp, player.exp)
    end

    if message ~= "" then
        player:SendHoverText(message)
        gg.log("玩家 %s 新增等级和经验成功：%s", player.name, message)
    end

    return true
end

--- 设置等级和经验
---@param player MPlayer 目标玩家
---@param level number|nil 要设置的等级
---@param exp number|nil 要设置的经验
function LevelExpCommand.setLevelExp(player, level, exp)
    local success = true
    local message = ""

    -- 设置等级
    if level then
        local oldLevel = player.level or 1
        player:SetLevel(level)
        message = message .. string.format("等级从 %d 设置为 %d", oldLevel, level)
    end

    -- 设置经验
    if exp then
        local oldExp = player.exp or 0
        player:SetExp(exp)
        message = message .. string.format("，经验从 %d 设置为 %d", oldExp, exp)
    end

    if message ~= "" then
        player:SendHoverText(message)
        gg.log("玩家 %s 设置等级和经验成功：%s", player.name, message)
    end

    return true
end

--- 减小等级和经验
---@param player MPlayer 目标玩家
---@param level number|nil 要减少的等级
---@param exp number|nil 要减少的经验
function LevelExpCommand.reduceLevelExp(player, level, exp)
    local success = true
    local message = ""

    -- 减少等级
    if level then
        local currentLevel = player.level or 1
        local newLevel = math.max(1, currentLevel - level) -- 等级最低为1
        player:SetLevel(newLevel)
        message = message .. string.format("等级从 %d 减少到 %d", currentLevel, newLevel)
    end

    -- 减少经验
    if exp then
        local currentExp = player.exp or 0
        local newExp = math.max(0, currentExp - exp) -- 经验最低为0
        player:SetExp(newExp)
        message = message .. string.format("，经验从 %d 减少到 %d", currentExp, newExp)
    end

    if message ~= "" then
        player:SendHoverText(message)
        gg.log("玩家 %s 减少等级和经验成功：%s", player.name, message)
    end

    return true
end

return LevelExpCommand
