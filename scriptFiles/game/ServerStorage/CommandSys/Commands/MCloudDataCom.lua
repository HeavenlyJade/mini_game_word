--- CloudService 数据管理指令处理器
--- 支持查看、删除和设置 CloudService 数据
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local cloudService = game:GetService("CloudService") ---@type CloudService

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class CloudDataCommand
local CloudDataCommand = {}

-- 所有系统的 CloudService key 前缀
local CLOUD_KEY_PREFIXES = {
    -- 背包系统
    "bag_key",
    -- 玩家核心数据
    "player_cloud",
    -- 技能数据
    "skill_cloud", 
    -- 游戏任务
    "game_task_cloud",
    -- 奖励加成
    "reward_bonus_cloud",
    -- 商城数据
    "shop_player_cloud",
    -- 抽奖数据
    "lottery_player_key",
    -- 奖励数据
    "reward_clound",
    -- 尾迹数据
    "trail_player_cloud",
    -- 伙伴数据
    "partner_player_cloud",
    -- 翅膀数据
    "wing_player_clound",
    -- 宠物数据
    "pet_player_cloud",
    -- 成就数据
    "achievement_data_new",
    -- 邮件数据 (使用固定格式)
    "mail_player_"
}

--- 查看 CloudService 数据
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function viewCloudData(params, player)
    local key = params["键名"]
    if not key then
        return false, "缺少'键名'参数"
    end

    local success, data = cloudService:GetTableOrEmpty(key)
    if success then
        local dataStr =gg.printTable(data)
        local msg = string.format("键名: %s\n数据: %s", key, dataStr)
        gg.log("查看 CloudService 数据成功", "键名:", key, "数据:", dataStr)
        player:SendHoverText(msg)
        return true, msg
    else
        local msg = string.format("查看 CloudService 数据失败，键名: %s", key)
        gg.log("查看 CloudService 数据失败", "键名:", key)
        return false, msg
    end
end

--- 删除 CloudService 数据
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function removeCloudData(params, player)
    local key = params["键名"]
    if not key then
        return false, "缺少'键名'参数"
    end

    local success = cloudService:RemoveKey(key)
    if success then
        local msg = string.format("成功删除 CloudService 数据，键名: %s", key)
        gg.log("删除 CloudService 数据成功", "键名:", key)
        return true, msg
    else
        local msg = string.format("删除 CloudService 数据失败，键名: %s", key)
        gg.log("删除 CloudService 数据失败", "键名:", key)
        return false, msg
    end
end

--- 设置 CloudService 数据为空
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function setCloudDataEmpty(params, player)
    local key = params["键名"]
    if not key then
        return false, "缺少'键名'参数"
    end

    -- 强制设置为空数据
    local emptyData = {}
    cloudService:SetTableAsync(key, emptyData, function(success)
        if success then
            gg.log("设置 CloudService 数据为空成功", "键名:", key)
        else
            gg.log("设置 CloudService 数据为空失败", "键名:", key)
        end
    end)

    local msg = string.format("已设置 CloudService 数据为空，键名: %s", key)
    gg.log("设置 CloudService 数据为空", "键名:", key)
    return true, msg
end

--- 批量查看多个键的数据
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function batchViewCloudData(params, player)
    local keys = params["键名列表"]
    if not keys or type(keys) ~= "table" then
        return false, "缺少'键名列表'参数或参数格式错误"
    end

    local results = {}
    local successCount = 0
    local totalCount = #keys

    for i, key in ipairs(keys) do
        local success, data = cloudService:GetTableOrEmpty(key)
        if success then
            local dataStr = gg.jsonEncode(data) or "无法序列化数据"
            table.insert(results, string.format("[%d] 键名: %s\n数据: %s", i, key, dataStr))
            successCount = successCount + 1
        else
            table.insert(results, string.format("[%d] 键名: %s\n状态: 获取失败", i, key))
        end
    end

    local msg = string.format("批量查看完成 (%d/%d 成功)\n%s", successCount, totalCount, table.concat(results, "\n\n"))
    gg.log("批量查看 CloudService 数据", "成功:", successCount, "总数:", totalCount)
    return true, msg
end

--- 批量删除多个键的数据
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function batchRemoveCloudData(params, player)
    local keys = params["键名列表"]
    if not keys or type(keys) ~= "table" then
        return false, "缺少'键名列表'参数或参数格式错误"
    end

    local results = {}
    local successCount = 0
    local totalCount = #keys

    for i, key in ipairs(keys) do
        local success = cloudService:RemoveKey(key)
        if success then
            table.insert(results, string.format("[%d] 键名: %s - 删除成功", i, key))
            successCount = successCount + 1
        else
            table.insert(results, string.format("[%d] 键名: %s - 删除失败", i, key))
        end
    end

    local msg = string.format("批量删除完成 (%d/%d 成功)\n%s", successCount, totalCount, table.concat(results, "\n"))
    gg.log("批量删除 CloudService 数据", "成功:", successCount, "总数:", totalCount)
    return true, msg
end

--- 删除指定玩家的所有数据
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
local function removePlayerAllData(params, player)
    local targetUin = params["玩家UIN"]
    if not targetUin then
        return false, "缺少'玩家UIN'参数"
    end

    local uin = tonumber(targetUin)
    if not uin then
        return false, "玩家UIN格式错误，必须是数字"
    end

    local results = {}
    local successCount = 0
    local totalCount = 0

    -- 为每个前缀生成对应的 key 并删除
    for _, prefix in ipairs(CLOUD_KEY_PREFIXES) do
        local key = prefix .. uin
        totalCount = totalCount + 1
        
        local success = cloudService:RemoveKey(key)
        if success then
            table.insert(results, string.format("✓ %s - 删除成功", key))
            successCount = successCount + 1
        else
            table.insert(results, string.format("✗ %s - 删除失败", key))
        end
    end

    local msg = string.format("玩家 [UIN:%d] 所有数据删除完成 (%d/%d 成功)\n%s", 
        uin, successCount, totalCount, table.concat(results, "\n"))
    gg.log("删除指定玩家所有数据", "玩家UIN:", uin, "成功:", successCount, "总数:", totalCount)
    player:SendHoverText(msg)
    return true, msg
end

--- CloudService 数据管理指令主入口
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean 是否成功
---@return string 结果消息
function CloudDataCommand.main(params, player)
    -- 权限检查
    if not gg.opUin[player.uin] then
        return false, "你没有执行此指令的权限"
    end

    local operationType = params["操作类型"]
    if not operationType then
        return false, "缺少'操作类型'参数。有效类型: '查看', '删除', '设置为空', '批量查看', '批量删除', '删除指定玩家所有数据'"
    end

    gg.log("CloudService 数据管理指令执行", "操作类型:", operationType, "执行者:", player.name)

    if operationType == "查看" then
        return viewCloudData(params, player)
    elseif operationType == "删除" then
        return removeCloudData(params, player)
    elseif operationType == "设置为空" then
        return setCloudDataEmpty(params, player)
    elseif operationType == "批量查看" then
        return batchViewCloudData(params, player)
    elseif operationType == "批量删除" then
        return batchRemoveCloudData(params, player)
    elseif operationType == "删除指定玩家所有数据" then
        return removePlayerAllData(params, player)
    else
        return false, "未知的操作类型: " .. operationType .. "。有效类型: '查看', '删除', '设置为空', '批量查看', '批量删除', '删除指定玩家所有数据'"
    end
end

return CloudDataCommand