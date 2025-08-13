local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CommonEventConfig = require(MainStorage.Code.Event.CommonEvent) ---@type CommonEventConfig
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
	uiName = "WaypointGui",
	layer = 3,
	hideOnInit = true,
}

---@class WaypointGui:ViewBase
local WaypointGui = ClassMgr.Class("WaypointGui", ViewBase)

---@override
function WaypointGui:OnInit(node, config)
	-- 面板与按钮
	self.panel = self:Get("黑色底图", ViewComponent) ---@type ViewComponent
	self.closeButton = self:Get("传送底图/关闭", ViewButton) ---@type ViewButton

	-- 传送点列表（使用ViewList克隆生成）
	self.waypointList = self:Get("传送底图/传送界面栏位", ViewList) ---@type ViewList

	-- 数据缓存
	self.teleportPoints = {} ---@type TeleportPointType[]

	-- 事件与按钮
	self:RegisterButtonEvents()
	self:RegisterEvents()

	-- 初始化填充
	self:LoadTeleportPoints()
end

function WaypointGui:RegisterButtonEvents()
	if self.closeButton then
		self.closeButton.clickCb = function()
			self:Close()
		end
	end
end

-- 事件注册：接收服务端 OpenUI 指令
function WaypointGui:RegisterEvents()
    -- 新事件：服务端指令 OpenWaypointGui
    ClientEventManager.Subscribe("OpenWaypointGui", function(data)
        if not data then return end
        if data.operation == "打开界面" then
            self:Open()
        elseif data.operation == "关闭界面" then
            self:Close()
        end
    end)
end

function WaypointGui:OnOpen()
	self:Open()
end

-- 载入所有传送点并排序
function WaypointGui:LoadTeleportPoints()
	self.teleportPoints = {}
	local all = ConfigLoader.GetAllTeleportPoints()
	for _, tp in pairs(all) do
		self.teleportPoints[#self.teleportPoints + 1] = tp
	end
	-- 仅按权重(小到大)排序
	table.sort(self.teleportPoints, function(a, b)
		return (a:GetWeight() or 1) < (b:GetWeight() or 1)
	end)
	self:RefreshList()

end

-- 刷新列表：使用 SetElementSize 克隆生成条目
function WaypointGui:RefreshList()
	if not self.waypointList then return end
	local size = #self.teleportPoints
	self.waypointList:SetElementSize(size)

	for i = 1, size do
		local tp = self.teleportPoints[i]
		local itemComp = self.waypointList:GetChild(i) ---@type ViewComponent
		if itemComp and itemComp.node then
			-- 图标
			local iconNode = itemComp.node
			gg.log("iconNode",iconNode,tp:GetIconPath(),tp:GetRequiredLevel())
			if iconNode then
				iconNode.Icon = tp:GetIconPath()
			end
		
            local levelNode = itemComp.node["等级"]
            if levelNode then
                levelNode.Title = ""..tp:GetRequiredLevel()
            end
			-- 灰显未解锁
			itemComp:SetGray(true)

			-- 点击事件（将条目包装为按钮以获得点击回调）
			local itemBtn = ViewButton.New(itemComp.node, self, itemComp.path)
			-- 设置按钮悬浮/点击图标
			local hoverImg = tp:GetIconPath()
			itemBtn:UpdateMainNodeState({ hoverImg = hoverImg, clickImg = hoverImg })
			itemBtn.clickCb = function()
				self:OnClickTeleport(tp)
			end
		end
	end
end

-- 点击传送：发送服务器请求，包含节点路径和名称
function WaypointGui:OnClickTeleport(tp)
	gg.log("传送点击",tp)
	if not tp then return end
	local requestData = {
        cmd = CommonEventConfig.REQUEST.TELEPORT_TO,
		args = {
			nodePath = tp:GetNodePath(),
			pointName = tp:GetDisplayName(),
			cost = tp:GetCost(),
		}
	}
	gg.network_channel:fireServer(requestData)
	-- 可选：立即关闭界面
	self:Close()
end

return WaypointGui.New(script.Parent, uiConfig)