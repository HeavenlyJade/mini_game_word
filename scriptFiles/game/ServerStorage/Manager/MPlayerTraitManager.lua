--- V109 miniw-haima
--- 玩家特点调用管理器
--- 静态类，供 MServerEventManager 调用，用于操作 MPlayer 对象

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
local FriendInviteService = game:GetService("FriendInviteService")

---@class MPlayerTraitManager
local MPlayerTraitManager = {
    mapId =24251217274568
}

--- 验证玩家
---@param uin number 玩家UIN
---@return MPlayer|nil 玩家对象
function MPlayerTraitManager.ValidatePlayer(uin)
    if not uin then
        gg.log("玩家特点调用缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("玩家特点调用找不到玩家:", uin)
        return nil
    end

    return player
end






--- 获取玩家广告观看信息
---@param player MPlayer 玩家对象
---@return table 广告观看信息
function MPlayerTraitManager.GetAdWatchInfo(player)
    if not player or not player:Is("MPlayer") then
        return {}
    end
    
    return {
        adWatchCount = player.adWatchCount,
        tempBuffs = player.tempBuffs or {}
    }
end

--- 获取邀请者信息
---@param player MPlayer 玩家对象
---@param mapId number|nil 地图ID，如果为nil则使用默认配置
---@return table|nil 邀请者信息
function MPlayerTraitManager.GetInvitePlayer(player, mapId)
    if not player or not player:Is("MPlayer") then
        return nil
    end
    
    -- 使用传入的mapId或默认配置
    local targetMapId = mapId or MPlayerTraitManager.mapId
    if not targetMapId or type(targetMapId) ~= "number" then
        gg.log("错误：GetInvitePlayer 缺少有效的地图ID参数")
        return nil
    end
    -- 调用 FriendInviteService 获取邀请者信息
    local result = nil
    
    -- 直接同步调用
    FriendInviteService:GetInvitePlayer(player.uin, targetMapId, function(inviteData)
        gg.log("获取邀请者信息成功:", player.name, "地图ID:", targetMapId, "邀请者信息:", inviteData)
    end)
    
    return result
end

--- 判断是否为新玩家
---@param player MPlayer 玩家对象
---@param mapId number|nil 地图ID，如果为nil则使用默认配置
---@return boolean|nil 是否为新玩家
function MPlayerTraitManager.IsNewToThisMap(player, mapId)
    if not player or not player:Is("MPlayer") then
        return nil
    end
    
    -- 使用传入的mapId或默认配置
    local targetMapId = mapId or MPlayerTraitManager.mapId
    if not targetMapId or type(targetMapId) ~= "number" then
        gg.log("错误：IsNewToThisMap 缺少有效的地图ID参数")
        return nil
    end
    
    -- 调用 FriendInviteService 判断是否为新玩家
    local FriendInviteService = game:GetService("FriendInviteService")

    local result = nil
    FriendInviteService:IsNewToThisMap(player.uin, targetMapId, function(isNew)
        gg.log("接口返回的数据新玩家判断完成:", player.name, "地图ID:", targetMapId, "是否新玩家:", isNew)

    end)
    
    return result
end

--- 获取被邀请者列表
---@param player MPlayer 玩家对象
---@param mapId number|nil 地图ID，如果为nil则使用默认配置
---@return table|nil 被邀请者列表
function MPlayerTraitManager.GetInvitedPlayerList(player, mapId)
    if not player or not player:Is("MPlayer") then
        return nil
    end
    
    -- 使用传入的mapId或默认配置
    local targetMapId = mapId or MPlayerTraitManager.mapId
    if not targetMapId or type(targetMapId) ~= "number" then
        gg.log("错误：GetInvitedPlayerList 缺少有效的地图ID参数")
        return nil
    end
    
    -- 调用 FriendInviteService 获取被邀请者列表
    local FriendInviteService = game:GetService("FriendInviteService")
    if not FriendInviteService then
        gg.log("错误：FriendInviteService 服务不可用")
        return nil
    end
    
    local result = nil
    
    -- 直接同步调用
    FriendInviteService:GetInvitedPlayerList(player.uin, targetMapId, function(invitedList)
        gg.log("获取被邀请者列表完成:", player.name, "地图ID:", targetMapId, "被邀请者数量:", invitedList)

    end)
    
    return result
end


--- 设置玩家挂机状态
---@param player MPlayer 玩家对象
---@param isIdling boolean 是否挂机
---@param idleSpotName string|nil 挂机点名称
---@return boolean 是否成功
function MPlayerTraitManager.SetIdlingStatus(player, isIdling, idleSpotName)
    if not player or not player:Is("MPlayer") then
        return false
    end
    
    if type(isIdling) == "boolean" then
        player:SetIdlingState(isIdling, idleSpotName)
        return true
    end
    
    return false
end




--- 添加临时buff


return MPlayerTraitManager
