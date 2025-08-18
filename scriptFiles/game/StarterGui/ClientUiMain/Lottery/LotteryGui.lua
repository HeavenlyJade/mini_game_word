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
    self.closeButton = self:Get("抽奖界面/关闭", ViewButton) ---@type ViewButton

    -- 抽奖按钮
    self.singleDrawButton = self:Get("抽奖界面/单抽", ViewButton) ---@type ViewButton
    self.fiveDrawButton = self:Get("抽奖界面/五连抽", ViewButton) ---@type ViewButton

    -- 价格显示
    self.singlePriceComponent = self:Get("抽奖界面/单抽", ViewButton) ---@type ViewButton
    self.fivePriceComponent = self:Get("抽奖界面/五连抽", ViewButton) ---@type ViewButton

    -- 抽奖档位
    self.lotteryTierComponent = self:Get("抽奖界面/抽奖档位", ViewList) ---@type ViewList

    -- 概率解锁栏位
    self.probabilityUnlockPanel = self:Get("抽奖界面/概率解锁栏位", ViewList) ---@type ViewList

    self.primaryTierButton = self:Get("抽奖界面/抽奖档位/初级档位", ViewButton) ---@type ViewButton
    self.intermediateTierButton = self:Get("抽奖界面/抽奖档位/中级档位", ViewButton) ---@type ViewButton
    self.advancedTierButton = self:Get("抽奖界面/抽奖档位/高级档位", ViewButton) ---@type ViewButton
    self.superTierButton = self:Get("抽奖界面/抽奖档位/终极档位", ViewButton) ---@type ViewButton
    -- self.superTierButton:SetVisible(false)
    -- 概率显示
    self.normalProbabilityComponent = self:Get("抽奖界面/概率解锁栏位/普通概率", ViewComponent) ---@type ViewComponent
    self.advancedProbabilityComponent = self:Get("抽奖界面/概率解锁栏位/高级概率", ViewComponent) ---@type ViewComponent



    -- 抽奖界面物品的list
    self.wingUltimateLotteryList = self:Get("抽奖界面/抽奖翅膀_初级_终极", ViewList) ---@type ViewList
    self.wingMidUltimateLotteryList = self:Get("抽奖界面/抽奖翅膀_中级_终极", ViewList) ---@type ViewList
    self.wingHighUltimateLotteryList = self:Get("抽奖界面/抽奖翅膀_高级_终极", ViewList) ---@type ViewList

    -- 现有宠物初级档位
    self.petBeginnerLotteryList = self:Get("抽奖界面/抽奖宠物_初级_初级", ViewList) ---@type ViewList
    self.petIntermediateLotteryList = self:Get("抽奖界面/抽奖宠物_初级_中级", ViewList) ---@type ViewList
    self.petAdvancedLotteryList = self:Get("抽奖界面/抽奖宠物_初级_高级", ViewList) ---@type ViewList

    -- 【补充】宠物中级档位ViewList
    self.petMidBeginnerLotteryList = self:Get("抽奖界面/抽奖宠物_中级_初级", ViewList) ---@type ViewList
    self.petMidIntermediateLotteryList = self:Get("抽奖界面/抽奖宠物_中级_中级", ViewList) ---@type ViewList
    self.petMidAdvancedLotteryList = self:Get("抽奖界面/抽奖宠物_中级_高级", ViewList) ---@type ViewList

    -- 【补充】宠物高级档位ViewList
    self.petHighBeginnerLotteryList = self:Get("抽奖界面/抽奖宠物_高级_初级", ViewList) ---@type ViewList
    self.petHighIntermediateLotteryList = self:Get("抽奖界面/抽奖宠物_高级_中级", ViewList) ---@type ViewList
    self.petHighAdvancedLotteryList = self:Get("抽奖界面/抽奖宠物_高级_高级", ViewList) ---@type ViewList

    -- 现有伙伴初级档位
    self.partnerBeginnerLotteryList = self:Get("抽奖界面/抽奖伙伴_初级_初级", ViewList) ---@type ViewList
    self.partnerUltimateLotteryList = self:Get("抽奖界面/抽奖伙伴_初级_终极", ViewList) ---@type ViewList
    -- 【补充】伙伴中级档位ViewList
    self.partnerMidBeginnerLotteryList = self:Get("抽奖界面/抽奖伙伴_中级_初级", ViewList) ---@type ViewList
    self.partnerMidUltimateLotteryList = self:Get("抽奖界面/抽奖伙伴_中级_终极", ViewList) ---@type ViewList
    -- 【补充】伙伴高级档位ViewList
    self.partnerHighBeginnerLotteryList = self:Get("抽奖界面/抽奖伙伴_高级_初级", ViewList) ---@type ViewList

    self.partnerHighUltimateLotteryList = self:Get("抽奖界面/抽奖伙伴_高级_终极", ViewList) ---@type ViewList


    -- 奖励模版节点
    self.rewardTemplate = self:Get("抽奖界面/模版界面/奖励模版", ViewComponent) ---@type ViewComponent

    -- 数据存储
    self.lotteryData = {} ---@type table 抽奖数据
    self.currentPoolName = "初级翅膀初级" ---@type string 当前选择的抽奖池
    self.availablePools = {} ---@type table 可用抽奖池列表
    self.pityProgress = {} ---@type table 保底进度数据
    self.lotteryConfigs = {} ---@type table 抽奖配置缓存
    self.priceConfigs = {} ---@type table 价格配置缓存

    -- 2. 事件注册
    self:RegisterEvents()

    -- 3. 按钮点击事件注册
    self:RegisterButtonEvents()

    -- 4. 初始化抽奖物品列表
    self:InitializeLotteryItemLists()

    --gg.log("LotteryGui 抽奖界面初始化完成，事件监听器已注册")
