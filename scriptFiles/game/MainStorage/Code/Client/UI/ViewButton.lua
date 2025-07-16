local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
---@class ViewButton:ViewComponent
---@field New fun(node: SandboxNode, ui: ViewBase, path?: string, realButtonPath?: string): ViewButton
local  ViewButton = ClassMgr.Class("ViewButton", ViewComponent)
local ButtonState = {
    IDLE = 'IDLE',     -- 空闲
    HOVER = 'HOVER',   -- 悬浮
    PRESSED = 'PRESSED' -- 按下
}

---@param node UIComponent
---@param key string
---@return string|any
function ViewButton:_getAttribute(node, key)
    if node then
        local value = node:GetAttribute(key)
        if value and value ~= "" then
            return value
        end
    end
    return nil
end

---@param node UIComponent
---@param state 'hover'|'click'
---@return string|nil
function ViewButton:_getImgForState(node, state)
    if state == 'click' then
        return self:_getAttribute(node, '图片-点击')
    elseif state == 'hover' then
        -- Fallback logic: hover -> click
        return self:_getAttribute(node, '图片-悬浮') or self:_getAttribute(node, '图片-点击')
    end
    return nil
end

---@param node UIComponent
---@param state 'hover'|'click'
---@return ColorQuad|nil
function ViewButton:_getColorForState(node, state)
    if state == 'click' then
        return self:_getAttribute(node, '点击颜色')
    elseif state == 'hover' then
        return self:_getAttribute(node, '悬浮颜色')
    end
    return nil
end

---@param enable boolean
---@param updateGray? boolean
function ViewButton:SetTouchEnable(enable, updateGray)
    self.enabled = enable
    if updateGray == nil then
        self:SetGray(not enable)
    end
end

---@param path2Child string
---@param icon string
---@param hoverIcon? string
function ViewButton:SetChildIcon(path2Child, icon, hoverIcon)
    hoverIcon = hoverIcon or icon
    local component = self:Get(path2Child)
    if component then
        local childNode = component.node
        local props = self.childClickImgs[path2Child]
        if props then
            props.normalImg = icon
        end
        childNode.Icon = icon
        -- 直接设置节点属性，作为新的状态来源
        childNode:SetAttribute("图片-悬浮", hoverIcon)
        childNode:SetAttribute("图片-点击", hoverIcon)
    end
end

function ViewButton:SetGray(isGray)
    self.img.Grayed = isGray
    -- for _, props in pairs(self.childClickImgs) do
    --     local child = props.node
    --     child.Grayed= isGray
    -- end
end

--- 集中处理状态变化的视觉和音效
---@param newState string 新状态 (来自 ButtonState)
function ViewButton:_changeState(newState)
    if self.state == newState then return end
    self.state = newState

    -- 更新主按钮
    if self.state == ButtonState.IDLE then
        self.img.Icon = self.normalImg
        self.img.FillColor = self.normalColor
    elseif self.state == ButtonState.HOVER then
        local hoverImg = self:_getImgForState(self.img, 'hover')
        self.img.Icon = hoverImg or self.normalImg
        local hoverColor = self:_getColorForState(self.img, 'hover')
        self.img.FillColor = hoverColor or self.normalColor
        local soundHover = self:_getAttribute(self.img, "音效-悬浮")
        if soundHover then ClientEventManager.Publish("PlaySound", { soundAssetId = soundHover }) end
    elseif self.state == ButtonState.PRESSED then
        local clickImg = self:_getImgForState(self.img, 'click')
        self.img.Icon = clickImg or self.normalImg
        local clickColor = self:_getColorForState(self.img, 'click')
        self.img.FillColor = clickColor or self.normalColor
        local soundPress = self:_getAttribute(self.img, "音效-点击")
        if soundPress then ClientEventManager.Publish("PlaySound", { soundAssetId = soundPress }) end
    end

    -- 更新子节点
    for _, props in pairs(self.childClickImgs) do
        local child = props.node
        if self.state == ButtonState.IDLE then
            child.Icon = props.normalImg
            child.FillColor = props.normalColor
        elseif self.state == ButtonState.HOVER then
            local childHoverImg = self:_getImgForState(child, 'hover')
            child.Icon = childHoverImg or props.normalImg
            local childHoverColor = self:_getColorForState(child, 'hover')
            child.FillColor = childHoverColor or props.normalColor
        elseif self.state == ButtonState.PRESSED then
            local childClickImg = self:_getImgForState(child, 'click')
            child.Icon = childClickImg or props.normalImg
            local childClickColor = self:_getColorForState(child, 'click')
            child.FillColor = childClickColor or props.normalColor
        end
    end
