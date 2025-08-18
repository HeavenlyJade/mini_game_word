local MainStorage = game:GetService("MainStorage")
local WorkSpace= game:GetService("WorkSpace")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local RaceTrackConfig = require(MainStorage.Code.Common.Config.RaceTrackConfig) ---@type RaceTrackConfig

---@class RaceTrack
local RaceTrack = {}

-- 静态数据
RaceTrack.trackData = {} ---@type table<string, {originalNode: SandboxNode, clonedNodes: SandboxNode[]}> 赛道数据映射
RaceTrack.config = RaceTrackConfig ---@type RaceTrackConfig 配置引用

--- 初始化赛道系统
function RaceTrack.InitializeRaceTrack()
    gg.log("开始初始化赛道系统")
    
    -- 遍历所有配置的赛道路径
    for i, trackPath in ipairs(RaceTrack.config.trackPaths) do
        gg.log("正在初始化赛道路径:", i, trackPath)
        
        -- 获取飞行环境节点（使用MGlobal的GetChild方法）
        local flightEnvironment = gg.GetChild(WorkSpace, trackPath)
        
        if flightEnvironment then
            -- 初始化该赛道的克隆
            RaceTrack.InitializeSingleTrack(trackPath, flightEnvironment)
            gg.log("赛道路径", i, "初始化完成")
        else
            gg.log("错误：找不到赛道路径", i, ":", trackPath)
        end
    end
    
    gg.log("所有赛道系统初始化完成")
end

--- 初始化单个赛道
---@param trackPath string 赛道路径
---@param flightEnvironment SandboxNode 飞行环境节点
function RaceTrack.InitializeSingleTrack(trackPath, flightEnvironment)
    gg.log("开始初始化赛道:", trackPath)
    
    -- 初始化该赛道的数据结构
    RaceTrack.trackData[trackPath] = {
        originalNode = flightEnvironment,
        clonedNodes = {}
    }
    
    -- 克隆该赛道的飞行环境节点
    RaceTrack.CloneFlightEnvironment(trackPath)
end

--- 克隆飞行环境节点
---@param trackPath string 赛道路径
function RaceTrack.CloneFlightEnvironment(trackPath)
    local trackInfo = RaceTrack.trackData[trackPath]
    if not trackInfo or not trackInfo.originalNode then return end
    
    local flightEnvironment = trackInfo.originalNode
    local cloneCount = RaceTrack.config.cloneSettings.cloneCount
    
    gg.log("开始克隆赛道", trackPath, "的", cloneCount, "个飞行环境节点")
    
    -- 清空之前的克隆节点数组
    trackInfo.clonedNodes = {}
    
    -- 获取原节点位置
    local originalPosition = flightEnvironment.Position
    local parentNode = flightEnvironment.Parent
    
    if not parentNode then
        gg.log("错误：赛道", trackPath, "的原节点没有父节点")
        return
    end
    
    -- 批量克隆节点
    for i = 1, cloneCount do
        -- 克隆整个飞行环境
        local clonedEnvironment = flightEnvironment:Clone()
        clonedEnvironment.Name = "飞行环境_克隆_" .. i .. "_" .. trackPath:match("([^/]+)$")
        
        -- 计算位置偏移：沿着Z轴依次排列
        local zOffset = i * RaceTrack.config.cloneSettings.zOffset
        
        clonedEnvironment.Position = Vector3.New(
            originalPosition.X, 
            originalPosition.Y,            -- 保持相同高度
            originalPosition.Z + zOffset   -- Z轴偏移
        )
        
        -- 设置克隆节点的IgnoreStreamSync属性为True
        clonedEnvironment.IgnoreStreamSync = true
        
        -- 设置子节点的IgnoreStreamSync属性为True
        RaceTrack.SetChildrenIgnoreStreamSync(clonedEnvironment)
        
        -- 将克隆的节点设置为原节点的父节点的子节点
        clonedEnvironment.Parent = parentNode
        
        -- 保存克隆的节点引用到数组
        table.insert(trackInfo.clonedNodes, clonedEnvironment)
        
        gg.log("赛道", trackPath, "克隆节点", i, "完成，位置:", clonedEnvironment.Position)
    end
    
    gg.log("赛道", trackPath, "的所有", cloneCount, "个飞行环境节点克隆完成")
end



