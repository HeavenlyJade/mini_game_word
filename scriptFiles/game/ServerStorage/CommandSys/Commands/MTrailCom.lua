--- 尾迹相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local TrailMgr = require(ServerStorage.MSystems.Trail.TrailMgr) ---@type TrailMgr
local TrailEventManager = require(ServerStorage.MSystems.Trail.TrailEventManager) ---@type TrailEventManager

---@class TrailCommand
local TrailCommand = {}

-- 子命令处理器
TrailCommand.handlers = {}

--- 私有方法：同步尾迹数据到客户端
---@param player MPlayer
function TrailCommand._syncToClient(player)
    local updatedData, errorMsg = TrailMgr.GetPlayerTrailList(player.uin)
    if updatedData then
        TrailEventManager.NotifyTrailListUpdate(player.uin, updatedData)
        --gg.log("尾迹数据已通过指令同步到客户端", player.uin)
    else
        --gg.log("尾迹数据同步失败，无法获取最新列表", player.uin, errorMsg)
    end
end

--- 新增尾迹
---@param params table
---@param player MPlayer
function TrailCommand.handlers.add(params, player)
    local trailName = params["尾迹"]
    local slotIndex = params["槽位"] and tonumber(params["槽位"]) or nil

    if not trailName then
        player:SendHoverText("缺少 '尾迹' 字段")
        return false
    end

    local success, actualSlot = TrailMgr.AddTrail(player, trailName, slotIndex)
    if success then
        local msg = string.format("新增物品 %s 添加尾迹: %s 到槽位 %d", player.name, trailName, actualSlot)
        player:SendHoverText(msg)
        --gg.log(msg)
        TrailCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("给玩家 %s 添加尾迹失败: 无法添加尾迹", player.name)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 移除尾迹
---@param params table
---@param player MPlayer
function TrailCommand.handlers.remove(params, player)
    local slotIndex = tonumber(params["槽位"])

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local trailData = TrailMgr.GetTrailBySlot(player.uin, slotIndex)
    if not trailData then
        local msg = string.format("槽位 %d 上没有尾迹", slotIndex)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
    local trailName = trailData.trailName

    local success, errorMsg = TrailMgr.RemoveTrailFromSlot(player.uin, slotIndex)
    if success then
        local msg = string.format("成功移除玩家 %s 在槽位 %d 的尾迹: %s", player.name, slotIndex, trailName)
        player:SendHoverText(msg)
        --gg.log(msg)
        TrailCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("移除玩家 %s 的尾迹失败: %s", player.name, errorMsg)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 设置尾迹属性
---@param params table
---@param player MPlayer
function TrailCommand.handlers.set(params, player)
    local slotIndex = tonumber(params["槽位"])
    local customName = params["自定义名称"]
    local isLocked = params["锁定"]

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local trailData = TrailMgr.GetTrailBySlot(player.uin, slotIndex)
    if not trailData then
        local msg = string.format("槽位 %d 上没有尾迹", slotIndex)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end

    local anythingChanged = false

    -- 设置自定义名称
    if customName then
        local success, errorMsg = TrailMgr.RenameTrail(player.uin, slotIndex, customName)
        if success then
            local msg = string.format("成功将槽位 %d 的尾迹重命名为: %s", slotIndex, customName)
            player:SendHoverText(msg)
            --gg.log(msg)
            anythingChanged = true
        else
            local msg = string.format("重命名尾迹失败: %s", errorMsg)
            player:SendHoverText(msg)
            --gg.log(msg)
            return false
        end
    end

    -- 设置锁定状态
    if isLocked ~= nil then
        local targetLocked = (isLocked == "true" or isLocked == true)
        local currentLocked = trailData.isLocked or false
        
        if targetLocked ~= currentLocked then
            local success, errorMsg, newLockStatus = TrailMgr.ToggleTrailLock(player.uin, slotIndex)
            if success then
                local lockText = newLockStatus and "锁定" or "解锁"
                local msg = string.format("成功%s槽位 %d 的尾迹", lockText, slotIndex)
                player:SendHoverText(msg)
                --gg.log(msg)
                anythingChanged = true
            else
                local msg = string.format("设置尾迹锁定状态失败: %s", errorMsg)
                player:SendHoverText(msg)
                --gg.log(msg)
                return false
            end
        else
            local lockText = currentLocked and "已锁定" or "未锁定"
            player:SendHoverText(string.format("尾迹%s状态无需更改", lockText))
        end
    end

    if anythingChanged then
        TrailCommand._syncToClient(player) -- 同步数据到客户端
    end

    return true
end

