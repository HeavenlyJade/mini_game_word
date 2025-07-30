-- PlayerInitMgr.lua

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local BagMgr = require(ServerStorage.MSystems.Bag.BagMgr) ---@type BagMgr

---@class PlayerInitMgr
local PlayerInitMgr = {}

--- 为新玩家执行初始化
---@param player MPlayer 玩家实例
function PlayerInitMgr.InitializeNewPlayer(player)
    gg.log("开始初始化新玩家:", player.name)
    
    -- 获取默认初始化配置
    local initConfig = ConfigLoader.GetPlayerInit('默认玩家初始化')
    if not initConfig then
        gg.log("错误：找不到默认玩家初始化配置")
        return
    end

    -- 1. 初始化货币
    PlayerInitMgr._InitializeCurrencies(player, initConfig)
    
    -- 2. 初始化变量
    PlayerInitMgr._InitializeVariables(player, initConfig)
    
    -- 3. 设置其他初始设置
    PlayerInitMgr._ApplyOtherSettings(player, initConfig)
    
    gg.log("玩家初始化完成:", player.name)
end

--- 内部函数：初始化货币
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._InitializeCurrencies(player, initConfig)
    local currencyMap = initConfig:GetCurrencyInitMap()
    
    for currencyName, amount in pairs(currencyMap) do
        gg.log(string.format("初始化货币 %s: %d", currencyName, amount))
        BagMgr.SetItemAmount(player.uin, currencyName, amount)
    end
end

--- 内部函数：初始化变量
---@param player MPlayer 玩家实例  
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._InitializeVariables(player, initConfig)
    local variableMap = initConfig:GetVariableInitMap()
    
    for variableName, value in pairs(variableMap) do
        gg.log(string.format("初始化变量 %s: %d", variableName, value))
        player.variableSystem:SetBaseValue(variableName, value)
    end
end

--- 内部函数：应用其他设置
---@param player MPlayer 玩家实例
---@param initConfig PlayerInitType 初始化配置
function PlayerInitMgr._ApplyOtherSettings(player, initConfig)
    if initConfig:IsNewPlayerConfig() then
        -- 可以在这里添加新手相关的特殊处理
        gg.log("应用新手玩家设置")
    end
    
    -- 如果需要设置初始等级（虽然通常在MPlayer创建时已设置）
    local initialLevel = initConfig:GetInitialLevel()
    if initialLevel > 1 then
        player.level = initialLevel
        gg.log("设置初始等级:", initialLevel)
    end
end

return PlayerInitMgr 