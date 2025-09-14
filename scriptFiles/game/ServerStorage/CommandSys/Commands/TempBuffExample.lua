--- 临时buff系统使用示例
--- 这个文件展示了如何使用MPlayer的临时buff系统

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class TempBuffExample
local TempBuffExample = {}

--- 示例：为玩家添加金币获取倍率buff
---@param playerUin number 玩家UIN
---@param duration number 持续时间（秒）
---@param multiplier number 倍率
function TempBuffExample.AddGoldBuff(playerUin, duration, multiplier)
    local player = MServerDataManager.getPlayerByUin(playerUin)
    if not player then
        gg.log("错误：找不到玩家", playerUin)
        return false
    end
    
    -- 添加金币获取倍率buff
    player:AddTempBuff("金币", duration, multiplier)
    return true
end

--- 示例：为玩家添加经验获取倍率buff
---@param playerUin number 玩家UIN
---@param duration number 持续时间（秒）
---@param multiplier number 倍率
function TempBuffExample.AddExpBuff(playerUin, duration, multiplier)
    local player = MServerDataManager.getPlayerByUin(playerUin)
    if not player then
        gg.log("错误：找不到玩家", playerUin)
        return false
    end
    
    -- 添加经验获取倍率buff
    player:AddTempBuff("经验", duration, multiplier)
    return true
end

--- 示例：查看玩家的所有临时buff
---@param playerUin number 玩家UIN
function TempBuffExample.ViewPlayerBuffs(playerUin)
    local player = MServerDataManager.getPlayerByUin(playerUin)
    if not player then
        gg.log("错误：找不到玩家", playerUin)
        return
    end
    
    local activeBuffs = player:GetActiveTempBuffs()
    gg.log("玩家", player.name, "的临时buff:")
    
    if next(activeBuffs) == nil then
        gg.log("  无临时buff")
        return
    end
    
    for variableName, buff in pairs(activeBuffs) do
        local remainingTime = buff.endTime - os.time()
        gg.log(string.format("  变量: %s, 倍率: %s, 剩余时间: %d秒", 
            variableName, tostring(buff.multiplier), remainingTime))
    end
end

--- 示例：测试临时buff效果
---@param playerUin number 玩家UIN
function TempBuffExample.TestBuffEffect(playerUin)
    local player = MServerDataManager.getPlayerByUin(playerUin)
    if not player then
        gg.log("错误：找不到玩家", playerUin)
        return
    end
    
    -- 添加2倍金币获取buff，持续60秒
    player:AddTempBuff("金币", 60, 2.0)
    
    -- 模拟使用VariableCommand添加金币
    local VariableCommand = require(ServerStorage.CommandSys.Commands.MVariableCom) ---@type VariableCommand
    local params = {
        ["操作类型"] = "新增",
        ["变量名"] = "金币",
        ["数值"] = 100,
        ["来源"] = "测试"
    }
    
    VariableCommand.main(params, player)
    
    gg.log("测试完成：玩家", player.name, "应该获得200金币（100 * 2倍buff）")
end

return TempBuffExample

-- ============================= 使用示例 =============================
-- 
-- 1. 添加金币获取倍率buff（2倍，持续300秒）
-- TempBuffExample.AddGoldBuff(123456789, 300, 2.0)
-- 
-- 2. 添加经验获取倍率buff（1.5倍，持续600秒）
-- TempBuffExample.AddExpBuff(123456789, 600, 1.5)
-- 
-- 3. 查看玩家所有临时buff
-- TempBuffExample.ViewPlayerBuffs(123456789)
-- 
-- 4. 测试临时buff效果
-- TempBuffExample.TestBuffEffect(123456789)
-- 
-- ============================= 临时buff系统说明 =============================
-- 
-- 临时buff系统结构：
-- player.tempBuffs = {
--     ["金币"] = {
--         startTime = 1640995200,  -- 开始时间戳
--         endTime = 1640995500,    -- 结束时间戳
--         multiplier = 2.0         -- 倍率
--     },
--     ["经验"] = {
--         startTime = 1640995200,
--         endTime = 1640995800,
--         multiplier = 1.5
--     }
-- }
-- 
-- 工作原理：
-- 1. 当调用VariableCommand.handlers.add时，会检查目标变量是否有临时buff
-- 2. 如果有临时buff且未过期，会将finalValue乘以buff的multiplier
-- 3. 过期的buff会在下次获取时自动清理
-- 
-- 支持的变量类型：
-- - 任何通过VariableCommand操作的变量都可以应用临时buff
-- - 常见的有：金币、经验、战力值、攻击力等
