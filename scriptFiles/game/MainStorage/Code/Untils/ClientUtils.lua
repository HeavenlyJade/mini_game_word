--- 客户端工具模块
--- 提供客户端常用的工具函数

---@class ClientUtils
local ClientUtils = {}

--- 根据路径获取本地玩家的UI节点
---@param path string UI路径，如 "TouchUIMain/BtnJump"
---@return SandboxNode|nil UI节点，如果获取失败返回nil
function ClientUtils.GetLocalUINode(path)
    if not path or type(path) ~= "string" then
        return nil
    end
    
    local localPlayer = game:GetService("Players").LocalPlayer
    if not localPlayer then
        return nil
    end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil
    end
    
    -- 按路径分割查找节点
    local current = playerGui
    for segment in path:gmatch("[^/]+") do
        current = current:FindFirstChild(segment)
        if not current then
            return nil
        end
    end
    
    return current
end

--- 隐藏指定路径的UI节点
---@param path string UI路径，如 "TouchUIMain/BtnJump"
---@return boolean 是否成功隐藏
function ClientUtils.HideUINode(path)
    local node = ClientUtils.GetLocalUINode(path)
    if not node then
        return false
    end
    
    node.Visible = false
    return true
end

--- 显示指定路径的UI节点
---@param path string UI路径，如 "TouchUIMain/BtnJump"
---@return boolean 是否成功显示
function ClientUtils.ShowUINode(path)
    if game.RunService:IsPC() then
        return false
    end
    
    local node = ClientUtils.GetLocalUINode(path)
    if not node then
        return false
    end
    
    node.Visible = true
    return true
end

--- 设置指定路径UI节点的显示状态
---@param path string UI路径，如 "TouchUIMain/BtnJump"
---@param visible boolean 是否显示
---@return boolean 是否成功设置
function ClientUtils.SetUINodeVisible(path, visible)
    local node = ClientUtils.GetLocalUINode(path)
    if not node then
        return false
    end
    
    node.Visible = visible
    return true
end

return ClientUtils
