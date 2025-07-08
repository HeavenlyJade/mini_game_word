local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local SimulatorDataSystem = require(ServerStorage.Gameplay.Simulator.SimulatorDataSystem)
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr

---@class SimulatorGrowthMgr
local SimulatorGrowthMgr = {}

--- 缓存所有在线玩家的数据
---@type table<string, table>
SimulatorGrowthMgr.playerDataCache = {}

-----------------------------------------------------------------------
-- 内部辅助函数
-----------------------------------------------------------------------

-- 简易公式求值器
function SimulatorGrowthMgr:_EvaluateFormula(formula, level)
    -- 将 'LVL' 替换为实际等级
    local expression = string.gsub(formula, "LVL", tostring(level))
    -- 使用 Lua 的 load 函数来安全地执行表达式求值
    local func = load("return " .. expression)
    if func then
        local success, result = pcall(func)
        if success then
            return math.floor(result)
        end
    end
    -- 如果公式错误，返回一个极大的值防止意外升级
    return 99999999
end


-----------------------------------------------------------------------
-- 核心业务逻辑
-----------------------------------------------------------------------

--- 升级天赋
---@param player Player
---@param talentName string 天赋的中文名，例如 "训练加成"
function SimulatorGrowthMgr:UpgradeTalent(player, talentName)
    local playerData = self.playerDataCache[player.UserId]
    if not playerData then return end

    local talentConfig = ConfigLoader.GetTalent(talentName)
    if not talentConfig then
        print("Error: Invalid talent name: " .. talentName)
        return
    end

    local currentLevel = playerData.talents[talentName] or 1
    if currentLevel >= talentConfig.maxLevel then
        print("Info: Talent at max level.")
        return
    end

    -- 1. 检查所有货币是否足够
    local costs = {}
    for _, costInfo in ipairs(talentConfig.costs) do
        local itemName = costInfo.item
        local requiredAmount = self:_EvaluateFormula(costInfo.formula, currentLevel)
        
        local currentAmount = BagMgr:GetItemCount(player, itemName)
        if currentAmount < requiredAmount then
            print(string.format("Info: Not enough %s. Required: %d, Have: %d", itemName, requiredAmount, currentAmount))
            return -- 任何一种货币不足，则直接返回
        end
        table.insert(costs, {name = itemName, amount = requiredAmount})
    end

    -- 2. 扣除所有货币
    for _, cost in ipairs(costs) do
        BagMgr:RemoveItem(player, cost.name, cost.amount)
    end

    -- 3. 提升天赋等级
    playerData.talents[talentName] = currentLevel + 1
    print(string.format("Success: Player %s upgraded talent '%s' to level %d.", player.Name, talentName, playerData.talents[talentName]))
end


-----------------------------------------------------------------------
-- 玩家数据生命周期管理
-----------------------------------------------------------------------

--- 当玩家进入游戏时调用
---@param player Player
function SimulatorGrowthMgr:OnPlayerJoin(player)
    local playerUID = player.UserId
    local dataSystem = SimulatorDataSystem:LoadData(playerUID)
    self.playerDataCache[playerUID] = dataSystem
    print(string.format("SimulatorGrowthMgr: Cached data for player %s.", player.Name))
end

--- 当玩家离开游戏时调用
---@param player Player
function SimulatorGrowthMgr:OnPlayerLeave(player)
    local playerUID = player.UserId
    local dataSystem = self.playerDataCache[playerUID]

    if dataSystem then
        SimulatorDataSystem:SaveData(playerUID, dataSystem)
        self.playerDataCache[playerUID] = nil
        print(string.format("SimulatorGrowthMgr: Saved and removed data for player %s.", player.Name))
    end
end

--- 给予玩家战力
---@param player Player
---@param amount number
function SimulatorGrowthMgr:AddPower(player, amount)
    local dataSystem = self.playerDataCache[player.UserId]
    if not dataSystem then
        return
    end

    dataSystem.currentPower = dataSystem.currentPower + amount
    
    -- 更新历史最高战力
    if dataSystem.currentPower > dataSystem.highestPower then
        dataSystem.highestPower = dataSystem.currentPower
    end

    print(string.format("Player %s gained %d power. Current: %d, Highest: %d", player.Name, amount, dataSystem.currentPower, dataSystem.highestPower))
    -- 在这里可以检查并触发解锁事件
end

-- 监听玩家加入和离开事件来自动管理数据
Players.PlayerAdded:Connect(function(player)
    SimulatorGrowthMgr:OnPlayerJoin(player)
end)

Players.PlayerRemoving:Connect(function(player)
    SimulatorGrowthMgr:OnPlayerLeave(player)
end)


return SimulatorGrowthMgr