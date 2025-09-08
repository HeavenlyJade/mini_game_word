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
        ----gg.log("排行榜类型无效：类型不是字符串", rankType)
        return false
    end

    if not RankingConfig.CONFIGS[rankType] then
        ----gg.log("排行榜类型无效：未找到配置", rankType)
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
        -- ----gg.log("使用缓存的CloudKVStore", rankType)
        return cloudStoreCache[rankType]
    end

    -- 创建新的CloudKVStore实例
    ----gg.log("尝试创建CloudKVStore", rankType)
    local cloudStore = CloudService:GetOrderDataCloud(rankType)
    if not cloudStore then
        ----gg.log("创建CloudKVStore失败", rankType)
        return nil
    end

    -- 验证CloudKVStore对象的可用性
    if type(cloudStore) ~= "userdata" and type(cloudStore) ~= "table" then
        ----gg.log("创建CloudKVStore失败：返回类型无效", rankType, "类型:", type(cloudStore))
        return nil
    end

    -- 检查必要的方法是否存在
    if not cloudStore.SetValue then
        ----gg.log("创建CloudKVStore失败：缺少SetValue方法", rankType)
        return nil
    end

    -- 缓存实例
    cloudStoreCache[rankType] = cloudStore
    ----gg.log("创建排行榜CloudKVStore成功", rankType, "类型:", type(cloudStore),cloudStore.Value_Dict)

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
    ----gg.log("排行榜存储初始化完成", rankType)
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
    ----gg.log("排行榜数据已清空", rankType)
    return true
end

--- 安全更新玩家分数（带云端数据验证）
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@param newScore number 新分数
---@param forceUpdate boolean|nil 是否强制更新（忽略分数比较）
---@return boolean, number, number 更新结果，旧分数，新分数
function RankingCloudDataMgr.SafeUpdatePlayerScore(rankType, uin, playerName, newScore, forceUpdate)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        return false, 0, 0
    end

    -- 详细的参数验证和调试
    if not uin or not playerName or not newScore then
        ----gg.log("安全更新排行榜分数失败：参数无效", rankType, uin, playerName, newScore)
        return false, 0, 0
    end

    -- 验证参数类型并转换为整数
    if type(newScore) ~= "number" then
        ----gg.log("安全更新排行榜分数失败：分数类型无效", rankType, uin, playerName, newScore, "类型:", type(newScore))
        return false, 0, 0
    end

    -- CloudKVStore要求value为int类型，转换为整数
    local intScore = math.floor(newScore)
    if intScore ~= newScore then
        ----gg.log("排行榜分数转换为整数", rankType, uin, newScore, "->", intScore)
    end

    ----gg.log("开始安全更新排行榜分数", rankType, "玩家:", uin, playerName, "新分数:", newScore)

    -- 先获取云端当前分数进行比对
    local currentCloudScore = RankingCloudDataMgr.GetPlayerScore(rankType, uin, playerName)
    if currentCloudScore == -1 then
        currentCloudScore = 0  -- 玩家不在排行榜上，分数为0
    end

    -- 验证是否需要更新
    if not forceUpdate and intScore <= currentCloudScore then
        ------gg.log("跳过更新：新分数不高于云端分数", rankType, uin, currentCloudScore, "->", intScore)
        return false, currentCloudScore, currentCloudScore
    end

    -- 执行更新操作，使用整数分数
    ----gg.log("调用CloudStore:SetValue", "key:", tostring(uin), "name:", playerName, "value:", intScore)
    local result = cloudStore:SetValue(tostring(uin), playerName, intScore)

    -- 增强错误处理和调试日志
    ----gg.log("CloudStore:SetValue返回值", "类型:", type(result), "值:", result)

    -- 兼容不同的返回值格式：根据实际测试，SetValue可能返回boolean或number
    local success = false
    if type(result) == "number" then
        -- API文档描述的格式：0表示成功，非0表示失败
        success = (result == 0)
    elseif type(result) == "boolean" then
        -- 实际实现格式：true表示成功，false表示失败
        success = result
    end

    if success then
        ----gg.log("安全更新排行榜分数成功", rankType, uin, currentCloudScore, "->", intScore)
        return true, currentCloudScore, intScore
    else
        ----gg.log("安全更新排行榜分数失败", rankType, uin, playerName, intScore, "错误码:", result, "类型:", type(result))
        return false, currentCloudScore, currentCloudScore
    end
