local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local CommonEventConfig = require(MainStorage.Code.Event.CommonEvent) ---@type CommonEventConfig
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
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

	-- 【修改】玩家变量数据缓存，替代等级和经验
	self.playerVariableData = {}

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
    
    -- 【修改】使用变量同步事件替代等级经验事件
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, function(data)
        self:OnPlayerVariableSync(data)
    end)
end

-- 【修改】处理玩家变量数据同步
function WaypointGui:OnPlayerVariableSync(data)
    --gg.log("WaypointGui收到玩家变量数据同步:", data)
    if not data or not data.variableData then
        return
    end
    
    -- 更新玩家变量数据缓存
    if not self.playerVariableData then
        self.playerVariableData = {}
    end
    
    -- 合并新数据到现有缓存中
    for variableName, variableData in pairs(data.variableData) do
        self.playerVariableData[variableName] = variableData
        
        -- 【调试】输出科学计数法变量的详细信息
        if variableName == "数据_固定值_历史最大战力值" and variableData and variableData.base then
            --gg.log("科学计数法变量详情:", variableName)
            --gg.log("  原始值:", variableData.base, "类型:", type(variableData.base))
            if type(variableData.base) == "number" then
                --gg.log("  数字格式化:", string.format("%.0f", variableData.base))
            elseif type(variableData.base) == "string" then
                local numValue = tonumber(variableData.base)
                --gg.log("  字符串转数字:", numValue)
            end
        end
    end
    
    -- 刷新传送点列表，因为变量变化可能影响解锁状态
    self:RefreshList()
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

-- 【修改】获取指定变量的值
function WaypointGui:GetVariableValue(variableName)
    if not self.playerVariableData then
        return 0
    end
    
    local varData = self.playerVariableData[variableName]
    return (varData and varData.base) or 0
end

function WaypointGui:GetPlayerData()
    local re_data = {}
    for k,v in pairs(self.playerVariableData) do
        re_data[k] = v.base
    end
    return re_data
end

-- 【修改】检查传送点是否解锁（基于变量条件）
function WaypointGui:IsTeleportPointUnlocked(tp)
    if not tp then return false end
    
    -- 检查基础解锁状态
    if not tp:IsUnlocked() then
        return false
    end
    
    -- 检查变量表达公式 - 使用传送点的内置检查方法
    local variableFormula = tp:GetVariableFormula()
    if variableFormula and variableFormula ~= '' then
        -- 构造正确的数据结构，ActionCosteRewardCal期望有variableData字段
        local playerDataForCheck = self:GetPlayerData()
        
        -- 使用传送点的变量条件检查方法，传入格式化后的玩家变量数据
        local canUse, message = tp:CheckVariableCondition(playerDataForCheck)
        -- gg.log("传送点条件检查:", tp:GetDisplayName(), "公式:", variableFormula, "结果:", canUse, "消息:", message)
        if not canUse then
            return false
        end
    end
    
    return true
end

-- 【修改】刷新列表：使用 SetElementSize 克隆生成条目
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
            if iconNode then
                iconNode.Icon = tp:GetIconPath()
            end
        
            -- 【修改】显示需求条件而不是等级
            local levelNode = itemComp.node["等级"]
            if levelNode then
                local requiredCondition = tp:GetRequiredCondition()
                if requiredCondition > 0 then
                    levelNode.Title = "需求: " .. gg.FormatLargeNumber(requiredCondition)
                else
                    levelNode.Title = "无限制"
                end
            end
            
            -- 【修改】根据变量条件判断是否解锁传送点
            local isUnlocked = self:IsTeleportPointUnlocked(tp)
            
            -- 灰显未解锁
            itemComp:SetGray(not isUnlocked)
            
            -- 点击事件（将条目包装为按钮以获得点击回调）
            local itemBtn = ViewButton.New(itemComp.node, self, itemComp.path)
            -- 设置按钮悬浮/点击图标
            local hoverImg = tp:GetIconPath()
            itemBtn:UpdateMainNodeState({ hoverImg = hoverImg, clickImg = hoverImg })
            
            -- 【修改】根据解锁状态设置按钮的可点击状态
            if isUnlocked then
                itemBtn:SetTouchEnable(true, false) -- 启用触摸，不更新灰显状态
            else
                itemBtn:SetTouchEnable(false, false) -- 禁用触摸，不更新灰显状态
            end
            
            itemBtn.clickCb = function()
                self:OnClickTeleport(tp)
            end
        end
    end
end

-- 【修改】点击传送：发送服务器请求，包含节点路径和名称
function WaypointGui:OnClickTeleport(tp)
    --gg.log("传送点击", tp)
    if not tp then return end
    
    -- 【修改】使用变量条件检查，如果条件不满足则阻止传送
    if not self:IsTeleportPointUnlocked(tp) then
        --gg.log("传送点未解锁，无法传送")
        return 
    end
    
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

-- 【修改】获取玩家指定变量的值
function WaypointGui:GetPlayerVariable(variableName)
    return self:GetVariableValue(variableName)
end

return WaypointGui.New(script.Parent, uiConfig)