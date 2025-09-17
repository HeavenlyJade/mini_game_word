--- 翅膀相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local WingMgr = require(ServerStorage.MSystems.Pet.Mgr.WingMgr) ---@type WingMgr
local WingEventManager = require(ServerStorage.MSystems.Pet.EventManager.WingEventManager) ---@type WingEventManager

---@class WingCommand
local WingCommand = {}

-- 子命令处理器
WingCommand.handlers = {}

--- 私有方法：同步翅膀数据到客户端
---@param player MPlayer
function WingCommand._syncToClient(player)
    local updatedData, errorMsg = WingMgr.GetPlayerWingList(player.uin)
    if updatedData then
        WingEventManager.NotifyWingListUpdate(player.uin, updatedData)
        --gg.log("翅膀数据已通过指令同步到客户端", player.uin)
    else
        --gg.log("翅膀数据同步失败，无法获取最新列表", player.uin, errorMsg)
    end
end

--- 新增翅膀
---@param params table
---@param player MPlayer
function WingCommand.handlers.add(params, player)
    local wingName = params["翅膀"]
    local slotIndex = params["槽位"] and tonumber(params["槽位"]) or nil

    if not wingName then
        --player:SendHoverText("缺少 '翅膀' 字段")
        return false
    end

    local success, errorMsg, actualSlot = WingMgr.AddWingToSlot(player.uin, wingName, slotIndex)
    if success then
        local msg = string.format("新增物品 %s 添加翅膀: %s 到槽位 %d", player.name, wingName, actualSlot)
        --player:SendHoverText(msg)
        --gg.log(msg)
        WingCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("给玩家 %s 添加翅膀失败: %s", player.name, errorMsg)
        --player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 移除翅膀
---@param params table
---@param player MPlayer
function WingCommand.handlers.remove(params, player)
    local slotIndex = tonumber(params["槽位"])

    if not slotIndex then
        --player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local wingInstance = WingMgr.GetWingInstance(player.uin, slotIndex)
    if not wingInstance then
        local msg = string.format("槽位 %d 上没有翅膀", slotIndex)
        --player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
    local wingName = wingInstance:GetConfigName()

    local success, errorMsg = WingMgr.RemoveWingFromSlot(player.uin, slotIndex)
    if success then
        local msg = string.format("成功移除玩家 %s 在槽位 %d 的翅膀: %s", player.name, slotIndex, wingName)
        --player:SendHoverText(msg)
        --gg.log(msg)
        WingCommand._syncToClient(player) -- 同步数据到客户端
        return true
    else
        local msg = string.format("移除玩家 %s 的翅膀失败: %s", player.name, errorMsg)
        --player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 设置翅膀属性
---@param params table
---@param player MPlayer
function WingCommand.handlers.set(params, player)
    local slotIndex = tonumber(params["槽位"])
    local level = tonumber(params["等级"])
    local star = tonumber(params["星级"])

    if not slotIndex then
        --player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    if not level and not star then
        --player:SendHoverText("请至少提供 '等级' 或 '星级' 字段中的一个")
        return false
    end

    local wingInstance = WingMgr.GetWingInstance(player.uin, slotIndex)
    if not wingInstance then
        --player:SendHoverText("槽位 " .. slotIndex .. " 上没有翅膀")
        return false
    end

    -- 设置等级
    if level then
        local success, errorMsg = WingMgr.LevelUpWing(player.uin, slotIndex, level)
        if success then
            local msg = string.format("成功设置翅膀 %s (槽位 %d) 等级为 %d", wingInstance:GetConfigName(), slotIndex, level)
            --player:SendHoverText(msg)
            --gg.log(msg)
        else
            local msg = string.format("设置翅膀 %s (槽位 %d) 等级失败: %s", wingInstance:GetConfigName(), slotIndex, errorMsg)
            --player:SendHoverText(msg)
            --gg.log(msg)
        end
    end

    -- 设置星级
    if star then
        local currentStar = wingInstance:GetStarLevel()
        if star > currentStar then
            local upgradesNeeded = star - currentStar
            local allSuccess = true
            --gg.log(string.format("开始为翅膀 %s (槽位 %d) 升星，当前: %d, 目标: %d", wingInstance:GetConfigName(), slotIndex, currentStar, star))
            for i = 1, upgradesNeeded do
                local success, errorMsg = WingMgr.UpgradeWingStar(player.uin, slotIndex)
                if not success then
                    local msg = string.format("升星失败: 从 %d 星升到 %d 星时出错: %s (请检查升星材料)", currentStar, currentStar + 1, errorMsg or '未知错误')
                    --player:SendHoverText(msg)
                    --gg.log(msg)
                    allSuccess = false
                    break
                end
                currentStar = currentStar + 1 -- 更新当前星级
            end

            if allSuccess then
                local msg = string.format("成功将翅膀 %s (槽位 %d) 星级提升至 %d", wingInstance:GetConfigName(), slotIndex, star)
                --player:SendHoverText(msg)
                --gg.log(msg)
            end
        elseif star < currentStar then
             --player:SendHoverText("目标星级不能低于当前星级")
        else
             --player:SendHoverText("翅膀已达到目标星级")
        end
    end
    WingCommand._syncToClient(player) -- 在所有操作后统一同步数据
    return true
