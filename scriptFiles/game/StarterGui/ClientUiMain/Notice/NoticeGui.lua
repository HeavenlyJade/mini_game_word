-- NoticeGui.lua
-- 获得物品通知界面逻辑

local MainStorage = game:GetService("MainStorage")

-- 引入核心模块
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader

-- 引入UI基类和组件
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewList = require(MainStorage.Code.Client.UI.ViewList) ---@type ViewList
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local CardIcon = require(MainStorage.Code.Common.Icon.card_icon) ---@type CardIcon

-- 引入事件系统
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

-- UI配置
local uiConfig = {
    uiName = "NoticeGui",
    layer = 4,
    hideOnInit = true,
}

---@class NoticeGui : ViewBase
local NoticeGui = ClassMgr.Class("NoticeGui", ViewBase)

---@override
function NoticeGui:OnInit(node, config)
    self.node = node
    -- 1. 节点初始化
    self:InitNodes()
    
    -- 2. 数据存储
    self:InitData()
    
    -- 3. 事件注册
    self:RegisterEvents()
    
    -- 4. 按钮点击事件注册
    self:RegisterButtonEvents()
    
    gg.log("NoticeGui 物品通知界面初始化完成")
end

-- 节点初始化
function NoticeGui:InitNodes()
    -- 主界面
    self.BaseButton = self:Get("黑色底图", ViewButton) ---@type ViewButton
    self.noticePanel = self:Get("通知界面", ViewComponent) ---@type ViewComponent
    self.closeButton = self:Get("通知界面/关闭", ViewButton) ---@type ViewButton
    

    
    -- 通知列表 (ViewList)
    self.noticeList = self:Get("通知界面/物品通知栏位", ViewList) ---@type ViewList
    
    -- 模板节点
    self.noticeTemplate = self:Get("通知界面/模版界面/通知模版", ViewComponent) ---@type ViewComponent
end

-- 数据初始化
function NoticeGui:InitData()
    self.noticeQueue = {} -- 通知队列
    self.maxNoticeCount = 50 -- 最大显示通知数量
    self.noticeDuration = 3 -- 通知显示时长（秒）
    self.isAutoHide = true -- 是否自动隐藏
end

-- 注册客户端事件
function NoticeGui:RegisterEvents()
    gg.log("注册物品通知事件监听")
    ClientEventManager.Subscribe(EventPlayerConfig.NOTIFY.ITEM_ACQUIRED_NOTIFY, function(data)
        self:OnItemAcquiredNotify(data)
    end)
end

-- 注册按钮事件
function NoticeGui:RegisterButtonEvents()
    self.closeButton.clickCb = function()
        
        self:Close()
    end
    self.BaseButton.clickCb = function()
        self:Close()
    end
end

--- 处理获得物品通知
---@param eventData table 通知数据
function NoticeGui:OnItemAcquiredNotify(eventData)
    local data = eventData.data
    gg.log("获得的结果通知",eventData)
    if not eventData or not data.rewards then
        --gg.log("错误：物品通知数据无效")
        return
    end

    self:Open()  
    
    self:DisplayNotice(data)

end



--- 清空通知显示
function NoticeGui:ClearNotices()
    self.noticeList:ClearChildren()
end

--- 显示单个通知
---@param notice table 通知数据
function NoticeGui:DisplayNotice(notice)
    gg.log("DisplayNotice",notice)
    -- 清空现有通知内容
    self:ClearNotices()
    --gg.log("notice",notice)
    -- 循环处理每个物品，为每个物品创建通知项

    for _, reward in ipairs(notice.rewards) do
        --gg.log("奖励类型:", reward.itemType,reward.itemName)
        -- 克隆模板节点
        local clonedNotice = self.noticeTemplate.node:Clone()
    
        -- 设置物品信息
        local itemNode = clonedNotice["背景"]
        local itemConfig = self:GetItemConfigByType(reward.itemType, reward.itemName)
        if itemConfig then
            -- 根据物品品质设置通知背景资源
            if itemConfig.rarity and CardIcon.qualityNoticeIcon[itemConfig.rarity] then
                itemNode.Icon = CardIcon.qualityNoticeIcon[itemConfig.rarity]
            end
            
            -- 设置物品图标
            if itemNode["图标"] then
                if itemConfig.imageResource then
                    itemNode["图标"].Icon = itemConfig.imageResource
                elseif  itemConfig.icon or itemConfig.avatarResource then
                    local iconResource = itemConfig.icon or itemConfig.avatarResource
                    if CardIcon.itemIconResources[iconResource] then
                        itemNode["图标"].Icon = CardIcon.itemIconResources[iconResource]
                    else
                        itemNode["图标"].Icon = iconResource -- 直接使用资源路径
                    end
                end
            end
            
            -- 设置物品名称
            if itemNode["名称"] then
                itemNode["名称"].Title = itemConfig.name or reward.itemName
            end
            
            -- 设置物品数量
            if reward.amount and reward.amount > 1 then
                if itemNode["数量"] then
                    itemNode["数量"].Title = "x" .. gg.FormatLargeNumber(reward.amount)
                end
            end
        end

        -- 使用ViewList的AppendChild方法添加到通知内容区域
        self.noticeList:AppendChild(clonedNotice)
        
    end

    
    -- 显示界面
    self:SetVisible(true)
end

--- 根据物品类型和名称获取配置数据
---@param itemType string 物品类型：宠物、伙伴、翅膀、尾迹、物品
---@param itemName string 物品名称
---@return table|nil 物品配置数据
function NoticeGui:GetItemConfigByType(itemType, itemName)
    if not itemType or not itemName then
        return nil
    end
    
    -- 根据物品类型调用对应的ConfigLoader方法
    if itemType == "宠物" then
        return ConfigLoader.GetPet(itemName)
    elseif itemType == "伙伴" then
        return ConfigLoader.GetPartner(itemName)
    elseif itemType == "翅膀" then
        return ConfigLoader.GetWing(itemName)
    elseif itemType == "尾迹" then
        return ConfigLoader.GetTrail(itemName)
    elseif itemType == "物品" then
        return ConfigLoader.GetItem(itemName)
    else
        gg.log("警告：未知的物品类型", itemType, itemName)
        return nil
    end
end


--- 自动隐藏通知
function NoticeGui:AutoHide()
    if self.isAutoHide then
        self:SetVisible(false)
    end
end

--- UI打开时调用
function NoticeGui:OnOpen()
    gg.log("NoticeGui 打开")
    -- 可以在这里刷新通知数据
end

--- UI关闭时调用
function NoticeGui:OnClose()
    gg.log("NoticeGui 关闭")
    -- 取消自动隐藏任务
    if self.autoHideTask then
        self.autoHideTask:Cancel()
        self.autoHideTask = nil
    end
end


return NoticeGui.New(script.Parent, uiConfig)
