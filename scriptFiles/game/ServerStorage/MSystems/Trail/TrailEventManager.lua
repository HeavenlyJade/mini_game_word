-- TrailEventManager.lua
-- 尾迹事件管理器
-- 负责处理所有尾迹相关的客户端请求和服务器响应

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ServerEventManager = require(MainStorage.Code.MServer.Event.ServerEventManager) ---@type ServerEventManager
local TrailEventConfig = require(MainStorage.Code.Event.EventTrail) ---@type TrailEventConfig
local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class TrailEventManager
local TrailEventManager = {}

-- 将配置导入到当前模块
TrailEventManager.REQUEST = TrailEventConfig.REQUEST
TrailEventManager.RESPONSE = TrailEventConfig.RESPONSE
TrailEventManager.NOTIFY = TrailEventConfig.NOTIFY

--- 初始化尾迹事件管理器
function TrailEventManager.Init()
    TrailEventManager.RegisterEventHandlers()
end

--- 注册所有事件处理器
function TrailEventManager.RegisterEventHandlers()
    -- 获取尾迹列表
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.GET_TRAIL_LIST, function(evt) TrailEventManager.HandleGetTrailList(evt) end)

    -- 装备/卸下尾迹
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.EQUIP_TRAIL, function(evt) TrailEventManager.HandleEquipTrail(evt) end)
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.UNEQUIP_TRAIL, function(evt) TrailEventManager.HandleUnequipTrail(evt) end)

    -- 删除尾迹
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.DELETE_TRAIL, function(evt) TrailEventManager.HandleDeleteTrail(evt) end)

    -- 切换尾迹锁定状态
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.TOGGLE_TRAIL_LOCK, function(evt) TrailEventManager.HandleToggleTrailLock(evt) end)

    -- 重命名尾迹
    ServerEventManager.Subscribe(TrailEventManager.REQUEST.RENAME_TRAIL, function(evt) TrailEventManager.HandleRenameTrail(evt) end)
end

--- 验证玩家
---@param evt table 事件参数
---@return MPlayer|nil 玩家对象
function TrailEventManager.ValidatePlayer(evt)
    local env_player = evt.player
    local uin = env_player.uin
    if not uin then
        --gg.log("尾迹事件缺少玩家UIN参数")
        return nil
    end

    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        --gg.log("尾迹事件找不到玩家: " .. uin)
        return nil
    end

    return player
end

--- 处理获取尾迹列表请求
---@param evt table 事件数据
function TrailEventManager.HandleGetTrailList(evt)
    --gg.log("获取尾迹列表", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local result, errorMsg = TrailMgr.GetPlayerTrailList(player.uin)
    if result then
        TrailEventManager.NotifyTrailListUpdate(player.uin, result)
    else
        --gg.log("获取尾迹列表失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "获取尾迹列表失败")
    end
end

--- 处理装备尾迹请求
---@param evt table 事件数据 {args = {trailSlotId, equipSlotId}}
function TrailEventManager.HandleEquipTrail(evt)
    --gg.log("处理装备尾迹请求", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local trailSlotId = args.trailSlotId
    local equipSlotId = args.equipSlotId

    if not trailSlotId or not equipSlotId then
        --gg.log("装备尾迹缺少参数", player.uin)
        TrailEventManager.NotifyError(player.uin, -1, "装备尾迹缺少参数")
        return
    end

    local success, errorMsg = TrailMgr.EquipTrail(player.uin, trailSlotId, equipSlotId)

    if success then
        local updatedData, getError = TrailMgr.GetPlayerTrailList(player.uin)
        if updatedData then
            TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        end
        --gg.log("装备尾迹成功", player.uin, "尾迹槽位", trailSlotId, "装备栏", equipSlotId)
        
        -- 发送装备成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.EQUIP_TRAIL_RESPONSE,
            success = true,
            trailSlotId = trailSlotId,
            equipSlotId = equipSlotId
        })
    else
        --gg.log("装备尾迹失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "装备尾迹失败")
        
        -- 发送装备失败响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.EQUIP_TRAIL_RESPONSE,
            success = false,
            error = errorMsg or "装备尾迹失败"
        })
    end
end

