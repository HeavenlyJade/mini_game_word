local MainStorage = game:GetService("MainStorage")
local CoreUI = game:GetService("CoreUI")


local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local ViewButton = require(MainStorage.Code.Client.UI.ViewButton) ---@type ViewButton
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
---@class GameSystem:ViewBase
local GameSystem = ClassMgr.Class("GameSystem", ViewBase)

local uiConfig = {
    uiName = "GameSystem",
    layer = 0,
    hideOnInit = false,
}

---@param viewButton ViewButton
function GameSystem:RegisterMenuButton(viewButton)
    if not viewButton then return end
    viewButton:SetTouchEnable(true)
    -- 设置新的点击回调
    viewButton.clickCb = function(ui, button)
        gg.log("菜单按钮点击", button.node.Name)
        if button.node.Name == "邮件" then
            GameSystem:onMailClick()
        elseif button.node.Name == "设置" then
            GameSystem:onSettingClick()
        end

    end
end

function GameSystem:OnInit(node, config)
    gg.log("GameSystem 初始化")
    self:RegisterMenuButton(self:Get("邮件", ViewButton))
    self:RegisterMenuButton(self:Get("设置", ViewButton))

    -- 在这里可以添加初始化逻辑
end

--- 处理邮件按钮点击
function GameSystem:onMailClick()
    gg.log("邮件按钮点击")
    ViewBase["MailGui"]:Open()
end

--- 处理设置按钮点击
function GameSystem:onSettingClick()
    gg.log("设置按钮点击")
    CoreUI:ExitGame()
end


return GameSystem.New(script.Parent, uiConfig)
