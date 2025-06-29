local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Common.Untils.MGlobal) ---@type gg
local ClassMgr = require(MainStorage.Code.Common.Untils.ClassMgr) ---@type ClassMgr
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager

---@class EquipingTag 装备词条
---@field id string 词条ID
---@field level number 词条等级
---@field handlers table<string, any[]> 词条处理器映射

---@class TagSystem 词条系统
---@field tagHandlers table<string, EquipingTag[]> 词条处理器
---@field tagIds table<string, EquipingTag> 词条ID映射
local TagSystem = ClassMgr.Class("TagSystem")

-- 初始化词条系统
function TagSystem:OnInit()
    self.tagHandlers = {} -- 词条处理器
    self.tagIds = {} -- 词条ID映射
end

-- 词条管理 --------------------------------------------------------

--- 获取词条
---@param id string 词条ID
---@return EquipingTag|nil
function TagSystem:GetTag(id)
    if self.tagIds[id] then
        return self.tagIds[id]
    end

    -- 模糊匹配
    for tagId, tag in pairs(self.tagIds) do
        if string.find(tagId, id) then
            return tag
        end
    end

    return nil
end

--- 重建词条处理器
function TagSystem:RebuildTagHandlers()
    self.tagHandlers = {}

    for _, equipingTag in pairs(self.tagIds) do
        for key, handlers in pairs(equipingTag.handlers) do
            if not self.tagHandlers[key] then
                self.tagHandlers[key] = {}
            end

            table.insert(self.tagHandlers[key], equipingTag)

            -- 如果有多个处理器，按优先级排序
            if #self.tagHandlers[key] > 1 then
                table.sort(self.tagHandlers[key], function(a, b)
                    return a.handlers[key][1]["优先级"] < b.handlers[key][1]["优先级"]
                end)
            end
        end
    end
end

--- 添加词条处理器
---@param equipingTag EquipingTag 词条对象
function TagSystem:AddTagHandler(equipingTag)
    if self.tagIds[equipingTag.id] then
        -- 已存在相同ID的词条，增加等级
        local existingTag = self.tagIds[equipingTag.id]
        existingTag.level = existingTag.level + equipingTag.level
    else
        self.tagIds[equipingTag.id] = equipingTag
    end

    self:RebuildTagHandlers()
end

--- 移除词条处理器
---@param id string 词条ID
function TagSystem:RemoveTagHandler(id)
    if self.tagIds[id] then
        local equippingTag = self.tagIds[id]

        -- 从tagHandlers中移除
        for key, handlers in pairs(equippingTag.handlers) do
            if self.tagHandlers[key] then
                for i, tag in ipairs(self.tagHandlers[key]) do
                    if tag.id == id then
                        table.remove(self.tagHandlers[key], i)
                        break
                    end
                end

                if #self.tagHandlers[key] == 0 then
                    self.tagHandlers[key] = nil
                end
            end
        end

        self.tagIds[id] = nil
    else
        -- 模糊匹配移除
        local removedIds = {}
        for tagId in pairs(self.tagIds) do
            if string.find(tagId, id) then
                table.insert(removedIds, tagId)
            end
        end

        for _, tagId in ipairs(removedIds) do
            self:RemoveTagHandler(tagId)
        end
    end
end

--- 触发词条
---@param key string 触发键
---@param entity any 触发实体
---@param target any 目标
---@param castParam any|nil 施法参数
---@param ... any 额外参数
function TagSystem:TriggerTags(key, entity, target, castParam, ...)
    -- 处理动态词条
    local args = {...}
    if castParam and castParam.dynamicTags and castParam.dynamicTags[key] then
        for _, equipingTag in ipairs(castParam.dynamicTags[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(entity, target, equipingTag, args)
            end
        end
    end

    -- 处理普通词条
    if self.tagHandlers[key] then
        for _, equipingTag in ipairs(self.tagHandlers[key]) do
            for _, tag in ipairs(equipingTag.handlers[key]) do
                tag:Trigger(entity, target, equipingTag, args)
            end
        end
    end
end

--- 获取所有词条
---@return table<string, EquipingTag>
function TagSystem:GetAllTags()
    return self.tagIds
end

--- 获取指定键的词条处理器
---@param key string 触发键
---@return EquipingTag[]|nil
function TagSystem:GetTagHandlers(key)
    return self.tagHandlers[key]
end

--- 清空所有词条
function TagSystem:ClearAllTags()
    self.tagHandlers = {}
    self.tagIds = {}
end

--- 获取词条数量
---@return number
function TagSystem:GetTagCount()
    local count = 0
    for _ in pairs(self.tagIds) do
        count = count + 1
    end
    return count
end

--- 检查是否有指定词条
---@param id string 词条ID
---@return boolean
function TagSystem:HasTag(id)
    return self.tagIds[id] ~= nil
end

--- 获取词条等级
---@param id string 词条ID
---@return number
function TagSystem:GetTagLevel(id)
    local tag = self.tagIds[id]
    return tag and tag.level or 0
end

--- 设置词条等级
---@param id string 词条ID
---@param level number 等级
function TagSystem:SetTagLevel(id, level)
    local tag = self.tagIds[id]
    if tag then
        tag.level = level
        self:RebuildTagHandlers()
    end
end

-- 静态方法 --------------------------------------------------------

--- 创建新的词条系统实例
---@return TagSystem
function TagSystem.New()
    local instance = TagSystem()
    instance:OnInit()
    return instance
end

return TagSystem 