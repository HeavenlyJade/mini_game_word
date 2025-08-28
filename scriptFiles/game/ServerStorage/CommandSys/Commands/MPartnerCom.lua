--- 伙伴相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local PartnerMgr = require(ServerStorage.MSystems.Pet.Mgr.PartnerMgr) ---@type PartnerMgr
local PartnerEventManager = require(ServerStorage.MSystems.Pet.EventManager.PartnerEventManager) ---@type PartnerEventManager

---@class PartnerCommand
local PartnerCommand = {}

-- 子命令处理器
PartnerCommand.handlers = {}

--- 私有方法：同步伙伴数据到客户端
---@param player MPlayer
function PartnerCommand._syncToClient(player)
    local updatedData, errorMsg = PartnerMgr.GetPlayerPartnerList(player.uin)
    if updatedData then
        PartnerEventManager.NotifyPartnerListUpdate(player.uin, updatedData)
        --gg.log("伙伴数据已通过指令同步到客户端", player.uin)
    else
        --gg.log("伙伴数据同步失败，无法获取最新列表", player.uin, errorMsg)
    end
end

--- 新增伙伴
---@param params table
---@param player MPlayer
function PartnerCommand.handlers.add(params, player)
    local partnerName = params["伙伴"]
    local slotIndex = params["槽位"] and tonumber(params["槽位"]) or nil

    if not partnerName then
        player:SendHoverText("缺少 '伙伴' 字段")
        return false
    end

    local success, errorMsg, actualSlot = PartnerMgr.AddPartnerToSlot(player.uin, partnerName, slotIndex)
    if success then
        local msg = string.format("获取伙伴 %s 到槽位 %d", partnerName, actualSlot)
        player:SendHoverText(msg)
        --gg.log(msg)
        PartnerCommand._syncToClient(player) -- 【修复】同步数据到客户端
        return true
    else
        local msg = string.format("给玩家 %s 添加伙伴失败: %s", player.name, errorMsg)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 移除伙伴
---@param params table
---@param player MPlayer
function PartnerCommand.handlers.remove(params, player)
    local slotIndex = tonumber(params["槽位"])

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local partnerInstance = PartnerMgr.GetPartnerInstance(player.uin, slotIndex)
    if not partnerInstance then
        local msg = string.format("槽位 %d 上没有伙伴", slotIndex)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
    local partnerName = partnerInstance:GetConfigName()

    local success, errorMsg = PartnerMgr.RemovePartnerFromSlot(player.uin, slotIndex)
    if success then
        local msg = string.format("成功移除玩家 %s 在槽位 %d 的伙伴: %s", player.name, slotIndex, partnerName)
        player:SendHoverText(msg)
        --gg.log(msg)
        PartnerCommand._syncToClient(player) -- 【修复】同步数据到客户端
        return true
    else
        local msg = string.format("移除玩家 %s 的伙伴失败: %s", player.name, errorMsg)
        player:SendHoverText(msg)
        --gg.log(msg)
        return false
    end
end

--- 设置伙伴属性
---@param params table
---@param player MPlayer
function PartnerCommand.handlers.set(params, player)
    local slotIndex = tonumber(params["槽位"])
    local level = tonumber(params["等级"])
    local star = tonumber(params["星级"])

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    if not level and not star then
        player:SendHoverText("请至少提供 '等级' 或 '星级' 字段中的一个")
        return false
    end

    local partnerInstance = PartnerMgr.GetPartnerInstance(player.uin, slotIndex)
    if not partnerInstance then
        player:SendHoverText("槽位 " .. slotIndex .. " 上没有伙伴")
        return false
    end

    -- 设置等级
    if level then
        local success, errorMsg = PartnerMgr.LevelUpPartner(player.uin, slotIndex, level)
        if success then
            local msg = string.format("成功设置伙伴 %s (槽位 %d) 等级为 %d", partnerInstance:GetConfigName(), slotIndex, level)
            player:SendHoverText(msg)
            --gg.log(msg)
        else
            local msg = string.format("设置伙伴 %s (槽位 %d) 等级失败: %s", partnerInstance:GetConfigName(), slotIndex, errorMsg)
            player:SendHoverText(msg)
            --gg.log(msg)
        end
    end

    -- 设置星级
    if star then
        local currentStar = partnerInstance:GetStarLevel()
        if star > currentStar then
            local upgradesNeeded = star - currentStar
            local allSuccess = true
            --gg.log(string.format("开始为伙伴 %s (槽位 %d) 升星，当前: %d, 目标: %d", partnerInstance:GetConfigName(), slotIndex, currentStar, star))
            for i = 1, upgradesNeeded do
                local success, errorMsg = PartnerMgr.UpgradePartnerStar(player.uin, slotIndex)
                if not success then
                    local msg = string.format("升星失败: 从 %d 星升到 %d 星时出错: %s (请检查升星材料)", currentStar, currentStar + 1, errorMsg or '未知错误')
                    player:SendHoverText(msg)
                    --gg.log(msg)
                    allSuccess = false
                    break
                end
                currentStar = currentStar + 1 -- 更新当前星级
            end

            if allSuccess then
                local msg = string.format("成功将伙伴 %s (槽位 %d) 星级提升至 %d", partnerInstance:GetConfigName(), slotIndex, star)
                player:SendHoverText(msg)
                --gg.log(msg)
            end
        elseif star < currentStar then
             player:SendHoverText("目标星级不能低于当前星级")
        else
             player:SendHoverText("伙伴已达到目标星级")
        end
    end
    PartnerCommand._syncToClient(player) -- 【修复】在所有操作后统一同步数据
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["删除"] = "remove",
    ["设置"] = "set"
}

--- 伙伴操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function PartnerCommand.main(params, player)
    local operationType = params["操作类型"]

    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '删除', '设置'")
        return false
    end

    -- 将中文指令映射到英文处理器
    local handlerName = operationMap[operationType]
    if not handlerName then
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '删除', '设置'")
        return false
    end

    local handler = PartnerCommand.handlers[handlerName]
    if handler then
        --gg.log("伙伴命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name,handler)
        return handler(params, player)
    else
        -- 理论上不会执行到这里，因为上面已经检查过了
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return PartnerCommand
