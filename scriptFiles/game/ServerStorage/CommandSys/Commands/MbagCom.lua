--- 背包物品相关命令处理器
--- V109 miniw-haima

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal)    ---@type gg
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr

---@class BagCommand
local BagCommand = {}

--- 新增物品
---@param params table
---@param player MPlayer
function BagCommand.add(params, player)
    local itemType = params["物品类型"]
    local amount = tonumber(params["数量"]) or 1

    if not itemType then
        player:SendHoverText("缺少'物品类型'字段")
        return false
    end

    if amount <= 0 then
        player:SendHoverText("物品数量必须大于0")
        return false
    end

    local success = BagMgr.AddItem(player, itemType, amount)
    if success then
        local msg = string.format("成功给玩家 %s 添加物品: %s x%d", player.name, itemType, amount)
        player:SendHoverText(msg)
        gg.log(msg)
        BagMgr.ForceSyncToClient(player.uin)
        return true
    else
        local msg = string.format("给玩家 %s 添加物品失败: %s x%d", player.name, itemType, amount)
        player:SendHoverText(msg)
        gg.log(msg)
        return false
    end
end

--- 减少物品
---@param params table
---@param player MPlayer
function BagCommand.remove(params, player)
    local itemType = params["物品类型"]
    local amount = tonumber(params["数量"]) or 1

    if not itemType then
        player:SendHoverText("缺少'物品类型'字段")
        return false
    end

    if amount <= 0 then
        player:SendHoverText("物品数量必须大于0")
        return false
    end

    local success = BagMgr.RemoveItem(player, itemType, amount)
    if success then
        local msg = string.format("成功从玩家 %s 移除物品: %s x%d", player.name, itemType, amount)
        player:SendHoverText(msg)
        gg.log(msg)
        BagMgr.ForceSyncToClient(player.uin)
        return true
    else
        local msg = string.format("从玩家 %s 移除物品失败 (可能数量不足): %s x%d", player.name, itemType, amount)
        player:SendHoverText(msg)
        gg.log(msg)
        return false
    end
end

--- 设置物品数量
---@param params table
---@param player MPlayer
function BagCommand.set(params, player)
    local itemType = params["物品类型"]
    local amount = tonumber(params["数量"]) or 0

    if not itemType then
        player:SendHoverText("缺少'物品类型'字段")
        return false
    end

    if amount < 0 then
        player:SendHoverText("物品数量不能为负数")
        return false
    end

    -- 获取玩家背包
    local bag = BagMgr.GetPlayerBag(player.uin)
    if not bag then
        player:SendHoverText("玩家背包不存在")
        return false
    end

    -- 获取当前物品数量
    local currentAmount = bag:GetItemAmount(itemType)

    if amount == 0 then
        -- 设置为0，直接移除所有该物品
        if currentAmount > 0 then
            local success = BagMgr.RemoveItem(player, itemType, currentAmount)
            if success then
                local msg = string.format("成功清空玩家 %s 的物品: %s", player.name, itemType)
                player:SendHoverText(msg)
                gg.log(msg)
                return true
            else
                local msg = string.format("清空玩家 %s 的物品失败: %s", player.name, itemType)
                player:SendHoverText(msg)
                gg.log(msg)
                return false
            end
        else
            local msg = string.format("玩家 %s 没有物品: %s", player.name, itemType)
            player:SendHoverText(msg)
            gg.log(msg)
            return true
        end
    else
        -- 设置指定数量
        if currentAmount == amount then
            local msg = string.format("玩家 %s 的物品 %s 数量已经是 %d", player.name, itemType, amount)
            player:SendHoverText(msg)
            gg.log(msg)
            return true
        elseif currentAmount > amount then
            -- 需要减少
            local removeAmount = currentAmount - amount
            local success = BagMgr.RemoveItem(player, itemType, removeAmount)
            if success then
                local msg = string.format("成功设置玩家 %s 的物品数量: %s %d→%d", player.name, itemType, currentAmount, amount)
                player:SendHoverText(msg)
                gg.log(msg)
                return true
            else
                local msg = string.format("设置玩家 %s 的物品数量失败: %s", player.name, itemType)
                player:SendHoverText(msg)
                gg.log(msg)
                return false
            end
        else
            -- 需要增加
            local addAmount = amount - currentAmount
            local success = BagMgr.AddItem(player, itemType, addAmount)
            if success then
                local msg = string.format("成功设置玩家 %s 的物品数量: %s %d→%d", player.name, itemType, currentAmount, amount)
                player:SendHoverText(msg)
                gg.log(msg)
                return true
            else
                local msg = string.format("设置玩家 %s 的物品数量失败: %s", player.name, itemType)
                player:SendHoverText(msg)
                gg.log(msg)
                return false
            end
        end
    end
end

--- 背包物品操作指令入口
---@param params table 背包命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function BagCommand.main(params, player)
    local operationType = params["操作类型"]
    local itemType = params["物品类型"]
    local amount = tonumber(params["数量"]) or 1

    -- 参数验证
    if not operationType then
        player:SendHoverText("缺少'操作类型'字段。有效类型: '新增', '减少', '设置'")
        return false
    end

    if not itemType then
        player:SendHoverText("缺少'物品类型'字段")
        return false
    end

    gg.log("背包命令执行", "操作类型:", operationType, "物品类型:", itemType, "数量:", amount, "执行者:", player.name)

    if operationType == "新增" then
        return BagCommand.add(params, player)
    elseif operationType == "减少" then
        return BagCommand.remove(params, player)
    elseif operationType == "设置" then
        return BagCommand.set(params, player)
    else
        player:SendHoverText("未知的操作类型: " .. operationType .. "。有效类型: '新增', '减少', '设置'")
        return false
    end
end

return BagCommand