end

function ViewButton:OnTouchOut()
    local currentTime = gg.GetTimeStamp()
    if currentTime - self.lastTouchOutTime < 0.1 then return end
    self.lastTouchOutTime = currentTime
    if not self.enabled then return end
    if self.state ~= ButtonState.PRESSED then return end

    local soundRelease = self:_getAttribute(self.img, "音效-抬起")
    if soundRelease then
        ClientEventManager.Publish("PlaySound", {
            soundAssetId = soundRelease
        })
    end

    -- 判断抬起时是否还在按钮上
    local isHover = self.node:IsRollOver()
    if isHover then
        -- 触发点击事件
        self:OnClick()
        -- 状态转换到悬浮
        self:_changeState(ButtonState.HOVER)
    else
        -- 状态直接转换到空闲
        self:_changeState(ButtonState.IDLE)
    end

    if self.touchEndCb then
        self.touchEndCb(self.ui, self)
    end
end

function ViewButton:OnTouchIn(vector2)
    local currentTime = gg.GetTimeStamp()
    if currentTime - self.lastTouchInTime < 0.1 then return end
    self.lastTouchInTime = currentTime

    if not self.enabled then
        return
    end

    self:_changeState(ButtonState.PRESSED)

    if self.enabled then
        ClientEventManager.Publish("ButtonTouchIn", {
            button = self
        })
    end
    if self.touchBeginCb then
        self.touchBeginCb(self.ui, self, vector2)
    end
end

function ViewButton:OnTouchMove(node, isTouchMove, vector2, int)
    if not self.enabled then return end
    if self.touchMoveCb then
        self.touchMoveCb(self.ui, self, vector2)
    end
end

function ViewButton:OnHoverOut()
    if self.state == ButtonState.PRESSED then return end
    self.isHover = false
    self:_changeState(ButtonState.IDLE)
end

function ViewButton:OnHoverIn(vector2)
    if self.state == ButtonState.PRESSED then return end
    if not self.enabled then return end
    self.isHover = true
    self:_changeState(ButtonState.HOVER)
end

function ViewButton:OnClick(vector2)
    if not self.enabled then return end
    if self.clickCb then
        self.clickCb(self.ui, self)
    end
    ClientEventManager.Publish("ButtonClicked", {
        button = self
    })
end

--- 重新从节点属性中加载按钮的状态（例如图片和颜色）
-- 当节点的属性被外部代码更改后，调用此方法来同步ViewButton的内部缓存
function ViewButton:ReloadStateFromNode()
    -- 此函数在重构后不再需要，因为状态会实时从节点获取
    -- 保留为空函数以兼容旧代码调用，避免出错
    if not self.img then return end
    self.normalImg = self.img.Icon
    self.normalColor = self.img.FillColor
    for _, props in pairs(self.childClickImgs) do
        props.normalImg = props.node.Icon
        props.normalColor = props.node.FillColor
    end
end

-- 初始化按钮基本属性
---@param img UIImage 按钮图片组件
function ViewButton:InitButtonProperties(img)
    img.ClickPass = false
    self.clickCb = nil ---@type fun(ui:ViewBase, button:ViewButton)
    self.touchBeginCb = nil ---@type fun(ui:ViewBase, button:ViewButton, pos:Vector2)
    self.touchMoveCb = nil ---@type fun(ui:ViewBase, button:ViewButton, pos:Vector2)
    self.touchEndCb = nil ---@type fun(ui:ViewBase, button:ViewButton, pos:Vector2)

    -- 只缓存节点的初始图和颜色，作为恢复时的基准
    self.normalImg = img.Icon
    self.normalColor = img.FillColor

    img.RollOver:Connect(function(node, isOver, vector2)
        self:OnHoverIn(vector2)
    end)

    img.RollOut:Connect(function(node, isOver, vector2)
        self:OnHoverOut()
    end)
    self:_BindNodeAndChild(img, false, true)
