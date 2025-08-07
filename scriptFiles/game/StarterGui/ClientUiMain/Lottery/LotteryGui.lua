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
    self.singlePriceComponent = self:Get("抽奖界面/单抽", ViewComponent) ---@type ViewComponent
    self.fivePriceComponent = self:Get("抽奖界面/五连抽", ViewComponent) ---@type ViewComponent

    -- 抽奖档位
    self.lotteryTierComponent = self:Get("抽奖界面/抽奖档位", ViewList) ---@type ViewList

    -- 概率解锁栏位
    self.probabilityUnlockPanel = self:Get("抽奖界面/概率解锁栏位", ViewList) ---@type ViewList

    self.primaryTierButton = self:Get("抽奖界面/抽奖档位/初级档位", ViewButton) ---@type ViewButton
    self.intermediateTierButton = self:Get("抽奖界面/抽奖档位/中级档位", ViewButton) ---@type ViewButton
    self.advancedTierButton = self:Get("抽奖界面/抽奖档位/高级档位", ViewButton) ---@type ViewButton
    self.superTierButton = self:Get("抽奖界面/抽奖档位/超级档位", ViewButton) ---@type ViewButton
    self.superTierButton:SetVisible(false)
    -- 概率显示
    self.normalProbabilityComponent = self:Get("抽奖界面/概率解锁栏位/普通概率", ViewComponent) ---@type ViewComponent
    self.advancedProbabilityComponent = self:Get("抽奖界面/概率解锁栏位/高级概率", ViewComponent) ---@type ViewComponent



    -- 抽奖界面物品的list
    self.wingBeginnerLotteryList = self:Get("抽奖界面/抽奖翅膀_初级_初级", ViewList) ---@type ViewList
    self.wingIntermediateLotteryList = self:Get("抽奖界面/抽奖翅膀_初级_中级", ViewList) ---@type ViewList
    self.wingAdvancedLotteryList = self:Get("抽奖界面/抽奖翅膀_初级_高级", ViewList) ---@type ViewList

    self.petBeginnerLotteryList = self:Get("抽奖界面/抽奖宠物_初级_初级", ViewList) ---@type ViewList
    self.petIntermediateLotteryList = self:Get("抽奖界面/抽奖宠物_初级_中级", ViewList) ---@type ViewList
    self.petAdvancedLotteryList = self:Get("抽奖界面/抽奖宠物_初级_高级", ViewList) ---@type ViewList

    self.partnerBeginnerLotteryList = self:Get("抽奖界面/抽奖伙伴_初级_初级", ViewList) ---@type ViewList
    self.partnerIntermediateLotteryList = self:Get("抽奖界面/抽奖伙伴_初级_中级", ViewList) ---@type ViewList
    self.partnerAdvancedLotteryList = self:Get("抽奖界面/抽奖伙伴_初级_高级", ViewList) ---@type ViewList

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

    gg.log("LotteryGui 抽奖界面初始化完成")
end

-- =================================
-- 事件注册
-- =================================

function LotteryGui:RegisterEvents()
    gg.log("注册抽奖系统事件监听")

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
        self:OnClickTierSelect("初级")
    end

    self.intermediateTierButton.clickCb = function()
        self:OnClickTierSelect("中级")
    end

    self.advancedTierButton.clickCb = function()
        self:OnClickTierSelect("高级")
    end

    self.superTierButton.clickCb = function()
        self:OnClickTierSelect("超级")
    end



    gg.log("抽奖界面按钮事件注册完成")
end

-- =================================
-- 界面生命周期
-- =================================

function LotteryGui:OnOpen()
    gg.log("LotteryGui抽奖界面打开")
    self:RequestLotteryData()
end

function LotteryGui:OnClose()
    gg.log("LotteryGui抽奖界面关闭")
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
    gg.log("请求抽奖数据同步")
    gg.network_channel:fireServer(requestData)
end

--- 请求可用抽奖池
function LotteryGui:RequestAvailablePools()
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_AVAILABLE_POOLS,
        args = {}
    }
    gg.log("请求可用抽奖池")
    gg.network_channel:fireServer(requestData)