end

--- 更新玩家分数到排行榜（兼容性方法）
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@param score number 分数
---@return boolean 是否成功
function RankingCloudDataMgr.UpdatePlayerScore(rankType, uin, playerName, score)
    local success, _, _ = RankingCloudDataMgr.SafeUpdatePlayerScore(rankType, uin, playerName, score, false)
    return success
end

--- 异步安全更新玩家分数
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@param newScore number 新分数
---@param forceUpdate boolean|nil 是否强制更新
---@param callback function|nil 回调函数 function(success, oldScore, newScore)
function RankingCloudDataMgr.SafeUpdatePlayerScoreAsync(rankType, uin, playerName, newScore, forceUpdate, callback)
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        if callback then callback(false, 0, 0) end
        return
    end

    if not uin or not playerName or not newScore then
        ----gg.log("异步安全更新排行榜分数失败：参数无效", rankType, uin, playerName, newScore)
        if callback then callback(false, 0, 0) end
        return
    end

    -- 验证参数类型并转换为整数
    if type(newScore) ~= "number" then
        ----gg.log("异步安全更新排行榜分数失败：分数类型无效", rankType, uin, playerName, newScore, "类型:", type(newScore))
        if callback then callback(false, 0, 0) end
        return
    end

    -- CloudKVStore要求value为int类型，转换为整数
    local intScore = math.floor(newScore)
    if intScore ~= newScore then
        ----gg.log("异步排行榜分数转换为整数", rankType, uin, newScore, "->", intScore)
    end

    -- 异步获取云端当前分数
    local function getScoreCallback(currentCloudScore)
        if not currentCloudScore or currentCloudScore == -1 then
            currentCloudScore = 0
        end

        -- 验证是否需要更新
        if not forceUpdate and intScore <= currentCloudScore then
            ------gg.log("跳过异步更新：新分数不高于云端分数", rankType, uin, currentCloudScore, "->", intScore)
            if callback then callback(false, currentCloudScore, currentCloudScore) end
            return
        end

        -- 执行异步更新，使用整数分数
        ----gg.log("调用CloudStore:SetValueAsync", "key:", tostring(uin), "name:", playerName, "value:", intScore)
        cloudStore:SetValueAsync(tostring(uin), playerName, intScore, function(code)
            -- 兼容不同的返回值格式：根据实际测试，SetValueAsync回调可能返回boolean或number
            ----gg.log("CloudStore:SetValueAsync回调返回值", "类型:", type(code), "值:", code)

            local success = false
            if type(code) == "number" then
                -- API文档描述的格式：0表示成功，非0表示失败
                success = (code == 0)
            elseif type(code) == "boolean" then
                -- 实际实现格式：true表示成功，false表示失败
                success = code
            end

            if success then
                ----gg.log("异步安全更新排行榜分数成功", rankType, uin, currentCloudScore, "->", intScore)
                if callback then callback(true, currentCloudScore, intScore) end
            else
                ----gg.log("异步安全更新排行榜分数失败", rankType, uin, playerName, intScore, "错误码:", code, "类型:", type(code))
                if callback then callback(false, currentCloudScore, currentCloudScore) end
            end
        end)
    end

    -- 先获取当前分数，然后进行比较和更新
    local currentScore = RankingCloudDataMgr.GetPlayerScore(rankType, uin, playerName)
    getScoreCallback(currentScore)
end

