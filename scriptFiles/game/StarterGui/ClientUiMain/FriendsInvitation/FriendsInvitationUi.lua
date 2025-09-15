-- FriendsUi.lua
-- 好友界面逻辑

local MainStorage = game:GetService("MainStorage")
local CoreUI = game:GetService("CoreUI")
local Players = game:GetService("Players")
local FriendInviteService = game:GetService("FriendInviteService")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local NodeConf = require(MainStorage.Code.Common.Icon.NodeConf) ---@type NodeConf
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入好友服务
local MiniApiFriendsService = require(MainStorage.Code.MServer.MiniApiServices.MiniApiFriendsService) ---@type MiniApiFriendsService

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent

-- UI配置
local uiConfig = {
	uiName = "FriendsInvitationGui",
	layer = 1,
	hideOnInit = true,
}

---@class FriendsInvitationGui : ViewBase
local FriendsInvitationGui = ClassMgr.Class("FriendsInvitationGui", ViewBase)

---@override
function FriendsInvitationGui:OnInit(node, config)
	-- 1. 节点初始化
	self.playerVariableData = {}

	self:InitNodes()

	-- 2. 注册事件监听
	self:RegisterEvents()
	self:InitData()
	
	-- 3. 初始化邀请人数显示
	self:UpdateInvitationCount()

end

function FriendsInvitationGui:InitData()
	self.rewardBonusConfig = ConfigLoader.GetRewardBonus("好友邀请") ---@type RewardBonusType
	self.rewardBonusData = self.rewardBonusConfig:GetRewardTierList() ---@type RewardTier[]
	--gg.log("rewardBonusData",self.rewardBonusData)
	-- 初始化玩家基础数据存储
	self.playerBaseData = {}
end
-- 节点初始化
function FriendsInvitationGui:InitNodes()
	-- 初始化数据结构
	self.friendComponents = {}
	self.friendItemComponents = {} ---@type ViewComponent[]
	self.closeButton = self:Get("好友界面/关闭", ViewButton) ---@type ViewButton
	self.closeButton.clickCb = function(ui, button)
		self:Close()
	end
	self.NumberInvitations = self:Get("好友界面/邀请人数", ViewComponent) ---@type ViewComponent
	self.rewardWings = self:Get("好友界面/奖励翅膀/领取", ViewButton) ---@type ViewButton
	self.rewardTrail = self:Get("好友界面/奖励尾迹/领取", ViewButton) ---@type ViewButton
	self.rewardCompanion = self:Get("好友界面/奖励伙伴/领取", ViewButton) ---@type ViewButton
	self.rewardPet = self:Get("好友界面/奖励宠物/领取", ViewButton) ---@type ViewButton
	self.rewardWings:SetTouchEnable(false, nil)
	self.rewardTrail:SetTouchEnable(false, nil)
	self.rewardCompanion:SetTouchEnable(false, nil)
	self.rewardPet:SetTouchEnable(false, nil)
	self.rewardWings.clickCb = function(ui, button)
		self:OnRewardClick("wings", self.rewardUniqueIds.wings)
	end
	self.rewardTrail.clickCb = function(ui, button)
		self:OnRewardClick("trail", self.rewardUniqueIds.trail)
	end
	self.rewardCompanion.clickCb = function(ui, button)
		self:OnRewardClick("companion", self.rewardUniqueIds.companion)
	end
	self.rewardPet.clickCb = function(ui, button)
		self:OnRewardClick("pet", self.rewardUniqueIds.pet)
	end
	
	-- 绑定奖励配置的UniqueId
	self.rewardUniqueIds = {
		wings = "ID4",      -- 翅膀奖励
		trail = "ID3",      -- 尾迹奖励  
		companion = "ID2",   -- 伙伴奖励
		pet = "ID1"          -- 宠物奖励
	}
	
end

-- 注册事件监听
function FriendsInvitationGui:RegisterEvents()
	-- 事件监听逻辑（待实现）
	ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, function(data)
        self:OnSyncPlayerVariables(data)
    end)
end


---@param data table 包含variableData的数据表
function FriendsInvitationGui:OnSyncPlayerVariables(data)
    if not data or not data.variableData then
        return
    end
    -- 提取base数据并封装为key-value结构
    local baseData = self:ExtractBaseData(data.variableData)
    
    -- 存储到实例变量中供其他方法使用
    self.playerBaseData = baseData
    
    -- 更新奖励按钮状态
    self:UpdateRewardButtons()
    
    -- 更新邀请人数显示
    self:UpdateInvitationCount()

end

--- 从variableData中提取base数据并封装为key-value结构
---@param variableData table 变量数据表
---@return table base数据的key-value结构
function FriendsInvitationGui:ExtractBaseData(variableData)
    local baseData = {}
    
    for variableName, variableInfo in pairs(variableData) do
        if variableInfo and type(variableInfo) == "table" and variableInfo.base then
            baseData[variableName] = variableInfo.base
        end
    end
    
    return baseData
end

