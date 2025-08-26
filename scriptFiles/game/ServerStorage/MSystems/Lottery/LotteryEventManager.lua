-- LotteryEventManager.lua
-- 抽奖系统事件管理器 - 静态类
-- 负责处理客户端请求和服务器响应事件

local game = game
local os = os
local pairs = pairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
-- 引入事件系统
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local LotteryEvent = require(MainStorage.Code.Event.LotteryEvent) ---@type LotteryEvent
local LotteryMgr = require(ServerStorage.MSystems.Lottery.LotteryMgr) ---@type LotteryMgr
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class LotteryEventManager
local LotteryEventManager = {}

--- 初始化事件监听器
function LotteryEventManager.Init()

    -- 订阅客户端请求事件
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.GET_LOTTERY_DATA, LotteryEventManager.OnGetLotteryData)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.SINGLE_DRAW, LotteryEventManager.OnSingleDraw)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.FIVE_DRAW, LotteryEventManager.OnFiveDraw)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.TEN_DRAW, LotteryEventManager.OnTenDraw)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.GET_DRAW_HISTORY, LotteryEventManager.OnGetDrawHistory)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.GET_AVAILABLE_POOLS, LotteryEventManager.OnGetAvailablePools)
    ServerEventManager.Subscribe(LotteryEvent.REQUEST.GET_POOL_STATS, LotteryEventManager.OnGetPoolStats)

end

--- 处理获取抽奖数据请求
---@param event table 事件对象
function LotteryEventManager.OnGetLotteryData(event)
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName
    gg.log("获取抽奖数据请求", event)
    if not player or not uin then
        return
    end

    local result = LotteryMgr.GetPlayerLotteryData(uin, poolName)

    -- 发送响应给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.LOTTERY_DATA, {
        success = result.success,
        data = result.success and {
            poolData = result.poolData,
            pityProgress = result.pityProgress,
            poolStats = result.poolStats,
            lotteryPools = result.lotteryPools,
            totalDrawCount = result.totalDrawCount
        } or nil,
        errorMsg = result.errorMsg
    })
end

--- 处理单次抽奖请求
---@param event table 事件对象
function LotteryEventManager.OnSingleDraw(event)
    gg.log("=== 收到单次抽奖请求 ===")
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName

    gg.log("玩家信息:", player and player.Name or "nil", "UIN:", uin)
    gg.log("请求参数:", args)
    gg.log("抽奖池名称:", poolName)

    if not player or not uin then
        gg.log("错误：玩家对象或UIN无效")
        return
    end

    if not poolName then
        gg.log("错误：抽奖池名称不能为空")
        LotteryEventManager.SendErrorResponse(uin, "抽奖池名称不能为空")
        return
    end

    gg.log("开始调用LotteryMgr.SingleDraw...")
    local result = LotteryMgr.SingleDraw(uin, poolName)
    gg.log("LotteryMgr.SingleDraw返回结果:", result)

    -- 发送抽奖结果给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.DRAW_RESULT, {
        success = result.success,
        drawType = "single",
        poolName = poolName,
        rewards = result.rewards,
        totalCost = result.totalCost,
        costType = result.costType,
        pityProgress = result.pityProgress,
        errorMsg = result.errorMsg
    })

    -- 如果抽奖成功，发送成功通知
    if result.success then
        LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.DRAW_SUCCESS, {
            poolName = poolName,
            drawType = "single",
            rewards = result.rewards
        })
        
        -- 发送物品获得通知给NoticeGui
        LotteryEventManager.SendItemAcquiredNotification(uin, result.rewards, poolName)
    else
        gg.log("抽奖失败:", result.errorMsg)
        player:SendHoverText("抽奖失败:"..result.errorMsg)
    end

    gg.log("=== 单次抽奖请求处理完成 ===")
end