--- 装备尾迹
---@param params table
---@param player MPlayer
function TrailCommand.handlers.equip(params, player)
    local slotIndex = tonumber(params["槽位"])
    local equipSlotId = params["装备栏"] or "尾迹" -- 默认装备栏

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local trailData = TrailMgr.GetTrailBySlot(player.uin, slotIndex)
    if not trailData then
        local msg = string.format("槽位 %d 上没有尾迹", slotIndex)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end

    local success, errorMsg = TrailMgr.EquipTrail(player.uin, slotIndex, equipSlotId)
    if success then
        local msg = string.format("成功装备玩家 %s 槽位 %d 的尾迹: %s 到装备栏 %s", 
                                 player.name, slotIndex, trailData.trailName, equipSlotId)
        player:SendHoverText(msg)
        --gg.log(msg)
        TrailCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("装备尾迹失败: %s", errorMsg)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 卸下尾迹
---@param params table
---@param player MPlayer
function TrailCommand.handlers.unequip(params, player)
    local equipSlotId = params["装备栏"] or "尾迹" -- 默认装备栏

    local success, errorMsg = TrailMgr.UnequipTrail(player.uin, equipSlotId)
    if success then
        local msg = string.format("成功卸下玩家 %s 装备栏 %s 的尾迹", player.name, equipSlotId)
        player:SendHoverText(msg)
        --gg.log(msg)
        TrailCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("卸下尾迹失败: %s", errorMsg)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 栏位设置
---@param params table
---@param player MPlayer
function TrailCommand.handlers.setslots(params, player)
    local carryCount = params["可携带"] and tonumber(params["可携带"]) or nil
    local bagCapacity = params["背包"] and tonumber(params["背包"]) or nil

    if not carryCount and not bagCapacity then
        player:SendHoverText("请至少提供 '可携带' 或 '背包' 字段中的一个")
        return false
    end

    local uin = player.uin
    local anythingChanged = false

    if carryCount then
        TrailMgr.SetUnlockedEquipSlots(uin, carryCount)
        player:SendHoverText("成功设置可携带尾迹栏位为: " .. carryCount)
        anythingChanged = true
    end

    if bagCapacity then
        TrailMgr.SetTrailBagCapacity(uin, bagCapacity)
        player:SendHoverText("成功设置尾迹背包容量为: " .. bagCapacity)
        anythingChanged = true
    end

    if anythingChanged then
        TrailCommand._syncToClient(player)
    end

    return true
end

--- 查看尾迹信息
---@param params table
---@param player MPlayer
function TrailCommand.handlers.info(params, player)
    local slotIndex = params["槽位"] and tonumber(params["槽位"]) or nil

    if slotIndex then
        -- 查看指定槽位的尾迹信息
        local trailData = TrailMgr.GetTrailBySlot(player.uin, slotIndex)
        if trailData then
            local lockStatus = trailData.isLocked and "已锁定" or "未锁定"
            local customName = trailData.customName and trailData.customName ~= "" and trailData.customName or "无"
            local msg = string.format("槽位 %d: %s | 自定义名称: %s | 状态: %s", 
                                     slotIndex, trailData.trailName, customName, lockStatus)
            player:SendHoverText(msg)
        else
            player:SendHoverText(string.format("槽位 %d 上没有尾迹", slotIndex))
        end
    else
        -- 查看所有尾迹信息
        local trailData, errorMsg = TrailMgr.GetPlayerTrailList(player.uin)
        if trailData then
            local trailCount = TrailMgr.GetTrailCount(player.uin)
            local stats = TrailMgr.GetTrailTypeStatistics(player.uin)
            
            local msg = string.format("玩家 %s 拥有 %d 个尾迹", player.name, trailCount)
            player:SendHoverText(msg)
            
            -- 显示尾迹类型统计
            for trailName, count in pairs(stats) do
                local statMsg = string.format("  %s: %d个", trailName, count)
                player:SendHoverText(statMsg)
            end
            
            -- 显示装备状态
            if trailData.activeSlots then
                for equipSlotId, trailSlotId in pairs(trailData.activeSlots) do
                    if trailSlotId and trailSlotId > 0 then
                        local equippedTrail = TrailMgr.GetTrailBySlot(player.uin, trailSlotId)
                        if equippedTrail then
                            local equipMsg = string.format("  装备栏 %s: 槽位 %d (%s)", 
                                                          equipSlotId, trailSlotId, equippedTrail.trailName)
                            player:SendHoverText(equipMsg)
                        end
                    end
                end
            end
        else
            player:SendHoverText("获取尾迹信息失败: " .. (errorMsg or "未知错误"))
        end
    end
    
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["删除"] = "remove", 
    ["移除"] = "remove",
    ["设置"] = "set",
    ["装备"] = "equip",
    ["卸下"] = "unequip",
    ["栏位设置"] = "setslots",
    ["信息"] = "info",
    ["查看"] = "info"
}

--- 尾迹操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function TrailCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '删除', '设置', '装备', '卸下', '栏位设置', '信息'")
        return false
    end

    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        local validTypes = "'新增', '删除', '设置', '装备', '卸下', '栏位设置', '信息'"
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: " .. validTypes)
        return false
    end

    local handler = TrailCommand.handlers[handlerName]
    if handler then
        --gg.log("尾迹命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name, handler)
        return handler(params, player)
    else
        -- 理论上不会执行到这里，因为上面已经检查过了
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return TrailCommand 