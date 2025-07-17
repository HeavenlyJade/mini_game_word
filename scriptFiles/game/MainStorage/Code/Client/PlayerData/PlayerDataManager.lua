
local MainStorage = game:GetService("MainStorage")
local LocalEventBus = require(MainStorage.Code.Client.PlayerData.LocalEventBus)
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager)
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class PlayerDataManager
local PlayerDataManager = {
    -- 数据存储
    bagData = {},        -- 背包数据
    variableData = {},   -- 变量数据
    questData = {},      -- 任务数据

    -- 状态
    isInitialized = false
}

--- 订阅服务端事件
function PlayerDataManager:SubscribeServerEvents()
    ClientEventManager.Subscribe("PlayerBagUpdate", function(data)
        self:UpdateBagData(data.bagData)
    end)

    ClientEventManager.Subscribe("PlayerVariableUpdate", function(data)
        self:UpdateVariableData(data.variables)
    end)

    ClientEventManager.Subscribe("PlayerQuestUpdate", function(data)
        self:UpdateQuestData(data.quests)
    end)
end

--- 初始化，注册事件监听
function PlayerDataManager:Init()
    if self.isInitialized then
        return
    end
    gg.log("PlayerDataManager 开始初始化...")
    self:SubscribeServerEvents()
    self.isInitialized = true
    gg.log("PlayerDataManager 初始化完成。")
end

--- 更新背包数据并通知
---@param data table 背包数据
function PlayerDataManager:UpdateBagData(data)
    self.bagData = data
    gg.log("背包数据已更新")
    LocalEventBus.Publish("BagDataChanged", self.bagData)
end

--- 更新变量数据并通知
---@param data table 变量数据
function PlayerDataManager:UpdateVariableData(data)
    self.variableData = data
    gg.log("玩家变量数据已更新")
    LocalEventBus.Publish("VariableDataChanged", self.variableData)
end

--- 更新任务数据并通知
---@param data table 任务数据
function PlayerDataManager:UpdateQuestData(data)
    self.questData = data
    gg.log("任务数据已更新")
    LocalEventBus.Publish("QuestDataChanged", self.questData)
end

--- 获取所有数据
---@return table
function PlayerDataManager:GetAllData()
    return {
        bag = self.bagData,
        variables = self.variableData,
        quests = self.questData,
    }
end

return PlayerDataManager