end

function ViewButton:_BindNodeAndChild(child, isDeep, bindEvents)
    if child:IsA("UIImage") then
        if isDeep then
            -- 简化子节点缓存，只存储节点引用和初始状态
            self.childClickImgs[child.Name] = {
                node = child,
                normalImg = child.Icon,
                normalColor = child.FillColor,
            }
        end
        if bindEvents then
            child.TouchBegin:Connect(function(node, isTouchBegin, vector2, number)
                print("TouchBegin", self.path)
                self:OnTouchIn(vector2)
            end)
            child.TouchEnd:Connect(function(node, isTouchEnd, vector2, number)
                print("TouchEnd", self.path)
                self:OnTouchOut()
            end)
            child.TouchMove:Connect(function(node, isTouchMove, vector2, number)
                self:OnTouchMove(node, isTouchMove, vector2, number)
            end)
            child.Click:Connect(function(node, isClick, vector2, number)
                print("click", self.path)
                self:OnClick(vector2)
            end)
        end
    end
    for _, c in ipairs(child.Children) do ---@type UIComponent
        if c:GetAttribute("继承按钮") then
            self:_BindNodeAndChild(c, true, true)
        end
    end
end

function ViewButton:OnInit(node, ui, path, realButtonPath)
    self.childClickImgs = {} ---@type table<string, table>
    self.enabled = true
    self.lastTouchInTime = 0  -- 防抖：记录上次TouchIn时间
    self.lastTouchOutTime = 0 -- 防抖：记录上次TouchOut时间
    self.state = ButtonState.IDLE
    
    -- 正确设置 self.node（ViewComponent基类需要）
    self.node = node
    
    self.img = node ---@type UIImage
    if realButtonPath then
        self.img = self.img[realButtonPath]
    end
    local img = self.img

    self:InitButtonProperties(img)

    if img["pc_hint"] then
        img["pc_hint"].Visible = game.RunService:IsPC()
    end

    self.isHover = false
end

-- === 新增：重新绑定到新的UI节点 ===
-- 用于在按钮复用时重新绑定到新的UI节点，重新设置所有事件监听器和属性
---@param newNode UIComponent 新的UI节点
---@param realButtonPath? string 真实按钮路径（与初始化时相同）
function ViewButton:RebindToNewNode(newNode, realButtonPath)
    if not newNode then return end

    -- 清理旧的childClickImgs（避免内存泄漏）
    self.childClickImgs = {}

    -- 更新节点引用
    self.node = newNode ---@type UIImage
    local oldImg = self.img
    self.img = newNode ---@type UIImage
    if realButtonPath then
        self.img = self.img[realButtonPath]
    end

    local img = self.img
    if not img then
        return
    end

    self:InitButtonProperties(img)
end

-- === 新增：更新子节点的图标缓存 ===
---@param childName string 子节点名称
---@param normalImg string|nil 默认图标
---@param hoverImg string|nil 悬浮图标
---@param clickImg string|nil 点击图标
function ViewButton:UpdateChildImageCache(childName, normalImg, hoverImg, clickImg)
    if not self.childClickImgs or not self.childClickImgs[childName] then
        return false
    end

    local childProps = self.childClickImgs[childName]
    local childNode = childProps.node

    -- 更新节点的UI属性
    if normalImg then
        childNode.Icon = normalImg
        childProps.normalImg = normalImg -- 更新基准状态
    end
    if hoverImg then
        childNode:SetAttribute("图片-悬浮", hoverImg)
    end
    if clickImg then
        childNode:SetAttribute("图片-点击", clickImg)
    end

    return true
end

