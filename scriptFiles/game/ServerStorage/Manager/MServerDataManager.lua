--- 服务端数据管理器
--- 负责管理服务端玩家、场景等数据

local game = game
local pairs = pairs
local ipairs = ipairs
local Players = game:GetService('Players')
local MainStorage = game:GetService("MainStorage")
--- 服务端数据存储
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
---@class MServerDataManager
local MServerDataManager = {
    server_players_list = {}, ---@type table<number, MPlayer>
    server_players_name_list = {},
    scene_node_handlers = {}, ---@type table<string, SceneNodeHandlerBase>

    MailMgr = nil, ---@type MailMgr | nil
    BagMgr = nil, ---@type BagMgr | nil

    uuid_start = 0,
    tick = 0
}

-- 游戏状态相关
MServerDataManager.game_stat = 0 -- 0=正常 1=完结

-- 装备槽位配置
MServerDataManager.equipSlot = { -- 各个装备槽位对应的装备类型

}



-----------------------------------------------
-- 从 Service - Players找到一个玩家
---@param uin_ number 玩家ID
---@return MPlayer|nil 找到的玩家对象
function MServerDataManager.getPlayerInfoByUin(uin_)
    local allPlayers = Players:GetPlayers()
    for _, player in ipairs(allPlayers) do
        if player.UserId == uin_ then
            return player
        end
    end
end

---@param name_ string
function MServerDataManager.getLivingByName(name_)
    if string.sub(name_, 1, 2) == 'u_' then
        for scene_name, scene in pairs(gg.server_scenes_list) do
            if scene.uuid2Entity[name_] then
                return scene.uuid2Entity[name_]
            end
        end
    end
    print("MServerDataManager.server_players_name_list", MServerDataManager.server_players_name_list)
    return MServerDataManager.server_players_name_list[name_]
end

-- 获得player实例
---@param uin_ number 玩家ID
---@return MPlayer|nil 玩家实例
function MServerDataManager.getPlayerByUin(uin_)
    if MServerDataManager.server_players_list[uin_] then
        return MServerDataManager.server_players_list[uin_]
    end
    return nil
end

-- 使用uuid查找一个怪物 m10002 m20003
---@param uuid_ string 怪物UUID
---@return Monster|nil 找到的怪物实例
function MServerDataManager.findMonsterByUuid(uuid_)
    for scene_name, scene in pairs(gg.server_scenes_list) do
        if next(scene.players) then
            -- 场景内有玩家
            if scene.monsters[uuid_] then
                return scene.monsters[uuid_]
            end
        end
    end
    return nil -- 查找失败
end

-- 使用uuid查找一个怪物 m10002 m20003，client端
---@param scene_name_ string 场景名称
---@param uuid_ string 怪物UUID
---@return Monster|nil 找到的怪物实例
function MServerDataManager.findMonsterClientContainer(scene_name_, uuid_)
    local contain_ = game.WorkSpace["Ground"][scene_name_].container_monster
    if contain_ then
        return contain_[uuid_]
    end
    return nil -- 查找失败
end

-- 获得武器法术效果容器
---@param scene_name_ string 场景名称
---@return SandboxNode 武器容器
function MServerDataManager.serverGetContainerWeapon(scene_name_)
    return game.WorkSpace["Ground"][scene_name_].container_weapon
end

-- 建立一个uuid
---@param pre_ string 前缀
---@return string 生成的UUID
function MServerDataManager.create_uuid(pre_)
    MServerDataManager.uuid_start = MServerDataManager.uuid_start + 1
    local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
    return pre_ .. MServerDataManager.uuid_start .. '_' .. (gg.GetTimeStamp() * 1000 + math.random(1, 1000)) % 1000 .. '_' ..
               math.random(10000, 99999)
end

function MServerDataManager.GetSceneNode(path)
    if not path then return nil end

    -- Split the path by first '/'
    local sceneName, remainingPath = string.match(path, "([^/]+)/(.+)")
    if not sceneName then return nil end

    -- Get the scene using the first part
    local scene = gg.server_scenes_list[sceneName]
    if not scene then return nil end

    -- Pass the remaining path to scene:Get()
    return scene:Get(remainingPath)
end

--- 根据完整路径从WorkSpace查找节点
---@param path string 节点路径，例如 "Ground/init_map/Scene/jump_plat"
---@return SandboxNode|nil
function MServerDataManager.GetNodeByFullPath(path)
    if not path or path == "" then return nil end

    local root = game:GetService("WorkSpace")
    local currentNode = root
    for part in string.gmatch(path, "[^/]+") do
        if currentNode then
            currentNode = currentNode[part]
            gg.log("currentNode",currentNode)
        else
            return nil
        end
    end
    return currentNode
end

-- 添加玩家到列表
---@param uin number 玩家ID
---@param player MPlayer 玩家实例
---@param nickname string 玩家昵称
function MServerDataManager.addPlayer(uin, player, nickname)
    MServerDataManager.server_players_list[uin] = player
    MServerDataManager.server_players_name_list[nickname] = player
end

-- 从列表中移除玩家
---@param uin number 玩家ID
---@param nickname string 玩家昵称
function MServerDataManager.removePlayer(uin, nickname)
    MServerDataManager.server_players_list[uin] = nil
    MServerDataManager.server_players_name_list[nickname] = nil
end

-- 添加场景
---@param sceneName string 场景名称
---@param scene Scene 场景实例
function MServerDataManager.addScene(sceneName, scene)
    gg.server_scenes_list[sceneName] = scene
end

-- 移除场景
---@param sceneName string 场景名称
function MServerDataManager.removeScene(sceneName)
    gg.server_scenes_list[sceneName] = nil
end

-- 添加场景节点处理器
---@param handler SceneNodeHandlerBase
function MServerDataManager.addSceneNodeHandler(handler)
    MServerDataManager.scene_node_handlers[handler.uuid] = handler
end

-- 移除场景节点处理器
---@param uuid string
function MServerDataManager.removeSceneNodeHandler(uuid)
    MServerDataManager.scene_node_handlers[uuid] = nil
end

-- 获取场景节点处理器
---@param uuid string
---@return SceneNodeHandlerBase
function MServerDataManager.getSceneNodeHandler(uuid)
    return MServerDataManager.scene_node_handlers[uuid]
end

-- 获取所有玩家
---@return table<number, MPlayer>
function MServerDataManager.getAllPlayers()
    return MServerDataManager.server_players_list
end

-- 获取所有场景
---@return table<string, Scene>
function MServerDataManager.getAllScenes()
    return gg.server_scenes_list
end

return MServerDataManager 