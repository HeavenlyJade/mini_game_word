--- MRankingCom.lua
-- 排行榜指令处理器
-- 使用 CloudKVStore 接口管理排行榜数据

local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local CloudService = game:GetService("CloudService") ---@type CloudService

local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RankingConfig = require(MainStorage.Code.Common.Config.RankingConfig) ---@type RankingConfig
local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager

---@class RankingCommand
local RankingCommand = {}

--- 内部辅助函数：验证排行榜类型并获取排行榜实例
---@param rankType string
---@return CloudKVStore|nil, string|nil
local function getAndValidateRanking(rankType)
    if not rankType then
        return nil, "缺少'排行榜类型'参数"
    end

    local isValid = false
    for _, typeValue in pairs(RankingConfig.TYPES) do
        if typeValue == rankType then
            isValid = true
            break
        end
    end

    if not isValid then
        return nil, string.format("无效的排行榜类型: %s", rankType)
    end

    local ranking = CloudService:GetOrderDataCloud(rankType)
    if not ranking then
        return nil, string.format("获取排行榜实例失败: %s", rankType)
    end

    return ranking, nil
end

--- 内部辅助函数：获取目标玩家信息
---@param params table
---@return number|nil, string|nil, string|nil
local function getTargetPlayerInfo(params)
    local uin, name
    if params["玩家UIN"] then
        uin = tonumber(params["玩家UIN"])
        if not uin then
            return nil, nil, "玩家UIN格式错误"
        end
        local player = MServerDataManager.getPlayerByUin(uin)
        name = player and player.name or "未知玩家"
    else
        return nil, nil, "缺少'玩家UIN'参数"
    end
    return uin, name, nil
end


--- 删除排行榜中的玩家数据
---@param params table
---@return boolean, string
local function removePlayer(params)
    local ranking, err = getAndValidateRanking(params["排行榜类型"])
    if not ranking then return false, err or "未知错误" end

    local uin, _, err = getTargetPlayerInfo(params)
    if not uin then return false, err or "未知错误" end

    local result = ranking:RemoveKey(tostring(uin))
    if result == 0 then
        local msg = string.format("成功从排行榜 [%s] 中删除玩家 [UIN:%d]", params["排行榜类型"], uin)
        gg.log(msg)
        return true, msg
    else
        local msg = string.format("从排行榜 [%s] 中删除玩家 [UIN:%d] 失败，返回代码: %s", params["排行榜类型"], uin, tostring(result))
        gg.log(msg)
        return false, msg
    end
end

--- 清空整个排行榜
---@param params table
---@return boolean, string
local function clearRanking(params)
    local ranking, err = getAndValidateRanking(params["排行榜类型"])
    if not ranking then return false, err or "未知错误" end

    ranking:Clean()
    local msg = string.format("已发送清空排行榜 [%s] 的指令", params["排行榜类型"])
    gg.log(msg)
    return true, msg
end

--- 设置玩家分数
---@param params table
---@return boolean, string
local function setScore(params)
    local ranking, err = getAndValidateRanking(params["排行榜类型"])
    if not ranking then return false, err or "未知错误" end

    local uin, name, err = getTargetPlayerInfo(params)
    if not uin then return false, err or "未知错误" end

    local score = tonumber(params["分数"])
    if not score then
        return false, "缺少'分数'参数或格式错误"
    end

    ranking:SetValueAsync(tostring(uin), name or "未知玩家", score, function(code)
        if code == 0 then
            gg.log(string.format("异步设置分数成功: 排行榜[%s], 玩家[%s], 分数[%d]", params["排行榜类型"], name or uin, score))
        else
            gg.log(string.format("异步设置分数失败: 排行榜[%s], 玩家[%s], 分数[%d], 代码[%s]", params["排行榜类型"], name or uin, score, tostring(code)))
        end
    end)

    return true, string.format("已发送异步设置分数指令: 玩家[%s], 分数[%d]", name or uin, score)
end

--- 查看玩家分数
---@param params table
---@return boolean, string
local function viewScore(params)
    local ranking, err = getAndValidateRanking(params["排行榜类型"])
    if not ranking then return false, err or "未知错误" end
    
    local uin, name, err = getTargetPlayerInfo(params)
    if not uin then return false, err or "未知错误" end

    ranking:GetValueAsync(tostring(uin), name or "未知玩家", function(code, val)
        if code == 0 then
            local playerNameForMsg = name or ("UIN:" .. uin)
            local msg = string.format("玩家 [%s] 在排行榜 [%s] 的分数为: %d", playerNameForMsg, params["排行榜类型"], val)
            gg.log(msg)
            -- 这里无法直接返回给指令执行者，因为是异步回调
        else
            gg.log(string.format("异步获取玩家分数失败: 玩家UIN[%s], 代码[%s]", tostring(uin), tostring(code)))
        end
    end)
    
    return true, "已发送异步获取玩家分数指令，请在服务器日志中查看结果"
end

--- 查看排行榜顶部排名
---@param params table
---@return boolean, string
local function viewTopRanks(params)
    local ranking, err = getAndValidateRanking(params["排行榜类型"])
    if not ranking then return false, err or "未知错误" end

    local count = tonumber(params["数量"]) or 10
    local rankData = ranking:GetTopSync(count)

    if not rankData or type(rankData) ~= "table" then
        return false, "获取排行榜数据失败或返回格式错误"
    end

    local results = {string.format("--- %s Top %d ---", params["排行榜类型"], count)}
    for i, entry in ipairs(rankData) do
        table.insert(results, string.format("排名 %d: UIN[%s], 分数[%d]", i, entry.key, entry.value))
    end

    local msg = table.concat(results, "\n")
    gg.log(msg)
    return true, msg
end

--- 排行榜指令主入口
---@param params table 指令参数
---@param player MPlayer 执行者
---@return boolean, string
function RankingCommand.main(params, player)
    if not gg.opUin[player.uin] then
        return false, "你没有执行此指令的权限"
    end

    local operationType = params["操作类型"]
    local handlers = {
        ["删除玩家"] = removePlayer,
        ["清空排行榜"] = clearRanking,
        ["设置分数"] = setScore,
        ["查看分数"] = viewScore,
        ["查看排行榜"] = viewTopRanks,
    }

    local handler = handlers[operationType]
    if handler then
        return handler(params)
    else
        local validOps = {}
        for opName, _ in pairs(handlers) do
            table.insert(validOps, opName)
        end
        return false, "无效的操作类型。有效值: " .. table.concat(validOps, ", ")
    end
end

return RankingCommand
