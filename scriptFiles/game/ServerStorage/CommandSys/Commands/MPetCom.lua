--- 宠物相关命令处理器

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local PetMgr = require(ServerStorage.MSystems.Pet.Mgr.PetMgr) ---@type PetMgr

---@class PetCommand
local PetCommand = {}

-- 子命令处理器
PetCommand.handlers = {}

--- 新增宠物
---@param params table
---@param player MPlayer
function PetCommand.handlers.add(params, player)
    local petName = params["宠物名称"]
    local slotIndex = params["槽位"] and tonumber(params["槽位"]) or nil

    if not petName then
        player:SendHoverText("缺少 '宠物名称' 字段")
        return false
    end

    local success, actualSlot = PetMgr.AddPet(player, petName, slotIndex)
    if success then
        local msg = string.format("成功给玩家 %s 添加宠物: %s 到槽位 %d", player.name, petName, actualSlot)
        player:SendHoverText(msg)
        gg.log(msg)
        return true
    else
        local msg = string.format("给玩家 %s 添加宠物失败: %s", player.name, petName)
        player:SendHoverText(msg)
        gg.log(msg)
        return false
    end
end

--- 移除宠物
---@param params table
---@param player MPlayer
function PetCommand.handlers.remove(params, player)
    local slotIndex = tonumber(params["槽位"])

    if not slotIndex then
        player:SendHoverText("缺少 '槽位' 字段")
        return false
    end

    local petInstance = PetMgr.GetPetInstance(player.uin, slotIndex)
    if not petInstance then
        local msg = string.format("槽位 %d 上没有宠物", slotIndex)
        player:SendHoverText(msg)
        gg.log(msg)
        return false
    end
    local petName = petInstance:GetConfigName()

    local success, errorMsg = PetMgr.RemovePetFromSlot(player.uin, slotIndex)
    if success then
        local msg = string.format("成功移除玩家 %s 在槽位 %d 的宠物: %s", player.name, slotIndex, petName)
        player:SendHoverText(msg)
        gg.log(msg)
        return true
    else
        local msg = string.format("移除玩家 %s 的宠物失败: %s", player.name, errorMsg)
        player:SendHoverText(msg)
        gg.log(msg)
        return false
    end
end

--- 设置宠物属性
---@param params table
---@param player MPlayer
function PetCommand.handlers.set(params, player)
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

    local petInstance = PetMgr.GetPetInstance(player.uin, slotIndex)
    if not petInstance then
        player:SendHoverText("槽位 " .. slotIndex .. " 上没有宠物")
        return false
    end

    -- 设置等级
    if level then
        local success, errorMsg = PetMgr.LevelUpPet(player.uin, slotIndex, level)
        if success then
            local msg = string.format("成功设置宠物 %s (槽位 %d) 等级为 %d", petInstance:GetConfigName(), slotIndex, level)
            player:SendHoverText(msg)
            gg.log(msg)
        else
            local msg = string.format("设置宠物 %s (槽位 %d) 等级失败: %s", petInstance:GetConfigName(), slotIndex, errorMsg)
            player:SendHoverText(msg)
            gg.log(msg)
        end
    end

    -- 设置星级
    if star then
        local currentStar = petInstance:GetStarLevel()
        if star > currentStar then
            local upgradesNeeded = star - currentStar
            local allSuccess = true
            gg.log(string.format("开始为宠物 %s (槽位 %d) 升星，当前: %d, 目标: %d", petInstance:GetConfigName(), slotIndex, currentStar, star))
            for i = 1, upgradesNeeded do
                local success, errorMsg = PetMgr.UpgradePetStar(player.uin, slotIndex)
                if not success then
                    local msg = string.format("升星失败: 从 %d 星升到 %d 星时出错: %s (请检查升星材料)", currentStar, currentStar + 1, errorMsg or '未知错误')
                    player:SendHoverText(msg)
                    gg.log(msg)
                    allSuccess = false
                    break
                end
                currentStar = currentStar + 1 -- 更新当前星级
            end

            if allSuccess then
                local msg = string.format("成功将宠物 %s (槽位 %d) 星级提升至 %d", petInstance:GetConfigName(), slotIndex, star)
                player:SendHoverText(msg)
                gg.log(msg)
            end
        elseif star < currentStar then
             player:SendHoverText("目标星级不能低于当前星级")
        else
             player:SendHoverText("宠物已达到目标星级")
        end
    end
    return true
end

-- 中文到英文的映射
local operationMap = {
    ["新增"] = "add",
    ["删除"] = "remove",
    ["设置"] = "set"
}

--- 宠物操作指令入口
---@param params table 命令参数
---@param player MPlayer 玩家
---@return boolean 是否成功
function PetCommand.main(params, player)
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

    local handler = PetCommand.handlers[handlerName]
    if handler then
        gg.log("宠物命令执行", "操作类型:", operationType, "参数:", params, "执行者:", player.name)
        return handler(params, player)
    else
        -- 理论上不会执行到这里，因为上面已经检查过了
        player:SendHoverText("内部错误：找不到指令处理器 " .. handlerName)
        return false
    end
end

return PetCommand 