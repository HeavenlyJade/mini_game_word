local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local AchievementEventConfig = require(MainStorage.Code.Event.AchievementEvent) ---@type AchievementEventConfig

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

local uiConfig = {
    uiName = "Warehouse",
    layer = 3,
    hideOnInit = false,  -- 改为false，让界面在初始化时显示
}

---@class Warehouse:ViewBase
local Warehouse = ClassMgr.Class("Warehouse", ViewBase)

---@override
function Warehouse:OnInit(node, config)
    -- 基础节点获取
    self.backgroundPanel = self:Get("底图", ViewComponent) ---@type ViewComponent
    self.collapseButton = self:Get("底图/收起", ViewButton) ---@type ViewButton
    self.expandButton = self:Get("底图/展开", ViewButton) ---@type ViewButton
    self.bgSection = self:Get("底图/背景", ViewComponent) ---@type ViewComponent
    self.warehouseList = self:Get("底图/背景/仓库", ViewList) ---@type ViewList
    
    -- 仓库下的所有子节点
    self.rebirthSection = self:Get("底图/背景/仓库/重生", ViewButton) ---@type ViewButton
    self.wingsSection = self:Get("底图/背景/仓库/翅膀", ViewButton) ---@type ViewButton
    self.companionSection = self:Get("底图/背景/仓库/伙伴", ViewButton) ---@type ViewButton
    self.petSection = self:Get("底图/背景/仓库/宠物", ViewButton) ---@type ViewButton
    self.trajectorySection = self:Get("底图/背景/仓库/轨迹", ViewButton) ---@type ViewButton
    self.talentSection = self:Get("底图/背景/仓库/天赋", ViewButton) ---@type ViewButton

    -- 数据存储
    self.warehouseData = {} ---@type table 仓库数据
    self.currentCategory = nil ---@type string 当前选中的分类
    self.selectedItem = nil ---@type table 当前选中的物品

    -- 注册事件
    self:RegisterEvents()
    self:RegisterButtonEvents()

    gg.log("Warehouse 仓库界面初始化完成")
end

-- 注册事件监听
function Warehouse:RegisterEvents()
    gg.log("注册仓库系统事件监听")
end

-- 注册按钮事件
function Warehouse:RegisterButtonEvents()
    -- 收起按钮
    self.collapseButton.clickCb = function()
        self.bgSection:SetVisible(false)
        self.expandButton:SetVisible(true)
        self.collapseButton:SetVisible(false)
        gg.log("收起按钮被点击")
    end
    
    -- 展开按钮
    self.expandButton.clickCb = function()
        self.bgSection:SetVisible(true)
        self.collapseButton:SetVisible(true)
        self.expandButton:SetVisible(false)
        gg.log("展开按钮被点击")
    end
    
    -- 重生按钮
    self.rebirthSection.clickCb = function()
        gg.network_channel:fireServer({
            cmd = AchievementEventConfig.REQUEST.GET_TALENT_LEVEL,
            args = { talentId = "重生" }
        })
        ViewBase["RebirthGui"]:Open()
    end
    self.wingsSection.clickCb =function ()
        ViewBase["WingGui"]:Open()
    end
    self.companionSection.clickCb = function ()
        ViewBase["CompanionGui"]:Open()
    end
    self.petSection.clickCb = function ()
        ViewBase["PetGui"]:Open()
    end
    self.trajectorySection.clickCb = function ()
        ViewBase["TrailGui"]:Open()
    end
    self.talentSection.clickCb = function ()
        ViewBase["TalentGui"]:Open()
    end
    gg.log("仓库界面按钮事件注册完成")  
end

-- 打开界面时的操作
function Warehouse:OnOpen()
    gg.log("Warehouse仓库界面打开")
end

-- 关闭界面时的操作
function Warehouse:OnClose()
    gg.log("Warehouse仓库界面关闭")
end

return Warehouse.New(script.Parent, uiConfig)