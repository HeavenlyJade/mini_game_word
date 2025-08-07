local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local LotteryEventConfig = require(MainStorage.Code.Event.LotteryEvent) ---@type LotteryEvent
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "LotteryGui",
    layer = 3,
    hideOnInit = true,
}

---@class LotteryGui:ViewBase
local LotteryGui = ClassMgr.Class("LotteryGui", ViewBase)

---@override
function LotteryGui:OnInit(node, config)
    -- 1. 节点初始化
    self.lotteryPanel = self:Get("黑色底图", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("黑色底图/抽奖界面/关闭", ViewButton) ---@type ViewButton

    -- 抽奖按钮
    self.singleDrawButton = self:Get("黑色底图/抽奖界面/单抽", ViewButton) ---@type ViewButton
    self.fiveDrawButton = self:Get("黑色底图/抽奖界面/五连抽", ViewButton) ---@type ViewButton

    -- 价格显示
    self.singlePriceComponent = self:Get("黑色底图/抽奖界面/单抽/价格圈/价格框", ViewComponent) ---@type ViewComponent
    self.fivePriceComponent = self:Get("黑色底图/抽奖界面/五连抽/价格图/价格框", ViewComponent) ---@type ViewComponent

    -- 抽奖档位
    self.lotteryTierComponent = self:Get("黑色底图/抽奖档位", ViewList) ---@type ViewList

    -- 概率解锁栏位
    self.probabilityUnlockPanel = self:Get("黑色底图/概率解锁栏位", ViewList) ---@type ViewList

    self.primaryTierButton = self:Get("黑色底图/概率解锁栏位/初级档位", ViewButton) ---@type ViewButton
    self.intermediateTierButton = self:Get("黑色底图/概率解锁栏位/中级档位", ViewButton) ---@type ViewButton
    self.advancedTierButton = self:Get("黑色底图/概率解锁栏位/高级档位", ViewButton) ---@type ViewButton
    self.superTierButton = self:Get("黑色底图/概率解锁栏位/超级档位", ViewButton) ---@type ViewButton

    -- 概率显示
    self.normalProbabilityComponent = self:Get("黑色底图/普通概率/价格图", ViewComponent) ---@type ViewComponent
    self.advancedProbabilityComponent = self:Get("黑色底图/高级概率/价格圈", ViewComponent) ---@type ViewComponent

    -- 奖励模板
    self.rewardTemplate = self:Get("黑色底图/抽奖界面/模版界面/奖励模版", ViewComponent) ---@type ViewComponent

    -- 抽奖类型按钮
    self.wingLotteryButton = self:Get("黑色底图/抽奖翅膀_初级", ViewButton) ---@type ViewButton
    self.petLotteryButton = self:Get("黑色底图/抽奖宠物_初级", ViewButton) ---@type ViewButton
    self.partnerLotteryButton = self:Get("黑色底图/抽奖伙伴_初级", ViewButton) ---@type ViewButton

    -- 数据存储
    self.lotteryData = {} ---@type table 抽奖数据
    self.currentPoolName = nil ---@type string|nil 当前选择的抽奖池
    self.availablePools = {} ---@type table 可用抽奖池列表
    self.pityProgress = {} ---@type table 保底进度数据
    self.lotteryConfigs = {} ---@type table 抽奖配置缓存
    self.priceConfigs = {} ---@type table 价格配置缓存

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    ----gg.log("LotteryGui 抽奖界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function LotteryGui:RegisterEvents()
    ----gg.log("注册抽奖系统事件监听")

    -- 监听抽奖数据响应
    ClientEventManager.Subscribe(LotteryEventConfig.RESPONSE.LOTTERY_DATA, function(data)
        self:OnLotteryDataResponse(data)
    end)

    -- 监听抽奖结果响应
    ClientEventManager.Subscribe(LotteryEventConfig.RESPONSE.DRAW_RESULT, function(data)
        self:OnLotteryResultResponse(data)
    end)

    -- 监听抽奖成功通知
    ClientEventManager.Subscribe(LotteryEventConfig.NOTIFY.DRAW_SUCCESS, function(data)
        self:OnLotterySuccessNotify(data)
    end)

    -- 监听保底进度更新通知
    ClientEventManager.Subscribe(LotteryEventConfig.NOTIFY.PITY_UPDATE, function(data)
        self:OnPityUpdateNotify(data)
    end)

    -- 监听新抽奖池可用通知
    ClientEventManager.Subscribe(LotteryEventConfig.NOTIFY.NEW_POOL_AVAILABLE, function(data)
        self:OnNewPoolAvailableNotify(data)
    end)

    -- 监听数据同步通知
    ClientEventManager.Subscribe(LotteryEventConfig.NOTIFY.DATA_SYNC, function(data)
        self:OnDataSyncNotify(data)
    end)

    -- 监听抽奖错误响应
    ClientEventManager.Subscribe(LotteryEventConfig.RESPONSE.ERROR, function(data)
        self:OnLotteryErrorResponse(data)
    end)
end

function LotteryGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function()
        self:Close()
    end

    -- 单抽按钮
    self.singleDrawButton.clickCb = function()
        self:OnClickSingleDraw()
    end

    -- 五连抽按钮
    self.fiveDrawButton.clickCb = function()
        self:OnClickFiveDraw()
    end

    -- 档位选择按钮
    self.primaryTierButton.clickCb = function()
        self:OnClickTierSelect("primary")
    end

    self.intermediateTierButton.clickCb = function()
        self:OnClickTierSelect("intermediate")
    end

    self.advancedTierButton.clickCb = function()
        self:OnClickTierSelect("advanced")
    end

    self.superTierButton.clickCb = function()
        self:OnClickTierSelect("super")
    end

    -- 抽奖类型选择按钮
    self.wingLotteryButton.clickCb = function()
        self:OnClickLotteryTypeSelect("wing")
    end

    self.petLotteryButton.clickCb = function()
        self:OnClickLotteryTypeSelect("pet")
    end

    self.partnerLotteryButton.clickCb = function()
        self:OnClickLotteryTypeSelect("partner")
    end

    ----gg.log("抽奖界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function LotteryGui:OnOpen()
    ----gg.log("LotteryGui抽奖界面打开")
    self:RequestLotteryData()
end

function LotteryGui:OnClose()
    ----gg.log("LotteryGui抽奖界面关闭")
end

-- =================================
-- 数据请求与响应
-- =================================

--- 请求抽奖数据
function LotteryGui:RequestLotteryData()
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_LOTTERY_DATA,
        args = {}
    }
    ----gg.log("请求抽奖数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 请求可用抽奖池
function LotteryGui:RequestAvailablePools()
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_AVAILABLE_POOLS,
        args = {}
    }
    ----gg.log("请求可用抽奖池")
    gg.network_channel:fireServer(requestData)
end

--- 请求抽奖池统计
function LotteryGui:RequestPoolStats(poolName)
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_POOL_STATS,
        args = { poolName = poolName }
    }
    ----gg.log("请求抽奖池统计:", poolName)
    gg.network_channel:fireServer(requestData)
end

--- 处理抽奖数据响应
function LotteryGui:OnLotteryDataResponse(data)
    ----gg.log("收到抽奖数据响应:", data)
    if data.success and data.data then
        self.lotteryData = data.data
        self.currentPoolName = data.data.currentPoolName or "wing_primary"
        
        ----gg.log("抽奖数据同步完成")

        -- 刷新界面显示
        self:RefreshLotteryDisplay()
        self:UpdatePriceDisplay()
        self:UpdateProbabilityDisplay()
        self:UpdatePityProgress()
    else
        ----gg.log("抽奖数据响应格式错误:", data.errorMsg)
    end
end

--- 处理抽奖结果响应
function LotteryGui:OnLotteryResultResponse(data)
    ----gg.log("收到抽奖结果响应:", data)
    if data.success and data.rewards then
        ----gg.log("抽奖成功，获得奖励:", data.rewards)
        self:ShowLotteryResult(data.rewards, data.drawType, data.poolName)
        
        -- 更新保底进度
        if data.pityProgress then
            self:UpdatePityProgress(data.pityProgress)
        end
        
        -- 刷新抽奖数据
        self:RequestLotteryData()
    else
        ----gg.log("抽奖失败:", data.errorMsg or "未知错误")
    end
end

--- 处理抽奖成功通知
function LotteryGui:OnLotterySuccessNotify(data)
    ----gg.log("收到抽奖成功通知:", data)
    -- 可以在这里添加额外的成功提示或动画效果
end

--- 处理保底进度更新通知
function LotteryGui:OnPityUpdateNotify(data)
    ----gg.log("收到保底进度更新:", data)
    if data.poolName and data.pityProgress then
        self:UpdatePityProgress(data.pityProgress, data.poolName)
    end
end

--- 处理新抽奖池可用通知
function LotteryGui:OnNewPoolAvailableNotify(data)
    ----gg.log("收到新抽奖池可用通知:", data)
    if data.poolName then
        -- 可以在这里添加新抽奖池的提示
        self:RequestAvailablePools()
    end
end

--- 处理数据同步通知
function LotteryGui:OnDataSyncNotify(data)
    ----gg.log("收到数据同步通知:", data)
    if data.lotteryData then
        self.lotteryData = data.lotteryData
        self:RefreshLotteryDisplay()
    end
end

--- 处理错误响应
function LotteryGui:OnLotteryErrorResponse(data)
    ----gg.log("收到抽奖系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    ----gg.log("错误信息:", errorMessage)
    -- TODO: 显示错误提示给玩家
end

--- 检查界面是否已打开
function LotteryGui:IsOpen()
    return self.lotteryPanel and self.lotteryPanel:IsVisible()
end

-- =================================
-- 按钮操作处理
-- =================================

--- 单抽按钮点击
function LotteryGui:OnClickSingleDraw()
    ----gg.log("点击单抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.SINGLE_DRAW)
end

--- 五连抽按钮点击
function LotteryGui:OnClickFiveDraw()
    ----gg.log("点击五连抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.FIVE_DRAW)
end

--- 档位选择按钮点击
function LotteryGui:OnClickTierSelect(tier)
    ----gg.log("选择档位:", tier)
    self.currentTier = tier
    self:UpdateTierSelection()
    self:UpdatePriceDisplay()
    self:UpdateProbabilityDisplay()
end

--- 抽奖类型选择按钮点击
function LotteryGui:OnClickLotteryTypeSelect(lotteryType)
    ----gg.log("选择抽奖类型:", lotteryType)
    self.currentLotteryType = lotteryType
    self:UpdateLotteryTypeSelection()
    self:UpdatePriceDisplay()
    self:UpdateProbabilityDisplay()
end

-- =================================
-- 网络请求发送
-- =================================

--- 发送抽奖请求
function LotteryGui:SendLotteryRequest(cmd)
    local requestData = {
        cmd = cmd,
        args = {
            poolName = self.currentPoolName or "wing_primary"
        }
    }
    ----gg.log("发送抽奖请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新抽奖界面显示
function LotteryGui:RefreshLotteryDisplay()
    ----gg.log("刷新抽奖界面显示")
    
    -- 更新档位选择状态
    self:UpdateTierSelection()
    
    -- 更新抽奖类型选择状态
    self:UpdateLotteryTypeSelection()
    
    -- 更新价格显示
    self:UpdatePriceDisplay()
    
    -- 更新概率显示
    self:UpdateProbabilityDisplay()
end

--- 更新档位选择状态
function LotteryGui:UpdateTierSelection()
    local currentTier = self:GetCurrentTier()
    -- 重置所有档位按钮状态
    if self.primaryTierButton then
        self.primaryTierButton:SetSelected(currentTier == "primary")
    end
    if self.intermediateTierButton then
        self.intermediateTierButton:SetSelected(currentTier == "intermediate")
    end
    if self.advancedTierButton then
        self.advancedTierButton:SetSelected(currentTier == "advanced")
    end
    if self.superTierButton then
        self.superTierButton:SetSelected(currentTier == "super")
    end
end

--- 更新抽奖类型选择状态
function LotteryGui:UpdateLotteryTypeSelection()
    local currentLotteryType = self:GetCurrentLotteryType()
    if self.wingLotteryButton then
        self.wingLotteryButton:SetSelected(currentLotteryType == "wing")
    end
    if self.petLotteryButton then
        self.petLotteryButton:SetSelected(currentLotteryType == "pet")
    end
    if self.partnerLotteryButton then
        self.partnerLotteryButton:SetSelected(currentLotteryType == "partner")
    end
end

--- 更新价格显示
function LotteryGui:UpdatePriceDisplay()
    local currentTier = self:GetCurrentTier()
    local currentLotteryType = self:GetCurrentLotteryType()
    local priceConfig = self:GetPriceConfig(currentTier, currentLotteryType)
    
    if priceConfig then
        -- 更新单抽价格
        if self.singlePriceComponent and self.singlePriceComponent.node then
            self.singlePriceComponent.node.Title = tostring(priceConfig.singlePrice or 0)
        end
        
        -- 更新五连抽价格
        if self.fivePriceComponent and self.fivePriceComponent.node then
            self.fivePriceComponent.node.Title = tostring(priceConfig.fivePrice or 0)
        end
    end
end

--- 更新概率显示
function LotteryGui:UpdateProbabilityDisplay()
    local currentTier = self:GetCurrentTier()
    local currentLotteryType = self:GetCurrentLotteryType()
    local probabilityConfig = self:GetProbabilityConfig(currentTier, currentLotteryType)
    
    if probabilityConfig then
        -- 更新普通概率显示
        if self.normalProbabilityComponent and self.normalProbabilityComponent.node then
            self.normalProbabilityComponent.node.Title = string.format("%.2f%%", probabilityConfig.normalProbability or 0)
        end
        
        -- 更新高级概率显示
        if self.advancedProbabilityComponent and self.advancedProbabilityComponent.node then
            self.advancedProbabilityComponent.node.Title = string.format("%.2f%%", probabilityConfig.advancedProbability or 0)
        end
    end
end

--- 更新保底进度显示
function LotteryGui:UpdatePityProgress(progress, poolName)
    local targetPool = poolName or self.currentPoolName
    if progress then
        self.pityProgress[targetPool] = progress
    end
    
    local currentProgress = self.pityProgress[targetPool] or 0
    ----gg.log("更新保底进度:", targetPool, currentProgress)
    
    -- TODO: 在UI上显示保底进度
    -- 例如：self.pityProgressLabel.node.Title = string.format("保底进度: %d/100", currentProgress)
end

--- 显示抽奖结果
function LotteryGui:ShowLotteryResult(rewards, drawType, poolName)
    ----gg.log("显示抽奖结果:", rewards, drawType, poolName)
    
    -- TODO: 实现抽奖结果展示逻辑
    -- 可以创建一个结果弹窗或使用现有的奖励模板来显示获得的物品
    
    -- 示例：使用奖励模板显示第一个奖励
    if rewards and #rewards > 0 and self.rewardBackground then
        local firstReward = rewards[1]
        
        -- 设置奖励图标
        if self.rewardIcon and firstReward.icon then
            self.rewardIcon.node.Icon = firstReward.icon
        end
        
        -- 设置奖励概率
        if self.rewardProbability and firstReward.probability then
            self.rewardProbability.node.Title = string.format("概率: %.2f%%", firstReward.probability)
        end
        
        -- 设置奖励加成
        if self.rewardBonus and firstReward.bonus then
            self.rewardBonus.node.Title = string.format("加成: +%d", firstReward.bonus)
        end
        
        -- 显示奖励模板
        self.rewardBackground.node.Visible = true
        
        -- 3秒后隐藏
        gg.scheduler:scheduleOnce(function()
            if self.rewardBackground then
                self.rewardBackground.node.Visible = false
            end
        end, 3)
    end
end

-- =================================
-- 工具方法
-- =================================

--- 获取价格配置
function LotteryGui:GetPriceConfig(tier, lotteryType)
    local configKey = tier .. "_" .. lotteryType
    if not self.priceConfigs[configKey] then
        -- TODO: 从配置加载器获取价格配置
        self.priceConfigs[configKey] = {
            singlePrice = 100,
            fivePrice = 450
        }
    end
    return self.priceConfigs[configKey]
end

--- 获取概率配置
function LotteryGui:GetProbabilityConfig(tier, lotteryType)
    local configKey = tier .. "_" .. lotteryType
    if not self.lotteryConfigs[configKey] then
        -- TODO: 从配置加载器获取概率配置
        self.lotteryConfigs[configKey] = {
            normalProbability = 85.0,
            advancedProbability = 15.0
        }
    end
    return self.lotteryConfigs[configKey]
end

--- 获取抽奖配置
function LotteryGui:GetLotteryConfig(lotteryName)
    if not lotteryName then return nil end

    if not self.lotteryConfigs[lotteryName] then
        self.lotteryConfigs[lotteryName] = ConfigLoader.GetLottery(lotteryName)
    end

    return self.lotteryConfigs[lotteryName]
end

--- 从抽奖池名称中获取当前档位
function LotteryGui:GetCurrentTier()
    if not self.currentPoolName then return "primary" end
    local parts = {}
    for part in string.gmatch(self.currentPoolName, "[^_]+") do
        table.insert(parts, part)
    end
    return parts[2] or "primary"
end

--- 从抽奖池名称中获取当前抽奖类型
function LotteryGui:GetCurrentLotteryType()
    if not self.currentPoolName then return "wing" end
    local parts = {}
    for part in string.gmatch(self.currentPoolName, "[^_]+") do
        table.insert(parts, part)
    end
    return parts[1] or "wing"
end

return LotteryGui.New(script.Parent, uiConfig)