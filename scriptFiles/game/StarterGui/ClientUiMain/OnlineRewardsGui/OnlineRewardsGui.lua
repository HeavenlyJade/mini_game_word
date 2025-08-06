--- 在线奖励界面
--- 负责显示和管理在线奖励的UI界面
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local RewardEvent = require(MainStorage.Code.Event.RewardEvent) ---@type RewardEvent
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "OnlineRewardsGui",
    layer = 3,
    hideOnInit = true,
}


---@class OnlineRewardsGui : ViewBase
local OnlineRewardsGui = ClassMgr.Class("OnlineRewardsGui", ViewBase)


function OnlineRewardsGui:OnInit(node, config)
    -- UI组件初始化
    self.closeButton = self:Get("在线奖励界面/关闭", ViewButton) ---@type ViewButton
    
    -- 奖励档位选择
    self.primarySlot = self:Get("在线奖励界面/奖励界面栏位_初级", ViewList) ---@type ViewList

    -- 奖励容器
    self.rewardTemplate = self:Get("在线奖励界面/模版界面/奖励模版", ViewComponent) ---@type ViewComponent
    if self.rewardTemplate and self.rewardTemplate.node then
        self.rewardTemplate.node.Visible = false -- 隐藏模板
    end
    
    -- 设置选中状态（安全检查）
    if self.primarySlot and self.primarySlot.SetSelected then
        self.primarySlot:SetSelected(true)
    end
    

    
    -- 一键领取按钮
    -- self.claimAllButton = self:Get("在线奖励界面/模版界面/一键领取", ViewButton) ---@type ViewButton
    
    -- 数据存储
    self.currentConfig = "在线奖励初级" ---@type string 当前选中的配置
    self.rewardData = {} ---@type table 服务端同步的奖励数据
    self.rewardButtons = {} ---@type table<string, ViewComponent> 奖励按钮缓存
    self.configSlots = {} ---@type table<string, ViewButton> 配置栏位映射
    self.rewardConfig = nil ---@type RewardType 当前奖励配置
    self.rewardNodeMap = {} ---@type table<string, any> 奖励节点映射
    
    

    
    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()
    
    -- 初始化奖励配置和界面

    self:InitRewardSlots()
    self:InitConfigSlots()
    
    -- 初始化UI状态
    self:InitializeUI()
    
    gg.log("OnlineRewardsGui 在线奖励界面初始化完成")
end