--- 处理五连抽请求
---@param event table 事件对象
function LotteryEventManager.OnFiveDraw(event)
    gg.log("=== 收到五连抽请求 ===")
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName

    gg.log("玩家信息:", player and player.Name or "nil", "UIN:", uin)
    gg.log("请求参数:", args)
    gg.log("抽奖池名称:", poolName)

    if not player or not uin then
        gg.log("错误：玩家对象或UIN无效")
        return
    end

    if not poolName then
        gg.log("错误：抽奖池名称不能为空")
        LotteryEventManager.SendErrorResponse(uin, "抽奖池名称不能为空")
        return
    end

    gg.log("开始调用LotteryMgr.FiveDraw...")
    local result = LotteryMgr.FiveDraw(uin, poolName)
    -- gg.log("LotteryMgr.FiveDraw返回结果:", result)

    -- 发送抽奖结果给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.DRAW_RESULT, {
        success = result.success,
        drawType = "five",
        poolName = poolName,
        rewards = result.rewards,
        totalCost = result.totalCost,
        costType = result.costType,
        pityProgress = result.pityProgress,
        errorMsg = result.errorMsg
    })

    -- 如果抽奖成功，发送成功通知
    if result.success then
        LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.DRAW_SUCCESS, {
            poolName = poolName,
            drawType = "five",
            rewards = result.rewards
        })
        
        -- 发送物品获得通知给NoticeGui
        LotteryEventManager.SendItemAcquiredNotification(uin, result.rewards, poolName)
    else
        gg.log("抽奖失败:", result.errorMsg)
        player:SendHoverText("抽奖失败:"..result.errorMsg)

    end

    gg.log("=== 五连抽请求处理完成 ===")
end

--- 处理十连抽请求
---@param event table 事件对象
function LotteryEventManager.OnTenDraw(event)
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName

    if not player or not uin then
        return
    end

    if not poolName then
        LotteryEventManager.SendErrorResponse(uin, "抽奖池名称不能为空")
        return
    end

    local result = LotteryMgr.TenDraw(uin, poolName)

    -- 发送抽奖结果给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.DRAW_RESULT, {
        success = result.success,
        drawType = "ten",
        poolName = poolName,
        rewards = result.rewards,
        totalCost = result.totalCost,
        costType = result.costType,
        pityProgress = result.pityProgress,
        errorMsg = result.errorMsg
    })

    -- 如果抽奖成功，发送成功通知
    if result.success then
        LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.DRAW_SUCCESS, {
            poolName = poolName,
            drawType = "ten",
            rewards = result.rewards
        })
        
        -- 发送物品获得通知给NoticeGui
        LotteryEventManager.SendItemAcquiredNotification(uin, result.rewards, poolName)
    end
end

--- 处理获取抽奖历史请求
---@param event table 事件对象
function LotteryEventManager.OnGetDrawHistory(event)
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName
    local limit = args.limit or 50

    if not player or not uin then
        return
    end

    local result = LotteryMgr.GetPlayerDrawHistory(uin, poolName, limit)

    -- 发送历史记录给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.DRAW_HISTORY, {
        success = result.success,
        poolName = poolName,
        history = result.history,
        total = result.total,
        errorMsg = result.errorMsg
    })
end

--- 处理获取可用抽奖池请求
---@param event table 事件对象
function LotteryEventManager.OnGetAvailablePools(event)
    local player = event.player
    local uin = player.uin

    if not player or not uin then
        return
    end

    local pools = LotteryMgr.GetAvailablePools()

    -- 发送可用抽奖池列表给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.AVAILABLE_POOLS, {
        success = true,
        pools = pools,
        count = #pools
    })
end

--- 处理获取抽奖池统计请求
---@param event table 事件对象
function LotteryEventManager.OnGetPoolStats(event)
    local player = event.player
    local uin = player.uin
    local args = event.args or {}
    local poolName = args.poolName

    if not player or not uin then
        return
    end

    if not poolName then
        LotteryEventManager.SendErrorResponse(uin, "抽奖池名称不能为空")
        return
    end

    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)
    if not lotterySystem then
        LotteryEventManager.SendErrorResponse(uin, "抽奖系统未初始化")
        return
    end

    local stats = lotterySystem:GetPoolStats(poolName)

    -- 发送统计数据给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.POOL_STATS, {
        success = true,
        poolName = poolName,
        stats = stats
    })
end

-- 通用响应方法 --------------------------------------------------------

--- 发送成功响应
---@param uin number 玩家UIN
---@param eventName string 响应事件名
---@param data table 响应数据
function LotteryEventManager.SendSuccessResponse(uin, eventName, data)
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
    })
end

--- 发送错误响应
---@param uin number 玩家UIN
---@param errorMsg string 错误信息
function LotteryEventManager.SendErrorResponse(uin, errorMsg)
    gg.network_channel:fireClient(uin, {
        cmd = LotteryEvent.RESPONSE.ERROR,
        data = {
            errorMsg = errorMsg
        }
    })
end

--- 发送通知
---@param uin number 玩家UIN
---@param eventName string 通知事件名
---@param data table 通知数据
function LotteryEventManager.SendNotification(uin, eventName, data)
    gg.network_channel:fireClient(uin, {
        cmd = eventName,
        data = data
    })