-- === 新增：批量更新子节点的UI属性和缓存 ===
---@param childName string 子节点名称
---@param normalImg string|nil 默认图标
---@param hoverImg string|nil 悬浮图标（如果为nil，使用normalImg）
---@param clickImg string|nil 点击图标
---@param updateNodeAttributes boolean|nil 是否同时更新节点的UI属性，默认true
function ViewButton:UpdateChildFullState(childName, normalImg, hoverImg, clickImg, updateNodeAttributes)
    if updateNodeAttributes == nil then
        updateNodeAttributes = true
    end

    -- 如果没有指定悬浮图标，使用默认图标
    if not hoverImg and normalImg then
        hoverImg = normalImg
    end

    -- 更新节点的UI属性
    if updateNodeAttributes and self.node and self.node[childName] then
        local childNode = self.node[childName]

        if normalImg then
            childNode.Icon = normalImg
        end
        if hoverImg then
            childNode:SetAttribute("图片-悬浮", hoverImg)
        end
        if clickImg then
            childNode:SetAttribute("图片-点击", clickImg)
        end
    end

    -- 更新ViewButton的缓存
    return self:UpdateChildImageCache(childName, normalImg, hoverImg, clickImg)
end

-- === 新增：更新主节点的UI属性和缓存 ===
---@param config table 配置表 {normalImg, hoverImg, clickImg, normalColor, hoverColor, clickColor}
function ViewButton:UpdateMainNodeState(config)
    if not self.img then
        return false
    end

    if not config or type(config) ~= "table" then
        return false
    end

    -- 提取配置表中的临时变量
    local normalImg = config.normalImg
    local hoverImg = config.hoverImg
    local clickImg = config.clickImg
    local normalColor = config.normalColor
    local hoverColor = config.hoverColor
    local clickColor = config.clickColor

    -- 如果没有指定悬浮图标，使用默认图标
    if not hoverImg and normalImg then
        hoverImg = normalImg
    end

    -- 更新节点的UI属性
    if normalImg then
        self.img.Icon = normalImg
    end
    if hoverImg then
        self.img:SetAttribute("图片-悬浮", hoverImg)
    end
    if clickImg then
        self.img:SetAttribute("图片-点击", clickImg)
    end

    -- 更新颜色属性
    if normalColor then
        self.img.FillColor = normalColor
    end
    if hoverColor then
        self.img:SetAttribute("悬浮颜色", hoverColor)
    end
    if clickColor then
        self.img:SetAttribute("点击颜色", clickColor)
    end

    -- 同时更新ViewButton的基准属性
    if normalImg then
        self.normalImg = normalImg
    end
    if normalColor then
        self.normalColor = normalColor
    end

    return true
end

-- === 新增：销毁按钮，清理所有引用和事件绑定 ===
function ViewButton:Destroy()
    -- === 关键：销毁UI节点，自动清理所有事件绑定和子节点 ===
    if self.node then
        self.node:Destroy()
    end

    -- 清理回调函数引用
    self.clickCb = nil
    self.touchBeginCb = nil
    self.touchMoveCb = nil
    self.touchEndCb = nil

    -- 清理图像引用
    self.img = nil
    self.normalImg = nil
    self.normalColor = nil

    -- 清理子图像字典
    if self.childClickImgs then
        for child, _ in pairs(self.childClickImgs) do
            self.childClickImgs[child.Name] = nil
        end
        self.childClickImgs = {}
    end

    -- 清理ViewComponent的基础属性
    self.node = nil
    self.ui = nil
    self.path = nil
    self.extraParams = nil
    self.enabled = nil
    self.isHover = nil
end

--- 新增：设置主按钮或子节点的自定义属性
---@param key string 属性的键
---@param value any 属性的值
---@param childName? string|nil (可选) 如果要设置子节点，则提供子节点名称
function ViewButton:SetAttribute(key, value, childName)
    local targetNode
    if childName then
        -- 优先从缓存的联动子节点中查找
        if self.childClickImgs and self.childClickImgs[childName] then
            targetNode = self.childClickImgs[childName].node
        elseif self.node and self.node[childName] then
            -- 否则，从主组件节点下查找
            targetNode = self.node[childName]
        end
    else
        -- 默认为主图片节点
        targetNode = self.img
    end

    if targetNode then
        targetNode:SetAttribute(key, value)
    else
        gg.log(string.format("ViewButton:SetAttribute 失败 - 无法找到节点。组件路径: %s, 子节点名: %s", self.path, tostring(childName)))
    end
end

return ViewButton
