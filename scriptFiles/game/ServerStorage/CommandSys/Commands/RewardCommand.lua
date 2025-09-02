--- 奖励系统相关命令处理器
--- 用于管理员修改玩家在线奖励数据
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RewardMgr = require(ServerStorage.MSystems.Reward.RewardMgr) ---@type RewardMgr

---@class RewardCommand
local RewardCommand = {}

--- 设置玩家在线时长
---@param params table 参数表
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function RewardCommand.setOnlineTime(params, player)
    local todayTime = tonumber(params["今日时长"]) 
    local roundTime = tonumber(params["本轮时长"])
    
    -- 参数验证
    if not todayTime and not roundTime then
        --player:SendHoverText("缺少时长参数：至少需要提供'今日时长'或'本轮时长'")
        return false
    end
    
    if todayTime and todayTime < 0 then
        --player:SendHoverText("今日时长不能为负数")
        return false
    end
    
    if roundTime and roundTime < 0 then
        --player:SendHoverText("本轮时长不能为负数")
        return false
    end
    
    -- 获取玩家奖励实例
    local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
    if not rewardInstance then
        --player:SendHoverText("玩家奖励数据未加载")
        gg.log(string.format("错误：玩家 %s (UIN:%d) 奖励数据未加载", player.name, player.uin))
        return false
    end
    
    -- 记录修改前的数据
    local oldTodayTime = rewardInstance.onlineData.todayOnlineTime
    local oldRoundTime = rewardInstance.onlineData.roundOnlineTime
    
    -- 执行修改
    local modified = {}
    if todayTime then
        rewardInstance.onlineData.todayOnlineTime = todayTime
        table.insert(modified, string.format("今日时长: %d→%d", oldTodayTime, todayTime))
    end
    
    if roundTime then
        rewardInstance.onlineData.roundOnlineTime = roundTime
        table.insert(modified, string.format("本轮时长: %d→%d", oldRoundTime, roundTime))
    end
    
    -- 同步客户端数据
    RewardMgr.SyncDataToClient(player)
    
    -- 立即保存数据
    RewardMgr.SavePlayerData(player.uin)
    
    local msg = string.format("成功设置玩家 %s 的在线时长: %s", player.name, table.concat(modified, ", "))
    --player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 设置玩家奖励轮次
---@param params table 参数表
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function RewardCommand.setRound(params, player)
    local round = tonumber(params["轮次"])
    
    -- 参数验证
    if not round then
        --player:SendHoverText("缺少'轮次'参数或参数格式错误")
        return false
    end
    
    if round < 1 then
        --player:SendHoverText("轮次必须大于等于1")
        return false
    end
    
    -- 获取玩家奖励实例
    local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
    if not rewardInstance then
        --player:SendHoverText("玩家奖励数据未加载")
        gg.log(string.format("错误：玩家 %s (UIN:%d) 奖励数据未加载", player.name, player.uin))
        return false
    end
    
    -- 记录修改前的数据
    local oldRound = rewardInstance.onlineData.currentRound
    
    -- 执行修改
    rewardInstance.onlineData.currentRound = round
    
    -- 同步客户端数据
    RewardMgr.SyncDataToClient(player)
    
    -- 立即保存数据
    RewardMgr.SavePlayerData(player.uin)
    
    local msg = string.format("成功设置玩家 %s 的奖励轮次: %d→%d", player.name, oldRound, round)
    --player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 设置已领取的奖励
