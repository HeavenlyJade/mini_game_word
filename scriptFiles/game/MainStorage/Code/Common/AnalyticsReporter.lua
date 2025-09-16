-- PlayerManagerWithAnalytics.lua
-- 玩家管理系统的数据埋点使用示例
-- 展示如何调用 AnalyticsReporter 静态类的方法

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

-- 引入数据埋点静态类
local AnalyticsReporter = require(MainStorage.Code.Common.AnalyticsReporter)

---@class PlayerManagerWithAnalytics
local PlayerManagerWithAnalytics = {}

--- 玩家加入处理
---@param player table 玩家对象
function PlayerManagerWithAnalytics.OnPlayerJoin(player)
    local uin = player.UserId
    local playerName = player.name
    local loginTime = gg.GetTimeStamp()
    
    -- 调用静态类方法上报玩家登录埋点
    AnalyticsReporter.ReportPlayerLogin(uin, playerName, loginTime)
    
    gg.log("玩家登录埋点已上报", uin, playerName)
end

--- 玩家离开处理
---@param player table 玩家对象
---@param onlineTime number 在线时长
function PlayerManagerWithAnalytics.OnPlayerLeave(player, onlineTime)
    local uin = player.UserId
    local playerName = player.name
    local logoutTime = gg.GetTimeStamp()
    
    -- 调用静态类方法上报玩家离线埋点
    AnalyticsReporter.ReportPlayerLogout(uin, playerName, onlineTime, logoutTime)
    
    gg.log("玩家离线埋点已上报", uin, playerName, "在线时长", onlineTime, "秒")
end

--- 玩家行为埋点
---@param uin number 玩家ID
---@param actionType string 行为类型
---@param details string 行为详情
function PlayerManagerWithAnalytics.ReportPlayerBehavior(uin, actionType, details)
    -- 调用静态类方法上报玩家行为
    AnalyticsReporter.ReportPlayerAction(uin, actionType, details, {
        mapId = "map_001",
        level = 10,
        gold = 1000,
    })
end

--- 游戏开始埋点
---@param uin number 玩家ID
---@param gameMode string 游戏模式
---@param mapId string 地图ID
function PlayerManagerWithAnalytics.StartGame(uin, gameMode, mapId)
    -- 调用静态类方法上报游戏开始埋点
    AnalyticsReporter.ReportGameStart(uin, gameMode, mapId, {
        difficulty = "normal",
        playerLevel = 15,
        teamSize = 1,
    })
    
    gg.log("游戏开始埋点已上报", uin, gameMode, mapId)
end

--- 游戏结束埋点
---@param uin number 玩家ID
---@param gameMode string 游戏模式
---@param result string 游戏结果
---@param duration number 游戏时长
---@param score number 得分
function PlayerManagerWithAnalytics.EndGame(uin, gameMode, result, duration, score)
    -- 调用静态类方法上报游戏结束埋点
    AnalyticsReporter.ReportGameEnd(uin, gameMode, result, duration, score)
    
    gg.log("游戏结束埋点已上报", uin, gameMode, result, "时长", duration, "秒")
end

--- 按钮点击埋点
---@param uin number 玩家ID
---@param buttonName string 按钮名称
---@param pageName string 页面名称
function PlayerManagerWithAnalytics.OnButtonClick(uin, buttonName, pageName)
    -- 调用静态类方法上报UI点击埋点
    AnalyticsReporter.ReportUIClick(uin, buttonName, pageName, {
        buttonType = "primary",
        position = "top_right",
    })
    
    gg.log("UI点击埋点已上报", uin, buttonName, pageName)
end

--- 页面访问埋点
---@param uin number 玩家ID
---@param pageName string 页面名称
---@param fromPage string|nil 来源页面
function PlayerManagerWithAnalytics.OnPageOpen(uin, pageName, fromPage)
    -- 调用静态类方法上报页面访问埋点
    AnalyticsReporter.ReportPageView(uin, pageName, fromPage)
    
    gg.log("页面访问埋点已上报", uin, pageName, "来源", fromPage)
end

--- 奖励领取埋点
---@param uin number 玩家ID
---@param rewardData table 奖励数据
function PlayerManagerWithAnalytics.ClaimReward(uin, rewardData)
    -- 调用静态类方法上报奖励领取埋点
    AnalyticsReporter.ReportRewardClaim(
        uin,
        rewardData.type,
        rewardData.id,
        rewardData.value,
        rewardData.source
    )
    
    gg.log("奖励领取埋点已上报", uin, rewardData.type, rewardData.value)
end

--- 商店购买埋点
---@param uin number 玩家ID
---@param itemId string 物品ID
---@param itemType string 物品类型
---@param price number 价格
---@param currency string 货币类型
function PlayerManagerWithAnalytics.ReportShopPurchase(uin, itemId, itemType, price, currency)
    -- 调用静态类方法进行自定义埋点
    AnalyticsReporter.ReportCustom({
        sceneId = AnalyticsReporter.SCENE_IDS.GAME,
        cardId = "SHOP_PURCHASE",
        compId = "ShopSystem",
        eventCode = "purchase",
        data = {
            standby1 = uin,
            standby2 = itemId,
            standby3 = itemType,
            standby4 = price,
            standby5 = currency,
            standby6 = os.date("%Y-%m-%d %H:%M:%S"),
            standby7 = "shop_purchase",
        }
    })
