local MainStorage = game:GetService("MainStorage")
local WorkSpace= game:GetService("WorkSpace")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class RaceTrack
local RaceTrack = {}

-- 静态数据
RaceTrack.flightEnvironment = nil ---@type SandboxNode 飞行环境节点
RaceTrack.clonedEnvironments = {} ---@type SandboxNode[] 克隆的飞行环境节点数组
RaceTrack.cloneCount = 30 ---@type number 克隆数量
RaceTrack.xOffset = 100 ---@type number X轴偏移量
RaceTrack.zOffset = 100 ---@type number Z轴偏移量

--- 初始化赛道系统
function RaceTrack.InitializeRaceTrack()
    --gg.log("开始初始化赛道系统")
    
    -- 获取飞行环境节点（使用MGlobal的GetChild方法）
    RaceTrack.flightEnvironment = gg.GetChild(WorkSpace, "Ground/init_map/terrain/Scene/race_track/地面赛道")
    --gg.log("self.flightEnvironment", RaceTrack.flightEnvironment)
    
    if RaceTrack.flightEnvironment then
        -- 克隆飞行环境节点
        RaceTrack.CloneFlightEnvironment()
        
        
        --gg.log("赛道系统初始化完成")
    else
        --gg.log("错误：找不到飞行环境节点")
    end
end

--- 克隆飞行环境节点
function RaceTrack.CloneFlightEnvironment()
    if not RaceTrack.flightEnvironment then return end
    
    --gg.log("开始克隆", RaceTrack.cloneCount, "个飞行环境节点")
    
    -- 清空之前的克隆节点数组
    RaceTrack.clonedEnvironments = {}
    
    -- 获取原节点位置
    local originalPosition = RaceTrack.flightEnvironment.Position
    local parentNode = RaceTrack.flightEnvironment.Parent
    
    if not parentNode then
        --gg.log("错误：原节点没有父节点")
        return
    end
    --gg.log("RaceTrack.flightEnvironmen",RaceTrack.flightEnvironment.Size)
    -- 批量克隆节点
    for i = 1, RaceTrack.cloneCount do
        -- 克隆整个飞行环境
        local clonedEnvironment = RaceTrack.flightEnvironment:Clone()
        clonedEnvironment.Name = "飞行环境_克隆_" .. i
        
        -- 计算位置偏移：沿着X轴和Z轴依次排列
        local zOffset = (i - 1) * RaceTrack.flightEnvironment.Size.Z
        
        clonedEnvironment.Position = Vector3.New(
            originalPosition.X , 
            originalPosition.Y,            -- 保持相同高度
            originalPosition.Z + zOffset   -- Z轴偏移
        )
        
        -- 将克隆的节点设置为原节点的父节点的子节点
        clonedEnvironment.Parent = parentNode
        
        -- 保存克隆的节点引用到数组
        table.insert(RaceTrack.clonedEnvironments, clonedEnvironment)
        
        --gg.log("克隆节点", i, "完成，位置:", clonedEnvironment.Position)
    end
    
    --gg.log("所有", RaceTrack.cloneCount, "个飞行环境节点克隆完成")
end



--- 设置空气墙属性
function RaceTrack.SetupAirWall(airWallNode, index)
    if not airWallNode then return end
    
    -- 设置空气墙的物理属性
    airWallNode.PhysXType = Enum.PhysXType.BOX
    
    -- 设置空气墙为透明但可碰撞
    airWallNode.Transparency = 0.8  -- 80%透明
    
    -- 可以添加其他属性设置
    -- 例如：碰撞检测、触发器等
    
    --gg.log("空气墙", index, "属性设置完成")
end

--- 获取克隆的飞行环境节点数组
function RaceTrack.GetClonedEnvironments()
    return RaceTrack.clonedEnvironments
end

--- 获取指定索引的克隆环境节点
function RaceTrack.GetClonedEnvironment(index)
    if index and index >= 1 and index <= #RaceTrack.clonedEnvironments then
        return RaceTrack.clonedEnvironments[index]
    end
    return nil
end

--- 获取地面赛道节点（从第一个克隆节点）
function RaceTrack.GetGroundTrack()
    if #RaceTrack.clonedEnvironments > 0 then
        return RaceTrack.clonedEnvironments[1]:FindFirstChild("地面赛道")
    end
    return nil
end

--- 获取指定克隆节点的地面赛道
function RaceTrack.GetGroundTrackByIndex(index)
    local clonedEnv = RaceTrack.GetClonedEnvironment(index)
    if clonedEnv then
        return clonedEnv:FindFirstChild("地面赛道")
    end
    return nil
end

--- 获取空气墙节点（从第一个克隆节点）
function RaceTrack.GetAirWall(index)
    if #RaceTrack.clonedEnvironments > 0 and index >= 1 and index <= 3 then
        return RaceTrack.clonedEnvironments[1]:FindFirstChild("空气墙" .. index)
    end
    return nil
end

--- 获取指定克隆节点的空气墙
function RaceTrack.GetAirWallByIndex(cloneIndex, airWallIndex)
    local clonedEnv = RaceTrack.GetClonedEnvironment(cloneIndex)
    if clonedEnv and airWallIndex >= 1 and airWallIndex <= 3 then
        return clonedEnv:FindFirstChild("空气墙" .. airWallIndex)
    end
    return nil
end

--- 显示/隐藏空气墙（第一个克隆节点）
function RaceTrack.SetAirWallVisible(index, visible)
    local airWall = RaceTrack.GetAirWall(index)
    if airWall then
        airWall.Visible = visible
        --gg.log("空气墙", index, "可见性设置为:", visible)
    end
end

--- 显示/隐藏指定克隆节点的空气墙
function RaceTrack.SetAirWallVisibleByIndex(cloneIndex, airWallIndex, visible)
    local airWall = RaceTrack.GetAirWallByIndex(cloneIndex, airWallIndex)
    if airWall then
        airWall.Visible = visible
        --gg.log("克隆节点", cloneIndex, "的空气墙", airWallIndex, "可见性设置为:", visible)
    end
end

--- 设置赛道位置（第一个克隆节点）
function RaceTrack.SetTrackPosition(position)
    if #RaceTrack.clonedEnvironments > 0 then
        RaceTrack.clonedEnvironments[1].Position = position
        --gg.log("赛道位置设置为:", position)
    end
end

--- 设置指定克隆节点的位置
function RaceTrack.SetTrackPositionByIndex(index, position)
    local clonedEnv = RaceTrack.GetClonedEnvironment(index)
    if clonedEnv then
        clonedEnv.Position = position
        --gg.log("克隆节点", index, "位置设置为:", position)
    end
end

--- 清理资源
function RaceTrack.Destroy()
    for i, clonedEnv in ipairs(RaceTrack.clonedEnvironments) do
        if clonedEnv then
            clonedEnv:Destroy()
            --gg.log("销毁克隆节点", i)
        end
    end
    RaceTrack.clonedEnvironments = {}
    --gg.log("所有赛道资源已清理")
end

--- 获取克隆节点数量
function RaceTrack.GetCloneCount()
    return #RaceTrack.clonedEnvironments
end

return RaceTrack