--- 获取指定变量的base值
---@param variableName string 变量名称
---@return number|nil base值，如果不存在返回nil
function FriendsInvitationGui:GetBaseValue(variableName)
    if not self.playerBaseData or not variableName then
        return nil
    end
    
    return self.playerBaseData[variableName]
end

--- 通用奖励点击处理
---@param rewardType string 奖励类型
---@param uniqueId string 奖励唯一ID
function FriendsInvitationGui:OnRewardClick(rewardType, uniqueId)
    --gg.log("点击奖励按钮:", rewardType, "UniqueId:", uniqueId)
    
    -- 获取对应的奖励等级配置
    local rewardTier = self.rewardBonusConfig:GetRewardTierById(uniqueId)
    if not rewardTier then
        --gg.log("错误：找不到奖励等级配置:", uniqueId)
        return
    end
    
    -- 准备玩家数据用于条件判断
    local playerData = self:PreparePlayerDataForCondition()
    
    -- 使用RewardBonusType的EvaluateCondition方法判断是否满足条件
    local isConditionMet = self.rewardBonusConfig:EvaluateCondition(
        rewardTier.ConditionFormula, 
        playerData, 
        nil
    )
    
    if not isConditionMet then
        --gg.log("条件不满足:", rewardTier.ConditionFormula, "玩家数据:", playerData)
        -- 可以在这里显示提示信息
        return
    end
    
    -- 发送奖励领取请求到服务端
    gg.network_channel:fireServer({
        cmd = "CLAIM_INVITE_REWARD",
        args = {
            configName = "好友邀请",
            uniqueId = uniqueId,
            rewardType = rewardType
        }
    })
    
    --gg.log("发送奖励领取请求:", uniqueId, "奖励类型:", rewardType)
end


--- 更新奖励按钮状态
function FriendsInvitationGui:UpdateRewardButtons()
    if not self.playerBaseData then
        return
    end
    
    local inviteCount = self:GetBaseValue("数据_固定值_邀请数量") or 0
    --gg.log("当前邀请数量:", inviteCount)
    
    -- 更新各个奖励按钮状态
    self:UpdateSingleRewardButton(self.rewardPet, self.rewardUniqueIds.pet, inviteCount)
    self:UpdateSingleRewardButton(self.rewardCompanion, self.rewardUniqueIds.companion, inviteCount)
    self:UpdateSingleRewardButton(self.rewardTrail, self.rewardUniqueIds.trail, inviteCount)
    self:UpdateSingleRewardButton(self.rewardWings, self.rewardUniqueIds.wings, inviteCount)
end

--- 更新单个奖励按钮状态
---@param button ViewButton 按钮对象
---@param uniqueId string 奖励唯一ID
---@param inviteCount number 当前邀请数量
function FriendsInvitationGui:UpdateSingleRewardButton(button, uniqueId, inviteCount)
    if not button or not uniqueId then
        return
    end
    
    -- 获取对应的奖励等级配置
    local rewardTier = self.rewardBonusConfig:GetRewardTierById(uniqueId)
    if not rewardTier then
        --gg.log("错误：找不到奖励等级配置:", uniqueId)
        button:SetGray(true)
        button:SetTouchEnable(false, nil)
        return
    end
    
    -- 准备玩家数据用于条件判断
    local playerData = self:PreparePlayerDataForCondition()
    
    -- 使用RewardBonusType的EvaluateCondition方法判断是否满足条件
    local canClaim = self.rewardBonusConfig:EvaluateCondition(
        rewardTier.ConditionFormula, 
        playerData, 
        nil
    )
    
    if canClaim then
        button:SetGray(false)
        button:SetTouchEnable(true, nil)
        --gg.log("奖励可领取:", uniqueId, "条件:", rewardTier.ConditionFormula, "玩家数据:", playerData)
    else
        button:SetGray(true)
        button:SetTouchEnable(false, nil)
        --gg.log("奖励不可领取:", uniqueId, "条件:", rewardTier.ConditionFormula, "玩家数据:", playerData)
    end
end

--- 更新邀请人数显示
function FriendsInvitationGui:UpdateInvitationCount()
    if not self.NumberInvitations then
        return
    end
    
    -- 获取邀请数量，如果没有数据则默认为0
    local inviteCount = self:GetBaseValue("数据_固定值_邀请数量") or 0
    
    -- 更新显示文本
    if self.NumberInvitations.node and self.NumberInvitations.node.Title then
        self.NumberInvitations.node.Title = string.format("邀请%d人", inviteCount)
    end
    
    --gg.log("更新邀请人数显示:", inviteCount)
end

--- 准备玩家数据用于条件判断
---@return table 玩家数据表
function FriendsInvitationGui:PreparePlayerDataForCondition()
    local playerData = {}
    
    -- 将base数据转换为RewardBonusType期望的格式
    if self.playerBaseData then
        for variableName, baseValue in pairs(self.playerBaseData) do
            playerData[variableName] = baseValue
        end
    end
    
    -- 确保邀请数量字段存在
    playerData["数据_固定值_邀请数量"] = playerData["数据_固定值_邀请数量"] or 0
    
    return playerData
end

--- 测试条件判断功能

return FriendsInvitationGui.New(script.Parent, uiConfig)
