-- Ranking.lua
-- 排行榜核心数据类（单个排行榜实例）
-- 负责管理单个排行榜的数据和业务操作，使用ClassMgr定义的数据实体

local game = game
local os = os
local pairs = pairs

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")

local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

-- 引入云数据管理器
local RankingCloudDataMgr = require(ServerStorage.MSystems.Ranking.RankingCloudDataMgr) ---@type RankingCloudDataMgr

---@class Ranking : Class
---@field rankType string 排行榜类型
---@field cloudStore CloudKVStore CloudKVStore实例
---@field isLoaded boolean 是否已加载
---@field lastUpdateTime number 最后更新时间
---@field config table 排行榜配置信息
---@field stats table 统计信息
local Ranking = ClassMgr.Class("Ranking")

--- 初始化排行榜实例
---@param rankType string 排行榜类型
function Ranking:OnInit(rankType)
    if not rankType or type(rankType) ~= "string" then
        gg.log("排行榜初始化失败：排行榜类型无效", rankType)
        return
    end
    
    self.rankType = rankType
    self.cloudStore = nil
    self.isLoaded = false
    self.lastUpdateTime = 0
    self.config = {}
    
    -- 初始化统计信息
    self.stats = {
        totalUpdates = 0,           -- 总更新次数
        lastScoreUpdate = 0,        -- 最后一次分数更新时间
        playerCount = 0,            -- 参与排行的玩家数量
        topScore = 0,               -- 最高分数
        lastRefreshTime = 0,        -- 最后刷新时间
    }
    
    gg.log("排行榜实例创建成功", rankType)
end

--- 初始化排行榜
---@return boolean 是否成功
function Ranking:Initialize()
    if not self.rankType then
        gg.log("初始化排行榜失败：排行榜类型未设置")
        return false
    end
    
    -- 获取排行榜配置
    local config = RankingCloudDataMgr.GetRankingConfig(self.rankType)
    if not config then
        gg.log("初始化排行榜失败：无法获取配置", self.rankType)
        return false
    end
    self.config = config
    
    -- 获取或创建CloudKVStore实例
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(self.rankType)
    if not cloudStore then
        gg.log("初始化排行榜失败：无法创建CloudKVStore", self.rankType)
        return false
    end
    self.cloudStore = cloudStore
    
    -- 初始化排行榜存储
    local success = RankingCloudDataMgr.InitRankingStore(self.rankType)
    if not success then
        gg.log("初始化排行榜失败：无法初始化存储", self.rankType)
        return false
    end
    
    self.isLoaded = true
    self.lastUpdateTime = os.time()
    self.stats.lastRefreshTime = os.time()
    
    gg.log("排行榜初始化成功", self.rankType, self.config.displayName)
    return true
end

--- 检查排行榜是否可用
---@return boolean 是否可用
function Ranking:IsAvailable()
    return self.isLoaded and self.cloudStore ~= nil
end

--- 更新玩家分数
---@param uin number 玩家UIN
---@param playerName string 玩家名称
---@param score number 分数
---@return boolean 是否成功
function Ranking:UpdatePlayerScore(uin, playerName, score)
    if not self:IsAvailable() then
        gg.log("更新玩家分数失败：排行榜未初始化", self.rankType)
        return false
    end
    
    if not uin or not playerName or not score then
        gg.log("更新玩家分数失败：参数无效", self.rankType, uin, playerName, score)
        return false
    end
    
    if type(uin) ~= "number" or type(score) ~= "number" then
        gg.log("更新玩家分数失败：参数类型错误", self.rankType, type(uin), type(score))
        return false
    end
    
    -- 使用云数据管理器更新分数
    local success = RankingCloudDataMgr.UpdatePlayerScore(self.rankType, tostring(uin), playerName, score)
    
    if success then
        -- 更新统计信息
        self:UpdateStats(score)
        --gg.log("更新玩家分数成功", self.rankType, uin, playerName, score)
    else
        gg.log("更新玩家分数失败", self.rankType, uin, playerName, score)
    end
    
    return success
end

--- 异步更新玩家分数
---@param uin number 玩家UIN
---@param playerName string 玩家名称
---@param score number 分数
---@param callback function|nil 回调函数
function Ranking:UpdatePlayerScoreAsync(uin, playerName, score, callback)
    if not self:IsAvailable() then
        gg.log("异步更新玩家分数失败：排行榜未初始化", self.rankType)
        if callback then callback(false) end
        return
    end
    
    if not uin or not playerName or not score then
        gg.log("异步更新玩家分数失败：参数无效", self.rankType, uin, playerName, score)
        if callback then callback(false) end
        return
    end
    
    -- 使用云数据管理器异步更新分数
    RankingCloudDataMgr.UpdatePlayerScoreAsync(self.rankType, tostring(uin), playerName, score, function(success)
        if success then
            -- 更新统计信息
            self:UpdateStats(score)
            --gg.log("异步更新玩家分数成功", self.rankType, uin, playerName, score)
        else
            gg.log("异步更新玩家分数失败", self.rankType, uin, playerName, score)
        end
        
        if callback then
            callback(success)
        end
    end)
