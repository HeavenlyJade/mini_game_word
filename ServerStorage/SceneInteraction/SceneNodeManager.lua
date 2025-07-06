-- File: SceneNodeManager.lua
-- Desc: 场景交互系统的总管理器，纯服务端运行。完全由事件驱动。

local ServerStorage = game:GetService("ServerStorage")
local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal)
local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)

-- 单例模式
local SceneNodeManager = {}

-- 处理器（专家）的映射表
local handlerMap = {
    ["跳台"] = require(ServerStorage.SceneInteraction.handlers.JumpPlatformHandler),
    -- ["陷阱"] = require(ServerStorage.SceneInteraction.handlers.TrapHandler), -- 未来在这里扩展
}

---
-- 初始化管理器，在MServerMain中调用
function SceneNodeManager:Init()
    gg.log("SceneNodeManager: 开始初始化...")

    -- [修改] 在全局数据管理器中创建统一的存储表
    serverDataMgr.sceneNodeHandlers = serverDataMgr.sceneNodeHandlers or {}

    local SceneNodeConfig = require(MainStorage.Code.Common.Config.SceneNodeConfig)
    if not SceneNodeConfig or not SceneNodeConfig.Data then
        gg.log("SceneNodeManager: 错误! 无法加载 SceneNodeConfig。")
        return
    end

    local activeCount = 0
    for nodeName, config in pairs(SceneNodeConfig.Data) do
        if not (config["是否启用"] == nil or config["是否启用"] == true) then goto continue end

        local HandlerClass = handlerMap[config["场景类型"]]
        if not HandlerClass then
            gg.log("SceneNodeManager: 警告! 节点 "..nodeName.." 的类型 '"..config["场景类型"].."' 没有注册对应的Handler。")
            goto continue
        end
        
        local entity = game.Workspace:FindNodeByPath(config["场景节点路径"])
        if not entity then
            gg.log("SceneNodeManager: 警告! 无法在场景中找到节点 "..nodeName.." 的实体，路径: "..config["场景节点路径"])
            goto continue
        end

        local handler = HandlerClass.new(entity, config)
        
        -- [修改] 将处理器实例存放到全局数据管理器中
        serverDataMgr.sceneNodeHandlers[nodeName] = handler
        gg.log("SceneNodeManager: 已成功创建节点处理器: " .. nodeName)
        activeCount = activeCount + 1

        -- 根据触发器类型，绑定正确的事件 (借鉴TriggerZone.lua的模式)
        local triggerType = config["触发器类型"]
        if triggerType == "TOUCH" then
            self:BindTouchEvent(handler)
        elseif triggerType == "AREA" then
            self:BindAreaEvents(handler)
        end

        -- 为有定时指令的节点启动定时器
        if config["定时指令列表"] and #config["定时指令列表"] > 0 then
             handler:StartPeriodicCommands()
        end

        ::continue::
    end

    gg.log("SceneNodeManager: 初始化完成，共激活 " .. activeCount .. " 个节点。")
end

---为"碰撞"类型的节点绑定引擎的 Touched 事件
function SceneNodeManager:BindTouchEvent(handler)
    handler.entity.Touched:Connect(function(otherPart)
        -- 尝试从碰撞的另一方获取玩家实体
        local player = serverDataMgr.getPlayerByActor(otherPart.Parent)
        if player then
            handler:OnTouch(player)
        end
    end)
end

---为"区域"类型的节点绑定引擎的 Touched 和 TouchEnded 事件来模拟 Enter/Leave
function SceneNodeManager:BindAreaEvents(handler)
    -- 借鉴TriggerZone.lua的逻辑
    handler.entity.Touched:Connect(function(otherPart)
        local player = serverDataMgr.getPlayerByActor(otherPart.Parent)
        if player then
            handler:OnEnter(player) -- 直接调用OnEnter
        end
    end)

    handler.entity.TouchEnded:Connect(function(otherPart)
        local player = serverDataMgr.getPlayerByActor(otherPart.Parent)
        if player then
            handler:OnLeave(player) -- 直接调用OnLeave
        end
    end)
end

-- 此处不再需要 Update 函数

return SceneNodeManager 