--- 处理卸下尾迹请求
---@param evt table 事件数据 {args = {equipSlotId}}
function TrailEventManager.HandleUnequipTrail(evt)
    --gg.log("处理卸下尾迹请求", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local equipSlotId = args.equipSlotId

    if not equipSlotId then
        --gg.log("卸下尾迹缺少参数", player.uin)
        TrailEventManager.NotifyError(player.uin, -1, "卸下尾迹缺少参数")
        return
    end

    local success, errorMsg = TrailMgr.UnequipTrail(player.uin, equipSlotId)

    if success then
        local updatedData, getError = TrailMgr.GetPlayerTrailList(player.uin)
        if updatedData then
            TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        end
        --gg.log("卸下尾迹成功", player.uin, "装备栏", equipSlotId)
        
        -- 发送卸下成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.UNEQUIP_TRAIL_RESPONSE,
            success = true,
            equipSlotId = equipSlotId
        })
    else
        --gg.log("卸下尾迹失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "卸下尾迹失败")
        
        -- 发送卸下失败响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.UNEQUIP_TRAIL_RESPONSE,
            success = false,
            error = errorMsg or "卸下尾迹失败"
        })
    end
end

--- 处理删除尾迹请求
---@param evt table 事件数据 {args = {slotIndex}}
function TrailEventManager.HandleDeleteTrail(evt)
    --gg.log("处理删除尾迹请求", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        --gg.log("删除尾迹缺少槽位参数", player.uin)
        TrailEventManager.NotifyError(player.uin, -1, "删除尾迹缺少槽位参数")
        return
    end

    local success, errorMsg = TrailMgr.DeleteTrail(player.uin, slotIndex)

    if success then
        local updatedData, getError = TrailMgr.GetPlayerTrailList(player.uin)
        if updatedData then
            TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        end
        --gg.log("删除尾迹成功", player.uin, "槽位", slotIndex)
        
        -- 发送删除成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.DELETE_TRAIL_RESPONSE,
            success = true,
            slotIndex = slotIndex
        })
    else
        --gg.log("删除尾迹失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "删除尾迹失败")
        
        -- 发送删除失败响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.DELETE_TRAIL_RESPONSE,
            success = false,
            error = errorMsg or "删除尾迹失败"
        })
    end
end

--- 处理切换尾迹锁定状态请求
---@param evt table 事件数据 {args = {slotIndex}}
function TrailEventManager.HandleToggleTrailLock(evt)
    --gg.log("处理切换尾迹锁定状态请求", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex

    if not slotIndex then
        --gg.log("切换尾迹锁定状态缺少槽位参数", player.uin)
        TrailEventManager.NotifyError(player.uin, -1, "切换尾迹锁定状态缺少槽位参数")
        return
    end

    local success, errorMsg, newLockStatus = TrailMgr.ToggleTrailLock(player.uin, slotIndex)

    if success then
        local updatedData, getError = TrailMgr.GetPlayerTrailList(player.uin)
        if updatedData then
            TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        end
        --gg.log("切换尾迹锁定状态成功", player.uin, "槽位", slotIndex, "新状态", newLockStatus)
        
        -- 发送切换锁定成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.TOGGLE_LOCK_RESPONSE,
            success = true,
            slotIndex = slotIndex,
            isLocked = newLockStatus
        })
    else
        --gg.log("切换尾迹锁定状态失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "切换尾迹锁定状态失败")
        
        -- 发送切换锁定失败响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.TOGGLE_LOCK_RESPONSE,
            success = false,
            error = errorMsg or "切换尾迹锁定状态失败"
        })
    end
end

