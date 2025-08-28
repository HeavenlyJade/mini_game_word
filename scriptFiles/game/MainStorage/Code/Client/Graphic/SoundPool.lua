local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

---@class SoundPool 音效池管理类
local SoundPool = {}

-- 私有属性
local _soundNodePoolReady = {} -- 可用音效节点池
local _lastPlayTimes = {} -- 记录每个声音的最后播放时间，防止0.1秒内重复播放
local _keyedSounds = {} -- 有键值的音效节点（如背景音乐）
local _soundPoolContainer = nil -- 音效池容器节点
local _isInitialized = false -- 是否已初始化

-- 常量配置
local POOL_SIZE = 50 -- 音效池大小
local REPEAT_THRESHOLD = 0.1 -- 防重复播放阈值（秒）
local DEFAULT_VOLUME = 1.0
local DEFAULT_PITCH = 1.0
local DEFAULT_RANGE = 6000

---初始化音效池
---@param poolSize number|nil 音效池大小，默认50个
function SoundPool.Init(poolSize)
    if _isInitialized then
        print("[SoundPool] Warning: Already initialized")
        return
    end
    
    poolSize = poolSize or POOL_SIZE
    
    -- 创建音效池容器
    _soundPoolContainer = SandboxNode.new("Transform", WorkSpace)
    _soundPoolContainer.Name = "SoundPool"
    
    -- 预创建音效节点
    for i = 1, poolSize do
        local soundNode = SandboxNode.new("Sound", _soundPoolContainer)
        soundNode.Name = "SoundNode" .. i
        table.insert(_soundNodePoolReady, soundNode)
    end
    
    -- 订阅音效播放事件
    ClientEventManager.Subscribe("PlaySound", function(data)
        SoundPool.PlaySound(data)
    end)
    
    _isInitialized = true
    print("[SoundPool] Initialized with " .. poolSize .. " sound nodes")
end

---播放音效
---播放音效（修复版本）
---@param data table 音效数据 {soundAssetId: string, key: string|nil, volume: number|nil, pitch: number|nil, range: number|nil, boundTo: string|nil, position: table|nil}
function SoundPool.PlaySound(data)
    if not _isInitialized then
        print("[SoundPool] 错误：未初始化，请先调用SoundPool.Init()")
        return
    end
    
    local sound = data.soundAssetId
    if not sound or sound == "" then
        return
    end
    
    -- 处理随机音效 [1~5] 格式
    sound = SoundPool._ProcessRandomSound(sound)
    
    -- 防重复播放检查
    if SoundPool._IsRecentlyPlayed(sound) then
        return
    end
    
    -- 获取音效节点
    local soundNode = SoundPool._GetSoundNode(data.key, sound)
    if not soundNode then
        return
    end
    
    -- 设置音效参数
    SoundPool._ConfigureSoundNode(soundNode, sound, data)
    
    -- 关键修复：无论是否有key都要设置位置，避免全局播放
    SoundPool._SetSoundPosition(soundNode, data)
    
    -- 播放音效
    soundNode:PlaySound()
    
    -- 获取当前玩家位置并记录日志
    local currentPlayer = game.Players.LocalPlayer
    local playerPos = currentPlayer and currentPlayer.Character and currentPlayer.Character.Position
    if playerPos then
        gg.log("[SoundPool] 音效已触发播放:", sound)
        gg.log("[SoundPool] 当前玩家位置:", playerPos)
        gg.log("[SoundPool] 音效播放位置:", soundNode.FixPos or "全局播放")
        
        -- 计算音效位置与玩家位置的距离
        if soundNode.FixPos then
            -- 检查FixPos是否为有效的Vector3对象
            if soundNode.FixPos.X and soundNode.FixPos.Y and soundNode.FixPos.Z then
                -- 使用VectorCalc.Distance3计算距离
                local VectorCalc = require(MainStorage.Code.Untils.VectorUtils).Vec
                local distance = VectorCalc.Distance3(soundNode.FixPos, playerPos)
                
                gg.log("[SoundPool] 音效与玩家距离:", distance, "最大衰减距离:", soundNode.RollOffMaxDistance)
                
                -- 检查距离是否超出音效范围
                if distance > soundNode.RollOffMaxDistance then
                    gg.log("[SoundPool] 警告：音效距离超出最大衰减范围，玩家可能听不到音效")
                end
            else
                gg.log("[SoundPool] 警告：音效位置FixPos不是有效的Vector3对象:", soundNode.FixPos)
            end
        else
            gg.log("[SoundPool] 音效为全局播放，无位置信息")
        end
    end

    -- 回收普通音效节点到池中
    if not data.key then
        SoundPool._RecycleSoundNode(soundNode)
    end
    
    -- 更新最后播放时间
    _lastPlayTimes[sound] = gg.GetTimeStamp()