function OnlineRewardsGui:InitRewardSlots()
    self.rewardConfig = ConfigLoader.GetReward(self.currentConfig)
    if not self.rewardConfig then
        gg.log("奖励配置未加载，无法初始化奖励槽位")
        return
    end
    
    -- 检查primarySlot是否存在
    if not self.primarySlot then
        gg.log("警告：primarySlot未找到，无法初始化奖励槽位")
        return
    end
    
    -- 清空现有槽位
    self.primarySlot:ClearChildren()
    self.rewardNodeMap = {}
    
    -- 获取奖励列表
    local rewardList = self.rewardConfig.rewardList
    if not rewardList then
        gg.log("奖励列表为空")
        return
    end
    
    -- 按时间节点排序
    table.sort(rewardList, function(a, b)
        return (a.timeNode or 0) < (b.timeNode or 0)
    end)
    
    -- 为每个奖励创建槽位
    for i, reward in ipairs(rewardList) do
        if self.rewardTemplate and self.rewardTemplate.node then
            local cloneNode = self.rewardTemplate.node:Clone()
            cloneNode.Visible = true
            cloneNode.Name = "奖励_" .. i
            
            -- 设置奖励槽位显示
            self:SetupRewardSlot(cloneNode, reward, i)
            
            -- 添加到槽位列表
            self.primarySlot:AppendChild(cloneNode)
            
            -- 建立节点映射
            self.rewardNodeMap[i] = cloneNode
        end
    end
    
    gg.log("奖励槽位初始化完成，共加载 " .. #rewardList .. " 个奖励")
end

function OnlineRewardsGui:InitConfigSlots()
    -- 获取可用的奖励配置
    local availableConfigs = self:GetAvailableRewardConfigs()
    
    -- 清空现有配置槽位映射
    self.configSlots = {}
    
    -- 检查primarySlot是否存在
    if not self.primarySlot then
        gg.log("警告：primarySlot未找到，无法初始化配置槽位")
        return
    end
    
    -- 为每个配置创建槽位（这里可以根据UI结构调整）
    for i, configName in ipairs(availableConfigs) do
        -- 这里可以根据实际的UI结构来获取配置槽位
        -- 目前先使用默认的primarySlot作为示例
        if i == 1 then -- 只处理第一个配置
            self.configSlots[configName] = self.primarySlot
        end
    end
    
    gg.log("配置槽位初始化完成，可用配置:", table.concat(availableConfigs, ", "))
end

function OnlineRewardsGui:SetupRewardSlot(slotNode, reward, index)
    if not slotNode then return end
    
    -- 设置奖励时间节点
    local backgroundNode = slotNode:FindFirstChild("背景")
    local timeNode = backgroundNode:FindFirstChild("时间节点")
    if timeNode and reward.timeNode then
        timeNode.Title = self:FormatTime(reward.timeNode)
    elseif timeNode then
        timeNode.Title = "00:00"
    end
    

    
    -- 设置奖励图标（如果有的话）
    local iconNode = backgroundNode:FindFirstChild("图标")
    if iconNode and reward.rewardItems then
        local item = reward.rewardItems
        if item.type == "物品" then
            -- 可以根据物品名称获取图标
            local itemConfig = ConfigLoader.GetItem(item.itemName)
            if itemConfig and itemConfig.icon then
                iconNode.Icon = itemConfig.icon
            end
        elseif item.type == "宠物" then
            local petConfig = ConfigLoader.GetPet(item.petConfig)
            if petConfig and petConfig.avatarResource then
                iconNode.Icon = petConfig.avatarResource
            end
        elseif item.type == "伙伴" then
            local partnerConfig = ConfigLoader.GetPartner(item.partnerConfig)
            if partnerConfig and partnerConfig.avatarResource then
                iconNode.Icon = partnerConfig.avatarResource
            end
        end
    end
    
    -- 设置奖励数量
    local amountNode = backgroundNode:FindFirstChild("奖励数量")
    if amountNode and reward.rewardItems then
        amountNode.Title = "x" .. (reward.rewardItems.amount or 1)
    end
    

    
    -- 绑定点击事件
    local slotButton = ViewButton.New(backgroundNode["领取"], self)
    slotButton:SetGray(true)
    slotButton:SetTouchEnable(false, nil)
    slotButton.clickCb = function()
        self:OnRewardSlotClick(index, reward)
    end
    slotButton.extraParams = {
        index = index,
        reward = reward
    }
    
    self.rewardButtons[index] = slotButton
end

function OnlineRewardsGui:OnRewardSlotClick(index, reward)
    gg.log("点击奖励槽位:", index, "时间节点:", reward.timeNode)
    
    -- 检查是否可以领取
    if self.rewardData and self.rewardData.rewards then
        local rewardStatus = self.rewardData.rewards[index]
        if rewardStatus and rewardStatus.status == 1 then
            self:ClaimReward(index)
        else
            gg.log("该奖励暂不可领取，状态:", rewardStatus and rewardStatus.status or "未知")
        end
    else
        gg.log("奖励数据未加载")
    end
end

-- =================================
-- 事件注册
-- =================================

function OnlineRewardsGui:RegisterEvents()
    gg.log("注册在线奖励系统事件监听")
    
    -- 监听在线奖励数据响应
    ClientEventManager.Subscribe(RewardEvent.RESPONSE.ONLINE_REWARD_DATA, function(data)
        self:OnRewardDataResponse(data)
    end)
    
    -- 监听领取奖励响应
    ClientEventManager.Subscribe(RewardEvent.RESPONSE.CLAIM_REWARD_RESULT, function(data)
        self:OnClaimRewardResponse(data)
    end)
    
    -- 监听一键领取响应
    ClientEventManager.Subscribe(RewardEvent.RESPONSE.CLAIM_ALL_RESULT, function(data)
        self:OnClaimAllResponse(data)
    end)
    
    -- 监听配置切换响应
    ClientEventManager.Subscribe(RewardEvent.RESPONSE.SWITCH_CONFIG_RESULT, function(data)
        self:OnSwitchConfigResponse(data)
    end)
    
    -- 监听数据同步通知
    ClientEventManager.Subscribe(RewardEvent.NOTIFY.DATA_SYNC, function(data)
        self:OnDataSync(data)
    end)
    
    -- 监听新奖励可领取通知
    ClientEventManager.Subscribe(RewardEvent.NOTIFY.NEW_AVAILABLE, function(data)
        gg.log("客户端收到 RewardEvent.NOTIFY.NEW_AVAILABLE 事件:", data)
        self:OnNewAvailable(data)
    end)
    
    -- 监听奖励已领取通知
    ClientEventManager.Subscribe(RewardEvent.NOTIFY.REWARD_CLAIMED, function(data)
        self:OnRewardClaimed(data)
    end)
    
    -- 监听轮次重置通知
    ClientEventManager.Subscribe(RewardEvent.NOTIFY.ROUND_RESET, function(data)
        self:OnRoundReset(data)
    end)
    
    -- 监听每日重置通知
    ClientEventManager.Subscribe(RewardEvent.NOTIFY.DAILY_RESET, function(data)
        self:OnDailyReset(data)
    end)
end

-- =================================
-- 按钮事件注册
-- =================================

function OnlineRewardsGui:RegisterButtonEvents()
    -- 关闭按钮
    self.closeButton.clickCb = function(ui, btn)
        self:Close()
    end
    
    -- 配置栏位切换
    for configName, slot in pairs(self.configSlots) do
        slot.clickCb = function(ui, btn)
            self:SwitchConfig(configName)
        end
    end
    
    -- 一键领取按钮（如果存在）
    if self.claimAllButton then
        self.claimAllButton.clickCb = function(ui, btn)
            self:ClaimAllRewards()
        end
    end
end

-- =================================
-- UI初始化
-- =================================

function OnlineRewardsGui:InitializeUI()
    -- 设置默认配置
    
    -- 隐藏界面
    self:SetVisible(false)
    
    gg.log("在线奖励界面UI初始化完成")
end

-- =================================
-- 界面显示/隐藏
-- =================================

function OnlineRewardsGui:Show()
    if self.isVisible then
        return
    end
    
    self.isVisible = true
    self:SetVisible(true)
    
    -- 确保奖励配置已加载
    if not self.rewardConfig then
        self:InitRewardConfig()
        self:InitRewardSlots()
        self:InitConfigSlots()
    end
    
    -- 请求服务器数据
    self:RequestRewardData()
    
    gg.log("在线奖励界面已显示")
end

function OnlineRewardsGui:Hide()
    if not self.isVisible then
        return
    end
    
    self.isVisible = false
    self:SetVisible(false)
    
    gg.log("在线奖励界面已隐藏")
end

-- =================================
-- 配置切换
-- =================================

function OnlineRewardsGui:SwitchConfig(configName)
    if self.currentConfig == configName then
        return
    end
    
    self.currentConfig = configName
    
    -- 重新加载奖励配置
    self:InitRewardConfig()
    self:InitRewardSlots()
    self:InitConfigSlots()
    

    
    -- 请求新配置的数据
    self:RequestRewardData()
    
    gg.log(string.format("切换到配置: %s", configName))
end



-- =================================
-- 数据请求
-- =================================

function OnlineRewardsGui:RequestRewardData()
    gg.network_channel:FireServer({
        cmd = RewardEvent.REQUEST.GET_ONLINE_REWARD_DATA,
        configName = self.currentConfig
    })
end

function OnlineRewardsGui:ClaimReward(index)
    gg.network_channel:FireServer({
        cmd = RewardEvent.REQUEST.CLAIM_ONLINE_REWARD,
        index = index,
        configName = self.currentConfig
    })
    
    gg.log(string.format("请求领取奖励: %d", index))
end

function OnlineRewardsGui:ClaimAllRewards()
    gg.network_channel:FireServer({
        cmd = RewardEvent.REQUEST.CLAIM_ALL_ONLINE_REWARDS,
        configName = self.currentConfig
    })
    
    gg.log("请求一键领取所有奖励")
end

-- =================================
-- 事件响应处理
-- =================================

function OnlineRewardsGui:OnRewardDataResponse(data)
    if not data or not data.success then
        gg.log("获取奖励数据失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    self.rewardData = data.data
    
    -- 确保奖励槽位已初始化
    if not self.rewardConfig then
        self:InitRewardConfig()
        self:InitRewardSlots()
        self:InitConfigSlots()
    end
    
    self:UpdateRewardDisplay()
    
    gg.log("奖励数据已更新")
end

function OnlineRewardsGui:OnClaimRewardResponse(data)
    if not data or not data.success then
        gg.log("领取奖励失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    -- 重新请求数据以更新显示
    self:RequestRewardData()
    
    gg.log(string.format("奖励领取成功: %d", data.index))
end

function OnlineRewardsGui:OnClaimAllResponse(data)
    if not data or not data.success then
        gg.log("一键领取失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    -- 重新请求数据以更新显示
    self:RequestRewardData()
    
    gg.log(string.format("一键领取成功，共领取 %d 个奖励", data.count))
end

function OnlineRewardsGui:OnSwitchConfigResponse(data)
    if not data or not data.success then
        gg.log("切换配置失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    gg.log(string.format("配置切换成功: %s", data.newConfig))
end

function OnlineRewardsGui:OnDataSync(data)
    if data.onlineStatus then
        self.rewardData = data.onlineStatus
        self:UpdateRewardDisplay()
    end
end

function OnlineRewardsGui:OnNewAvailable(data)
    gg.log("客户端收到新奖励可领取通知:", data)
    if data.hasAvailable then
        -- 可以在这里添加红点提示或其他UI反馈
        gg.log(string.format("有新的奖励可领取，在线时长: %d 秒，可领取索引: %s", 
            data.onlineTime or 0, table.concat(data.availableIndices or {}, ", ")))
        
        -- 如果有具体的可领取索引，可以立即更新UI
        if data.availableIndices and #data.availableIndices > 0 then
            -- 可以在这里添加红点提示或其他视觉反馈
            gg.log(string.format("发现 %d 个新可领取奖励", #data.availableIndices))
        end
    end
end

function OnlineRewardsGui:OnRewardClaimed(data)
    if data.type == "online" then
        -- 重新请求数据以更新显示
        self:RequestRewardData()
    end
end

function OnlineRewardsGui:OnRoundReset(data)
    gg.log(string.format("轮次重置: 第 %d 轮", data.newRound))
    -- 重新请求数据
    self:RequestRewardData()
end

function OnlineRewardsGui:OnDailyReset(data)
    gg.log(string.format("每日重置: %s", data.date))
    -- 重新请求数据
    self:RequestRewardData()
end

-- =================================
-- UI更新
-- =================================

function OnlineRewardsGui:UpdateRewardDisplay()
    if not self.rewardData or not self.rewardData.rewards then
        return
    end
    
    -- 更新奖励槽位状态
    for index, rewardStatus in ipairs(self.rewardData.rewards) do
        local slotNode = self.rewardNodeMap[index]
        if slotNode then
            self:UpdateRewardSlotStatus(slotNode, rewardStatus, index)
        end
    end
end

function OnlineRewardsGui:UpdateRewardSlotStatus(slotNode, rewardStatus, index)
    if not slotNode then return end
    
    -- 更新状态显示
    local statusNode = slotNode:FindFirstChild("状态")
    if statusNode then
        local statusText = self:GetRewardStatusText(rewardStatus.status)
        statusNode.Title = statusText
    end
    
    -- 更新按钮状态
    local slotButton = self.rewardButtons[index]
    if slotButton then
        local canClaim = rewardStatus.status == 1
        slotButton:SetGray(not canClaim)
        slotButton:SetTouchEnable(canClaim, nil)
    end
    
    -- 可以添加其他视觉反馈，比如背景颜色变化等

end



function OnlineRewardsGui:GetRewardDescription(reward)
    if not reward or not reward.rewardItems then
        return "未知奖励"
    end
    
    local item = reward.rewardItems
    local desc = ""
    
    if item.type == "物品" then
        desc = string.format("%s x%d", item.itemName or "未知物品", item.amount or 1)
    elseif item.type == "宠物" then
        desc = string.format("宠物：%s", item.petConfig or "未知宠物")
    elseif item.type == "伙伴" then
        desc = string.format("伙伴：%s", item.partnerConfig or "未知伙伴")
    elseif item.type == "翅膀" then
        desc = string.format("翅膀：%s", item.wingConfig or "未知翅膀")
    end
    
    return desc
end

-- =================================
-- 工具方法
-- =================================

function OnlineRewardsGui:GetRewardStatusText(status)
    if status == 0 then
        return "未达成"
    elseif status == 1 then
        return "可领取"
    elseif status == 2 then
        return "已领取"
    else
        return "未知"
    end
end

function OnlineRewardsGui:GetCurrentRewardList()
    if not self.rewardConfig then
        return {}
    end
    
    return self.rewardConfig.rewardList or {}
end

function OnlineRewardsGui:GetRewardByIndex(index)
    local rewardList = self:GetCurrentRewardList()
    return rewardList[index]
end

function OnlineRewardsGui:GetAvailableRewardConfigs()
    -- 获取所有可用的奖励配置
    local allRewards = ConfigLoader.GetAllRewards()
    local availableConfigs = {}
    
    for configName, rewardConfig in pairs(allRewards) do
        if rewardConfig.rewardType == "在线奖励" then
            table.insert(availableConfigs, configName)
        end
    end
    
    return availableConfigs
end

function OnlineRewardsGui:FormatTime(seconds)
    -- 直接使用RewardType的FormatTime方法，避免重复实现
    if self.rewardConfig then
        return self.rewardConfig:FormatTime(seconds)
    else
        -- 备用实现，当rewardConfig未加载时使用
        if not seconds or seconds < 0 then
            return "00:00"
        end
        
        local minutes = math.floor(seconds / 60)
        local secs = seconds % 60
        
        if minutes >= 60 then
            local hours = math.floor(minutes / 60)
            minutes = minutes % 60
            return string.format("%02d:%02d:%02d", hours, minutes, secs)
        else
            return string.format("%02d:%02d", minutes, secs)
        end
    end
end

return OnlineRewardsGui.New(script.Parent, uiConfig) 