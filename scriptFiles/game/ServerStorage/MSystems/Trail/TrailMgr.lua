-- TrailMgr.lua
-- 尾迹系统管理模块
-- 负责管理所有在线玩家的尾迹管理器，提供系统级接口

local game = game
local os = os
local table = table
local pairs = pairs
local ipairs = ipairs

local MainStorage = game:GetService('MainStorage')
local ServerStorage = game:GetService('ServerStorage')
local RunService = game:GetService('RunService')
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local CloudTrailDataAccessor = require(ServerStorage.MSystems.Trail.TrailCloudDataMgr) ---@type CloudTrailDataAccessor
local Trail = require(ServerStorage.MSystems.Trail.Trail) ---@type Trail
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local TrailEventConfig = require(MainStorage.Code.Event.EventTrail) ---@type TrailEventConfig

---@class TrailMgr
local TrailMgr = {
    -- 在线玩家尾迹管理器缓存 {uin = Trail管理器实例}
    server_player_trails = {}, ---@type table<number, Trail>

    -- 定时保存间隔（秒）
    SAVE_INTERVAL = 60
}

function SaveAllPlayerTRAIL_()
    local count = 0
    for uin, trailManager in pairs(TrailMgr.server_player_trails) do
        if trailManager then
            -- 提取数据并保存到云端
            local playerTrailData = trailManager:GetSaveData()
            if playerTrailData then
                CloudTrailDataAccessor:SavePlayerTrailData(uin, playerTrailData)
                count = count + 1
            end
        end
    end
    --gg.log("定时保存尾迹数据完成，保存了", count, "个玩家的尾迹")
end

local saveTimer = SandboxNode.New("Timer", game.WorkSpace) ---@type Timer
saveTimer.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
saveTimer.Name = 'TRAIL_SAVE_ALL'
saveTimer.Delay = 60
saveTimer.Loop = true
saveTimer.Interval = 60
saveTimer.Callback = SaveAllPlayerTRAIL_
saveTimer:Start()

---玩家上线处理
---@param player MPlayer 玩家对象
function TrailMgr.OnPlayerJoin(player)
    if not player or not player.uin then
        --gg.log("尾迹系统：玩家上线处理失败：玩家对象无效")
        return
    end

    local uin = player.uin
    --gg.log("开始处理玩家尾迹上线", uin)

    -- 从云端加载玩家尾迹数据
    local playerTrailData = CloudTrailDataAccessor:LoadPlayerTrailData(uin)

    -- 获取尾迹装备槽配置
    local equipSlotIds = TrailEventConfig.EQUIP_CONFIG.TRAIL_SLOTS

    -- 创建Trail管理器实例并缓存
    local trailManager = Trail.New(uin, equipSlotIds)
    trailManager:LoadFromTrailData(playerTrailData)
    TrailMgr.server_player_trails[uin] = trailManager

    --gg.log("玩家尾迹管理器加载完成", uin, "尾迹数量", trailManager:GetTrailCount())
end

---玩家离线处理
---@param uin number 玩家ID
function TrailMgr.OnPlayerLeave(uin)
    local trailManager = TrailMgr.server_player_trails[uin]
    if trailManager then
        -- 提取数据并保存到云端
        local playerTrailData = trailManager:GetSaveData()
        if playerTrailData then
            CloudTrailDataAccessor:SavePlayerTrailData(uin, playerTrailData)
        end

        -- 清理玩家离开时的尾迹特效
        trailManager:CleanupPlayerTrailEffects(uin)

        -- 清理内存缓存
        TrailMgr.server_player_trails[uin] = nil
        --gg.log("玩家尾迹数据已保存并清理", uin)
    end
end

---获取玩家尾迹管理器
---@param uin number 玩家ID
---@return Trail|nil 尾迹管理器实例
function TrailMgr.GetPlayerTrail(uin)
    local trailManager = TrailMgr.server_player_trails[uin]
    if not trailManager then
        --gg.log("尾迹系统：在缓存中未找到玩家", uin, "的尾迹管理器，尝试动态加载。")
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            TrailMgr.OnPlayerJoin(player)
            trailManager = TrailMgr.server_player_trails[uin]
        end

        if trailManager then
            --gg.log("尾迹系统：为玩家", uin, "动态加载尾迹管理器成功。")
        else
            --gg.log("尾迹系统：为玩家", uin, "动态加载尾迹管理器失败。")
        end
    end
    return trailManager
