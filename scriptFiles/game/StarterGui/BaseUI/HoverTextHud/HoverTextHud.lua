
local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewBase = require(MainStorage.Code.Client.UI.ViewBase) ---@type ViewBase
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local ClientScheduler = require(MainStorage.Code.Client.ClientScheduler) ---@type ClientScheduler
---@class TextInfo
---@field node UITextLabel
---@field fadeTimer number
---@field fadeDuration number
---@field fadeOutDuration number
---@field targetY number
---@field updateTaskId number

---@class HoverTextHud:ViewBase
local HoverTextHud = ClassMgr.Class("HoverTextHud", ViewBase)

local uiConfig = {
    uiName = "HoverTextHud",
    layer = 999,  -- 设置为最高层级，确保始终在最顶层显示
    hideOnInit = false,
    closeHuds = false,
    mouseVisible = false,  -- 悬浮文本不需要鼠标交互
    closeHideMouse = false  -- 关闭时不影响鼠标状态
}

function HoverTextHud:OnInit(node, config)
    self.textPool = {} ---@type TextInfo[]
    self.activeTexts = {} ---@type TextInfo[]
    self.template = self:Get("文本").node ---@type UITextLabel
    self.template.Visible = false
    
    -- 设置模板的渲染层级
    if self.template.RenderIndex then
        self.template.RenderIndex = 9999
    end
    
    -- 计算初始位置
    self.initialY = self.template.Position.y
    self.textSpacing = 40 -- 文本之间的间距
    
    -- 监听服务端发送的悬浮文本事件
    ClientEventManager.Subscribe("SendHoverText", function(evt)
        self:ShowText(evt.txt)
    end)
end

function HoverTextHud:GetTextFromPool()
    -- 尝试从对象池中获取一个文本对象
    local textInfo = table.remove(self.textPool)
    
    -- 如果没有可用的对象，创建一个新的
    if not textInfo then
        local newNode = self.template:Clone()
        newNode:SetParent(self.template.Parent)
        
        -- 确保新节点也有最高的渲染层级
        if newNode.RenderIndex then
            newNode.RenderIndex = 9999
        end
        
        textInfo = {
            node = newNode,
            fadeTimer = 0,
            fadeDuration = 2,
            fadeOutDuration = 0.5,
            targetY = 0,
            updateTaskId = 0
        }
    end
    
    -- 重置状态
    textInfo.fadeTimer = 0
    textInfo.node.Visible = true
    textInfo.node.TitleColor = ColorQuad.New(255, 255, 255, 255)
    
    -- 添加到活动列表
    table.insert(self.activeTexts, textInfo)
    
    -- 注册更新任务
    textInfo.updateTaskId = ClientScheduler.add(function()
        self:UpdateText(textInfo)
    end, 0, 0.06) -- 每帧更新一次
    
    return textInfo
end

function HoverTextHud:ReturnTextToPool(textInfo)
    -- 取消更新任务
    if textInfo.updateTaskId > 0 then
        ClientScheduler.cancel(textInfo.updateTaskId)
        textInfo.updateTaskId = 0
    end
    
    -- 从活动列表中移除
    for i, activeText in ipairs(self.activeTexts) do
        if activeText == textInfo then
            table.remove(self.activeTexts, i)
            break
        end
    end
    
    -- 重置并返回对象池
    textInfo.node.Visible = false
    table.insert(self.textPool, textInfo)
end

function HoverTextHud:UpdateText(textInfo)
    -- 更新淡出计时器
    textInfo.fadeTimer = textInfo.fadeTimer + 0.06
    
    -- 如果超过显示时间，开始淡出
    if textInfo.fadeTimer >= textInfo.fadeDuration then
        local fadeProgress = (textInfo.fadeTimer - textInfo.fadeDuration) / textInfo.fadeOutDuration
        if fadeProgress >= 1 then
            -- 完全淡出后返回对象池
            self:ReturnTextToPool(textInfo)
            return
        end
        
        -- 设置透明度
        local alpha = math.floor(255 * (1 - fadeProgress))
        textInfo.node.TitleColor = ColorQuad.New(255, 255, 255, alpha)
    end
    
    -- 更新位置
    local index = 0
    for i, activeText in ipairs(self.activeTexts) do
        if activeText == textInfo then
            index = i
            break
        end
    end
    
    if index > 0 then
        local targetY = self.initialY - (index - 1) * self.textSpacing
        textInfo.targetY = targetY
        
        -- 平滑移动到目标位置
        local currentPos = textInfo.node.Position
        local newY = currentPos.y + (targetY - currentPos.y) * 0.2 -- 使用缓动效果
        textInfo.node.Position = Vector2.New(currentPos.x, newY)
    end
end

function HoverTextHud:ShowText(text)
    local textInfo = self:GetTextFromPool()
    
    -- 设置文本
    textInfo.node.Title = text
    -- 显示UI
    self:Open()
end

function HoverTextHud:Update()
    -- 如果没有活动文本，关闭UI
    if #self.activeTexts == 0 then
        self:Close()
    end
end

-- 重写Open方法，避免影响其他UI的层级管理
function HoverTextHud:Open()
    if self.displaying then
        return
    end
    self.displaying = true
    self:SetVisible(true)
    
    -- 设置UI节点的渲染层级为最高层
    if self.node and self.node.RenderIndex then
        self.node.RenderIndex = 9999
        --gg.log("HoverTextHud: 设置渲染层级为最高层 RenderIndex=9999")
    end
    
    --gg.log("HoverTextHud: 悬浮文本显示，当前layer=" .. self.layer)
    -- 不调用父类的层级管理逻辑，直接显示
end

-- 重写Close方法，避免影响其他UI的层级管理
function HoverTextHud:Close()
    self:SetVisible(false)
    if not self.displaying then
        return
    end
    self.displaying = false
    -- 不调用父类的层级管理逻辑，直接隐藏
end

return HoverTextHud.New(script.Parent, uiConfig)