end

--- 社交功能埋点
---@param uin number 玩家ID
---@param actionType string 行为类型
---@param targetUin number 目标玩家ID
---@param extraInfo table 额外信息
function PlayerManagerWithAnalytics.ReportSocialAction(uin, actionType, targetUin, extraInfo)
    -- 调用静态类方法进行自定义埋点
    AnalyticsReporter.ReportCustom({
        sceneId = AnalyticsReporter.SCENE_IDS.PLAYER,
        cardId = "SOCIAL_ACTION",
        compId = "SocialSystem",
        eventCode = actionType,
        data = {
            standby1 = uin,
            standby2 = actionType,
            standby3 = targetUin,
            standby4 = extraInfo.detail or "",
            standby5 = os.date("%Y-%m-%d %H:%M:%S"),
        }
    })
end

--- 错误日志埋点
---@param errorType string 错误类型
---@param errorMessage string 错误信息
---@param context string 上下文
function PlayerManagerWithAnalytics.ReportError(errorType, errorMessage, context)
    -- 调用静态类方法进行自定义埋点
    AnalyticsReporter.ReportCustom({
        sceneId = AnalyticsReporter.SCENE_IDS.SYSTEM,
        cardId = "ERROR_LOG",
        compId = "ErrorTracker",
        eventCode = "error",
        data = {
            standby1 = errorType,
            standby2 = errorMessage,
            standby3 = context,
            standby4 = os.date("%Y-%m-%d %H:%M:%S"),
            standby5 = "system_error",
        }
    })
end

--- 批量上报示例
---@param uin number 玩家ID
function PlayerManagerWithAnalytics.ReportBatchEvents(uin)
    local batchReports = {
        -- 玩家属性更新
        {
            sceneId = AnalyticsReporter.SCENE_IDS.PLAYER,
            cardId = "PLAYER_STAT_UPDATE",
            compId = "PlayerStats",
            eventCode = "update",
            data = {
                standby1 = uin,
                standby2 = "level_up",
                standby3 = "20",
                standby4 = os.date("%Y-%m-%d %H:%M:%S"),
            }
        },
        
        -- 成就解锁
        {
            sceneId = AnalyticsReporter.SCENE_IDS.GAME,
            cardId = "ACHIEVEMENT_UNLOCK",
            compId = "AchievementSystem",
            eventCode = "unlock",
            data = {
                standby1 = uin,
                standby2 = "first_victory",
                standby3 = "战斗成就",
                standby4 = os.date("%Y-%m-%d %H:%M:%S"),
            }
        },
    }
    
    -- 调用静态类方法批量上报
    AnalyticsReporter.ReportBatch(batchReports)
    gg.log("批量埋点上报完成", #batchReports, "条")
end

--- 定时上报服务器统计
function PlayerManagerWithAnalytics.ReportServerStats()
    local onlinePlayerCount = 25
    local avgOnlineTime = 1800  -- 30分钟
    
    -- 调用静态类方法上报在线统计
    AnalyticsReporter.ReportOnlineStats(onlinePlayerCount, avgOnlineTime)
    
    -- 调用静态类方法上报性能统计
    local fps = 60
    local memoryUsage = 512  -- MB
    local serverLoad = 0.75  -- 75%
    
    AnalyticsReporter.ReportPerformance(fps, memoryUsage, serverLoad)
    
    gg.log("定时统计上报完成")
end

--- 初始化定时上报
function PlayerManagerWithAnalytics.InitPeriodicReporting()
    -- 每10分钟上报一次统计数据
    local timer = SandboxNode.New("Timer", game.WorkSpace)
    timer.Name = "PeriodicAnalyticsTimer"
    timer.Delay = 600
    timer.Loop = true
    timer.Interval = 600
    timer.Callback = function()
        PlayerManagerWithAnalytics.ReportServerStats()
    end
    timer:Start()
    
    gg.log("定时埋点上报系统已启动")
end

--- 使用常量进行埋点
---@param uin number 玩家ID
function PlayerManagerWithAnalytics.UseConstants(uin)
    -- 使用预定义的场景ID和事件代码
    AnalyticsReporter.ReportCustom({
        sceneId = AnalyticsReporter.SCENE_IDS.GAME,
        cardId = AnalyticsReporter.CARD_IDS.GAME_MODE,
        compId = "GameModeSelector",
        eventCode = AnalyticsReporter.EVENT_CODES.CLICK,
        data = {
            standby1 = uin,
            standby2 = "racing_mode",
            standby3 = "mode_selection",
        }
    })
end

return PlayerManagerWithAnalytics