end

--- 发送保底进度更新通知
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
---@param pityProgress number 保底进度
function LotteryEventManager.SendPityUpdate(uin, poolName, pityProgress)
    LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.PITY_UPDATE, {
        poolName = poolName,
        pityProgress = pityProgress
    })
end

--- 发送新抽奖池可用通知
---@param uin number 玩家ID
---@param poolName string 抽奖池名称
function LotteryEventManager.SendNewPoolAvailable(uin, poolName)
    LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.NEW_POOL_AVAILABLE, {
        poolName = poolName
    })
end

--- 发送数据同步通知
---@param uin number 玩家ID
---@param lotteryData table 抽奖数据
function LotteryEventManager.SendDataSync(uin, lotteryData)
    LotteryEventManager.SendNotification(uin, LotteryEvent.NOTIFY.DATA_SYNC, {
        lotteryData = lotteryData
    })
end

--- 广播抽奖成功消息（可选功能，用于全服通知稀有奖励）
---@param playerName string 玩家名称
---@param poolName string 抽奖池名称
---@param rewardName string 奖励名称
---@param rarity string 稀有度
function LotteryEventManager.BroadcastRareReward(playerName, poolName, rewardName, rarity)
    if rarity == "SSR" or rarity == "UR" then
        -- 这里可以实现全服广播逻辑
        gg.log("全服广播：玩家", playerName, "在", poolName, "中获得了", rarity, "级奖励", rewardName)

        -- 可以通过其他系统发送全服消息
        -- 例如：ChatMgr.BroadcastSystemMessage(message)
    end
end

--- 新增：向客户端通知所有初始抽奖数据
---@param uin number 玩家UIN
function LotteryEventManager.NotifyAllDataToClient(uin)
    local lotterySystem = LotteryMgr.GetPlayerLottery(uin)

    if not lotterySystem then
        gg.log("警告: 玩家", uin, "的抽奖数据不存在，跳过抽奖数据同步")
        return
    end

    -- 获取所有抽奖池数据
    local lotteryData = lotterySystem:GetData()

    -- 发送完整抽奖数据给客户端
    LotteryEventManager.SendSuccessResponse(uin, LotteryEvent.RESPONSE.LOTTERY_DATA, {
        success = true,
        data = lotteryData
    })

    gg.log("已主动同步抽奖数据到客户端:", uin)
end

--- 发送物品获得通知给NoticeGui
---@param uin number 玩家UIN
---@param rewards table[] 奖励列表
---@param poolName string 抽奖池名称
function LotteryEventManager.SendItemAcquiredNotification(uin, rewards, poolName)
    if not rewards or #rewards == 0 then
        return
    end
    
    -- 转换奖励数据格式为NoticeGui需要的格式
    local noticeRewards = {}
    for _, reward in ipairs(rewards) do
        -- 从抽奖系统的奖励记录中获取正确的类型和名称
        local itemType = reward.rewardType or "物品" -- 使用抽奖系统返回的rewardType
        local itemName = reward.rewardName or "未知物品" -- 使用抽奖系统返回的rewardName
        gg.log("奖励类型:", itemType,itemName)
        -- 如果itemType是中文，直接使用；如果是英文，转换为中文
        if itemType == "pet" then
            itemType = "宠物"
        elseif itemType == "partner" then
            itemType = "伙伴"
        elseif itemType == "wing" then
            itemType = "翅膀"
        elseif itemType == "trail" then
            itemType = "尾迹"
        elseif itemType == "item" then
            itemType = "物品"
        end
        
        table.insert(noticeRewards, {
            itemType = itemType,
            itemName = itemName,
            amount = reward.quantity or 1
        })
    end
    
    -- 发送物品获得通知
    gg.network_channel:fireClient(uin, {
        cmd = EventPlayerConfig.NOTIFY.ITEM_ACQUIRED_NOTIFY,
        data = {
            rewards = noticeRewards,
            source = "抽奖获得",
            message = string.format("恭喜在%s中获得了以下物品！", poolName or "抽奖池")
        }
    })
    
    gg.log("已发送物品获得通知给玩家", uin, "奖励数量:", #noticeRewards)
    -- 打印详细的奖励信息用于调试
    for i, reward in ipairs(noticeRewards) do
        gg.log(string.format("奖励%d: 类型=%s, 名称=%s, 数量=%d", i, reward.itemType, reward.itemName, reward.amount))
    end
end

return LotteryEventManager