end
---激活音效节点（简化接口）
---@param soundAssetID string 音效资源ID
---@param parent string|nil 父对象路径
---@param localPosition table|nil 本地位置 {x, y, z}
function SoundPool.ActivateSoundNode(soundAssetID, parent, localPosition)
    SoundPool.PlaySound({
        soundAssetId = soundAssetID,
        boundTo = parent,
        volume = DEFAULT_VOLUME,
        pitch = DEFAULT_PITCH,
        range = DEFAULT_RANGE,
        position = localPosition
    })
end

---停止有键值的音效
---@param key string 音效键值
function SoundPool.StopKeyedSound(key)
    if not _isInitialized then
        return
    end
    
    local soundNode = _keyedSounds[key]
    if soundNode then
        soundNode:StopSound()
        soundNode:Destroy()
        _keyedSounds[key] = nil
    end
end

---停止所有有键值的音效
function SoundPool.StopAllKeyedSounds()
    if not _isInitialized then
        return
    end
    
    for key, soundNode in pairs(_keyedSounds) do
        soundNode:StopSound()
        soundNode:Destroy()
    end
    _keyedSounds = {}
end

---清理音效池
function SoundPool.Cleanup()
    if not _isInitialized then
        return
    end
    
    -- 停止所有有键值的音效
    SoundPool.StopAllKeyedSounds()
    
    -- 清理音效池
    if _soundPoolContainer then
        _soundPoolContainer:Destroy()
        _soundPoolContainer = nil
    end
    
    -- 重置状态
    _soundNodePoolReady = {}
    _lastPlayTimes = {}
    _isInitialized = false
    
    print("[SoundPool] Cleanup completed")
end

---获取音效池状态信息
---@return table 状态信息
function SoundPool.GetStatus()
    return {
        isInitialized = _isInitialized,
        poolSize = #_soundNodePoolReady,
        keyedSoundsCount = SoundPool._GetTableLength(_keyedSounds),
        lastPlayTimesCount = SoundPool._GetTableLength(_lastPlayTimes)
    }
end

-- 私有方法

---处理随机音效
---@param sound string 原始音效路径
---@return string 处理后的音效路径
function SoundPool._ProcessRandomSound(sound)
    if type(sound) == "string" then
        return sound:gsub("%[(%d+)~(%d+)%]", function(a, b)
            local n, m = tonumber(a), tonumber(b)
            if n and m and n <= m then
                return tostring(math.random(n, m))
            end
            return a .. "~" .. b
        end)
    end
    return sound
end

---检查音效是否在阈值时间内重复播放
---@param sound string 音效路径
---@return boolean 是否重复播放
function SoundPool._IsRecentlyPlayed(sound)
    local currentTime = gg.GetTimeStamp()
    local lastPlayTime = _lastPlayTimes[sound]
    return lastPlayTime and (currentTime - lastPlayTime) < REPEAT_THRESHOLD
end

---获取音效节点
---@param key string|nil 音效键值
---@param sound string 音效路径
---@return Sound|nil 音效节点
function SoundPool._GetSoundNode(key, sound)
    if key then
        return SoundPool._GetKeyedSoundNode(key, sound)
    else
        return SoundPool._GetPooledSoundNode()
    end
end

---获取有键值的音效节点
---@param key string 音效键值
---@param sound string 音效路径
---@return Sound|nil 音效节点
function SoundPool._GetKeyedSoundNode(key, sound)
    local soundNode = _keyedSounds[key]
    
    if soundNode then
        -- 如果素材一样且正在播放，则无事发生
        if soundNode.SoundPath == sound then
            return nil
        end
        soundNode:StopSound()
    else
        -- 创建新的Sound节点
        soundNode = SandboxNode.new("Sound", game.Players.LocalPlayer.Character) ---@type Sound
        soundNode.Name = "KeyedSound_" .. tostring(key)
        soundNode.IsLoop = true
        _keyedSounds[key] = soundNode
    end
    
    return soundNode