end

--- 新增翅膀栏位（新增背包容量和可携带数量）
---@param params table
---@param player MPlayer
function WingCommand.handlers.addslots(params, player)
    local carryCount = params["新增可携带"] and tonumber(params["新增可携带"])
    local bagCapacity = params["新增背包"] and tonumber(params["新增背包"])

    if not carryCount and not bagCapacity then
        --player:SendHoverText("请至少提供 '可携带' 或 '背包' 字段中的一个")
        return false
    end

    local uin = player.uin
    local anythingChanged = false

    if carryCount then
        if WingMgr.AddUnlockedEquipSlots(uin, carryCount) then
            --player:SendHoverText("成功新增可携带翅膀栏位: " .. carryCount)
            anythingChanged = true
        else
            --player:SendHoverText("新增可携带栏位失败, 可能是玩家数据未加载")
        end
    end

    if bagCapacity then
        if WingMgr.AddWingBagCapacity(uin, bagCapacity) then
            --player:SendHoverText("成功新增翅膀背包容量: " .. bagCapacity)
            anythingChanged = true
        else
            --player:SendHoverText("新增背包容量失败, 可能是玩家数据未加载")
        end
    end

    if anythingChanged then
        WingCommand._syncToClient(player)
    end

    return true
end

--- 减少翅膀栏位
---@param params table
---@param player MPlayer
function WingCommand.handlers.reduceslots(params, player)
    local carryCount = params["减少可携带"] and tonumber(params["减少可携带"])
    local bagCapacity = params["减少背包"] and tonumber(params["减少背包"])

    if not carryCount and not bagCapacity then
        --player:SendHoverText("请至少提供 '可携带' 或 '背包' 字段中的一个")
        return false
    end

    local uin = player.uin
    local anythingChanged = false

    if carryCount then
        if WingMgr.ReduceUnlockedEquipSlots(uin, carryCount) then
            --player:SendHoverText("成功减少可携带翅膀栏位: " .. carryCount)
            anythingChanged = true
        else
            --player:SendHoverText("减少可携带栏位失败, 可能是玩家数据未加载")
        end
    end

    if bagCapacity then
        if WingMgr.ReduceWingBagCapacity(uin, bagCapacity) then
            --player:SendHoverText("成功减少翅膀背包容量: " .. bagCapacity)
            anythingChanged = true
        else
            --player:SendHoverText("减少背包容量失败, 可能是玩家数据未加载")
        end
    end

    if anythingChanged then
        WingCommand._syncToClient(player)
    end

    return true
end

--- 设置翅膀栏位
---@param params table
---@param player MPlayer
function WingCommand.handlers.setslots(params, player)
    local carryCount = params["可携带"] and tonumber(params["可携带"])
    local bagCapacity = params["背包"] and tonumber(params["背包"])

    if not carryCount and not bagCapacity then
        --player:SendHoverText("请至少提供 '可携带' 或 '背包' 字段中的一个")
        return false
    end

    local uin = player.uin
    local anythingChanged = false

    if carryCount then
        if WingMgr.SetUnlockedEquipSlots(uin, carryCount) then
            --player:SendHoverText("成功设置可携带翅膀栏位为: " .. carryCount)
            anythingChanged = true
        else
            --player:SendHoverText("设置可携带栏位失败, 可能是玩家数据未加载")
        end
    end

    if bagCapacity then
        if WingMgr.SetWingBagCapacity(uin, bagCapacity) then
            --player:SendHoverText("成功设置翅膀背包容量为: " .. bagCapacity)
            anythingChanged = true
        else
            --player:SendHoverText("设置背包容量失败, 可能是玩家数据未加载")
        end
    end

    if anythingChanged then
        WingCommand._syncToClient(player)
    end

    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["删除"] = "remove",
    ["设置"] = "set",
    ["栏位设置"] = "setslots",
    ["栏位新增"] = "addslots",
    ["栏位减少"] = "reduceslots"
}

--- 翅膀操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function WingCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        --player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '删除', '设置', '栏位设置'")
        return false
    end

    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        --player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '删除', '设置', '栏位设置'")
        return false
    end

    local handler = WingCommand.handlers[handlerName]
    if handler then
        --gg.log("翅膀命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- 理论上不会执行到这里，因为上面已经检查过了
        --player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return WingCommand