---@param params table 参数表
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function RewardCommand.setClaimed(params, player)
    local indexList = params["索引列表"]
    
    -- 参数验证
    if not indexList or type(indexList) ~= "table" then
        --player:SendHoverText("缺少'索引列表'参数或参数格式错误，应为数组格式")
        return false
    end
    
    -- 验证索引有效性
    for _, index in ipairs(indexList) do
        local indexNum = tonumber(index)
        if not indexNum or indexNum < 1 then
            --player:SendHoverText(string.format("无效的奖励索引: %s", tostring(index)))
            return false
        end
    end
    
    -- 获取玩家奖励实例
    local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
    if not rewardInstance then
        --player:SendHoverText("玩家奖励数据未加载")
        gg.log(string.format("错误：玩家 %s (UIN:%d) 奖励数据未加载", player.name, player.uin))
        return false
    end
    
    -- 记录修改前的数据
    local oldClaimedCount = #rewardInstance.onlineData.claimedIndices
    
    -- 转换为数字并去重
    local newClaimedIndices = {}
    local indexMap = {}
    for _, index in ipairs(indexList) do
        local indexNum = tonumber(index)
        if indexNum and not indexMap[indexNum] then
            table.insert(newClaimedIndices, indexNum)
            indexMap[indexNum] = true
        end
    end
    
    -- 执行修改
    rewardInstance.onlineData.claimedIndices = newClaimedIndices
    
    -- 同步客户端数据
    RewardMgr.SyncDataToClient(player)
    
    -- 立即保存数据
    RewardMgr.SavePlayerData(player.uin)
    
    local msg = string.format("成功设置玩家 %s 的已领取奖励: %d个→%d个 [%s]", 
        player.name, oldClaimedCount, #newClaimedIndices, table.concat(newClaimedIndices, ","))
    --player:SendHoverText(msg)
    gg.log(msg)
    
    return true
end

--- 清除已领取的奖励（设为未领取）
---@param params table 参数表
---@param player MPlayer 玩家对象
---@return boolean 是否成功
function RewardCommand.clearClaimed(params, player)
    local indexList = params["索引列表"]
    
    -- 获取玩家奖励实例
    local rewardInstance = RewardMgr.GetPlayerReward(player.uin)
    if not rewardInstance then
        --player:SendHoverText("玩家奖励数据未加载")
        gg.log(string.format("错误：玩家 %s (UIN:%d) 奖励数据未加载", player.name, player.uin))
        return false
    end
    
    local oldClaimedIndices = {}
    for _, index in ipairs(rewardInstance.onlineData.claimedIndices) do
        table.insert(oldClaimedIndices, index)
    end
    
    if not indexList or type(indexList) ~= "table" or #indexList == 0 then
        -- 清除所有已领取状态
        rewardInstance.onlineData.claimedIndices = {}
        
        local msg = string.format("成功清除玩家 %s 的所有已领取奖励状态 (原有%d个)", 
            player.name, #oldClaimedIndices)
        --player:SendHoverText(msg)
        gg.log(msg)
    else
        -- 清除指定索引的已领取状态
        local clearIndexMap = {}
        for _, index in ipairs(indexList) do
            local indexNum = tonumber(index)
            if indexNum then
                clearIndexMap[indexNum] = true
            end
        end
        
        -- 过滤掉需要清除的索引
        local newClaimedIndices = {}
        for _, index in ipairs(rewardInstance.onlineData.claimedIndices) do
            if not clearIndexMap[index] then
                table.insert(newClaimedIndices, index)
            end
        end
        
        rewardInstance.onlineData.claimedIndices = newClaimedIndices
        
        local clearedCount = #oldClaimedIndices - #newClaimedIndices
        local msg = string.format("成功清除玩家 %s 的指定奖励领取状态: 清除%d个，剩余%d个", 
            player.name, clearedCount, #newClaimedIndices)
        --player:SendHoverText(msg)
        gg.log(msg)
    end
    
    -- 同步客户端数据
    RewardMgr.SyncDataToClient(player)
    
    -- 立即保存数据
    RewardMgr.SavePlayerData(player.uin)
    
    return true
end

-- 中文到英文的操作映射
local operationMap = {
    ["设置在线时长"] = "setOnlineTime",
    ["设置轮次"] = "setRound",
    ["设置已领取"] = "setClaimed",
    ["清除已领取"] = "clearClaimed"
}

--- 奖励操作指令入口
---@param params table 奖励命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function RewardCommand.main(params, player)
    local operationType = params["操作类型"]
    
    -- 参数验证
    if not operationType then
        --player:SendHoverText("缺少'操作类型'字段。有效类型: '设置在线时长', '设置轮次', '设置已领取', '清除已领取'")
        return false
    end
    
    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        --player:SendHoverText("未知的操作类型: " .. operationType .. 
            -- "。有效类型: '设置在线时长', '设置轮次', '设置已领取', '清除已领取'")
        return false
    end
    
    local handler = RewardCommand[handlerName]
    if handler then
        gg.log("奖励命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- 理论上不会执行到这里，因为上面已经检查过了
        --player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return RewardCommand