end

---从音效池获取音效节点
---@return Sound|nil 音效节点
function SoundPool._GetPooledSoundNode()
    local soundNode = _soundNodePoolReady[1]
    if soundNode == nil then
        print("[SoundPool] Warning: No available sound nodes")
        return nil
    end
    return soundNode
end

---配置音效节点参数
---@param soundNode Sound 音效节点
---@param sound string 音效路径
---@param data table 音效数据
function SoundPool._ConfigureSoundNode(soundNode, sound, data)
    --gg.log("[SoundPool] 配置音效节点参数：", sound)
    
    soundNode.SoundPath = sound
    soundNode.Volume = data.volume or DEFAULT_VOLUME
    soundNode.Pitch = data.pitch or DEFAULT_PITCH
    soundNode.RollOffMaxDistance = data.range or DEFAULT_RANGE
    
    -- 关键修复：确保3D音效设置正确
    soundNode.RollOffMode = Enum.RollOffMode.Linear -- 使用线性衰减模式
    soundNode.RollOffMinDistance = 300 -- 最小衰减距离设为100，确保近距离能听到
    
    --gg.log("[SoundPool] 音效节点配置完成：")
    --gg.log("[SoundPool] - 资源路径：", soundNode.SoundPath)
    --gg.log("[SoundPool] - 音量：", soundNode.Volume)
    --gg.log("[SoundPool] - 音高：", soundNode.Pitch)
    --gg.log("[SoundPool] - 最大衰减距离：", soundNode.RollOffMaxDistance)
    --gg.log("[SoundPool] - 衰减模式：", soundNode.RollOffMode)
end

---设置音效位置
---@param soundNode Sound 音效节点
---@param data table 音效数据
function SoundPool._SetSoundPosition(soundNode, data)
    --gg.log("[SoundPool] 开始设置音效位置，数据：", data)
    
    if data.boundTo then
        local targetNode = gg.GetChild(WorkSpace, data.boundTo)
        if targetNode then ---@cast targetNode Transform
            soundNode.FixPos = targetNode.Position
            --gg.log("[SoundPool] 音效绑定到节点：", data.boundTo, "位置：", targetNode.Position)
        else
            --gg.log("[SoundPool] 警告：找不到绑定节点：", data.boundTo)
        end
    elseif data.position then
        local pos = Vector3.New(data.position[1], data.position[2], data.position[3])
        soundNode.FixPos = pos
        --gg.log("[SoundPool] 音效设置固定位置：", pos)
    else
        -- -- 关键问题：如果没有提供位置信息，音效会成为全局音效
        -- -- 这里我们不设置任何位置，让它保持默认（可能是全局）
        -- --gg.log("[SoundPool] 警告：没有提供boundTo或position，音效可能为全局播放。")
        -- soundNode.FixPos = nil
        -- soundNode.TransObject = nil
    end
    
    -- 验证3D设置
    SoundPool._Validate3DSound(soundNode, data)
end

---验证3D音效设置
---@param soundNode Sound 音效节点
---@param data table 音效数据
function SoundPool._Validate3DSound(soundNode, data)
    if soundNode.FixPos or soundNode.TransObject then
        --gg.log("[SoundPool] 3D音效验证通过。位置:", soundNode.FixPos, "绑定对象:", soundNode.TransObject)
    else
        --gg.log("[SoundPool] 3D音效验证失败：FixPos和TransObject均未设置，将作为2D全局音效播放。")
        --gg.log("[SoundPool] - 触发数据:", data)
    end
end

---回收音效节点到池中
---@param soundNode Sound 音效节点
function SoundPool._RecycleSoundNode(soundNode)
    table.remove(_soundNodePoolReady, 1)
    table.insert(_soundNodePoolReady, soundNode)
end

---获取表的长度
---@param t table 表
---@return number 长度
function SoundPool._GetTableLength(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

-- 自动初始化
SoundPool.Init()

return SoundPool