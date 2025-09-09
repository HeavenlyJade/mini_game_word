-- FriendsUi.lua
-- 好友界面逻辑

local MainStorage = game:GetService("MainStorage")
local CoreUI = game:GetService("CoreUI")
local Players = game:GetService("Players")

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
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent

-- UI配置
local uiConfig = {
	uiName = "FriendsUi",
	layer = 1,
	hideOnInit = true,
}

---@class FriendsUi : ViewBase
local FriendsUi = ClassMgr.Class("FriendsUi", ViewBase)

---@override
function FriendsUi:OnInit(node, config)
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
function FriendsUi:InitNodes()
	-- 初始化数据结构
	self.friendComponents = {}
	self.friendItemComponents = {} ---@type ViewComponent[]
end

-- 注册事件监听
function FriendsUi:RegisterEvents()
	-- 事件监听逻辑（待实现）
end

-- 加载本地玩家和好友信息
function FriendsUi:LoadLocalPlayerAndFriends()
	-- 获取本地玩家
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		gg.log("错误：无法获取本地玩家")
		return
	end
	
	local playerUin = localPlayer.UserId
	gg.log("当前本地玩家UIN: " .. tostring(playerUin))
	
	-- 获取好友总数
	local totalFriends = MiniApiFriendsService.GetSize()
	gg.log("好友总数: " .. tostring(totalFriends))
	
	-- 获取在线好友数量
	local onlineFriends = MiniApiFriendsService.GetOnlineFriendsCount()
	gg.log("在线好友数量: " .. tostring(onlineFriends))
	
	-- 获取所有好友信息
	local allFriends = MiniApiFriendsService.GetAllFriends()
	gg.log("获取到的好友列表数量: " .. tostring(#allFriends))
	
	-- 使用gg.log打印allFriends的详细信息
	gg.log("=== allFriends 详细信息 ===")
	gg.print_table(allFriends, "allFriends")
	
	-- 更新内部数据
	self.friendsData = {
		friendsList = allFriends,
		onlineCount = onlineFriends,
		totalCount = totalFriends
	}
	
	-- 打印所有好友信息
	self:PrintAllFriendsInfo()
end

-- 打印所有好友信息
function FriendsUi:PrintAllFriendsInfo()
	gg.log("=== 好友信息列表 ===")
	
	if not self.friendsData.friendsList or #self.friendsData.friendsList == 0 then
		gg.log("没有好友")
		return
	end
	
	for i, friend in ipairs(self.friendsData.friendsList) do
		local status = friend.onLine and "在线" or "离线"
		gg.log(string.format("好友 %d: UIN=%d, 昵称=%s, 状态=%s", 
			i, friend.uin, friend.nickName, status))
	end
	
	gg.log("=== 统计信息 ===")
	gg.log("总好友数: " .. self.friendsData.totalCount)
	gg.log("在线好友数: " .. self.friendsData.onlineCount)
end


return FriendsUi.New(script.Parent, uiConfig)