end

---装备尾迹
---@param uin number 玩家ID
---@param trailSlotId number 要装备的尾迹背包槽位ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function TrailMgr.EquipTrail(uin, trailSlotId, equipSlotId)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家尾迹数据不存在"
    end

    local success, errorMsg = trailManager:EquipTrail(trailSlotId, equipSlotId)

    if success then
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            TrailMgr.UpdateAllEquippedTrailModels(player)
        end
        -- 通知客户端数据更新
        TrailMgr.NotifyTrailDataUpdate(uin)
    end

    return success, errorMsg
end

---卸下尾迹
---@param uin number 玩家ID
---@param equipSlotId string 目标装备栏ID
---@return boolean, string|nil
function TrailMgr.UnequipTrail(uin, equipSlotId)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家尾迹数据不存在"
    end

    local success, errorMsg = trailManager:UnequipTrail(equipSlotId)

    if success then
        local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
        local player = serverDataMgr.getPlayerByUin(uin)
        if player then
            TrailMgr.UpdateAllEquippedTrailModels(player)
        end
        -- 通知客户端数据更新
        TrailMgr.NotifyTrailDataUpdate(uin)
    end

    return success, errorMsg
end

---获取玩家所有尾迹信息
---@param uin number 玩家ID
---@return table|nil 尾迹列表，失败返回nil
---@return string|nil 错误信息
function TrailMgr.GetPlayerTrailList(uin)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return nil, "玩家数据不存在"
    end

    return trailManager:GetPlayerTrailList(), nil
end

---获取尾迹数量
---@param uin number 玩家ID
---@return number 尾迹数量
function TrailMgr.GetTrailCount(uin)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return 0
    end

    return trailManager:GetTrailCount()
end

---获取指定槽位的尾迹数据
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return table|nil 尾迹数据
function TrailMgr.GetTrailBySlot(uin, slotIndex)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return nil
    end

    return trailManager:GetTrailBySlot(slotIndex)
end

---添加尾迹到指定槽位
---@param uin number 玩家ID
---@param trailName string 尾迹配置名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否成功
---@return string|nil 错误信息
---@return number|nil 实际使用的槽位
function TrailMgr.AddTrailToSlot(uin, trailName, slotIndex)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家数据不存在", nil
    end

    return trailManager:AddTrail(trailName, slotIndex)
end

---移除指定槽位的尾迹
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean 是否成功
---@return string|nil 错误信息
function TrailMgr.RemoveTrailFromSlot(uin, slotIndex)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家数据不存在"
    end

    return trailManager:RemoveTrail(slotIndex)
end

---删除尾迹（兼容接口）
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil
function TrailMgr.DeleteTrail(uin, slotIndex)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家数据不存在"
    end

    return trailManager:DeleteTrail(slotIndex)
end

---切换尾迹锁定状态
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@return boolean, string|nil, boolean|nil
function TrailMgr.ToggleTrailLock(uin, slotIndex)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家数据不存在", nil
    end

    return trailManager:ToggleTrailLock(slotIndex)
end

---重命名尾迹
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
---@param newName string 新名称
---@return boolean, string|nil
function TrailMgr.RenameTrail(uin, slotIndex, newName)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return false, "玩家数据不存在"
    end

    return trailManager:RenameTrail(slotIndex, newName)
end

---给玩家添加尾迹
---@param player MPlayer 玩家对象
---@param trailName string 尾迹名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function TrailMgr.AddTrail(player, trailName, slotIndex)
    if not player or not player.uin then
        --gg.log("TrailMgr.AddTrail: 玩家对象无效")
        return false, nil
    end

    local success, errorMsg, actualSlot = TrailMgr.AddTrailToSlot(player.uin, trailName, slotIndex)
    if success then
        --gg.log("TrailMgr.AddTrail: 成功给玩家", player.uin, "添加尾迹", trailName, "槽位", actualSlot)
        -- 通知客户端数据更新
        TrailMgr.NotifyTrailDataUpdate(player.uin, actualSlot)
    else
        --gg.log("TrailMgr.AddTrail: 给玩家", player.uin, "添加尾迹失败", trailName, "错误", errorMsg)
    end

    return success, actualSlot
end

