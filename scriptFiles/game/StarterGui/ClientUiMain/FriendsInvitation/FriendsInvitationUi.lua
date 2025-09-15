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
	self:InitNodes()

	-- 2. 注册事件监听
	self:RegisterEvents()

	-- 3. 初始化数据
	self.friendsData = {
		friendsList = {},
		onlineCount = 0,
		totalCount = 0
	}
	
	-- 4. 获取本地玩家和好友信息
	self:LoadLocalPlayerAndFriends()
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
	self.rewardWings = self:Get("好友界面/奖励翅膀/领取", ViewButton) ---@type ViewButton
	self.rewardTrail = self:Get("好友界面/奖励尾迹/领取", ViewButton) ---@type ViewButton
	self.rewardCompanion = self:Get("好友界面/奖励伙伴/领取", ViewButton) ---@type ViewButton
	self.rewardPet = self:Get("好友界面/奖励宠物/领取", ViewButton) ---@type ViewButton
	self.rewardWings:SetTouchEnable(false, nil)
	self.rewardTrail:SetTouchEnable(false, nil)
	self.rewardCompanion:SetTouchEnable(false, nil)
	self.rewardPet:SetTouchEnable(false, nil)
	self.rewardWings.clickCb = function(ui, button)
		self:OnRewardWingsClick()
	end
	self.rewardTrail.clickCb = function(ui, button)
		self:OnRewardTrailClick()
	end
	self.rewardCompanion.clickCb = function(ui, button)
		self:OnRewardCompanionClick()
	end
	self.rewardPet.clickCb = function(ui, button)
		self:OnRewardPetClick()
	end
	
end

-- 注册事件监听
function FriendsInvitationGui:RegisterEvents()
	-- 事件监听逻辑（待实现）
end



return FriendsInvitationGui.New(script.Parent, uiConfig)