--- 设置指定直接子节点的IgnoreStreamSync属性为True
---@param parentNode SandboxNode 父节点
function RaceTrack.SetChildrenIgnoreStreamSync(parentNode)
    if not parentNode then return end
    
    -- 只设置指定的直接子节点：飞行环境和飞行赛道
    local flightEnvironment = parentNode["飞行环境"]
    if flightEnvironment then
        flightEnvironment.IgnoreStreamSync = true
    end
    
    local flightTrack = parentNode["飞行赛道"]
    if flightTrack then
        flightTrack.IgnoreStreamSync = true
    end
end

--- 设置空气墙属性
---@param airWallNode SandboxNode 空气墙节点
---@param index number 空气墙索引
---@param trackPath string 赛道路径（可选）
function RaceTrack.SetupAirWall(airWallNode, index, trackPath)
    if not airWallNode then return end
    
    -- 设置空气墙的物理属性
    airWallNode.PhysXType = Enum.PhysXType.BOX
    
    -- 设置空气墙为透明但可碰撞
    airWallNode.Transparency = RaceTrack.config.cloneSettings.transparency
    
    -- 可以添加其他属性设置
    -- 例如：碰撞检测、触发器等
    
    local trackName = trackPath and trackPath:match("([^/]+)$") or "默认"
    gg.log("赛道", trackName, "的空气墙", index, "属性设置完成")
end

--- 获取指定赛道的克隆环境节点数组
---@param trackPath string 赛道路径
---@return SandboxNode[]|nil
function RaceTrack.GetClonedEnvironments(trackPath)
    local trackInfo = RaceTrack.trackData[trackPath]
    return trackInfo and trackInfo.clonedNodes or nil
end

--- 获取所有赛道的克隆环境节点
---@return SandboxNode[]
function RaceTrack.GetAllClonedEnvironments()
    local allCloned = {}
    for trackPath, trackInfo in pairs(RaceTrack.trackData) do
        for _, clonedNode in ipairs(trackInfo.clonedNodes) do
            table.insert(allCloned, clonedNode)
        end
    end
    return allCloned
end

--- 获取指定赛道的指定索引的克隆环境节点
---@param trackPath string 赛道路径
---@param index number 克隆节点索引
---@return SandboxNode|nil
function RaceTrack.GetClonedEnvironment(trackPath, index)
    local trackInfo = RaceTrack.trackData[trackPath]
    if trackInfo and index and index >= 1 and index <= #trackInfo.clonedNodes then
        return trackInfo.clonedNodes[index]
    end
    return nil
end

--- 获取指定赛道的第一个克隆节点的地面赛道
---@param trackPath string 赛道路径
---@return SandboxNode|nil
function RaceTrack.GetGroundTrack(trackPath)
    local clonedEnvs = RaceTrack.GetClonedEnvironments(trackPath)
    if clonedEnvs and #clonedEnvs > 0 then
        return clonedEnvs[1]:FindFirstChild("地面赛道")
    end
    return nil
end

--- 获取指定赛道的指定克隆节点的地面赛道
---@param trackPath string 赛道路径
---@param index number 克隆节点索引
---@return SandboxNode|nil
function RaceTrack.GetGroundTrackByIndex(trackPath, index)
    local clonedEnv = RaceTrack.GetClonedEnvironment(trackPath, index)
    if clonedEnv then
        return clonedEnv:FindFirstChild("地面赛道")
    end
    return nil
end

--- 获取指定赛道的第一个克隆节点的空气墙
---@param trackPath string 赛道路径
---@param index number 空气墙索引
---@return SandboxNode|nil
function RaceTrack.GetAirWall(trackPath, index)
    local clonedEnvs = RaceTrack.GetClonedEnvironments(trackPath)
    if clonedEnvs and #clonedEnvs > 0 and index >= 1 and index <= 3 then
        return clonedEnvs[1]:FindFirstChild("空气墙" .. index)
    end
    return nil
end

--- 获取指定赛道的指定克隆节点的空气墙
---@param trackPath string 赛道路径
---@param cloneIndex number 克隆节点索引
---@param airWallIndex number 空气墙索引
---@return SandboxNode|nil
function RaceTrack.GetAirWallByIndex(trackPath, cloneIndex, airWallIndex)
    local clonedEnv = RaceTrack.GetClonedEnvironment(trackPath, cloneIndex)
    if clonedEnv and airWallIndex >= 1 and airWallIndex <= 3 then
        return clonedEnv:FindFirstChild("空气墙" .. airWallIndex)
    end
    return nil
