-- 节点克隆生成器
-- 负责管理各种节点的克隆和生成功能

local ServerStorage = game:GetService("ServerStorage")
---@class NodeCloneGenerator
local NodeCloneGenerator = {}

-- 生成玩家头顶昵称显示节点
---@param player MPlayer
function NodeCloneGenerator.GeneratePlayerNameDisplay(player)
    if not player then return end

    local character = player.actor
    if not character then return end

    local nickname = player.name or "未知"
    if not nickname or nickname == "" then
        nickname = "玩家" .. tostring(player.UserId)
    end

    local myJobTitle = ServerStorage.NodeConf.NameBillboard:Clone()
    myJobTitle.IgnoreStreamSync = true
    myJobTitle.Parent = character
    myJobTitle.LocalPosition = Vector3.New(0, 246, 0)
    myJobTitle.Name = "NameBillboard"
    myJobTitle.OwnerUin = player.uin
    myJobTitle.Visible = true
    myJobTitle.TitleName.Title = nickname
    myJobTitle.Privilege.Visible = false
    if player.variableSystem then
        local privilegeValue = player.variableSystem:GetVariable("特权_固定值_特权标识", 0)
        myJobTitle.Privilege.Visible = (privilegeValue == 1)
    end
end

-- 更新玩家昵称显示
function NodeCloneGenerator.UpdatePlayerNameDisplay(player, newNickname)
    if not player then return end
    
    local character = player.actor
    if not character then return end
    
    local nameBillboard = character:FindFirstChild("NameBillboard" .. tostring(player.uin))
    if nameBillboard and nameBillboard.TitleName then
        nameBillboard.TitleName.Title = newNickname or "未知"
    end
end

-- 移除玩家昵称显示
function NodeCloneGenerator.RemovePlayerNameDisplay(player)
    if not player then return end
    
    local character = player.actor
    if not character then return end
    
    local nameBillboard = character:FindFirstChild("NameBillboard" .. tostring(player.uin))
    if nameBillboard then
        nameBillboard:Destroy()
    end
end

-- 通用节点克隆方法
function NodeCloneGenerator.CloneNode(nodePath, parent, position, name)
    if not nodePath then return nil end
    
    local node = ServerStorage.NodeConf[nodePath]:Clone()
    if parent then
        node.Parent = parent
    end
    if position then
        node.LocalPosition = position
    end
    if name then
        node.Name = name
    end
    
    return node
end

-- 生成装饰性节点（宠物、伙伴、翅膀等）
function NodeCloneGenerator.GenerateDecorativeNode(player, nodeType, nodeName, position)
    if not player or not nodeType or not nodeName then return nil end
    
    local character = player.Character
    if not character then return nil end
    
    local node = ServerStorage.NodeConf[nodeType]:Clone()
    node.Parent = character
    node.Name = nodeName
    if position then
        node.LocalPosition = position
    end
    
    return node
end

return NodeCloneGenerator