end

--- 请求抽奖池统计
function LotteryGui:RequestPoolStats(poolName)
    local requestData = {
        cmd = LotteryEventConfig.REQUEST.GET_POOL_STATS,
        args = { poolName = poolName }
    }
    gg.log("请求抽奖池统计:", poolName)
    gg.network_channel:fireServer(requestData)
end

--- 处理抽奖数据响应
function LotteryGui:OnLotteryDataResponse(data)
    gg.log("收到抽奖数据响应:", data)
    if data.success and data.data then
        self.lotteryData = data.data
        self.currentPoolName = data.data.currentPoolName or "初级翅膀初级"
        
        gg.log("抽奖数据同步完成")

        -- 刷新界面显示
        self:RefreshLotteryDisplay()
        self:UpdatePriceDisplay()
        self:UpdateProbabilityDisplay()
        self:UpdatePityProgress()
    else
        gg.log("抽奖数据响应格式错误:", data.errorMsg)
    end
end

--- 处理抽奖结果响应
function LotteryGui:OnLotteryResultResponse(data)
    gg.log("收到抽奖结果响应:", data)
    if data.success and data.rewards then
        gg.log("抽奖成功，获得奖励:", data.rewards)
        
        -- 更新保底进度
        if data.pityProgress then
            self:UpdatePityProgress(data.pityProgress)
        end
        
        -- 刷新抽奖数据
        self:RequestLotteryData()
    else
        gg.log("抽奖失败:", data.errorMsg or "未知错误")
    end
end

--- 处理抽奖成功通知
function LotteryGui:OnLotterySuccessNotify(data)
    gg.log("收到抽奖成功通知:", data)
    -- 可以在这里添加额外的成功提示或动画效果
end

--- 处理保底进度更新通知
function LotteryGui:OnPityUpdateNotify(data)
    gg.log("收到保底进度更新:", data)
    if data.poolName and data.pityProgress then
        self:UpdatePityProgress(data.pityProgress, data.poolName)
    end
end

--- 处理新抽奖池可用通知
function LotteryGui:OnNewPoolAvailableNotify(data)
    gg.log("收到新抽奖池可用通知:", data)
    if data.poolName then
        -- 可以在这里添加新抽奖池的提示
        self:RequestAvailablePools()
    end
end

--- 处理数据同步通知
function LotteryGui:OnDataSyncNotify(data)
    gg.log("收到数据同步通知:", data)
    if data.lotteryData then
        self.lotteryData = data.lotteryData
        self:RefreshLotteryDisplay()
    end
end

