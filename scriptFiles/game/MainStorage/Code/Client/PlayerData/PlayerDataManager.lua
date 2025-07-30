local MainStorage = game:GetService("MainStorage")
local LocalEventBus = require(MainStorage.Code.Client.PlayerData.LocalEventBus)
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager)
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local PlayerDataEventConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local BagEventConfig = require(MainStorage.Code.Event.event_bag) ---@type BagEventConfig

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
    -- 【修改】订阅背包系统原有的同步事件，而不是新的 PlayerDataSync_Bag


    -- 订阅新的变量和任务数据同步事件
    ClientEventManager.Subscribe(PlayerDataEventConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE, function(data)
        self:HandleVariableSync(data)
    end)

    ClientEventManager.Subscribe(PlayerDataEventConfig.NOTIFY.PLAYER_DATA_SYNC_QUEST, function(data)
        self:HandleQuestSync(data)
    end)

    -- 订阅错误响应
    ClientEventManager.Subscribe(PlayerDataEventConfig.NOTIFY.PLAYER_DATA_LOADED, function(data)
        self:HandleDataLoadResponse(data)
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

--- 【新增】处理来自背包系统的数据同步
function PlayerDataManager:HandleBagSyncFromBagSystem(data)
    gg.log("收到背包系统同步数据:", data)
    
    -- 将背包系统的数据格式转换为 PlayerData 格式
    local bagData = {
        items = data.items or {},
        moneys = data.moneys or {} 
    }
    
    self:UpdateBagData(bagData, "full")  -- 背包系统的同步默认为全量同步
end

--- 【修改】处理新格式的变量数据同步
function PlayerDataManager:HandleVariableSync(data)
    if data.errorCode and data.errorCode ~= PlayerDataEventConfig.ERROR_CODES.SUCCESS then
        gg.log("变量数据同步失败:", PlayerDataEventConfig.GetErrorMessage(data.errorCode))
        return
    end
    
    self:UpdateVariableData(data.variableData, data.syncType)
end

--- 【修改】处理新格式的任务数据同步
function PlayerDataManager:HandleQuestSync(data)
    if data.errorCode and data.errorCode ~= PlayerDataEventConfig.ERROR_CODES.SUCCESS then
        gg.log("任务数据同步失败:", PlayerDataEventConfig.GetErrorMessage(data.errorCode))
        return
    end
    
    self:UpdateQuestData(data.questData, data.syncType)
end

--- 处理数据加载响应（包括错误处理）
function PlayerDataManager:HandleDataLoadResponse(data)
    if data.errorCode == PlayerDataEventConfig.ERROR_CODES.SUCCESS then
        gg.log("玩家数据加载成功")
        LocalEventBus.Publish("PlayerDataLoaded", true)
    else
        gg.log("玩家数据加载失败:", PlayerDataEventConfig.GetErrorMessage(data.errorCode))
        LocalEventBus.Publish("PlayerDataLoadError", {
            errorCode = data.errorCode,
            errorMessage = data.errorMessage
        })
    end
end

--- 增强的数据更新方法，支持增量和全量同步
function PlayerDataManager:UpdateBagData(data, syncType)
    if not data then return end
    
    if syncType == "full" then
        -- 全量替换
        self.bagData = data
    else
        -- 增量合并
        if not self.bagData then self.bagData = {} end
        for key, value in pairs(data) do
            self.bagData[key] = value
        end
    end
    
    gg.log("背包数据已更新 (", syncType, ")")
    LocalEventBus.Publish("BagDataChanged", self.bagData)
end

--- 增强的数据更新方法，支持增量和全量同步
function PlayerDataManager:UpdateVariableData(data, syncType)
    if not data then return end
    
    if syncType == "full" then
        -- 全量替换
        self.variableData = data
    else
        -- 增量合并
        if not self.variableData then self.variableData = {} end
        for key, value in pairs(data) do
            self.variableData[key] = value
        end
    end
    
    gg.log("玩家变量数据已更新 (", syncType, ")")
    LocalEventBus.Publish("VariableDataChanged", self.variableData)
end

--- 增强的数据更新方法，支持增量和全量同步
function PlayerDataManager:UpdateQuestData(data, syncType)
    if not data then return end
    
    if syncType == "full" then
        -- 全量替换
        self.questData = data
    else
        -- 增量合并
        if not self.questData then self.questData = {} end
        for key, value in pairs(data) do
            self.questData[key] = value
        end
    end
    
    gg.log("任务数据已更新 (", syncType, ")")
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