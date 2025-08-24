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
---@param data table 音效数据 {soundAssetId: string, key: string|nil, volume: number|nil, pitch: number|nil, range: number|nil, boundTo: string|nil, position: table|nil}
function SoundPool.PlaySound(data)
    if not _isInitialized then
        print("[SoundPool] Error: Not initialized. Call SoundPool.Init() first")
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
    
    -- 设置音效位置
    if not data.key then
        SoundPool._SetSoundPosition(soundNode, data)
    end
    
    -- 播放音效
    soundNode:PlaySound()
    
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
    soundNode.SoundPath = sound
    soundNode.Volume = data.volume or DEFAULT_VOLUME
    soundNode.Pitch = data.pitch or DEFAULT_PITCH
    soundNode.RollOffMaxDistance = data.range or DEFAULT_RANGE
end

---设置音效位置
---@param soundNode Sound 音效节点
---@param data table 音效数据
function SoundPool._SetSoundPosition(soundNode, data)
    if data.boundTo then
        local targetNode = gg.GetChild(WorkSpace, data.boundTo)
        if targetNode then ---@cast targetNode Transform
            soundNode.FixPos = targetNode.Position
        end
    elseif data.position then
        soundNode.FixPos = Vector3.New(data.position[1], data.position[2], data.position[3])
    else
        soundNode.FixPos = game.Players.LocalPlayer.Character.Position
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