end

--- 显示/隐藏指定赛道的第一个克隆节点的空气墙
---@param trackPath string 赛道路径
---@param index number 空气墙索引
---@param visible boolean 是否可见
function RaceTrack.SetAirWallVisible(trackPath, index, visible)
    local airWall = RaceTrack.GetAirWall(trackPath, index)
    if airWall then
        airWall.Visible = visible
        local trackName = trackPath:match("([^/]+)$")
        gg.log("赛道", trackName, "的空气墙", index, "可见性设置为:", visible)
    end
end

--- 显示/隐藏指定赛道的指定克隆节点的空气墙
---@param trackPath string 赛道路径
---@param cloneIndex number 克隆节点索引
---@param airWallIndex number 空气墙索引
---@param visible boolean 是否可见
function RaceTrack.SetAirWallVisibleByIndex(trackPath, cloneIndex, airWallIndex, visible)
    local airWall = RaceTrack.GetAirWallByIndex(trackPath, cloneIndex, airWallIndex)
    if airWall then
        airWall.Visible = visible
        local trackName = trackPath:match("([^/]+)$")
        gg.log("赛道", trackName, "的克隆节点", cloneIndex, "的空气墙", airWallIndex, "可见性设置为:", visible)
    end
end

--- 设置指定赛道的第一个克隆节点的位置
---@param trackPath string 赛道路径
---@param position Vector3 目标位置
function RaceTrack.SetTrackPosition(trackPath, position)
    local clonedEnvs = RaceTrack.GetClonedEnvironments(trackPath)
    if clonedEnvs and #clonedEnvs > 0 then
        clonedEnvs[1].Position = position
        local trackName = trackPath:match("([^/]+)$")
        gg.log("赛道", trackName, "位置设置为:", position)
    end
end

--- 设置指定赛道的指定克隆节点的位置
---@param trackPath string 赛道路径
---@param index number 克隆节点索引
---@param position Vector3 目标位置
function RaceTrack.SetTrackPositionByIndex(trackPath, index, position)
    local clonedEnv = RaceTrack.GetClonedEnvironment(trackPath, index)
    if clonedEnv then
        clonedEnv.Position = position
        local trackName = trackPath:match("([^/]+)$")
        gg.log("赛道", trackName, "的克隆节点", index, "位置设置为:", position)
    end
end

--- 清理指定赛道的资源
---@param trackPath string 赛道路径
function RaceTrack.DestroyTrack(trackPath)
    local trackInfo = RaceTrack.trackData[trackPath]
    if trackInfo then
        for i, clonedEnv in ipairs(trackInfo.clonedNodes) do
            if clonedEnv then
                clonedEnv:Destroy()
                local trackName = trackPath:match("([^/]+)$")
                gg.log("销毁赛道", trackName, "的克隆节点", i)
            end
        end
        trackInfo.clonedNodes = {}
        RaceTrack.trackData[trackPath] = nil
        local trackName = trackPath:match("([^/]+)$")
        gg.log("赛道", trackName, "资源已清理")
    end
end

--- 清理所有赛道资源
function RaceTrack.Destroy()
    for trackPath, _ in pairs(RaceTrack.trackData) do
        RaceTrack.DestroyTrack(trackPath)
    end
    gg.log("所有赛道资源已清理")
end

--- 获取指定赛道的克隆节点数量
---@param trackPath string 赛道路径
---@return number
function RaceTrack.GetCloneCount(trackPath)
    local trackInfo = RaceTrack.trackData[trackPath]
    return trackInfo and #trackInfo.clonedNodes or 0
end

--- 获取所有赛道的总克隆节点数量
---@return number
function RaceTrack.GetTotalCloneCount()
    local totalCount = 0
    for trackPath, trackInfo in pairs(RaceTrack.trackData) do
        totalCount = totalCount + #trackInfo.clonedNodes
    end
    return totalCount
end

--- 获取已初始化的赛道数量
---@return number
function RaceTrack.GetTrackCount()
    local count = 0
    for _ in pairs(RaceTrack.trackData) do
        count = count + 1
    end
    return count
end

return RaceTrack