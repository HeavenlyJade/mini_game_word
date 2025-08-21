-- RankingCloudDataMgr.lua
-- 排行榜云数据管理器
-- 负责CloudKVStore操作封装、数据序列化/反序列化、排行榜初始化和重置

local game = game
local os = os

local MainStorage = game:GetService("MainStorage")
local CloudService = game:GetService("CloudService") ---@type CloudService
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RankingConfig = require(MainStorage.Code.Common.Config.RankingConfig) ---@type RankingConfig

---@class RankingCloudDataMgr
local RankingCloudDataMgr = {}

-- 排行榜CloudKVStore实例缓存
local cloudStoreCache = {} ---@type table<string, CloudKVStore>

--- 验证排行榜类型是否有效
---@param rankType string 排行榜类型
---@return boolean 是否有效
function RankingCloudDataMgr.ValidateRankingType(rankType)
    if not rankType or type(rankType) ~= "string" then
        gg.log("排行榜类型无效：类型不是字符串", rankType)
        return false
    end
    
    if not RankingConfig.CONFIGS[rankType] then
        gg.log("排行榜类型无效：未找到配置", rankType)
        return false
    end
    
    return true
end

--- 获取或创建CloudKVStore实例
---@param rankType string 排行榜类型
---@return CloudKVStore|nil CloudKVStore实例
function RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        return nil
    end
    
    -- 检查缓存
    if cloudStoreCache[rankType] then
        return cloudStoreCache[rankType]
    end
    
    -- 创建新的CloudKVStore实例
    local cloudStore = CloudService:GetOrderDataCloud(rankType)
    if not cloudStore then
        gg.log("创建CloudKVStore失败", rankType)
        return nil
    end
    
    -- 缓存实例
    cloudStoreCache[rankType] = cloudStore
    gg.log("创建排行榜CloudKVStore成功", rankType)
    
    return cloudStore
end

--- 初始化排行榜存储
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingCloudDataMgr.InitRankingStore(rankType)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return false
    end
    
    -- CloudKVStore会自动处理初始化，这里只需要确保实例存在
    gg.log("排行榜存储初始化完成", rankType)
    return true
end

--- 清空排行榜数据
---@param rankType string 排行榜类型
---@return boolean 是否成功
function RankingCloudDataMgr.ClearRankingStore(rankType)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return false
    end
    
    -- 使用CloudKVStore的Clean方法清理数据
    cloudStore:Clean()
    gg.log("排行榜数据已清空", rankType)
    return true
end

--- 更新玩家分数到排行榜
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@param score number 分数
---@return boolean 是否成功
function RankingCloudDataMgr.UpdatePlayerScore(rankType, uin, playerName, score)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return false
    end
    
    if not uin or not playerName or not score then
        gg.log("更新排行榜分数失败：参数无效", rankType, uin, playerName, score)
        return false
    end
    
    -- 同步设置分数
    local result = cloudStore:SetValue(tostring(uin), playerName, score)
    if result == 0 then
        --gg.log("更新排行榜分数成功", rankType, uin, playerName, score)
        return true
    else
        gg.log("更新排行榜分数失败", rankType, uin, playerName, score, "错误码:", result)
        return false
    end
end

--- 异步更新玩家分数到排行榜
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称  
---@param score number 分数
---@param callback function|nil 回调函数
function RankingCloudDataMgr.UpdatePlayerScoreAsync(rankType, uin, playerName, score, callback)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        if callback then callback(false) end
        return
    end
    
    if not uin or not playerName or not score then
        gg.log("异步更新排行榜分数失败：参数无效", rankType, uin, playerName, score)
        if callback then callback(false) end
        return
    end
    
    -- 异步设置分数
    cloudStore:SetValueAsync(tostring(uin), playerName, score, function(code)
        local success = (code == 0)
        if success then
            --gg.log("异步更新排行榜分数成功", rankType, uin, playerName, score)
        else
            gg.log("异步更新排行榜分数失败", rankType, uin, playerName, score, "错误码:", code)
        end
        
        if callback then
            callback(success)
        end
    end)
end

