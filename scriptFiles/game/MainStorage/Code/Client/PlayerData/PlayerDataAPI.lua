
local MainStorage = game:GetService("MainStorage")
local PlayerDataManager = require(MainStorage.Code.Client.PlayerData.PlayerDataManager)
local LocalEventBus = require(MainStorage.Code.Client.PlayerData.LocalEventBus)
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class PlayerDataAPI
local PlayerDataAPI = {}

--- 获取背包数据
---@return table
function PlayerDataAPI.GetBagData()
    return PlayerDataManager.bagData
end

--- 获取单个变量值
---@param key string 变量名
---@return any
function PlayerDataAPI.GetVariable(key)
    return PlayerDataManager.variableData[key]
end

--- 获取所有变量数据
---@return table
function PlayerDataAPI.GetVariableData()
    return PlayerDataManager.variableData
end


--- 获取任务数据
---@return table
function PlayerDataAPI.GetQuestData()
    return PlayerDataManager.questData
end

--- 监听背包数据变化
---@param callback function
function PlayerDataAPI.OnBagChanged(callback)
    LocalEventBus.Subscribe("BagDataChanged", callback)
end

--- 监听变量数据变化
---@param callback function
function PlayerDataAPI.OnVariableChanged(callback)
    LocalEventBus.Subscribe("VariableDataChanged", callback)
end

--- 监听任务数据变化
---@param callback function
function PlayerDataAPI.OnQuestChanged(callback)
    LocalEventBus.Subscribe("QuestDataChanged", callback)
end

return PlayerDataAPI