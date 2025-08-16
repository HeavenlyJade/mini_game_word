-- InitAutoSpotNodes.lua
-- 初始化挂机区域节点配置
-- 自动设置挂机点的需求描述和作用描述节点的Title属性

local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class InitAutoSpotNodes
local InitAutoSpotNodes = {}

--- 初始化所有挂机点节点配置
function InitAutoSpotNodes.InitializeAllAutoSpotNodes()
    gg.log("开始初始化挂机区域节点配置")
    
    -- 获取所有场景节点配置
    local allSceneNodes = ConfigLoader.GetAllSceneNodes()
    
    -- 遍历所有场景节点，找到挂机点类型
    for nodeName, sceneNode in pairs(allSceneNodes) do
        if sceneNode.sceneType == "挂机点" then
            InitAutoSpotNodes.InitializeSingleAutoSpotNode(sceneNode)
        end
    end
    
    gg.log("挂机区域节点配置初始化完成")
end

--- 初始化单个挂机点节点配置
---@param sceneNode SceneNodeType 场景节点配置对象
function InitAutoSpotNodes.InitializeSingleAutoSpotNode(sceneNode)
    if not sceneNode then return end
    
    gg.log("初始化挂机点:", sceneNode.name)
    
    -- 获取节点路径
    local nodePath = sceneNode.nodePath
    if not nodePath or nodePath == "" then
        gg.log("错误：挂机点", sceneNode.name, "没有配置节点路径")
        return
    end
    
    -- 在场景中查找对应的节点
    local targetNode = gg.GetChild(WorkSpace, nodePath)
    if not targetNode then
        gg.log("错误：找不到挂机点", sceneNode.name, "的节点，路径:", nodePath)
        return
    end
    
    -- 获取需求描述和作用描述
    local requirementDesc = sceneNode.requirementDesc or ""
    local effectDesc = sceneNode.effectDesc or ""
    
    -- 设置需求描述节点
    local requirementNode = InitAutoSpotNodes.SetNodeTitleByPath(targetNode, sceneNode.requirementDescNode, requirementDesc)
    requirementNode.Size = Vector2.New(400, 50)
    -- 设置作用描述节点
    local effectNode = InitAutoSpotNodes.SetNodeTitleByPath(targetNode, sceneNode.effectDescNode, effectDesc)
    
    gg.log("挂机点", sceneNode.name, "配置完成")
end

--- 根据路径设置节点的Title属性
---@param parentNode SandboxNode 父节点
---@param nodePath string 子节点路径
---@param title string 要设置的Title值
function InitAutoSpotNodes.SetNodeTitleByPath(parentNode, nodePath, title)
    gg.log("设置节点", nodePath, "的Title为:", title,parentNode)
    if not parentNode or not nodePath or nodePath == "" or not title or title == "" then
        return
    end
    
    -- 查找子节点
    local targetNode = gg.GetChild(parentNode, nodePath)
    if not targetNode then
        gg.log("警告：找不到节点路径:", nodePath)
        return
    end  
    gg.log("设置节点", nodePath, "的Title为:", title,targetNode)
    targetNode.Title = title
    
    return targetNode

end


--- 获取所有挂机点配置
---@return SceneNodeType[] 挂机点配置数组
function InitAutoSpotNodes.GetAllAutoSpotConfigs()
    local allSceneNodes = ConfigLoader.GetAllSceneNodes()
    local autoSpotConfigs = {}
    
    for nodeName, sceneNode in pairs(allSceneNodes) do
        if sceneNode.sceneType == "挂机点" then
            table.insert(autoSpotConfigs, sceneNode)
        end
    end
    
    return autoSpotConfigs
end


return InitAutoSpotNodes