end

--- 获取排行榜列表
---@param startRank number 起始排名
---@param count number 获取数量
---@return table 排行榜数据
function Ranking:GetRankingList(startRank, count)
    if not self:IsAvailable() then
        gg.log("获取排行榜列表失败：排行榜未初始化", self.rankType)
        return {}
    end
    
    -- 参数默认值和验证
    startRank = startRank or 1
    count = count or 10
    
    if startRank <= 0 or count <= 0 then
        gg.log("获取排行榜列表失败：参数无效", self.rankType, startRank, count)
        return {}
    end
    
    -- 限制最大查询数量
    local maxCount = self.config.maxDisplayCount or 100
    if count > maxCount then
        count = maxCount
        gg.log("获取排行榜列表：数量超限，已调整", self.rankType, count, maxCount)
    end
    
    local rankingData = {}
    
    if startRank == 1 then
        -- 从第一名开始，直接使用GetTopSync
        rankingData = RankingCloudDataMgr.GetTopRankingData(self.rankType, count)
    else
        -- 从指定排名开始，需要使用GetOrderDataIndex逐个获取
        for i = startRank, startRank + count - 1 do
            local data = RankingCloudDataMgr.GetRankingDataByIndex(self.rankType, false, i)
            if data and #data > 0 then
                table.insert(rankingData, data[1])
            else
                -- 没有更多数据了
                break
            end
        end
    end
    
    -- 格式化返回数据
    local formattedData = self:FormatRankingData(rankingData, startRank)
    
    --gg.log("获取排行榜列表成功", self.rankType, startRank, count, "实际返回:", #formattedData)
    return formattedData
end

--- 获取玩家排名信息
---@param uin number 玩家UIN
---@param playerName string|nil 玩家名称（可选）
---@return table 排名信息 {rank: number, score: number, playerName: string}
function Ranking:GetPlayerRank(uin, playerName)
    if not self:IsAvailable() then
        gg.log("获取玩家排名失败：排行榜未初始化", self.rankType)
        return {rank = -1, score = 0, playerName = ""}
    end
    
    if not uin or type(uin) ~= "number" then
        gg.log("获取玩家排名失败：UIN无效", self.rankType, uin)
        return {rank = -1, score = 0, playerName = ""}
    end
    
    -- 如果没有提供玩家名称，从排行榜数据中查找
    if not playerName or playerName == "" then
        local rankInfo = self:FindPlayerInRankingData(uin)
        if rankInfo then
            return rankInfo
        else
            return {rank = -1, score = 0, playerName = ""}
        end
    end
    
    -- 有玩家名称时，直接查询分数
    local score = RankingCloudDataMgr.GetPlayerScore(self.rankType, tostring(uin), playerName or "")
    if score <= 0 then
        -- 玩家不在排行榜上
        return {rank = -1, score = 0, playerName = playerName}
    end
    
    -- 获取玩家详细排名信息
    local rank = self:FindPlayerRankByScore(uin, score)
    
    return {
        rank = rank,
        score = score,
        playerName = playerName,
        uin = uin
    }
end

--- 在排行榜数据中查找玩家信息
---@param uin number 玩家UIN
---@return table|nil 玩家排名信息 {rank: number, score: number, playerName: string}
function Ranking:FindPlayerInRankingData(uin)
    if not self:IsAvailable() or not uin then
        return nil
    end
    
    -- 获取前100名数据进行查找
    local topData = RankingCloudDataMgr.GetTopRankingData(self.rankType, 100)
    
    for rank, data in pairs(topData) do
        if data.key and tonumber(data.key) == uin then
            return {
                rank = rank,
                score = data.value or 0,
                playerName = data.name or "",
                uin = uin
            }
        end
    end
    
    -- 如果在前100名中没找到，返回nil
    return nil
end

--- 通过分数查找玩家排名
---@param uin number 玩家UIN
---@param score number 玩家分数
---@return number 排名，-1表示未找到
function Ranking:FindPlayerRankByScore(uin, score)
    if not self:IsAvailable() or not uin or not score then
        return -1
    end
    
    -- 获取前100名数据进行查找
    local topData = RankingCloudDataMgr.GetTopRankingData(self.rankType, 100)
    
    for rank, data in pairs(topData) do
        if data.key and tonumber(data.key) == uin and data.value == score then
            return rank
        end
    end
    
    -- 如果在前100名中没找到，说明排名在100名之后或者不在榜上
    return -1
end

--- 刷新排行榜
---@return boolean 是否成功
function Ranking:Refresh()
    if not self:IsAvailable() then
        gg.log("刷新排行榜失败：排行榜未初始化", self.rankType)
        return false
    end
    
    -- CloudKVStore是实时的，这里主要更新内部状态
    self.stats.lastRefreshTime = os.time()
    
    -- 可以在这里添加其他刷新逻辑，比如缓存清理等
    
    gg.log("刷新排行榜成功", self.rankType)
    return true
end

--- 清空排行榜
---@return boolean 是否成功
function Ranking:ClearRanking()
    if not self:IsAvailable() then
        gg.log("清空排行榜失败：排行榜未初始化", self.rankType)
        return false
    end
    
    -- 使用云数据管理器清空数据
    local success = RankingCloudDataMgr.ClearRankingStore(self.rankType)
    
    if success then
        -- 重置统计信息
        self.stats.totalUpdates = 0
        self.stats.playerCount = 0
        self.stats.topScore = 0
        self.stats.lastScoreUpdate = 0
        self.stats.lastRefreshTime = os.time()
        
        gg.log("清空排行榜成功", self.rankType)
    else
        gg.log("清空排行榜失败", self.rankType)
    end
    
    return success
end

--- 移除玩家数据
---@param uin number 玩家UIN
---@return boolean 是否成功
function Ranking:RemovePlayer(uin)
    if not self:IsAvailable() then
        gg.log("移除玩家数据失败：排行榜未初始化", self.rankType)
        return false
    end
    
    if not uin or type(uin) ~= "number" then
        gg.log("移除玩家数据失败：UIN无效", self.rankType, uin)
        return false
    end
    
    -- 使用云数据管理器移除玩家数据
    local success = RankingCloudDataMgr.RemovePlayer(self.rankType, tostring(uin))
    
    if success then
        gg.log("移除玩家数据成功", self.rankType, uin)
    else
        gg.log("移除玩家数据失败", self.rankType, uin)
    end
    
    return success
end

--- 格式化排行榜数据
---@param rawData table 原始数据
---@param startRank number 起始排名
---@return table 格式化后的数据
function Ranking:FormatRankingData(rawData, startRank)
    if not rawData or type(rawData) ~= "table" then
        return {}
    end
    
    local formattedData = {}
    startRank = startRank or 1
    
    for i, data in pairs(rawData) do
        if data and data.key and data.value then
            local formatItem = {
                rank = startRank + i - 1,
                uin = tonumber(data.key) or 0,
                playerName = data.nick or "",
                score = data.value or 0,
                rankType = self.rankType
            }
            table.insert(formattedData, formatItem)
        end
    end
    
    return formattedData
end

--- 更新统计信息
---@param score number 新分数
function Ranking:UpdateStats(score)
    if not score or type(score) ~= "number" then
        return
    end
    
    self.stats.totalUpdates = self.stats.totalUpdates + 1
    self.stats.lastScoreUpdate = os.time()
    
    -- 更新最高分数
    if score > self.stats.topScore then
        self.stats.topScore = score
    end
    
    -- 更新玩家数量（这里是估算，实际数量需要查询CloudKVStore）
    -- 可以定期通过GetTopSync(大数量)来更新准确的玩家数量
end

--- 获取排行榜统计信息
---@return table 统计信息
function Ranking:GetStats()
    -- 创建统计信息副本，包含当前状态
    local currentStats = {}
    for k, v in pairs(self.stats) do
        currentStats[k] = v
    end
    
    -- 添加实时信息
    currentStats.rankType = self.rankType
    currentStats.displayName = self.config.displayName or self.rankType
    currentStats.isLoaded = self.isLoaded
    currentStats.lastUpdateTime = self.lastUpdateTime
    currentStats.configMaxDisplay = self.config.maxDisplayCount or 100
    currentStats.resetType = self.config.resetType or "none"
    
    return currentStats
end

--- 获取排行榜配置
---@return table 配置信息
function Ranking:GetConfig()
    return self.config
end

--- 获取排行榜类型
---@return string 排行榜类型
function Ranking:GetRankType()
    return self.rankType
end

--- 检查是否需要重置
---@return boolean 是否需要重置
function Ranking:CheckNeedReset()
    if not self.config then
        return false
    end
    
    return RankingCloudDataMgr.CheckNeedReset(self.rankType)
end

--- 获取排行榜摘要信息
---@return table 摘要信息
function Ranking:GetSummary()
    local summary = {
        rankType = self.rankType,
        displayName = self.config.displayName or self.rankType,
        isLoaded = self.isLoaded,
        totalUpdates = self.stats.totalUpdates,
        topScore = self.stats.topScore,
        lastUpdateTime = self.lastUpdateTime,
        lastRefreshTime = self.stats.lastRefreshTime
    }
    
    return summary
end

--- 验证排行榜数据完整性
---@return boolean, string 是否正常，错误信息
function Ranking:ValidateIntegrity()
    if not self.rankType then
        return false, "排行榜类型未设置"
    end
    
    if not self.config or not self.config.name then
        return false, "排行榜配置丢失"
    end
    
    if not self.cloudStore then
        return false, "CloudKVStore实例丢失"
    end
    
    if not self.isLoaded then
        return false, "排行榜未正确初始化"
    end
    
    return true, "数据完整性正常"
end

--- 销毁排行榜实例
function Ranking:Destroy()
    gg.log("销毁排行榜实例", self.rankType)
    
    -- 清理引用
    self.cloudStore = nil
    self.config = {}
    self.stats = {}
    self.isLoaded = false
    
    -- 调用父类销毁方法
    if self.Super and self.Super.Destroy then
        self.Super.Destroy(self)
    end
end

return Ranking