--- 处理错误响应
function LotteryGui:OnLotteryErrorResponse(data)
    gg.log("收到抽奖系统错误响应:", data)
    local errorMessage = data.errorMessage or "操作失败"
    gg.log("错误信息:", errorMessage)
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
    gg.log("点击单抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.SINGLE_DRAW)
end

--- 五连抽按钮点击
function LotteryGui:OnClickFiveDraw()
    gg.log("点击五连抽按钮")
    self:SendLotteryRequest(LotteryEventConfig.REQUEST.FIVE_DRAW)
end

--- 档位选择按钮点击
function LotteryGui:OnClickTierSelect(tier)
    gg.log("选择档位:", tier)
    -- 根据当前抽奖类型和档位组合成抽奖池名称
    local lotteryType = self:GetCurrentLotteryType()
    self.currentPoolName = lotteryType .. tier
    self:UpdateTierSelection()
    self:UpdatePriceDisplay()
    self:UpdateProbabilityDisplay()
    self:UpdatePityProgress()
    -- 刷新当前抽奖池的物品列表
    self:RefreshCurrentLotteryItems()
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
    gg.log("发送抽奖请求:", requestData.args)
    gg.network_channel:fireServer(requestData)
end

-- =================================
-- UI刷新方法
-- =================================

--- 刷新抽奖界面显示
function LotteryGui:RefreshLotteryDisplay()
    gg.log("刷新抽奖界面显示")
    
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
    -- 重置所有档位按钮状态
    if self.primaryTierButton then
        self.primaryTierButton:SetSelected(currentTier == "初级")
    end
    if self.intermediateTierButton then
        self.intermediateTierButton:SetSelected(currentTier == "中级")
    end
    if self.advancedTierButton then
        self.advancedTierButton:SetSelected(currentTier == "高级")
    end
    if self.superTierButton then
        self.superTierButton:SetSelected(currentTier == "超级")
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
    gg.log("更新保底进度:", targetPool, currentProgress)
    
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
    if not self.lotteryConfigs[configKey] then
        -- 从ConfigLoader获取LotteryType配置
        local lotteryType = ConfigLoader.GetLottery(configKey)
        
        if lotteryType then
            -- 获取奖励池和总权重
            local rewardPool = lotteryType.rewardPool
            local totalWeight = lotteryType:GetTotalWeight()
            
            if rewardPool and totalWeight > 0 then
                -- 计算概率：前两个为普通奖励，第三个为高级奖励
                local normalWeight = 0
                local advancedWeight = 0
                
                if #rewardPool >= 1 then
                    normalWeight = normalWeight + (rewardPool[1].weight or 0)
                end
                if #rewardPool >= 2 then
                    normalWeight = normalWeight + (rewardPool[2].weight or 0)
                end
                if #rewardPool >= 3 then
                    advancedWeight = rewardPool[3].weight or 0
                end
                
                self.lotteryConfigs[configKey] = {
                    normalProbability = (normalWeight / totalWeight * 100),
                    advancedProbability = (advancedWeight / totalWeight * 100)
                }
            else
                -- 默认配置
                self.lotteryConfigs[configKey] = {
                    normalProbability = 85.0,
                    advancedProbability = 15.0
                }
            end
        else
            -- 默认配置
            self.lotteryConfigs[configKey] = {
                normalProbability = 85.0,
                advancedProbability = 15.0
            }
        end
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
    -- 例如："初级翅膀初级" -> "初级"
    -- "初级宠物中级" -> "中级"
    if string.find(self.currentPoolName, "初级") then
        if string.find(self.currentPoolName, "初级初级") then
            return "初级"
        elseif string.find(self.currentPoolName, "初级中级") then
            return "中级"
        elseif string.find(self.currentPoolName, "初级高级") then
            return "高级"
        elseif string.find(self.currentPoolName, "初级超级") then
            return "超级"
        end
    end
    
    return "初级"
end

--- 从抽奖池名称中获取当前抽奖类型
function LotteryGui:GetCurrentLotteryType()
    if not self.currentPoolName then return "初级翅膀" end
    
    -- 根据LotteryConfig的配置，解析抽奖池名称
    -- 例如："初级翅膀初级" -> "初级翅膀"
    -- "初级宠物中级" -> "初级宠物"
    if string.find(self.currentPoolName, "初级翅膀") then
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
    gg.log("开始初始化抽奖物品列表")
    
    -- 翅膀抽奖列表
    self:LoadLotteryItemsToList("初级翅膀初级", self.wingBeginnerLotteryList)
    self:LoadLotteryItemsToList("初级翅膀中级", self.wingIntermediateLotteryList)
    self:LoadLotteryItemsToList("初级翅膀高级", self.wingAdvancedLotteryList)
    
    -- 宠物抽奖列表
    self:LoadLotteryItemsToList("初级宠物初级", self.petBeginnerLotteryList)
    self:LoadLotteryItemsToList("初级宠物中级", self.petIntermediateLotteryList)
    self:LoadLotteryItemsToList("初级宠物高级", self.petAdvancedLotteryList)
    
    -- 伙伴抽奖列表
    self:LoadLotteryItemsToList("初级伙伴初级", self.partnerBeginnerLotteryList)
    self:LoadLotteryItemsToList("初级伙伴中级", self.partnerIntermediateLotteryList)
    self:LoadLotteryItemsToList("初级伙伴高级", self.partnerAdvancedLotteryList)
    
    gg.log("抽奖物品列表初始化完成")
end

--- 加载指定抽奖池的物品到对应ViewList
---@param poolName string 抽奖池名称
---@param viewList ViewList 目标ViewList
function LotteryGui:LoadLotteryItemsToList(poolName, viewList)
    if not viewList then
        gg.log("警告：ViewList为空，跳过抽奖池", poolName)
        return
    end
    
    -- 获取抽奖配置
    local lotteryConfig = ConfigLoader.GetLottery(poolName)
    if not lotteryConfig or not lotteryConfig.rewardPool then
        gg.log("警告：抽奖池配置不存在或无奖励池", poolName)
        return
    end
    
    gg.log("加载抽奖池物品:", poolName, "奖励数量:", #lotteryConfig.rewardPool)
    
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
        gg.log("警告：无法获取奖励信息", rewardItem)
        return
    end
    
    gg.log("创建奖励物品节点:", rewardInfo.name, "稀有度:", rewardInfo.rarity)
    
    -- 克隆奖励模版节点
    if not self.rewardTemplate or not self.rewardTemplate.node then
        gg.log("警告：找不到奖励模版节点")
        return
    end
    
    -- 克隆模版节点
    local itemNode = self.rewardTemplate.node:Clone()
    if not itemNode then
        gg.log("警告：克隆奖励模版节点失败")
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
        gg.log("设置奖励图片:", rewardInfo.name, "图片资源:", rewardInfo.icon)
    end
    
    -- 查找并设置概率显示
    local probabilityNode = backgroundNode:FindFirstChild("概率")
    gg.log("概率节点:", probabilityNode)
    if probabilityNode then
        -- 直接从LotteryType获取格式化的概率显示
        local lotteryConfig = ConfigLoader.GetLottery(poolName)
        
        if lotteryConfig then
            local probabilityText = lotteryConfig:GetFormattedProbability(rewardItem)
            probabilityNode.Title = probabilityText
            gg.log("设置奖励概率:", rewardInfo.name, "概率:", probabilityText)
        end
    end
    
    -- 查找并设置加成显示
    local bonusNode = backgroundNode:FindFirstChild("加成")
    gg.log("加成节点:", bonusNode)

    if bonusNode then
        -- 根据稀有度设置加成显示
        local bonusText = self:GetRarityBonusText(rewardInfo.rarity)
        bonusNode.Title = bonusText
        gg.log("设置奖励加成:", rewardInfo.name, "加成:", bonusText)
    end
    
    -- 将节点添加到ViewList
    viewList:AppendChild(itemNode)
    gg.log("成功添加奖励物品节点到ViewList:", rewardInfo.name)
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
        gg.log("警告：奖励配置中缺少奖励名称", rewardItem)
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
    
    gg.log("刷新抽奖池物品列表:", poolName)
    
    -- 根据当前抽奖类型选择对应的ViewList
    local targetViewList = nil
    if string.find(currentLotteryType, "翅膀") then
        if currentTier == "初级" then
            targetViewList = self.wingBeginnerLotteryList
        elseif currentTier == "中级" then
            targetViewList = self.wingIntermediateLotteryList
        elseif currentTier == "高级" then
            targetViewList = self.wingAdvancedLotteryList
        end
    elseif string.find(currentLotteryType, "宠物") then
        if currentTier == "初级" then
            targetViewList = self.petBeginnerLotteryList
        elseif currentTier == "中级" then
            targetViewList = self.petIntermediateLotteryList
        elseif currentTier == "高级" then
            targetViewList = self.petAdvancedLotteryList
        end
    elseif string.find(currentLotteryType, "伙伴") then
        if currentTier == "初级" then
            targetViewList = self.partnerBeginnerLotteryList
        elseif currentTier == "中级" then
            targetViewList = self.partnerIntermediateLotteryList
        elseif currentTier == "高级" then
            targetViewList = self.partnerAdvancedLotteryList
        end
    end
    
    if targetViewList then
        self:LoadLotteryItemsToList(poolName, targetViewList)
    end
end

return LotteryGui.New(script.Parent, uiConfig)