-- PlayerInitMgr.lua

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig
local CommandManager = require(ServerStorage.CommandSys.MCommandMgr) ---@type CommandManager

---@class PlayerInitMgr
local PlayerInitMgr = {}

--- 为新玩家执行初始化
---@param player MPlayer 玩家实例
function PlayerInitMgr.InitializeNewPlayer(player)
    gg.log("开始初始化新玩家:", player.name)

    -- 获取默认初始化配置
    local initConfig = ConfigLoader.GetPlayerInit('玩家初始化')
    if not initConfig then
        --gg.log("错误：找不到默认玩家初始化配置")
        return
    end

    -- 1. 初始化货币
    PlayerInitMgr._InitializeCurrencies(player, initConfig)

    -- 2. 初始化变量
    PlayerInitMgr._InitializeVariables(player, initConfig)

    -- 3. 设置其他初始设置
    PlayerInitMgr._ApplyOtherSettings(player, initConfig)

    -- 4. 执行指令初始化
    PlayerInitMgr._ExecuteInitCommands(player, initConfig)

    -- 5. 【新增】同步初始化数据到客户端
    PlayerInitMgr._SyncInitializedData(player)

    --gg.log("玩家初始化完成:", player.name)
end

--- 内部函数：初始化货币
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._InitializeCurrencies(player, initConfig)
    local currencyMap = initConfig:GetCurrencyInitMap()

    for currencyName, amount in pairs(currencyMap) do
        --gg.log(string.format("初始化货币 %s: %d", currencyName, amount))
        BagMgr.AddItem(player, currencyName, amount)
    end
end

--- 内部函数：初始化变量
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._InitializeVariables(player, initConfig)
    local variableMap = initConfig:GetVariableInitMap()

    for variableName, value in pairs(variableMap) do
        --gg.log(string.format("初始化变量 %s: %d", variableName, value))
        player.variableSystem:SetBaseValue(variableName, value)
    end
end

--- 内部函数：应用其他设置
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._ApplyOtherSettings(player, initConfig)
    if initConfig:IsNewPlayerConfig() then
        -- 可以在这里添加新手相关的特殊处理
        --gg.log("应用新手玩家设置")
    end

    -- 如果需要设置初始等级（虽然通常在MPlayer创建时已设置）
    local initialLevel = initConfig:GetInitialLevel()
    if initialLevel > 1 then
        player.level = initialLevel
        --gg.log("设置初始等级:", initialLevel)
    end
end

--- 内部函数：执行指令初始化
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._ExecuteInitCommands(player, initConfig)
    local commandList = initConfig:GetCommandInitList()
    
    if not commandList or #commandList == 0 then
        --gg.log("没有指令需要初始化")
        return
    end
    
    gg.log("开始执行新玩家指令初始化，共", #commandList, "条指令")
    
    for i, commandStr in ipairs(commandList) do
        if commandStr and commandStr ~= "" then
            --gg.log("执行初始化指令", i, ":", commandStr)
            local success = CommandManager.ExecuteCommand(commandStr, player, true) -- silent = true 避免重复日志
            if not success then
                gg.log("初始化指令执行失败:", commandStr)
            end
        end
    end
    
    gg.log("新玩家指令初始化完成")
end

--- 【新增】内部函数：同步初始化后的核心数据到客户端
---@param player MPlayer 玩家实例
function PlayerInitMgr._SyncInitializedData(player)
    --gg.log("向客户端同步新玩家的初始化数据:", player.name)

    -- 1. 同步通过此管理器初始化的变量
    if player.variableSystem then
        local variableData = player.variableSystem.variables
        gg.network_channel:fireClient(player.uin, {
            cmd = EventPlayerConfig.NOTIFY.PLAYER_DATA_SYNC_VARIABLE,
            variableData = variableData,
        })
        --gg.log("已同步新玩家的变量数据")
    end

    -- 2. 强制同步背包数据
    -- 尽管SetItemAmount可能会触发部分同步，但在这里进行一次全量同步可以保证最终数据的一致性
    if BagMgr.ForceSyncToClient then
        BagMgr.ForceSyncToClient(player.uin)
        --gg.log("已强制同步新玩家的背包数据")
    end
end

return PlayerInitMgr
