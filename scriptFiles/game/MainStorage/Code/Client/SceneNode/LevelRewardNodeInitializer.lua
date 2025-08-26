-- 初始化关卡奖励节点器.lua
-- 负责加载并初始化init_map、map2和map3的关卡奖励节点
-- 基于LevelNodeRewardType配置进行节点克隆和触发器绑定

local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local ConfigLoader = require(MainStorage.Code.Common.ConfigLoader) ---@type ConfigLoader
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local EventPlayerConfig = require(MainStorage.Code.Event.EventPlayer) ---@type EventPlayerConfig

---@class LevelRewardNodeInitializer
local LevelRewardNodeInitializer = {}

-- 存储已克隆的节点引用，用于后续管理
LevelRewardNodeInitializer.clonedNodes = {}

--- 初始化所有关卡奖励节点
function LevelRewardNodeInitializer.InitializeAllLevelRewardNodes()
    --gg.log("开始初始化关卡奖励节点器")
    
    -- 获取所有关卡奖励配置
    local allLevelRewards = ConfigLoader.GetAllLevelNodeRewards()
    
    -- 初始化init_map、map2和map3的关卡奖励节点
    local targetMaps = {"init_map", "map2", "map3"}
    
    for _, mapName in ipairs(targetMaps) do
        --gg.log("正在初始化地图:", mapName, "的关卡奖励节点")
        
        -- 筛选当前地图的配置
        local mapConfigs = LevelRewardNodeInitializer.GetConfigsByMap(allLevelRewards, mapName)
        
        for _, config in pairs(mapConfigs) do
            LevelRewardNodeInitializer.InitializeSingleLevelReward(config, mapName)
        end
    end
    
    --gg.log("关卡奖励节点器初始化完成，共克隆节点数:", #LevelRewardNodeInitializer.clonedNodes)
end

--- 根据地图名称筛选配置
---@param allConfigs table<string, LevelNodeRewardType> 所有关卡奖励配置
---@param mapName string 地图名称 ("map2", "map3")
---@return table<string, LevelNodeRewardType> 筛选后的配置
function LevelRewardNodeInitializer.GetConfigsByMap(allConfigs, mapName)
    local result = {}
    
    for configId, config in pairs(allConfigs) do
        -- 检查配置的所属场景是否为目标地图
        local sceneName = config:GetSceneName()
        if sceneName and sceneName == mapName then
            result[configId] = config
            --gg.log("找到地图", mapName, "的关卡奖励配置:", config:GetName())
        end
    end
    
    return result
end

--- 初始化单个关卡奖励配置
---@param config LevelNodeRewardType 关卡奖励配置
---@param mapName string 地图名称
function LevelRewardNodeInitializer.InitializeSingleLevelReward(config, mapName)
    if not config then 
        --gg.log("错误：关卡奖励配置为空")
        return 
    end
    
    --gg.log("初始化关卡奖励配置:", config:GetName())
    
    -- 获取场景节点路径
    local sceneNodePath = config:GetSceneNodePath()
    if not sceneNodePath or sceneNodePath == "" then
        --gg.log("错误：关卡奖励配置", config:GetName(), "没有配置场景节点路径")
        return
    end
    
    -- 在场景中查找原始节点
    local originalNode = gg.GetChild(WorkSpace, sceneNodePath)
    if not originalNode then
        --gg.log("错误：找不到场景节点，路径:", sceneNodePath)
        return
    end
    
    -- 获取节点的父容器
    local parentNode = originalNode.Parent
    if not parentNode then
        --gg.log("错误：原始节点没有父容器，路径:", sceneNodePath)
        return
    end
    
    -- 循环_idMap进行节点克隆
    local idMap = config._idMap
    if not idMap or not next(idMap) then
        --gg.log("警告：配置", config:GetName(), "没有可用的_idMap数据")
        return
    end
    
    --gg.log("开始克隆节点，_idMap项目数:", LevelRewardNodeInitializer.GetTableCount(idMap))
    
    local cloneIndex = 0
    for uniqueId, rewardNode in pairs(idMap) do
        cloneIndex = cloneIndex + 1
        LevelRewardNodeInitializer.CloneSingleRewardNode(
            originalNode, 
            parentNode, 
            uniqueId, 
            rewardNode, 
            cloneIndex,
            config:GetName(),
            mapName
        )
    end
end

--- 克隆单个奖励节点
---@param originalNode SandboxNode 原始节点
---@param parentNode SandboxNode 父容器节点
---@param uniqueId string 唯一ID
---@param rewardNode LevelNodeRewardItem 奖励节点数据
---@param cloneIndex number 克隆索引
---@param configName string 配置名称
---@param mapName string 地图名称
function LevelRewardNodeInitializer.CloneSingleRewardNode(originalNode, parentNode, uniqueId, rewardNode, cloneIndex, configName, mapName)
    -- 克隆原始节点
    local clonedNode = originalNode:Clone()
    
    -- 设置克隆节点的名称（包含唯一标识）
    clonedNode.Name = string.format("%s_奖励节点_%s_%d", originalNode.Name, uniqueId, cloneIndex)
    
    -- 获取生成的距离配置
    local distanceConfig = rewardNode["生成的距离配置"] or 0
    
    -- 修改x轴距离（将距离配置应用到x轴位置）
    local originalPos = originalNode.Position
    local newPosition = Vector3.New(
        originalPos.X , 
        originalPos.Y,          
        originalPos.Z   + distanceConfig         
    )
    clonedNode.Position = newPosition
    
    -- 设置克隆节点的IgnoreStreamSync属性为true（优化网络同步）
    clonedNode.IgnoreStreamSync = true
    clonedNode.Visible = true
    
    -- 将克隆节点添加到父容器
    clonedNode.Parent = parentNode
    
    -- 绑定TriggerBox触发事件
    LevelRewardNodeInitializer.BindTriggerBoxEvent(clonedNode, uniqueId, rewardNode, configName, mapName)
    
    -- 保存克隆节点引用
    table.insert(LevelRewardNodeInitializer.clonedNodes, {
        node = clonedNode,
        uniqueId = uniqueId,
        rewardNode = rewardNode,
        configName = configName,
        mapName = mapName,
        distanceConfig = distanceConfig
    })
    
    --gg.log(string.format("克隆节点完成 - 配置:%s, ID:%s, 位置:(%g,%g,%g), 距离配置:%g", 
        -- configName, uniqueId, newPosition.X, newPosition.Y, newPosition.Z, distanceConfig))
end

--- 绑定TriggerBox触发事件
---@param clonedNode SandboxNode 克隆的节点
---@param uniqueId string 唯一ID
---@param rewardNode LevelNodeRewardItem 奖励节点数据
---@param configName string 配置名称
---@param mapName string 地图名称
function LevelRewardNodeInitializer.BindTriggerBoxEvent(clonedNode, uniqueId, rewardNode, configName, mapName)
    -- 查找TriggerBox子节点
    local triggerBox = clonedNode:FindFirstChild("TriggerBox") -- 递归查找
    
    if not triggerBox then
        --gg.log("警告：在克隆节点中找不到TriggerBox，节点:", clonedNode.Name)
        return
    end
    
    if triggerBox.ClassType ~= 'TriggerBox' then
        --gg.log("警告：找到的节点不是TriggerBox类型，节点:", triggerBox.Name, "类型:", triggerBox.ClassType)
        return
    end
    
    -- 绑定触发事件
    triggerBox.Touched:Connect(function(actor)
        LevelRewardNodeInitializer.OnTriggerBoxTouched(actor, uniqueId, rewardNode, configName, mapName,triggerBox)
    end)
    
    --gg.log("TriggerBox触发事件绑定完成 - 节点:", clonedNode.Name, "ID:", uniqueId)
end

--- TriggerBox触发事件处理
---@param actor any 触发的Actor对象
---@param uniqueId string 唯一ID
---@param rewardNode LevelNodeRewardItem 奖励节点数据
---@param configName string 配置名称
---@param mapName string 地图名称
function LevelRewardNodeInitializer.OnTriggerBoxTouched(actor, uniqueId, rewardNode, configName, mapName,triggerBox)
    -- 检查是否为玩家触发
    if not actor or not actor.UserId then
        return -- 只处理玩家触发
    end
    
    local playerId = actor.UserId
    --gg.log("玩家触发关卡奖励节点 - 玩家ID:", playerId, "奖励ID:", uniqueId, "配置:", configName)
    
    -- 播放触发音效
    LevelRewardNodeInitializer.PlayTriggerSound(triggerBox)
    
    -- 构建发送到服务端的消息数据
    local messageData = {
        cmd = EventPlayerConfig.REQUEST.LEVEL_REWARD_NODE_TRIGGERED,           -- 命令类型
        playerId = playerId,                        -- 玩家ID
        uniqueId = uniqueId,                        -- 奖励节点唯一ID
        configName = configName,                    -- 配置名称
        mapName = mapName,                          -- 地图名称
        rewardType = rewardNode["奖励类型"] or "",   -- 奖励类型
        itemType = rewardNode["物品类型"] or "",     -- 物品类型
        itemCount = rewardNode["物品数量"] or 0,     -- 物品数量
        rewardCondition = rewardNode["奖励条件"] or "", -- 奖励条件
        distanceConfig = rewardNode["生成的距离配置"] or 0, -- 距离配置
        timestamp = os.time()                       -- 时间戳
    }
    
    -- 发送消息到服务端（这里使用网络通道发送）
    LevelRewardNodeInitializer.SendToServer(messageData)
    
    -- 记录详细日志用于调试
    --gg.log(string.format("关卡奖励触发详情 - 奖励类型:%s, 物品类型:%s, 数量:%d, 条件:%s", 
        -- messageData.rewardType, messageData.itemType, messageData.itemCount, messageData.rewardCondition))
end

--- 发送消息到服务端
---@param messageData table 消息数据
function LevelRewardNodeInitializer.SendToServer(messageData)
    -- 使用项目的网络通道发送消息到服务端
    if gg.network_channel then
        gg.network_channel:fireServer(messageData)
        --gg.log("关卡奖励消息已发送到服务端, 命令:", messageData.cmd, "玩家:", messageData.playerId)
    else
        --gg.log("错误：无法找到网络通道，无法发送消息到服务端")
    end
end

--- 获取table中元素数量的辅助函数
---@param t table
---@return number
function LevelRewardNodeInitializer.GetTableCount(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- 清理所有克隆的节点（用于重置或清理）
function LevelRewardNodeInitializer.CleanupClonedNodes()
    --gg.log("开始清理克隆的关卡奖励节点")
    
    for i, nodeInfo in ipairs(LevelRewardNodeInitializer.clonedNodes) do
        if nodeInfo.node and nodeInfo.node.Parent then
            nodeInfo.node:Destroy()
            --gg.log("销毁克隆节点:", nodeInfo.configName, "ID:", nodeInfo.uniqueId)
        end
    end
    
    -- 清空引用数组
    LevelRewardNodeInitializer.clonedNodes = {}
    
    --gg.log("关卡奖励节点清理完成")
end

--- 获取指定地图的所有克隆节点信息
---@param mapName string 地图名称
---@return table[] 该地图的克隆节点信息列表
function LevelRewardNodeInitializer.GetClonedNodesByMap(mapName)
    local result = {}
    
    for _, nodeInfo in ipairs(LevelRewardNodeInitializer.clonedNodes) do
        if nodeInfo.mapName == mapName then
            table.insert(result, nodeInfo)
        end
    end
    
    return result
end

--- 获取指定配置的所有克隆节点信息
---@param configName string 配置名称
---@return table[] 该配置的克隆节点信息列表
function LevelRewardNodeInitializer.GetClonedNodesByConfig(configName)
    local result = {}
    
    for _, nodeInfo in ipairs(LevelRewardNodeInitializer.clonedNodes) do
        if nodeInfo.configName == configName then
            table.insert(result, nodeInfo)
        end
    end
    
    return result
end

--- 播放触发音效
---@param triggerBox TriggerBox 触发器节点
function LevelRewardNodeInitializer.PlayTriggerSound(triggerBox)
    if not triggerBox then
        return
    end
    
    -- 获取触发音效自定义属性
    local triggerSound = triggerBox:GetAttribute("触发音效")
    if not triggerSound or triggerSound == "" then
        return
    end
    
    -- 导入SoundPool模块
    local SoundPool = require(game:GetService("MainStorage").Code.Client.Graphic.SoundPool) ---@type SoundPool
    
    -- 播放音效
    SoundPool.PlaySound({
        soundAssetId = triggerSound,
        volume = 1.0,
        pitch = 1.0,
        range = 6000
    })
    
    --gg.log("播放触发音效:", triggerSound)
end

return LevelRewardNodeInitializer