---给玩家添加尾迹（通过UIN）
---@param uin number 玩家UIN
---@param trailName string 尾迹名称
---@param slotIndex number|nil 槽位索引，nil表示自动分配
---@return boolean 是否添加成功
---@return number|nil 实际使用的槽位
function TrailMgr.AddTrailByUin(uin, trailName, slotIndex)
    local serverDataMgr = require(ServerStorage.Manager.MServerDataManager)
    local player = serverDataMgr.getPlayerByUin(uin)
    if not player then
        --gg.log("TrailMgr.AddTrailByUin: 玩家不存在", uin)
        return false, nil
    end

    return TrailMgr.AddTrail(player, trailName, slotIndex)
end

---通知客户端尾迹数据更新
---@param uin number 玩家ID
---@param slotIndex number|nil 具体槽位，nil表示全部更新
function TrailMgr.NotifyTrailDataUpdate(uin, slotIndex)
    local TrailEventManager = require(ServerStorage.MSystems.Trail.TrailEventManager) ---@type TrailEventManager

    if slotIndex then
        -- 单个尾迹更新
        local trailManager = TrailMgr.GetPlayerTrail(uin)
        if trailManager then
            local trailData = trailManager:GetTrailBySlot(slotIndex)
            if trailData then
                TrailEventManager.NotifyTrailUpdate(uin, trailData)
            end
        end
    else
        -- 全部尾迹更新
        local result, errorMsg = TrailMgr.GetPlayerTrailList(uin)
        if result then
            TrailEventManager.NotifyTrailListUpdate(uin, result)
        end
    end
end

---强制同步玩家尾迹数据到客户端
---@param uin number 玩家UIN
function TrailMgr.ForceSyncToClient(uin)
    local result, errorMsg = TrailMgr.GetPlayerTrailList(uin)
    if result then
        local TrailEventManager = require(ServerStorage.MSystems.Trail.TrailEventManager) ---@type TrailEventManager
        TrailEventManager.NotifyTrailListUpdate(uin, result)
        --gg.log("强制同步尾迹数据到客户端", uin)
    else
        --gg.log("强制同步尾迹数据失败", uin, errorMsg)
    end
end

---强制保存玩家数据到云端
---@param uin number 玩家UIN
function TrailMgr.ForceSavePlayerData(uin)
    local trailManager = TrailMgr.server_player_trails[uin]
    if trailManager then
        local playerTrailData = trailManager:GetSaveData()
        if playerTrailData then
            CloudTrailDataAccessor:SavePlayerTrailData(uin, playerTrailData)
            --gg.log("强制保存玩家尾迹数据", uin)
        end
    end
end

---更新所有装备的尾迹模型
---@param player MPlayer 玩家对象
function TrailMgr.UpdateAllEquippedTrailModels(player)
    if not player or not player.uin then
        --gg.log("错误：玩家对象无效，无法更新尾迹模型")
        return
    end

    local trailManager = TrailMgr.GetPlayerTrail(player.uin)
    if not trailManager then
        --gg.log("错误：找不到玩家尾迹管理器，无法更新尾迹模型", player.uin)
        return
    end

    -- 调用尾迹管理器的更新方法
    trailManager:UpdateAllEquippedTrailModels(player)
end

---设置尾迹背包容量
---@param uin number 玩家ID
---@param capacity number 新容量
function TrailMgr.SetTrailBagCapacity(uin, capacity)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if trailManager then
        trailManager:SetTrailBagCapacity(capacity)
        --gg.log("玩家", uin, "尾迹背包容量已设置为", capacity)
    end
end

---设置已解锁装备栏数量
---@param uin number 玩家ID
---@param count number 装备栏数量
function TrailMgr.SetUnlockedEquipSlots(uin, count)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if trailManager then
        trailManager:SetUnlockedEquipSlots(count)
        --gg.log("玩家", uin, "可携带尾迹栏位数量已设置为", count)
    end
end

---获取尾迹类型统计
---@param uin number 玩家ID
---@return table<string, number> 尾迹类型统计
function TrailMgr.GetTrailTypeStatistics(uin)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return {}
    end

    return trailManager:GetTrailTypeStatistics()
end

---查找指定名称的尾迹槽位
---@param uin number 玩家ID
---@param trailName string 尾迹名称
---@return table<number> 槽位列表
function TrailMgr.FindTrailSlotsByName(uin, trailName)
    local trailManager = TrailMgr.GetPlayerTrail(uin)
    if not trailManager then
        return {}
    end

    return trailManager:FindTrailSlotsByName(trailName)
end

return TrailMgr 