--- 获取排行榜TOP数据
---@param rankType string 排行榜类型
---@param count number 获取数量
---@return table 排行榜数据
function RankingCloudDataMgr.GetTopRankingData(rankType, count)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return {}
    end
    
    if not count or count <= 0 then
        count = 10 -- 默认获取前10名
    end
    
    local result = cloudStore:GetTopSync(count)
    if result and type(result) == "table" then
        --gg.log("获取TOP排行榜数据成功", rankType, "数量:", #result)
        return result
    else
        gg.log("获取TOP排行榜数据失败", rankType, count)
        return {}
    end
end

--- 获取排行榜BOTTOM数据
---@param rankType string 排行榜类型
---@param count number 获取数量
---@return table 排行榜数据
function RankingCloudDataMgr.GetBottomRankingData(rankType, count)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return {}
    end
    
    if not count or count <= 0 then
        count = 10 -- 默认获取后10名
    end
    
    local result = cloudStore:GetBottomSync(count)
    if result and type(result) == "table" then
        --gg.log("获取BOTTOM排行榜数据成功", rankType, "数量:", #result)
        return result
    else
        gg.log("获取BOTTOM排行榜数据失败", rankType, count)
        return {}
    end
end

--- 获取指定排名的数据
---@param rankType string 排行榜类型
---@param bAscend boolean 是否升序
---@param index number 排名索引
---@return table 排行榜数据
function RankingCloudDataMgr.GetRankingDataByIndex(rankType, bAscend, index)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return {}
    end
    
    if not index or index <= 0 then
        gg.log("获取排名数据失败：索引无效", rankType, index)
        return {}
    end
    
    local result = cloudStore:GetOrderDataIndex(bAscend, index)
    if result and type(result) == "table" then
        --gg.log("获取指定排名数据成功", rankType, "排名:", index)
        return result
    else
        gg.log("获取指定排名数据失败", rankType, bAscend, index)
        return {}
    end
end

--- 获取玩家分数
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@return number 玩家分数，失败返回-1
function RankingCloudDataMgr.GetPlayerScore(rankType, uin, playerName)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return -1
    end
    
    if not uin or not playerName then
        gg.log("获取玩家分数失败：参数无效", rankType, uin, playerName)
        return -1
    end
    
    local result = cloudStore:GetValue(tostring(uin), playerName)
    if result and type(result) == "number" then
        --gg.log("获取玩家分数成功", rankType, uin, playerName, result)
        return result
    else
        --gg.log("获取玩家分数失败或玩家未上榜", rankType, uin, playerName)
        return -1
    end
end

--- 移除玩家数据
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@return boolean 是否成功
function RankingCloudDataMgr.RemovePlayer(rankType, uin)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return false
    end
    
    if not uin then
        gg.log("移除玩家数据失败：UIN无效", rankType, uin)
        return false
    end
    
    local result = cloudStore:RemoveKey(tostring(uin))
    if result == 0 then
        gg.log("移除玩家排行榜数据成功", rankType, uin)
        return true
    else
        gg.log("移除玩家排行榜数据失败", rankType, uin, "错误码:", result)
        return false
    end
end

--- 异步移除玩家数据
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param callback function|nil 回调函数
function RankingCloudDataMgr.RemovePlayerAsync(rankType, uin, callback)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        if callback then callback(false) end
        return
    end
    
    if not uin then
        gg.log("异步移除玩家数据失败：UIN无效", rankType, uin)
        if callback then callback(false) end
        return
    end
    
    cloudStore:RemoveKeyAsync(tostring(uin), function(code)
        local success = (code == 0)
        if success then
            gg.log("异步移除玩家排行榜数据成功", rankType, uin)
        else
            gg.log("异步移除玩家排行榜数据失败", rankType, uin, "错误码:", code)
        end
        
        if callback then
            callback(success)
        end
    end)
end

--- 获取排行榜配置信息
---@param rankType string 排行榜类型
---@return table|nil 配置信息
function RankingCloudDataMgr.GetRankingConfig(rankType)
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        return nil
    end
    
    return RankingConfig.CONFIGS[rankType]
end

--- 获取所有支持的排行榜类型
---@return table 排行榜类型列表
function RankingCloudDataMgr.GetAllRankingTypes()
    local types = {}
    for rankType, _ in pairs(RankingConfig.CONFIGS) do
        table.insert(types, rankType)
    end
    return types
end

--- 检查排行榜是否需要重置（根据配置的重置类型）
---@param rankType string 排行榜类型
---@return boolean 是否需要重置
function RankingCloudDataMgr.CheckNeedReset(rankType)
    local config = RankingCloudDataMgr.GetRankingConfig(rankType)
    if not config then
        return false
    end
    
    local resetType = config.resetType
    if resetType == "none" then
        return false
    end
    
    -- TODO: 实现具体的时间检查逻辑
    -- 这里可以根据resetType和当前时间判断是否需要重置
    -- 暂时返回false，实际项目中可以扩展
    return false
end

--- 系统初始化 - 预加载所有排行榜类型
function RankingCloudDataMgr.SystemInit()
    gg.log("排行榜云数据管理器初始化开始")
    
    for rankType, config in pairs(RankingConfig.CONFIGS) do
        local success = RankingCloudDataMgr.InitRankingStore(rankType)
        if success then
            gg.log("排行榜类型初始化成功", rankType, config.displayName)
        else
            gg.log("排行榜类型初始化失败", rankType, config.displayName)
        end
    end
    
    gg.log("排行榜云数据管理器初始化完成")
end

--- 系统关闭清理
function RankingCloudDataMgr.SystemShutdown()
    gg.log("排行榜云数据管理器关闭清理开始")
    
    -- 清理CloudKVStore实例缓存
    cloudStoreCache = {}
    
    gg.log("排行榜云数据管理器关闭清理完成")
end

return RankingCloudDataMgr