end

-- =================================
-- 事件注册
-- =================================

function LotteryGui:RegisterEvents()
    --gg.log("注册抽奖系统事件监听")

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

    -- 【更新】监听OpenLotteryUI事件：支持打开/关闭
    ClientEventManager.Subscribe("OpenLotteryUI", function(args)
        if not args then return end
        if args.operation == "关闭界面" then
            self:Close()
            return
        end
        -- 默认/显式打开
        if args.lotteryType then
            self:OpenWithType(args.lotteryType)
        else
            self:Open()
        end
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
        self:OnClickTierSelect("初级")
    end

    self.intermediateTierButton.clickCb = function()
        self:OnClickTierSelect("中级")
    end

    self.advancedTierButton.clickCb = function()
        self:OnClickTierSelect("高级")
    end

    self.superTierButton.clickCb = function()
        self:OnClickTierSelect("终极")
    end



    --gg.log("抽奖界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function LotteryGui:OnOpen()
    --gg.log("LotteryGui抽奖界面打开")
    self:RequestLotteryData()
end

function LotteryGui:OnClose()
    --gg.log("LotteryGui抽奖界面关闭")
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
    --gg.log("请求抽奖数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 请求可用抽奖池
function LotteryGui:RequestAvailablePools()
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_AVAILABLE_POOLS,
        args = {}
    }
    --gg.log("请求可用抽奖池")
    gg.network_channel:fireServer(requestData)
end

--- 请求抽奖池统计
function LotteryGui:RequestPoolStats(poolName)
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_POOL_STATS,
        args = { poolName = poolName }
    }
    --gg.log("请求抽奖池统计:", poolName)
    gg.network_channel:fireServer(requestData)
end

--- 处理抽奖数据响应
function LotteryGui:OnLotteryDataResponse(data)
    --gg.log("收到抽奖数据响应:", data)
    if data.success and data.data then
        self.lotteryData = data.data
        self.currentPoolName = data.data.currentPoolName or "初级翅膀初级"
        
        --gg.log("抽奖数据同步完成")

        -- 刷新界面显示
        self:RefreshLotteryDisplay()
        self:UpdatePriceDisplay()
        self:UpdateProbabilityDisplay()
        self:UpdatePityProgress()
    else
        --gg.log("抽奖数据响应格式错误:", data.errorMsg)
    end
end

--- 处理抽奖结果响应
function LotteryGui:OnLotteryResultResponse(data)
    --gg.log("收到抽奖结果响应:", data)
    if data.success and data.rewards then
        --gg.log("抽奖成功，获得奖励:", data.rewards)
        
        -- 更新保底进度
        if data.pityProgress then
            self:UpdatePityProgress(data.pityProgress)
        end
        
        -- 刷新抽奖数据
        self:RequestLotteryData()
    else
        --gg.log("抽奖失败:", data.errorMsg or "未知错误")
    end
end

--- 处理抽奖成功通知
function LotteryGui:OnLotterySuccessNotify(data)
    --gg.log("收到抽奖成功通知:", data)
    -- 可以在这里添加额外的成功提示或动画效果
end

--- 处理保底进度更新通知
function LotteryGui:OnPityUpdateNotify(data)
    --gg.log("收到保底进度更新:", data)
    if data.poolName and data.pityProgress then
        self:UpdatePityProgress(data.pityProgress, data.poolName)
    end
end

--- 处理新抽奖池可用通知
function LotteryGui:OnNewPoolAvailableNotify(data)
    --gg.log("收到新抽奖池可用通知:", data)
    if data.poolName then
        -- 可以在这里添加新抽奖池的提示
        self:RequestAvailablePools()
    end
end

--- 处理数据同步通知
function LotteryGui:OnDataSyncNotify(data)
    --gg.log("收到数据同步通知:", data)
    if data.lotteryData then
        self.lotteryData = data.lotteryData
        self:RefreshLotteryDisplay()
    end
end

--- 处理错误响应
function LotteryGui:OnLotteryErrorResponse(data)
    --gg.log("收到抽奖系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    --gg.log("错误信息:", errorMessage)
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
    --gg.log("点击单抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.SINGLE_DRAW)
end

--- 五连抽按钮点击
function LotteryGui:OnClickFiveDraw()
    --gg.log("点击五连抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.FIVE_DRAW)
end

--- 档位选择按钮点击
function LotteryGui:OnClickTierSelect(tier)
    --gg.log("选择档位:", tier)
    -- 根据当前抽奖类型和档位组合成抽奖池名称
    local lotteryType = self:GetCurrentLotteryType()
    self.currentPoolName = lotteryType .. tier
    --gg.log("更新抽奖池名称:", self.currentPoolName)
    
    -- 更新档位选择状态和显示对应的ViewList
    self:UpdateTierSelection()
    
    -- 更新价格和概率显示
    self:UpdatePriceDisplay()
    self:UpdateProbabilityDisplay()
    self:UpdatePityProgress()
end



-- =================================
-- 网络请求发送
-- =================================

--- 发送抽奖请求
function LotteryGui:SendLotteryRequest(cmd)
    local requestData = {
        cmd = cmd,
        args = {
            poolName = self.currentPoolName or "初级翅膀初级"
        }
    }
    --gg.log("发送抽奖请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新抽奖界面显示
function LotteryGui:RefreshLotteryDisplay()
    --gg.log("刷新抽奖界面显示")
    
    -- 更新档位选择状态
    self:UpdateTierSelection()
    

    
    -- 更新价格显示
    self:UpdatePriceDisplay()
    
    -- 更新概率显示
    self:UpdateProbabilityDisplay()
end

--- 更新档位选择状态
function LotteryGui:UpdateTierSelection()
    local currentTier = self:GetCurrentTier()
    
    -- 根据当前抽奖类型和档位显示对应的ViewList
    self:ShowCurrentLotteryList()
    
    --gg.log("更新档位选择:", currentTier, "当前抽奖类型:", self:GetCurrentLotteryType())
end

--- 显示当前抽奖类型和档位对应的ViewList
function LotteryGui:ShowCurrentLotteryList()
    local currentTier = self:GetCurrentTier()
    local currentLotteryType = self:GetCurrentLotteryType()
    
    -- 隐藏所有ViewList
    self:HideAllLotteryLists()
    
    -- 根据档位和抽奖类型显示对应的ViewList
    if currentLotteryType == "初级宠物" then
        if currentTier == "初级" and self.petBeginnerLotteryList then
            self.petBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "中级" and self.petIntermediateLotteryList then
            self.petIntermediateLotteryList:SetVisible(true)
        elseif currentTier == "高级" and self.petAdvancedLotteryList then
            self.petAdvancedLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "中级宠物" then
        if currentTier == "初级" and self.petMidBeginnerLotteryList then
            self.petMidBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "中级" and self.petMidIntermediateLotteryList then
            self.petMidIntermediateLotteryList:SetVisible(true)
        elseif currentTier == "高级" and self.petMidAdvancedLotteryList then
            self.petMidAdvancedLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "高级宠物" then
        if currentTier == "初级" and self.petHighBeginnerLotteryList then
            self.petHighBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "中级" and self.petHighIntermediateLotteryList then
            self.petHighIntermediateLotteryList:SetVisible(true)
        elseif currentTier == "高级" and self.petHighAdvancedLotteryList then
            self.petHighAdvancedLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "初级翅膀" then
        if currentTier == "终极" and self.wingUltimateLotteryList then
            self.wingUltimateLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "中级翅膀" then
        if currentTier == "终极" and self.wingMidUltimateLotteryList then
            self.wingMidUltimateLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "高级翅膀" then
        if currentTier == "终极" and self.wingHighUltimateLotteryList then
            self.wingHighUltimateLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "初级伙伴" then
        if currentTier == "初级" and self.partnerBeginnerLotteryList then
            self.partnerBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "终极" and self.partnerUltimateLotteryList then
            self.partnerUltimateLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "中级伙伴" then
        if currentTier == "初级" and self.partnerMidBeginnerLotteryList then
            self.partnerMidBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "终极" and self.partnerMidUltimateLotteryList then
            self.partnerMidUltimateLotteryList:SetVisible(true)
        end
    elseif currentLotteryType == "高级伙伴" then
        if currentTier == "初级" and self.partnerHighBeginnerLotteryList then
            self.partnerHighBeginnerLotteryList:SetVisible(true)
        elseif currentTier == "终极" and self.partnerHighUltimateLotteryList then
            self.partnerHighUltimateLotteryList:SetVisible(true)
        end
    end
    
    --gg.log("显示抽奖列表:", currentLotteryType, currentTier)
end

--- 隐藏所有抽奖ViewList
function LotteryGui:HideAllLotteryLists()
    -- 隐藏翅膀ViewList
    if self.wingUltimateLotteryList then
        self.wingUltimateLotteryList:SetVisible(false)
    end
    if self.wingMidUltimateLotteryList then
        self.wingMidUltimateLotteryList:SetVisible(false)
    end
    if self.wingHighUltimateLotteryList then
        self.wingHighUltimateLotteryList:SetVisible(false)
    end
    
    -- 隐藏宠物初级档位ViewList
    if self.petBeginnerLotteryList then
        self.petBeginnerLotteryList:SetVisible(false)
    end
    if self.petIntermediateLotteryList then
        self.petIntermediateLotteryList:SetVisible(false)
    end
    if self.petAdvancedLotteryList then
        self.petAdvancedLotteryList:SetVisible(false)
    end
    
    -- 隐藏宠物中级档位ViewList
    if self.petMidBeginnerLotteryList then
        self.petMidBeginnerLotteryList:SetVisible(false)
    end
    if self.petMidIntermediateLotteryList then
        self.petMidIntermediateLotteryList:SetVisible(false)
    end
    if self.petMidAdvancedLotteryList then
        self.petMidAdvancedLotteryList:SetVisible(false)
    end
    
    -- 隐藏宠物高级档位ViewList
    if self.petHighBeginnerLotteryList then
        self.petHighBeginnerLotteryList:SetVisible(false)
    end
    if self.petHighIntermediateLotteryList then
        self.petHighIntermediateLotteryList:SetVisible(false)
    end
    if self.petHighAdvancedLotteryList then
        self.petHighAdvancedLotteryList:SetVisible(false)
    end
    
    -- 隐藏伙伴初级档位ViewList
    if self.partnerBeginnerLotteryList then
        self.partnerBeginnerLotteryList:SetVisible(false)
    end
    if self.partnerUltimateLotteryList then
        self.partnerUltimateLotteryList:SetVisible(false)
    end
    
    -- 隐藏伙伴中级档位ViewList
    if self.partnerMidBeginnerLotteryList then
        self.partnerMidBeginnerLotteryList:SetVisible(false)
    end
    if self.partnerMidUltimateLotteryList then
        self.partnerMidUltimateLotteryList:SetVisible(false)
    end
    
    -- 隐藏伙伴高级档位ViewList
    if self.partnerHighBeginnerLotteryList then
        self.partnerHighBeginnerLotteryList:SetVisible(false)
    end
    if self.partnerHighUltimateLotteryList then
        self.partnerHighUltimateLotteryList:SetVisible(false)
    end
    
    --gg.log("隐藏所有抽奖ViewList")
end


--- 更新价格显示
function LotteryGui:UpdatePriceDisplay()
    local currentTier = self:GetCurrentTier()
    local currentLotteryType = self:GetCurrentLotteryType()
    local priceConfig = self:GetPriceConfig(currentTier, currentLotteryType)
    
    if priceConfig then
        -- 更新单抽价格，使用格式化显示
        if self.singlePriceComponent then
            local singlePrice = priceConfig.singlePrice or 0
            self.singlePriceComponent.node["价格图"]["价格框"].Title = gg.FormatLargeNumber(singlePrice)
        end
        
        -- 更新五连抽价格，使用格式化显示
        if self.fivePriceComponent then
            local fivePrice = priceConfig.fivePrice or 0
            self.fivePriceComponent.node["价格图"]["价格框"].Title = gg.FormatLargeNumber(fivePrice)
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
    --gg.log("更新保底进度:", targetPool, currentProgress)
    
    -- TODO: 在UI上显示保底进度
    -- 例如：self.pityProgressLabel.node.Title = string.format("保底进度: %d/100", currentProgress)
end





-- =================================
-- 工具方法
-- =================================

--- 获取价格配置
function LotteryGui:GetPriceConfig(tier, lotteryType)
    -- 根据LotteryConfig的配置名称构建key
    local configKey = lotteryType .. tier
    if not self.priceConfigs[configKey] then
        -- 从ConfigLoader获取LotteryType配置
        local lotteryType = ConfigLoader.GetLottery(configKey)
        
        if lotteryType then
            -- 获取单次和五连抽的消耗配置
            local singleCost = lotteryType:GetCost("single")
            local fiveCost = lotteryType:GetCost("five")
            
            self.priceConfigs[configKey] = {
                singlePrice =  singleCost.costAmount ,
                fivePrice =  fiveCost.costAmount 
            }
        else
            -- 默认配置
            self.priceConfigs[configKey] = {
                singlePrice = 100,
                fivePrice = 450
            }
        end
    end
    return self.priceConfigs[configKey]
end

--- 获取概率配置
function LotteryGui:GetProbabilityConfig(tier, lotteryType)
    -- 根据LotteryConfig的配置名称构建key
    local configKey = lotteryType .. tier
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

--- 检查抽奖池是否可用
function LotteryGui:IsPoolAvailable(poolName)
    local lotteryType = ConfigLoader.GetLottery(poolName)
    return lotteryType ~= nil and lotteryType:IsEnabled()
end

--- 获取所有可用的抽奖池
function LotteryGui:GetAvailablePools()
    local pools = {}
    local allLotteries = ConfigLoader.GetAllLotteries()
    
    for poolName, lotteryType in pairs(allLotteries) do
        if lotteryType:IsEnabled() then
            table.insert(pools, poolName)
        end
    end
    
    return pools
end

--- 从抽奖池名称中获取当前档位
function LotteryGui:GetCurrentTier()
    if not self.currentPoolName then return "初级" end
    
    -- 根据LotteryConfig的配置，解析抽奖池名称
    -- 例如："初级宠物初级" -> "初级"
    -- "初级翅膀终极" -> "终极"
    -- "高级伙伴终极" -> "终极"
    
    -- 检查终极档位
    if string.find(self.currentPoolName, "终极$") then
        return "终极"
    -- 检查高级档位
    elseif string.find(self.currentPoolName, "高级$") then
        return "高级"
    -- 检查中级档位
    elseif string.find(self.currentPoolName, "中级$") then
        return "中级"
    -- 检查初级档位
    elseif string.find(self.currentPoolName, "初级$") then
        return "初级"
    end
    
    return "初级"
end

--- 从抽奖池名称中获取当前抽奖类型
function LotteryGui:GetCurrentLotteryType()
    if not self.currentPoolName then return "初级翅膀" end
    
    -- 根据LotteryConfig的配置，解析抽奖池名称
    -- 例如："高级宠物初级" -> "高级宠物"
    -- "中级伙伴终极" -> "中级伙伴"
    -- "初级翅膀终极" -> "初级翅膀"
    
    -- 检查高级类型
    if string.find(self.currentPoolName, "高级翅膀") then
        return "高级翅膀"
    elseif string.find(self.currentPoolName, "高级宠物") then
        return "高级宠物"
    elseif string.find(self.currentPoolName, "高级伙伴") then
        return "高级伙伴"
    -- 检查中级类型
    elseif string.find(self.currentPoolName, "中级翅膀") then
        return "中级翅膀"
    elseif string.find(self.currentPoolName, "中级宠物") then
        return "中级宠物"
    elseif string.find(self.currentPoolName, "中级伙伴") then
        return "中级伙伴"
    -- 检查初级类型
    elseif string.find(self.currentPoolName, "初级翅膀") then
        return "初级翅膀"
    elseif string.find(self.currentPoolName, "初级宠物") then
        return "初级宠物"
    elseif string.find(self.currentPoolName, "初级伙伴") then
        return "初级伙伴"
    end
    
    return "初级翅膀"
end

-- =================================
-- 抽奖物品列表初始化
-- =================================

--- 初始化所有抽奖物品列表
function LotteryGui:InitializeLotteryItemLists()
    --gg.log("开始初始化抽奖物品列表")
    
    -- 翅膀抽奖列表
    self:LoadLotteryItemsToList("初级翅膀终极", self.wingUltimateLotteryList)
    self:LoadLotteryItemsToList("中级翅膀终极", self.wingMidUltimateLotteryList)
    self:LoadLotteryItemsToList("高级翅膀终极", self.wingHighUltimateLotteryList)
    
    -- 宠物抽奖列表
    self:LoadLotteryItemsToList("初级宠物初级", self.petBeginnerLotteryList)
    self:LoadLotteryItemsToList("初级宠物中级", self.petIntermediateLotteryList)
    self:LoadLotteryItemsToList("初级宠物高级", self.petAdvancedLotteryList)
    self:LoadLotteryItemsToList("中级宠物初级", self.petMidBeginnerLotteryList)
    self:LoadLotteryItemsToList("中级宠物中级", self.petMidIntermediateLotteryList)
    self:LoadLotteryItemsToList("中级宠物高级", self.petMidAdvancedLotteryList)
    self:LoadLotteryItemsToList("高级宠物初级", self.petHighBeginnerLotteryList)
    self:LoadLotteryItemsToList("高级宠物中级", self.petHighIntermediateLotteryList)
    self:LoadLotteryItemsToList("高级宠物高级", self.petHighAdvancedLotteryList)
    
    -- 伙伴抽奖列表
    self:LoadLotteryItemsToList("初级伙伴初级", self.partnerBeginnerLotteryList)
    self:LoadLotteryItemsToList("初级伙伴终极", self.partnerUltimateLotteryList)
    self:LoadLotteryItemsToList("中级伙伴初级", self.partnerMidBeginnerLotteryList)
    self:LoadLotteryItemsToList("中级伙伴终极", self.partnerMidUltimateLotteryList)
    self:LoadLotteryItemsToList("高级伙伴初级", self.partnerHighBeginnerLotteryList)
    self:LoadLotteryItemsToList("高级伙伴终极", self.partnerHighUltimateLotteryList)

    
    --gg.log("抽奖物品列表初始化完成")
end

--- 加载指定抽奖池的物品到对应ViewList
---@param poolName string 抽奖池名称
---@param viewList ViewList 目标ViewList
function LotteryGui:LoadLotteryItemsToList(poolName, viewList)
    if not viewList then
        --gg.log("警告：ViewList为空，跳过抽奖池", poolName)
        return
    end
    
    -- 获取抽奖配置
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    if not lotteryConfig or not lotteryConfig.rewardPool then
        --gg.log("警告：抽奖池配置不存在或无奖励池", poolName)
        return
    end
    
    --gg.log("加载抽奖池物品:", poolName, "奖励数量:", #lotteryConfig.rewardPool)
    
    -- 清空现有物品
    viewList:ClearChildren()
    
    -- 遍历奖励池，为每个奖励创建UI节点
    for i, rewardItem in ipairs(lotteryConfig.rewardPool) do
        self:CreateLotteryItemNode(viewList, rewardItem, i, poolName)
    end
end

--- 为奖励项创建UI节点
---@param viewList ViewList 目标ViewList
---@param rewardItem table 奖励项配置
---@param index number 索引
---@param poolName string 抽奖池名称
function LotteryGui:CreateLotteryItemNode(viewList, rewardItem, index, poolName)
    -- 获取奖励信息
    local rewardInfo = self:GetRewardInfo(rewardItem)
    if not rewardInfo then
        --gg.log("警告：无法获取奖励信息", rewardItem)
        return
    end
    
    -- --gg.log("创建奖励物品节点:", rewardInfo.name, "稀有度:", rewardInfo.rarity)
    
    -- 克隆奖励模版节点
    if not self.rewardTemplate or not self.rewardTemplate.node then
        --gg.log("警告：找不到奖励模版节点")
        return
    end
    
    -- 克隆模版节点
    local itemNode = self.rewardTemplate.node:Clone()
    if not itemNode then
        --gg.log("警告：克隆奖励模版节点失败")
        return
    end
    
    -- 设置节点名称
    itemNode.Name = "奖励物品_" .. index
    
    -- 查找并设置背景图片
    local backgroundNode = itemNode:FindFirstChild("背景")
    local iconNode = backgroundNode:FindFirstChild("图标")
    if iconNode and rewardInfo.icon then
        -- 设置图片资源
        iconNode.Icon = rewardInfo.icon
        -- --gg.log("设置奖励图片:", rewardInfo.name, "图片资源:", rewardInfo.icon)
    end
    
    -- 查找并设置概率显示
    local probabilityNode = backgroundNode:FindFirstChild("概率")
    if probabilityNode then
        -- 直接从LotteryType获取格式化的概率显示
        local lotteryConfig = ConfigLoader.GetLottery(poolName)
        
        if lotteryConfig then
            local probabilityText = lotteryConfig:GetFormattedProbability(rewardItem)
            probabilityNode.Title = probabilityText
            -- --gg.log("设置奖励概率:", rewardInfo.name, "概率:", probabilityText)
        end
    end
    
    -- 查找并设置加成显示
    local bonusNode = backgroundNode:FindFirstChild("加成")

    if bonusNode then
        -- 根据稀有度设置加成显示
        local bonusText = self:GetRarityBonusText(rewardInfo.rarity)
        bonusNode.Title = bonusText
        -- --gg.log("设置奖励加成:", rewardInfo.name, "加成:", bonusText)
    end
    
    -- 将节点添加到ViewList
    viewList:AppendChild(itemNode)
    -- --gg.log("成功添加奖励物品节点到ViewList:", rewardInfo.name)
end

--- 获取奖励信息
---@param rewardItem table 奖励项配置
---@return table|nil 奖励信息 {name: string, icon: string, rarity: string}
function LotteryGui:GetRewardInfo(rewardItem)
    if not rewardItem then return nil end
    
    local rewardType = rewardItem.rewardType
    local rewardName = nil
    
    -- 根据奖励类型获取奖励名称
    if rewardType == "宠物" then
        rewardName = rewardItem.petConfig
    elseif rewardType == "伙伴" then
        rewardName = rewardItem.partnerConfig
    elseif rewardType == "翅膀" then
        rewardName = rewardItem.wingConfig
    elseif rewardType == "尾迹" then
        rewardName = rewardItem.trailConfig
    elseif rewardType == "物品" then
        rewardName = rewardItem.item
    end
    
    if not rewardName then
        --gg.log("警告：奖励配置中缺少奖励名称", rewardItem)
        return nil
    end
    
    local rewardInfo = {}
    
    -- 根据奖励类型获取配置
    if rewardType == "宠物" then
        local petConfig = ConfigLoader.GetPet(rewardName)
        if petConfig then
            rewardInfo.name = petConfig.name or rewardName
            rewardInfo.icon = petConfig.avatarResource
            rewardInfo.rarity = petConfig.rarity or "N"
        end
    elseif rewardType == "伙伴" then
        local partnerConfig = ConfigLoader.GetPartner(rewardName)
        if partnerConfig then
            rewardInfo.name = partnerConfig.name or rewardName
            rewardInfo.icon = partnerConfig.avatarResource
            rewardInfo.rarity = partnerConfig.rarity or "N"
        end
    elseif rewardType == "翅膀" then
        local wingConfig = ConfigLoader.GetWing(rewardName)
        if wingConfig then
            rewardInfo.name = wingConfig.name or rewardName
            rewardInfo.icon = wingConfig.avatarResource
            rewardInfo.rarity = wingConfig.rarity or "N"
        end
    elseif rewardType == "尾迹" then
        local trailConfig = ConfigLoader.GetTrail(rewardName)
        if trailConfig then
            rewardInfo.name = trailConfig.name or rewardName
            rewardInfo.icon = trailConfig.avatarResource
            rewardInfo.rarity = trailConfig.rarity or "N"
        end
    elseif rewardType == "物品" then
        local itemConfig = ConfigLoader.GetItem(rewardName)
        if itemConfig then
            rewardInfo.name = itemConfig.name or rewardName
            rewardInfo.icon = itemConfig.icon
            rewardInfo.rarity = itemConfig.rarity or "N"
        end
    else
        -- 未知类型，使用默认值
        rewardInfo.name = rewardName
        rewardInfo.icon = nil
        rewardInfo.rarity = "N"
    end
    
    return rewardInfo
end

--- 根据稀有度获取加成文本
---@param rarity string 稀有度
---@return string 加成文本
function LotteryGui:GetRarityBonusText(rarity)
    local bonusMap = {
        N = "普通",
        R = "稀有",
        SR = "超稀有", 
        SSR = "极稀有",
        UR = "终极稀有",
        LR = "传说稀有"
    }
    
    return bonusMap[rarity] or "普通"
end





--- 刷新当前抽奖池的物品列表
function LotteryGui:RefreshCurrentLotteryItems()
    local currentTier = self:GetCurrentTier()
    local currentLotteryType = self:GetCurrentLotteryType()
    local poolName = currentLotteryType .. currentTier
    
    --gg.log("刷新抽奖池物品列表:", poolName)
    
    -- 根据当前抽奖类型选择对应的ViewList
    local targetViewList = nil
    if string.find(currentLotteryType, "翅膀") then
        if currentTier == "终极" then
            if currentLotteryType == "初级翅膀" then
                targetViewList = self.wingUltimateLotteryList
            elseif currentLotteryType == "中级翅膀" then
                targetViewList = self.wingMidUltimateLotteryList
            elseif currentLotteryType == "高级翅膀" then
                targetViewList = self.wingHighUltimateLotteryList
            end
        end
    elseif string.find(currentLotteryType, "宠物") then
        if currentTier == "初级" then
            if currentLotteryType == "初级宠物" then
                targetViewList = self.petBeginnerLotteryList
            elseif currentLotteryType == "中级宠物" then
                targetViewList = self.petMidBeginnerLotteryList
            elseif currentLotteryType == "高级宠物" then
                targetViewList = self.petHighBeginnerLotteryList
            end
        elseif currentTier == "中级" then
            if currentLotteryType == "初级宠物" then
                targetViewList = self.petIntermediateLotteryList
            elseif currentLotteryType == "中级宠物" then
                targetViewList = self.petMidIntermediateLotteryList
            elseif currentLotteryType == "高级宠物" then
                targetViewList = self.petHighIntermediateLotteryList
            end
        elseif currentTier == "高级" then
            if currentLotteryType == "初级宠物" then
                targetViewList = self.petAdvancedLotteryList
            elseif currentLotteryType == "中级宠物" then
                targetViewList = self.petMidAdvancedLotteryList
            elseif currentLotteryType == "高级宠物" then
                targetViewList = self.petHighAdvancedLotteryList
            end
        end
    elseif string.find(currentLotteryType, "伙伴") then
        if currentTier == "初级" then
            if currentLotteryType == "初级伙伴" then
                targetViewList = self.partnerBeginnerLotteryList
            elseif currentLotteryType == "中级伙伴" then
                targetViewList = self.partnerMidBeginnerLotteryList
            elseif currentLotteryType == "高级伙伴" then
                targetViewList = self.partnerHighBeginnerLotteryList
            end
        elseif currentTier == "终极" then
            if currentLotteryType == "初级伙伴" then
                targetViewList = self.partnerUltimateLotteryList
            elseif currentLotteryType == "中级伙伴" then
                targetViewList = self.partnerMidUltimateLotteryList
            elseif currentLotteryType == "高级伙伴" then
                targetViewList = self.partnerHighUltimateLotteryList
            end
        end
    end
    
    if targetViewList then
        self:LoadLotteryItemsToList(poolName, targetViewList)
    end
end

--- 根据抽奖类型打开界面
---@param lotteryType string 抽奖类型（翅膀/宠物/伙伴）
function LotteryGui:OpenWithType(lotteryType)
    --gg.log("打开抽奖界面，类型:", lotteryType)
    self:Open()
    self:SetLotteryType(lotteryType)
    --gg.log("打开抽奖界面，类型:", lotteryType)
end

--- 根据抽奖类型控制档位按钮的显示
---@param lotteryType string 抽奖类型（翅膀/宠物/伙伴）
function LotteryGui:UpdateTierButtonsVisibility(lotteryType)
    -- 隐藏所有档位按钮
    self.primaryTierButton:SetVisible(false)
    self.intermediateTierButton:SetVisible(false)
    self.advancedTierButton:SetVisible(false)
    self.superTierButton:SetVisible(false)
    
    -- 根据抽奖类型显示对应的档位按钮
    if lotteryType == "翅膀" then
        -- 翅膀只有终极档位
        self.superTierButton:SetVisible(true)
    elseif lotteryType == "宠物" then
        -- 宠物有初级、中级、高级档位
        self.primaryTierButton:SetVisible(true)
        self.intermediateTierButton:SetVisible(true)
        self.advancedTierButton:SetVisible(true)
    elseif lotteryType == "伙伴" then
        -- 伙伴有初级、终极档位
        self.primaryTierButton:SetVisible(true)
        self.superTierButton:SetVisible(true)
    end
end

--- 设置抽奖类型
---@param lotteryType string 抽奖类型（翅膀/宠物/伙伴）
function LotteryGui:SetLotteryType(lotteryType)
    -- 更新档位按钮的显示状态
    self:UpdateTierButtonsVisibility(lotteryType)
    
    -- 根据抽奖类型设置当前抽奖池名称（使用该类型的第一个可用档位）
    if lotteryType == "翅膀" then
        -- 翅膀只有终极档位
        self.currentPoolName = "初级翅膀终极"
    elseif lotteryType == "宠物" then
        -- 宠物从初级档位开始
        self.currentPoolName = "初级宠物初级"
    elseif lotteryType == "伙伴" then
        -- 伙伴从初级档位开始
        self.currentPoolName = "初级伙伴初级"
    else
        -- 默认使用翅膀
        self.currentPoolName = "初级翅膀终极"
        --gg.log("未知的抽奖类型:", lotteryType, "，使用默认类型：翅膀")
    end
    
    -- 刷新界面显示
    self:RefreshLotteryDisplay()
    self:UpdatePriceDisplay()
    self:UpdateProbabilityDisplay()
    self:UpdatePityProgress()
    self:RefreshCurrentLotteryItems()
    
    --gg.log("设置抽奖类型完成:", lotteryType, "当前池:", self.currentPoolName)
end

return LotteryGui.New(script.Parent, uiConfig)