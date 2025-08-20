--- Actor子节点操作指令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MPlayer = require(ServerStorage.EntityTypes.MPlayer) ---@type MPlayer

---@class ActorNodeCommand
local ActorNodeCommand = {}

--- 主命令处理函数
---@param params table 命令参数
---@param player MPlayer 目标玩家
function ActorNodeCommand.main(params, player)
    if not player then
        gg.log("错误：未指定目标玩家")
        return false
    end

    local operation = params["操作类型"]
    local nodeName = params["节点名称"]
    local visible = params["可见性"]

    if not operation then
        gg.log("错误：未指定操作类型")
        return false
    end

    if not nodeName then
        gg.log("错误：未指定节点名称")
        return false
    end

    -- 执行操作
    if operation == "设置可见性" then
        if visible == nil then
            gg.log("错误：设置可见性时必须指定可见性值")
            return false
        end
        return ActorNodeCommand.setNodeVisibility(player, nodeName, visible)
    elseif operation == "获取可见性" then
        return ActorNodeCommand.getNodeVisibility(player, nodeName)
    elseif operation == "列出所有节点" then
        return ActorNodeCommand.listAllNodes(player)
    else
        gg.log("错误：不支持的操作类型，支持的类型：设置可见性、获取可见性、列出所有节点")
        return false
    end
end

--- 根据路径查找节点
---@param parent SandboxNode 父节点
---@param path string 节点路径（支持斜杠分隔）
---@return SandboxNode|nil 找到的节点
local function findNodeByPath(parent, path)
    if not path or path == "" then
        return parent
    end
    
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    local current = parent
    for _, part in ipairs(parts) do
        if not current then
            return nil
        end
        current = current:FindFirstChild(part)
    end
    
    return current
end

--- 设置节点可见性
---@param player MPlayer 目标玩家
---@param nodeName string 节点名称或路径（支持斜杠分隔，如"称号/特权"）
---@param visible boolean 是否可见
function ActorNodeCommand.setNodeVisibility(player, nodeName, visible)
    if not player.actor then
        --player:SendHoverText("错误：玩家角色不存在")
        return false
    end

    local targetNode = findNodeByPath(player.actor, nodeName)
    if not targetNode then
        --player:SendHoverText(string.format("错误：找不到路径为 '%s' 的节点", nodeName))
        return false
    end

    -- 检查节点是否有Visible属性
    if targetNode.Visible == nil then
        --player:SendHoverText(string.format("错误：节点 '%s' 没有Visible属性", nodeName))
        return false
    end

    -- 设置可见性
    local oldVisible = targetNode.Visible
    targetNode.Visible = visible

    local message = string.format("节点 '%s' 的可见性已从 %s 设置为 %s", 
        nodeName, 
        tostring(oldVisible), 
        tostring(visible))
    
    --player:SendHoverText(message)
    gg.log("玩家 %s 设置节点可见性成功：%s", player.name, message)
    
    return true
end

--- 获取节点可见性
---@param player MPlayer 目标玩家
---@param nodeName string 节点名称或路径（支持斜杠分隔，如"称号/特权"）
function ActorNodeCommand.getNodeVisibility(player, nodeName)
    if not player.actor then
        --player:SendHoverText("错误：玩家角色不存在")
        return false
    end

    local targetNode = findNodeByPath(player.actor, nodeName)
    if not targetNode then
        --player:SendHoverText(string.format("错误：找不到路径为 '%s' 的节点", nodeName))
        return false
    end

    -- 检查节点是否有Visible属性
    if targetNode.Visible == nil then
        --player:SendHoverText(string.format("错误：节点 '%s' 没有Visible属性", nodeName))
        return false
    end

    local message = string.format("节点 '%s' 的当前可见性：%s", nodeName, tostring(targetNode.Visible))
    --player:SendHoverText(message)
    gg.log("玩家 %s 获取节点可见性：%s", player.name, message)
    
    return true
end

--- 列出所有可操作的节点
---@param player MPlayer 目标玩家
function ActorNodeCommand.listAllNodes(player)
    if not player.actor then
        --player:SendHoverText("错误：玩家角色不存在")
        return false
    end

    local nodes = {}
    local function collectNodes(parent, prefix)
        for _, child in pairs(parent:GetChildren()) do
            local fullName = prefix and (prefix .. "/" .. child.Name) or child.Name
            if child.Visible ~= nil then
                table.insert(nodes, {
                    name = fullName,
                    visible = child.Visible
                })
            end
            -- 递归查找子节点
            collectNodes(child, fullName)
        end
    end

    collectNodes(player.actor, "")

    if #nodes == 0 then
        --player:SendHoverText("没有找到可操作的节点")
        return false
    end

    -- 构建节点列表消息
    local message = "可操作的节点列表：\n"
    for i, node in ipairs(nodes) do
        message = message .. string.format("%d. %s (可见性: %s)\n", i, node.name, tostring(node.visible))
    end

    -- --player:SendHoverText(message)
    gg.log("玩家 %s 获取节点列表成功，共找到 %d 个可操作节点", player.name, #nodes)
    
    return true
end

return ActorNodeCommand
