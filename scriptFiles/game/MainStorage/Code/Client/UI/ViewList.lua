local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local ViewComponent = require(MainStorage.Code.Client.UI.ViewComponent) ---@type ViewComponent
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class ViewList : ViewComponent
---@field node UIList
---@field childrens ViewComponent[] 子元素列表
---@field childNameTemplate string|nil 子元素名称模板
---@field onAddElementCb fun(child: SandboxNode): ViewComponent 添加元素时的回调函数
---@field New fun(node: UIComponent|ViewComponent, ui: ViewBase, path: string, onAddElementCb: fun(child: SandboxNode): ViewComponent): ViewList
local ViewList = ClassMgr.Class("ViewList", ViewComponent)


local function RecursivlySetNotifyStop(button)
    button.IsNotifyEventStop = false
    for _, child in ipairs(button.Children) do
        RecursivlySetNotifyStop(child)
    end
end

---@param node SandboxNode
---@param ui ViewBase
---@param onAddElementCb fun(child: SandboxNode): ViewComponent
function ViewList:OnInit(node, ui, path, onAddElementCb)
    self.childrens = {}      -- 名字索引
    self.childrensList = {}  -- 数组索引
    self.childNameTemplate = nil
    self.onAddElementCb = onAddElementCb or function(child, childPath)
        return ViewComponent.New(child, ui, childPath)
    end
    for idx, child in pairs(self.node.Children) do
        local childName = child.Name
        local childPath = self.path .. "/" .. childName
        local button = self.onAddElementCb(child)
        if button then
            RecursivlySetNotifyStop(button.node)
            button.path = childPath
            self.childrens[childName] = button
            self.childrensList[#self.childrensList + 1] = button
            button.index = idx
        end
    end
end

---@private
function ViewList:RegisterComponent(child)
end

function ViewList:GetToStringParams()
    local d = ViewComponent.GetToStringParams(self)
    d["Child"] = self.childrensList
    return d
end

---@param index number
---@return ViewComponent
function ViewList:GetChild(index)
    if index <= 0 then
        return nil
    end
    local child = self.childrensList[index]
    if not child then
        self:SetElementSize(index)
        child = self.childrensList[index]
    end
    child.node.Visible = true
    return child
end

function ViewList:HideChildrenFrom(index)
    if #self.childrensList > index then
        for i = index + 1, #self.childrensList do
            self.childrensList[i]:SetVisible(false)
        end
    end
end

---@return number
function ViewList:GetChildCount()
    return #self.childrensList
end

---@param size number
function ViewList:SetElementSize(size)
    if size < 0 then size = 0 end
    -- 只保留模板节点（如'背景'）克隆逻辑
    local templateKey, templateNode
    local count = 0
    gg.log("self.childrens",self.childrens)
    for k, v in pairs(self.childrens) do
        templateKey = k
        templateNode = v
        count = count + 1
    end
    -- 扩容
    gg.log("templateKey",templateKey)
    gg.log("templateNode",templateNode.node)
    for i = #self.childrensList + 1, size do

        if  templateKey and templateNode then
            local childName = templateKey .. i
            local child = templateNode.node:Clone()
            child:SetParent(self.node)
            child.Name = childName
            if self.onAddElementCb then
                local childPath = self.path .. "/" .. childName
                local button = self.onAddElementCb(child, childPath)
                if button then
                    RecursivlySetNotifyStop(button.node)
                    button.path = childPath
                    button.index = i
                    self.childrensList[i] = button
                    self.childrens[childName] = button  -- 同步名字索引
                    button:SetVisible(true)
                end
            end
        end
    end
    gg.log("生成后的",self.childrensList)
    gg.log("self.childrens",self.childrens)
    -- -- 显示/隐藏并同步移除多余名字key
    -- for i = 1, #self.childrensList do
    --     local button = self.childrensList[i]
    --     if i <= size then
    --         button:SetVisible(true)
    --     else
    --         button:SetVisible(false)
    --         -- 移除名字索引
    --         if self.childrens[button.node.Name] == button then
    --             self.childrens[button.node.Name] = nil
    --         end
    --     end
    -- end
end

---@param visible boolean
function ViewList:SetGray(visible)
    self.node.Grayed = visible
end

---@param visible boolean
function ViewList:SetVisible(visible)
    self.node.Visible = visible
    self.node.Enabled = visible
end

---私有方法：根据childrens数组刷新UI布局
function ViewList:_refreshLayout()
    -- 步骤 1: 完全卸载 (Detach)
    -- 创建一个临时表来持有子节点，避免在迭代时修改集合
    local childrenToDetach = {}
    for _, child in pairs(self.node.Children) do
        table.insert(childrenToDetach, child)
    end
    for _, child in ipairs(childrenToDetach) do
        child:SetParent(nil)
    end

    -- 步骤 2: 重新装载 (Re-attach) 并更新元数据
    for i, comp in ipairs(self.childrens) do
        -- 重新设置父节点，按新顺序装载
        comp.node:SetParent(self.node)
        -- 更新元数据
        comp.index = i
        comp.path = self.path .. "/" .. comp.node.Name
    end
end


---私有方法：将一个ViewComponent|ViewButton插入到childrens数组中
---@param Component ViewComponent|ViewButton 要插入的组件
---@param index number 目标索引
function ViewList:insertIntoChildrens(Component, index)
    -- 安全地插入到 self.childrens 数组
    local targetIndex = index
    if not targetIndex or targetIndex > #self.childrens + 1 or targetIndex < 1 then
        targetIndex = #self.childrens + 1 -- 如果index无效或越界，则插入到末尾
    end
    Component.node:SetParent(self.node)
    table.insert(self.childrens, targetIndex, Component)
end


---在指定位置插入子节点
---@param childNode SandboxNode 要添加的子节点
---@param index number 要插入的位置
---@param shouldRefresh boolean|nil 是否在插入后立即刷新UI布局，默认为false
function ViewList:InsertChild(childNode, index, shouldRefresh)
    -- 步骤 1: 创建逻辑包装器
    childNode.Parent = self.node
    local viewComponent = self.onAddElementCb(childNode)
    if not viewComponent then
        return -- 如果创建失败，则直接返回
    end
    -- 步骤 2: 插入到childrens 字典
    -- 名字索引
    self.childrens[childNode.Name] = viewComponent
    -- 数字索引
    if not index or index > #self.childrensList + 1 or index < 1 then
        index = #self.childrensList + 1
    end
    table.insert(self.childrensList, index, viewComponent)
    -- 步骤 3: 如果需要，则刷新布局
    if shouldRefresh then
        self:_refreshLayout()
    end
end

function ViewList:AppendChild(childNode)
    self:InsertChild(childNode, #self.childrensList + 1, false)
end

--- 通过名称获取子节点实例
---@param childName string 要查找的子节点名称
---@return ViewComponent|nil
function ViewList:GetChildByName(childName)
    return self.childrens[childName]
end

--- 通过名称移除子节点
---@param childName string 要移除的子节点的名称
---@return boolean true|false
function ViewList:RemoveChildByName(childName)
    -- 先从名字索引删除
    local button = self.childrens[childName]
    self.childrens[childName] = nil

    -- 再从数字索引数组删除
    if button then
        for i, v in ipairs(self.childrensList) do
            if v == button then
                table.remove(self.childrensList, i)
                break
            end
        end
        -- 销毁节点
        if button.node then
            button.node:Destroy()
        end
    end
end


---清空所有子元素
---@param keepNodes string[] | nil 要保留的子节点名称列表
function ViewList:ClearChildren(keepNodes)
    local keepSet = {}
    if keepNodes then
        for _, name in ipairs(keepNodes) do
            keepSet[name] = true
        end
    end

    local childrenToDestroy = {}
    local newChildrensList = {}
    local newChildrens = {}

    for _, child in ipairs(self.childrensList) do
        local childName = child.node and child.node.Name
        if childName and keepSet[childName] then
            -- 保留这个节点
            table.insert(newChildrensList, child)
            newChildrens[childName] = child
        else
            -- 准备销毁这个节点
            table.insert(childrenToDestroy, child)
        end
    end

    for _, child in ipairs(childrenToDestroy) do
        if child.node then
            child.node:Destroy()
        end
    end

    self.childrensList = newChildrensList
    self.childrens = newChildrens
end

return ViewList
