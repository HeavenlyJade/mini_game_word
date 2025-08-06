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
    
    -- 倒计时相关
    self.onlineTime = 0 ---@type number 当前在线时长（秒）
    self.lastUpdateTime = 0 ---@type number 最后更新时间戳
    self.countdownTimer = nil ---@type Timer 倒计时定时器
    
    

    
    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()
    
    -- 初始化奖励配置和界面

    self:InitRewardSlots()
    self:InitConfigSlots()
    
    -- 初始化UI状态
    self:InitializeUI()
    
    --gg.log("OnlineRewardsGui 在线奖励界面初始化完成")
end


function OnlineRewardsGui:InitRewardConfig()
    self.rewardConfig = ConfigLoader.GetReward(self.currentConfig)
    if not self.rewardConfig then
        --gg.log("奖励配置未加载，无法初始化奖励槽位")
        return false
    end
    return true
end

function OnlineRewardsGui:InitRewardSlots()
    if not self:InitRewardConfig() then
        return
    end
    
    -- 检查primarySlot是否存在
    if not self.primarySlot then
        --gg.log("警告：primarySlot未找到，无法初始化奖励槽位")
        return
    end
    
    -- 清空现有槽位
    self.primarySlot:ClearChildren()
    self.rewardNodeMap = {}
    
    -- 获取奖励列表
    local rewardList = self.rewardConfig.rewardList
    if not rewardList then
        --gg.log("奖励列表为空")
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
    
    --gg.log("奖励槽位初始化完成，共加载 " .. #rewardList .. " 个奖励")
end

function OnlineRewardsGui:InitConfigSlots()
    -- 获取可用的奖励配置
    local availableConfigs = self:GetAvailableRewardConfigs()
    
    -- 清空现有配置槽位映射
    self.configSlots = {}
    
    -- 检查primarySlot是否存在
    if not self.primarySlot then
        --gg.log("警告：primarySlot未找到，无法初始化配置槽位")
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
    
    --gg.log("配置槽位初始化完成，可用配置:", table.concat(availableConfigs, ", "))
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
    gg.log("=== 点击奖励槽位 ===")
    gg.log(string.format("奖励索引: %d, 时间节点: %d", index, reward.timeNode or 0))
    gg.log(string.format("当前在线时长: %d 秒", self.onlineTime or 0))
    
    -- 客户端时间检查：如果在线时长不足，直接拒绝
    if reward.timeNode and self.onlineTime < reward.timeNode then
        gg.log(string.format("客户端拒绝：在线时长不足，需要 %d 秒，当前只有 %d 秒", 
            reward.timeNode, self.onlineTime))
        return
    end
    
    -- 检查是否可以领取
    if self.rewardData and self.rewardData.rewards then
        local rewardStatus = self.rewardData.rewards[index]
        if rewardStatus then
            gg.log(string.format("奖励状态: %d (0=未达成, 1=可领取, 2=已领取)", rewardStatus.status))
            
            if rewardStatus.status == 1 then
                gg.log("奖励可领取，开始领取流程")
                self:ClaimReward(index)
            else
                gg.log(string.format("该奖励暂不可领取，状态: %d", rewardStatus.status))
            end
        else
            gg.log("警告：找不到奖励状态数据")
        end
    else
        gg.log("警告：奖励数据未加载")
    end
    gg.log("=== 点击奖励槽位结束 ===")
end

-- =================================
-- 事件注册
-- =================================

function OnlineRewardsGui:RegisterEvents()
    --gg.log("注册在线奖励系统事件监听")
    
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
        --gg.log("客户端收到 RewardEvent.NOTIFY.NEW_AVAILABLE 事件:", data)
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
    
    -- 启动倒计时定时器
    self:StartCountdownTimer()
    
    --gg.log("在线奖励界面UI初始化完成")
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
    
    -- 启动倒计时定时器
    self:StartCountdownTimer()
    
    -- 请求服务器数据
    self:RequestRewardData()
    
    --gg.log("在线奖励界面已显示")
end

function OnlineRewardsGui:Hide()
    if not self.isVisible then
        return
    end
    
    self.isVisible = false
    self:SetVisible(false)
    
    -- 停止倒计时定时器
    self:StopCountdownTimer()
    
    --gg.log("在线奖励界面已隐藏")
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
    
    --gg.log(string.format("切换到配置: %s", configName))
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
    gg.log("=== 开始领取奖励 ===")
    gg.log(string.format("奖励索引: %d, 配置: %s", index, self.currentConfig))
    
    -- 立即隐藏对应的领取按钮，防止重复点击
    self:HideClaimButton(index)
    
    gg.log("发送领取请求到服务端")
    gg.network_channel:FireServer({
        cmd = RewardEvent.REQUEST.CLAIM_ONLINE_REWARD,
        index = index,
        configName = self.currentConfig
    })
    
    gg.log("=== 领取奖励请求已发送 ===")
end

function OnlineRewardsGui:ClaimAllRewards()
    -- 立即隐藏所有可领取的按钮，防止重复点击
    if self.rewardData and self.rewardData.rewards then
        for index, rewardStatus in ipairs(self.rewardData.rewards) do
            if rewardStatus.status == 1 then  -- 可领取状态
                self:HideClaimButton(index)
            end
        end
    end
    
    gg.network_channel:FireServer({
        cmd = RewardEvent.REQUEST.CLAIM_ALL_ONLINE_REWARDS,
        configName = self.currentConfig
    })
    
    --gg.log("请求一键领取所有奖励")
end

-- =================================
-- 事件响应处理
-- =================================

function OnlineRewardsGui:OnRewardDataResponse(data)
    if not data or not data.success then
        --gg.log("获取奖励数据失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    self.rewardData = data.data
    
    -- 同步在线时长
    if self.rewardData and self.rewardData.roundOnlineTime then
        self.onlineTime = self.rewardData.roundOnlineTime
        self.lastUpdateTime = gg.GetTimeStamp()
        --gg.log(string.format("初始化在线时长: %d 秒", self.onlineTime))
    end
    
    -- 确保奖励槽位已初始化
    if not self.rewardConfig then
        self:InitRewardConfig()
        self:InitRewardSlots()
        self:InitConfigSlots()
    end
    
    self:UpdateRewardDisplay()
    
    --gg.log("奖励数据已更新")
end

function OnlineRewardsGui:OnClaimRewardResponse(data)
    if not data or not data.success then
        --gg.log("领取奖励失败:", data and data.errorMsg or "未知错误")
        
        -- 领取失败时，恢复按钮状态
        if data and data.index then
            self:ShowClaimButton(data.index)  -- 重新显示按钮
            self:UpdateSingleRewardStatus(data.index, 1)  -- 恢复为可领取状态
        end
        return
    end
    
    -- 领取成功，立即更新状态
    if data.index then
        self:UpdateSingleRewardStatus(data.index, 2)  -- 标记为已领取
    end
    
    --gg.log(string.format("奖励领取成功: %d", data.index))
end

function OnlineRewardsGui:OnClaimAllResponse(data)
    if not data or not data.success then
        --gg.log("一键领取失败:", data and data.errorMsg or "未知错误")
        
        -- 一键领取失败时，恢复所有按钮状态
        if self.rewardData and self.rewardData.rewards then
            for index, rewardStatus in ipairs(self.rewardData.rewards) do
                if rewardStatus.status == 1 then  -- 可领取状态
                    self:ShowClaimButton(index)  -- 重新显示按钮
                    self:UpdateSingleRewardStatus(index, 1)  -- 恢复为可领取状态
                end
            end
        end
        return
    end
    
    -- 一键领取成功，更新所有已领取的按钮状态
    if data.rewards and #data.rewards > 0 then
        for _, rewardData in ipairs(data.rewards) do
            local index = rewardData.index
            if index then
                self:UpdateSingleRewardStatus(index, 2)  -- 标记为已领取
            end
        end
    end
    
    --gg.log(string.format("一键领取成功，共领取 %d 个奖励", data.count))
end

function OnlineRewardsGui:OnSwitchConfigResponse(data)
    if not data or not data.success then
        --gg.log("切换配置失败:", data and data.errorMsg or "未知错误")
        return
    end
    
    --gg.log(string.format("配置切换成功: %s", data.newConfig))
end

function OnlineRewardsGui:OnDataSync(data)
    if data.onlineStatus then
        self.rewardData = data.onlineStatus
        self:UpdateRewardDisplay()
    end
end

function OnlineRewardsGui:OnNewAvailable(data)
    --gg.log("客户端收到新奖励可领取通知:", data)
    
    -- 更新在线时长（从服务端同步）
    if data.onlineTime then
        self.onlineTime = data.onlineTime
        self.lastUpdateTime = gg.GetTimeStamp()
        --gg.log(string.format("同步在线时长: %d 秒", self.onlineTime))
    end
    
    -- 更新所有奖励的状态
    if data.availableIndices then
        for _, index in ipairs(data.availableIndices) do
            self:UpdateSingleRewardStatus(index, 1)  -- 标记为可领取
            --gg.log(string.format("已更新奖励 %d 为可领取状态", index))
        end
        --gg.log(string.format("更新了 %d 个可领取奖励", #data.availableIndices))
    end
    
    if data.claimedIndices then
        for _, index in ipairs(data.claimedIndices) do
            self:UpdateSingleRewardStatus(index, 2)  -- 标记为已领取
            --gg.log(string.format("已更新奖励 %d 为已领取状态", index))
        end
        --gg.log(string.format("更新了 %d 个已领取奖励", #data.claimedIndices))
    end
    
    if data.unavailableIndices then
        for _, index in ipairs(data.unavailableIndices) do
            self:UpdateSingleRewardStatus(index, 0)  -- 标记为不可领取
            --gg.log(string.format("已更新奖励 %d 为不可领取状态", index))
        end
        --gg.log(string.format("更新了 %d 个不可领取奖励", #data.unavailableIndices))
    end
    
    -- 显示总体信息
    if data.hasAvailable then
        --gg.log(string.format("有新的奖励可领取，在线时长: %d 秒", data.onlineTime or 0))
    end
end

function OnlineRewardsGui:OnRewardClaimed(data)
    if data.type == "online" and data.index then
        -- 立即更新状态为已领取
        self:UpdateSingleRewardStatus(data.index, 2)
    end
end

function OnlineRewardsGui:OnRoundReset(data)
    --gg.log(string.format("轮次重置: 第 %d 轮", data.newRound))
    -- 重新请求数据
    self:RequestRewardData()
end

function OnlineRewardsGui:OnDailyReset(data)
    --gg.log(string.format("每日重置: %s", data.date))
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
    
    --gg.log("奖励显示更新完成")
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
    
    -- 特殊处理：已领取的奖励隐藏按钮，其他状态显示按钮
    if rewardStatus.status == 2 then
        self:HideClaimButton(index)
    else
        self:ShowClaimButton(index)
    end
    
    -- 可以添加其他视觉反馈，比如背景颜色变化等

end

--- 立即更新单个奖励槽位的状态
---@param index number 奖励索引
---@param status number 状态: 0=未达成, 1=可领取, 2=已领取
function OnlineRewardsGui:UpdateSingleRewardStatus(index, status)
    -- 更新本地数据
    if self.rewardData and self.rewardData.rewards then
        local rewardStatus = self.rewardData.rewards[index]
        if rewardStatus then
            rewardStatus.status = status
        end
    end
    
    -- 更新UI显示
    local slotNode = self.rewardNodeMap[index]
    if slotNode then
        local rewardStatus = {
            status = status
        }
        self:UpdateRewardSlotStatus(slotNode, rewardStatus, index)
        
        -- 特殊处理：已领取的奖励隐藏按钮
        if status == 2 then
            self:HideClaimButton(index)
        end
    end
    
    --gg.log(string.format("已更新奖励 %d 的状态为: %d", index, status))
end

--- 隐藏领取按钮
---@param index number 奖励索引
function OnlineRewardsGui:HideClaimButton(index)
    local slotNode = self.rewardNodeMap[index]
    if not slotNode then
        --gg.log(string.format("警告：找不到奖励 %d 的节点", index))
        return
    end
    
    -- 查找并隐藏领取按钮
    local backgroundNode = slotNode:FindFirstChild("背景")
    if backgroundNode then
        local claimButton = backgroundNode:FindFirstChild("领取")
        if claimButton then
            claimButton.Visible = false
            --gg.log(string.format("已隐藏奖励 %d 的领取按钮", index))
        else
            --gg.log(string.format("警告：找不到奖励 %d 的领取按钮", index))
        end
    else
        --gg.log(string.format("警告：找不到奖励 %d 的背景节点", index))
    end
    
    -- 同时禁用ViewButton
    local slotButton = self.rewardButtons[index]
    if slotButton then
        slotButton:SetGray(true)
        slotButton:SetTouchEnable(false, nil)
        --gg.log(string.format("已禁用奖励 %d 的ViewButton", index))
    else
        --gg.log(string.format("警告：找不到奖励 %d 的ViewButton", index))
    end
end

--- 显示领取按钮（用于恢复状态）
---@param index number 奖励索引
function OnlineRewardsGui:ShowClaimButton(index)
    local slotNode = self.rewardNodeMap[index]
    if not slotNode then
        return
    end
    
    -- 查找并显示领取按钮
    local backgroundNode = slotNode:FindFirstChild("背景")
    if backgroundNode then
        local claimButton = backgroundNode:FindFirstChild("领取")
        if claimButton then
            claimButton.Visible = true
            --gg.log(string.format("已显示奖励 %d 的领取按钮", index))
        end
    end
    
    -- 同时启用ViewButton（根据状态决定是否可点击）
    local slotButton = self.rewardButtons[index]
    if slotButton then
        -- 检查当前状态
        if self.rewardData and self.rewardData.rewards then
            local rewardStatus = self.rewardData.rewards[index]
            if rewardStatus then
                local canClaim = rewardStatus.status == 1
                slotButton:SetGray(not canClaim)
                slotButton:SetTouchEnable(canClaim, nil)
                --gg.log(string.format("已启用奖励 %d 的ViewButton，可点击: %s", index, tostring(canClaim)))
            end
        end
    end
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
            return "00:00:00"
        end
        
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60
        
        -- 如果小时为0，只显示分:秒
        if hours == 0 then
            return string.format("%02d:%02d", minutes, secs)
        else
            -- 否则显示时:分:秒
            return string.format("%02d:%02d:%02d", hours, minutes, secs)
        end
    end
end

-- =================================
-- 倒计时定时器管理
-- =================================

--- 启动倒计时定时器
function OnlineRewardsGui:StartCountdownTimer()
    -- 如果定时器已存在，先停止
    self:StopCountdownTimer()
    
    -- 创建新的定时器
    self.countdownTimer = SandboxNode.New("Timer", game.WorkSpace)
    self.countdownTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    self.countdownTimer.Name = "OnlineRewardsGui_CountdownTimer"
    self.countdownTimer.Delay = 1
    self.countdownTimer.Loop = true
    self.countdownTimer.Interval = 1  -- 每秒执行
    self.countdownTimer.Callback = function()
        self:UpdateCountdown()
    end
    self.countdownTimer:Start()
    
    --gg.log("在线奖励倒计时定时器已启动")
end

--- 停止倒计时定时器
function OnlineRewardsGui:StopCountdownTimer()
    if self.countdownTimer then
        self.countdownTimer:Stop()
        self.countdownTimer:Destroy()
        self.countdownTimer = nil
        --gg.log("在线奖励倒计时定时器已停止")
    end
end

--- 更新倒计时显示
function OnlineRewardsGui:UpdateCountdown()
    -- 增加在线时长
    self.onlineTime = self.onlineTime + 1
    
    -- 更新所有奖励槽位的时间显示
    self:UpdateAllRewardTimeDisplays()
    
    -- 检查是否有新的奖励变为可领取
    self:CheckForNewAvailableRewards()
    

end

--- 更新所有奖励槽位的时间显示
function OnlineRewardsGui:UpdateAllRewardTimeDisplays()
    if not self.rewardConfig or not self.rewardConfig.rewardList then
        return
    end
    
    for index, reward in ipairs(self.rewardConfig.rewardList) do
        local slotNode = self.rewardNodeMap[index]
        if slotNode then
            local backgroundNode = slotNode:FindFirstChild("背景")
            if backgroundNode then
                local timeNode = backgroundNode:FindFirstChild("时间节点")
                if timeNode and reward.timeNode then
                    -- 计算剩余时间
                    local remainingTime = math.max(0, reward.timeNode - self.onlineTime)
                    
                    -- 根据状态显示不同的时间格式
                    local currentStatus = self:GetRewardStatus(index)
                    if currentStatus == 2 then
                        -- 已领取：显示"已领取"
                        timeNode.Title = "已领取"
                    elseif currentStatus == 1 then
                        -- 可领取：显示"可领取"
                        timeNode.Title = "可领取"
                    else
                        -- 未达成：显示倒计时
                        if remainingTime > 0 then
                            timeNode.Title = self:FormatTime(remainingTime)
                        else
                            timeNode.Title = "00:00"
                        end
                    end
                    
                    -- 如果时间到了，更新按钮状态
                    if remainingTime <= 0 and currentStatus == 0 then
                        self:UpdateRewardButtonState(index, 1)  -- 标记为可领取
                    end
                end
            end
        end
    end
end

--- 检查是否有新的奖励变为可领取
function OnlineRewardsGui:CheckForNewAvailableRewards()
    if not self.rewardConfig or not self.rewardConfig.rewardList then
        return
    end
    
    local newAvailableCount = 0
    
    for index, reward in ipairs(self.rewardConfig.rewardList) do
        if reward.timeNode and self.onlineTime >= reward.timeNode then
            -- 检查当前状态
            local currentStatus = self:GetRewardStatus(index)
            if currentStatus == 0 then  -- 如果当前是未达成状态
                self:UpdateRewardButtonState(index, 1)  -- 更新为可领取
                newAvailableCount = newAvailableCount + 1
                --gg.log(string.format("奖励 %d 变为可领取状态", index))
            end
        end
    end
    
    if newAvailableCount > 0 then
        --gg.log(string.format("有 %d 个新奖励变为可领取", newAvailableCount))
    end
end

--- 更新奖励按钮状态
---@param index number 奖励索引
---@param status number 状态: 0=未达成, 1=可领取, 2=已领取
function OnlineRewardsGui:UpdateRewardButtonState(index, status)
    gg.log(string.format("更新奖励 %d 按钮状态: %d", index, status))
    
    -- 更新本地数据
    if self.rewardData and self.rewardData.rewards then
        local rewardStatus = self.rewardData.rewards[index]
        if rewardStatus then
            rewardStatus.status = status
        end
    end
    
    -- 额外检查：只有时间真正到达的奖励才能设置为可领取
    if status == 1 then
        local reward = self.rewardConfig and self.rewardConfig:GetRewardByIndex(index)
        if reward and reward.timeNode and self.onlineTime < reward.timeNode then
            gg.log(string.format("警告：奖励 %d 时间未到，强制设置为不可领取", index))
            status = 0  -- 强制设置为未达成
        end
    end
    
    -- 更新UI显示
    local slotButton = self.rewardButtons[index]
    if slotButton then
        local canClaim = status == 1
        slotButton:SetGray(not canClaim)
        slotButton:SetTouchEnable(canClaim, nil)
        gg.log(string.format("按钮 %d 设置为可点击: %s", index, tostring(canClaim)))
    end
    
    -- 根据状态显示或隐藏按钮
    if status == 2 then
        self:HideClaimButton(index)
    elseif status == 1 then
        self:ShowClaimButton(index)
    end
end

--- 获取奖励状态（本地计算）
---@param index number 奖励索引
---@return number 状态: 0=未达成, 1=可领取, 2=已领取
function OnlineRewardsGui:GetRewardStatus(index)
    -- 检查是否已领取
    if self.rewardData and self.rewardData.rewards then
        local rewardStatus = self.rewardData.rewards[index]
        if rewardStatus and rewardStatus.status == 2 then
            return 2  -- 已领取
        end
    end
    
    -- 检查是否可领取
    if self.rewardConfig then
        local reward = self.rewardConfig:GetRewardByIndex(index)
        if reward and reward.timeNode and self.onlineTime >= reward.timeNode then
            return 1  -- 可领取
        end
    end
    
    return 0  -- 未达成
end

return OnlineRewardsGui.New(script.Parent, uiConfig) 