--- 异步更新玩家分数到排行榜（兼容性方法）
---@param rankType string 排行榜类型
---@param uin string 玩家UIN
---@param playerName string 玩家名称
---@param score number 分数
---@param callback function|nil 回调函数
function RankingCloudDataMgr.UpdatePlayerScoreAsync(rankType, uin, playerName, score, callback)
    RankingCloudDataMgr.SafeUpdatePlayerScoreAsync(rankType, uin, playerName, score, false, function(success, oldScore, newScore)
        if callback then callback(success) end
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
        ------gg.log("获取TOP排行榜数据成功", rankType, "数量:", #result)
        return result
    else
        ----gg.log("获取TOP排行榜数据失败", rankType, count)
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
        ----gg.log("获取排名数据失败：索引无效", rankType, index)
        return {}
    end

    local result = cloudStore:GetOrderDataIndex(bAscend, index)
    if result and type(result) == "table" then
        ------gg.log("获取指定排名数据成功", rankType, "排名:", index)
        return result
    else
        ----gg.log("获取指定排名数据失败", rankType, bAscend, index)
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
        ----gg.log("获取玩家分数失败：参数无效", rankType, uin, playerName)
        return -1
    end

    local result = cloudStore:GetValue(tostring(uin), playerName)
    if result and type(result) == "number" then
        ------gg.log("获取玩家分数成功", rankType, uin, playerName, result)
        return result
    else
        ------gg.log("获取玩家分数失败或玩家未上榜", rankType, uin, playerName)
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
        ----gg.log("移除玩家数据失败：UIN无效", rankType, uin)
        return false
    end

    local result = cloudStore:RemoveKey(tostring(uin))
    if result == 0 then
        ----gg.log("移除玩家排行榜数据成功", rankType, uin)
        return true
    else
        ----gg.log("移除玩家排行榜数据失败", rankType, uin, "错误码:", result)
        return false
    end
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

-- 批量安全更新玩家分数 (重构版)
--- 1. 获取Top100数据
--- 2. 内存比对
--- 3. 异步更新
---@param rankType string 排行榜类型
---@param updates table 更新数据数组 {{uin, playerName, score}, ...}
---@param forceUpdate boolean|nil 是否强制更新
---@return number, table 成功发起的更新数量，详细结果
function RankingCloudDataMgr.BatchSafeUpdatePlayerScore(rankType, updates, forceUpdate)
    if not updates or type(updates) ~= "table" or #updates == 0 then
        ----gg.log("批量安全更新失败：更新数据无效", rankType)
        return 0, {}
    end

    -- 获取CloudStore实例
    local cloudStore = RankingCloudDataMgr.GetOrCreateCloudStore(rankType)
    if not cloudStore then
        ----gg.log("批量安全更新失败：无法获取CloudStore", rankType)
        return 0, {}
    end

    -- 1. 使用GetTopSync获取排行榜Top100数据
    local topDataList = cloudStore:GetTopSync(100) or {}
    local cloudScores = {} -- { [uin_string] = score }
    for _, data in pairs(topDataList) do
        if data and data.key then
            cloudScores[data.key] = data.value or 0
        end
    end
    --gg.log("获取Top100数据成功", rankType, "数量:", #topDataList)

    -- 2. 在内存中进行批量比对，筛选出需要更新的数据
    local needUpdateList = {}
    local results = {}
    
    for i, updateData in pairs(updates) do
        if updateData and type(updateData) == "table" and #updateData >= 3 then
            local uin = updateData[1]
            local playerName = updateData[2]
            local newScore = updateData[3]
            
            if uin and playerName  then
                local uinStr = tostring(uin)
                
                -- 从获取的Top100数据中查找旧分数，如果找不到则默认为0
                local oldScore = cloudScores[uinStr] or 0
                
                -- 判断是否需要更新
                local needUpdate = forceUpdate or (newScore > oldScore)
                
                if needUpdate then
                    table.insert(needUpdateList, {
                        uin = uinStr,
                        playerName = playerName,
                        score = newScore,
                        oldScore = oldScore
                    })
                end
                
                -- 记录比对结果
                table.insert(results, {
                    index = i,
                    uin = uin,
                    playerName = playerName,
                    success = needUpdate, -- success 在这里表示“将要尝试更新”
                    oldScore = oldScore,
                    newScore = newScore,
                    scoreChanged = needUpdate and (oldScore ~= newScore)
                })
            else
                -- 无效数据
                 table.insert(results, { index = i, uin = uin, success = false, error = "数据格式无效" })
            end
        else
            -- 数据格式无效
            table.insert(results, { index = i, success = false, error = "数据格式无效" })
        end
    end

    -- 3. 异步更新需要变更的数据
    if #needUpdateList > 0 then
        ----gg.log("批量异步更新开始", rankType, "需要更新数量:", #needUpdateList)
        
        for _, item in pairs(needUpdateList) do
            cloudStore:SetValueAsync(item.uin, item.playerName, item.score, function(code)
                if code == 0 then
                    --gg.log("异步更新成功", item.uin, item.playerName, item.oldScore, "->", item.score)
                else
                    ----gg.log("异步更新失败", item.uin, item.playerName, item.score, "错误码:", code)
                end
            end)
        end
    end

    --gg.log("批量安全更新检查完成", rankType, "总数:", #updates, "需要更新:", #needUpdateList)
    return #needUpdateList, results
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



--- 获取排行榜表格数据（如果不存在则返回空表）
---@param rankType string 排行榜类型
---@return boolean, table 是否成功，排行榜数据
function RankingCloudDataMgr.GetTableOrEmpty(rankType)
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        ----gg.log("获取排行榜表格数据失败：排行榜类型无效", rankType)
        return false, {}
    end

    local cloudService = game:GetService("CloudService")
    local key = "ranking_table_" .. rankType
    
    local ret, ret2 = cloudService:GetTableOrEmpty(key)
    
    if ret then
        if ret2 and type(ret2) == "table" then
            ----gg.log("获取排行榜表格数据成功", rankType, "数据数量:", #ret2)
            return true, ret2
        else
            ----gg.log("排行榜表格数据为空，返回空表", rankType)
            return true, {}
        end
    else
        ----gg.log("获取排行榜表格数据失败", rankType)
        return false, {}
    end
end

--- 异步保存排行榜表格数据
---@param rankType string 排行榜类型
---@param data table 排行榜数据 [{key=uin, value=score, nick=playerName}, ...]
---@param callback function|nil 回调函数 function(success)
function RankingCloudDataMgr.SetTableAsync(rankType, data, callback)
    if not RankingCloudDataMgr.ValidateRankingType(rankType) then
        gg.log("保存排行榜表格数据失败：排行榜类型无效", rankType)
        if callback then callback(false) end
        return
    end

    if not data or type(data) ~= "table" then
        ----gg.log("保存排行榜表格数据失败：数据无效", rankType)
        if callback then callback(false) end
        return
    end

    -- 限制数据长度最大为100
    local limitedData = {}
    local count = 0
    for _, item in pairs(data) do
        if count >= 100 then
            break
        end
        
        if item and item.key and item.value and item.nick then
            table.insert(limitedData, {
                key = tostring(item.key),
                value = math.floor(item.value), -- 确保value为整数
                nick = tostring(item.nick)
            })
            count = count + 1
        end
    end

    local cloudService = game:GetService("CloudService")
    local key = "ranking_table_" .. rankType
    
    cloudService:SetTableAsync(key, limitedData, function(success)
        if success then
            ----gg.log("保存排行榜表格数据成功", rankType, "保存数量:", #limitedData)
        else
            ----gg.log("保存排行榜表格数据失败", rankType)
        end
        
        if callback then
            callback(success)
        end
    end)
end

--- 系统初始化 - 预加载所有排行榜类型
function RankingCloudDataMgr.SystemInit()
    ----gg.log("排行榜云数据管理器初始化开始")

    for rankType, config in pairs(RankingConfig.CONFIGS) do
        local success = RankingCloudDataMgr.InitRankingStore(rankType)
        if success then
            ----gg.log("排行榜类型初始化成功", rankType, config.displayName)
        else
            ----gg.log("排行榜类型初始化失败", rankType, config.displayName)
        end
    end

    ----gg.log("排行榜云数据管理器初始化完成")
end



return RankingCloudDataMgr
