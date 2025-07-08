--- 飞车玩法核心数据存取模块 (Data Access Layer)
-- 定义了玩家在飞车玩法中需要被存储的数据结构，并负责与CloudService交互。
-- 这是一个静态工具模块，不应被实例化。

local cloudService = game:GetService("CloudService")   ---@type CloudService
local SimulatorDataSystem = {}


--- 加载玩家的模拟器数据
---@param playerUID string 玩家ID
---@return table 返回一个新的、加载好数据的玩家数据表
function SimulatorDataSystem:LoadData(playerUID)
    local key = "simulator_data_" .. playerUID
    local success, cloudData = cloudService:GetTableOrEmpty(key)

    -- 默认数据结构
    local data = {
        currentPower = 0,       -- 当前战力
        highestPower = 0,       -- 历史最高战力
        gold = 0,               -- 金币 (用于抽奖/升级天赋)
        trophies = 0,           -- 奖杯 (用于升级稀有天赋，如重生档位)
        rebirths = 0,           -- 重生总次数

        -- 天赋等级
        talents = {
            rebirthTier = 1,        -- 重生档位
            doubleTraining = 1,     -- 双倍训练加成
            trophyGain = 1,         -- 奖杯获取
            moveSpeed = 1,          -- 移速加成
            trainingGain = 1,       -- 训练加成加成
            takeoffSpeed = 1,       -- 起步速度
            goldGain = 1,           -- 金币倍数
        }
    }

    -- 如果有云端数据，则进行合并
    if success and cloudData then
        data.currentPower = cloudData.currentPower or data.currentPower
        data.highestPower = cloudData.highestPower or data.highestPower
        data.gold = cloudData.gold or data.gold
        data.trophies = cloudData.trophies or data.trophies
        data.petCurrency = cloudData.petCurrency or data.petCurrency
        data.rebirths = cloudData.rebirths or data.rebirths

        if cloudData.talents then
            for talentName, level in pairs(cloudData.talents) do
                data.talents[talentName] = level
            end
        end
    end
    
    return data
end

--- 保存玩家的模拟器数据
---@param playerUID string 玩家ID
---@param data table 需要保存的数据
function SimulatorDataSystem:SaveData(playerUID, data)
    local key = "simulator_data_" .. playerUID
    cloudService:SetTableAsync(key, data, function(success)
        if not success then
            print(string.format("Error: Failed to save simulator data for player %s", playerUID))
        else
            print(string.format("Success: Saved simulator data for player %s", playerUID))
        end
    end)
end

return SimulatorDataSystem