--- 处理重命名尾迹请求
---@param evt table 事件数据 {args = {slotIndex, newName}}
function TrailEventManager.HandleRenameTrail(evt)
    --gg.log("处理重命名尾迹请求", evt)
    local player = TrailEventManager.ValidatePlayer(evt)
    if not player then return end

    local args = evt.args or {}
    local slotIndex = args.slotIndex
    local newName = args.newName

    if not slotIndex or not newName then
        --gg.log("重命名尾迹缺少参数", player.uin, "槽位", slotIndex, "新名称", newName)
        TrailEventManager.NotifyError(player.uin, -1, "重命名尾迹缺少参数")
        return
    end

    local success, errorMsg = TrailMgr.RenameTrail(player.uin, slotIndex, newName)

    if success then
        local updatedData, getError = TrailMgr.GetPlayerTrailList(player.uin)
        if updatedData then
            TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        end
        --gg.log("重命名尾迹成功", player.uin, "槽位", slotIndex, "新名称", newName)
        
        -- 发送重命名成功响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.RENAME_TRAIL_RESPONSE,
            success = true,
            slotIndex = slotIndex,
            newName = newName
        })
    else
        --gg.log("重命名尾迹失败", player.uin, errorMsg)
        TrailEventManager.NotifyError(player.uin, -1, errorMsg or "重命名尾迹失败")
        
        -- 发送重命名失败响应
        gg.network_channel:fireClient(player.uin, {
            cmd = TrailEventManager.RESPONSE.RENAME_TRAIL_RESPONSE,
            success = false,
            error = errorMsg or "重命名尾迹失败"
        })
    end
end

--- 通知客户端尾迹列表更新
---@param uin number 玩家ID
---@param trailData table 完整的尾迹数据
function TrailEventManager.NotifyTrailListUpdate(uin, trailData)
    --gg.log("通知客户端尾迹列表更新", uin, trailData)
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.NOTIFY.TRAIL_LIST_UPDATE,
        trailList = trailData.companionList or {},     -- 尾迹列表
        activeSlots = trailData.activeSlots or {},     -- 激活槽位映射
        equipSlotIds = trailData.equipSlotIds or {},   -- 可用装备栏ID
        trailSlots = trailData.trailSlots or 30,       -- 背包容量
        unlockedEquipSlots = trailData.unlockedEquipSlots or 1  -- 已解锁装备栏数量
    })
end

--- 通知客户端单个尾迹更新
---@param uin number 玩家ID
---@param trailData table 尾迹数据
function TrailEventManager.NotifyTrailUpdate(uin, trailData)
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.NOTIFY.TRAIL_UPDATE,
        trailData = trailData
    })
end

--- 通知客户端获得尾迹
---@param uin number 玩家ID
---@param trailName string 尾迹名称
---@param slotIndex number 槽位索引
function TrailEventManager.NotifyTrailObtained(uin, trailName, slotIndex)
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.NOTIFY.TRAIL_OBTAINED,
        trailName = trailName,
        slotIndex = slotIndex
    })
end

--- 通知客户端尾迹被移除
---@param uin number 玩家ID
---@param slotIndex number 槽位索引
function TrailEventManager.NotifyTrailRemoved(uin, slotIndex)
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.NOTIFY.TRAIL_REMOVED,
        slotIndex = slotIndex
    })
end

--- 通知客户端尾迹装备状态变化
---@param uin number 玩家ID
---@param equipSlotId string 装备栏ID
---@param trailSlotId number|nil 尾迹槽位ID（nil表示卸下）
function TrailEventManager.NotifyTrailEquipStatusChanged(uin, equipSlotId, trailSlotId)
    if trailSlotId then
        -- 装备尾迹
        gg.network_channel:fireClient(uin, {
            cmd = TrailEventManager.NOTIFY.TRAIL_EQUIPPED,
            equipSlotId = equipSlotId,
            trailSlotId = trailSlotId
        })
    else
        -- 卸下尾迹
        gg.network_channel:fireClient(uin, {
            cmd = TrailEventManager.NOTIFY.TRAIL_UNEQUIPPED,
            equipSlotId = equipSlotId
        })
    end
end

--- 通知客户端错误信息
---@param uin number 玩家ID
---@param errorCode number 错误代码
---@param errorMsg string 错误信息
function TrailEventManager.NotifyError(uin, errorCode, errorMsg)
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.RESPONSE.ERROR_RESPONSE,
        errorCode = errorCode,
        errorMsg = errorMsg
    })
    
    -- 同时发送错误通知
    gg.network_channel:fireClient(uin, {
        cmd = TrailEventManager.NOTIFY.ERROR_NOTIFY,
        errorCode = errorCode,
        errorMsg = errorMsg
    })
end

return TrailEventManager 