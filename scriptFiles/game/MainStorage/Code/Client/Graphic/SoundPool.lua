local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

---@class SoundPool 音效池管理类
local SoundPool = {}

-- 私有属性 - 原有功能
local _soundNodePoolReady = {} -- 可用音效节点池
local _lastPlayTimes = {} -- 记录每个声音的最后播放时间，防止0.1秒内重复播放
local _keyedSounds = {} -- 有键值的音效节点（如背景音乐）
local _soundPoolContainer = nil -- 音效池容器节点
local _isInitialized = false -- 是否已初始化

-- 私有属性 - 背景音乐播放器
local _backgroundMusicStack = {} -- 背景音乐优先级栈
local _currentBackgroundMusic = nil -- 当前播放的背景音乐节点

-- 常量配置
local POOL_SIZE = 50 -- 音效池大小
local REPEAT_THRESHOLD = 0.1 -- 防重复播放阈值（秒）
local DEFAULT_VOLUME = 1.0
local DEFAULT_PITCH = 1.0
local DEFAULT_RANGE = 6000

---初始化音效池（修改背景音乐事件订阅）
---@param poolSize number|nil 音效池大小，默认50个
function SoundPool.Init(poolSize)
    if _isInitialized then
        --gg.log("[SoundPool] Warning: Already initialized")
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
    
    -- 【新增】订阅停止有键值音效事件
    ClientEventManager.Subscribe("StopKeyedSound", function(data)
        SoundPool.StopKeyedSound(data.key)
    end)
    
    -- 【修改】订阅背景音乐播放事件
    ClientEventManager.Subscribe("PlayBackgroundMusic", function(data)
        SoundPool.PlayBackgroundMusic(data.soundAssetId, data.musicKey, data.volume)
    end)
    
    -- 【修改】订阅背景音乐停止事件
    ClientEventManager.Subscribe("StopBackgroundMusic", function(data)
        SoundPool.StopBackgroundMusic(data.musicKey)
    end)
    
    _isInitialized = true
    --gg.log("[SoundPool] 音效池初始化完成，包含 " .. poolSize .. " 个音效节点")
end

---播放音效（原有功能）
---@param data table 音效数据 {soundAssetId: string, key: string|nil, volume: number|nil, pitch: number|nil, range: number|nil, boundTo: string|nil, position: table|nil}
function SoundPool.PlaySound(data)
    if not _isInitialized then
        --gg.log("[SoundPool] 错误：未初始化，请先调用SoundPool.Init()")
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

    -- 回收普通音效节点到池中
    if not data.key then
        SoundPool._RecycleSoundNode(soundNode)
    end
    
    -- 更新最后播放时间
    _lastPlayTimes[sound] = gg.GetTimeStamp()
end

-- ========== 背景音乐播放器功能（栈模式） ==========

---播放背景音乐（入栈）
---@param soundAssetId string 音效资源ID
---@param musicKey string 音乐标识键
---@param volume number|nil 音量，默认0.5
function SoundPool.PlayBackgroundMusic(soundAssetId, musicKey, volume)
    if not _isInitialized then
        --gg.log("[SoundPool] 错误：未初始化")
        return
    end
    
    if not soundAssetId or soundAssetId == "" then
        --gg.log("[SoundPool] 错误：背景音乐资源ID为空")
        return
    end
    
    if not musicKey or musicKey == "" then
        --gg.log("[SoundPool] 错误：音乐键值为空")
        return
    end
    
    volume = volume or 0.5
    
    -- 将新音乐推入栈顶
    SoundPool._PushBackgroundMusic(soundAssetId, musicKey, volume)
    
    -- 播放栈顶音乐
    SoundPool._PlayTopMusic()
    
    --gg.log("[SoundPool] 背景音乐入栈：" .. soundAssetId .. " 键值：" .. musicKey)
end

---停止背景音乐（出栈）
---@param musicKey string 音乐标识键
function SoundPool.StopBackgroundMusic(musicKey)
    if not _isInitialized then
        return
    end
    
    if not musicKey or musicKey == "" then
        --gg.log("[SoundPool] 错误：音乐键值为空")
        return
    end
    
    -- 从栈中移除指定键值的音乐
    local removed = SoundPool._RemoveFromMusicStack(musicKey)
    
    if removed then
        -- 播放新的栈顶音乐
        SoundPool._PlayTopMusic()
        --gg.log("[SoundPool] 背景音乐出栈：" .. musicKey)
    else
        --gg.log("[SoundPool] 未找到要停止的音乐：" .. musicKey)
    end
end

---停止所有背景音乐（修正版）
function SoundPool.StopAllBackgroundMusic()
    if not _isInitialized then
        return
    end
    
    -- 停止并销毁栈中所有音乐节点
    for _, musicInfo in ipairs(_backgroundMusicStack) do
        if musicInfo.musicNode then
            musicInfo.musicNode:StopSound()
            musicInfo.musicNode:Destroy()
        end
    end
    
    -- 清空当前播放引用和音乐栈
    _currentBackgroundMusic = nil
    _backgroundMusicStack = {}
    
    --gg.log("[SoundPool] 所有背景音乐已停止，栈已清空")
end

---获取背景音乐栈状态
---@return table 状态信息
function SoundPool.GetBackgroundMusicStatus()
    local currentMusic = nil
    local topMusic = _backgroundMusicStack[#_backgroundMusicStack]
    
    if _currentBackgroundMusic and topMusic then
        currentMusic = {
            soundAssetId = topMusic.soundAssetId,
            musicKey = topMusic.musicKey,
            volume = topMusic.volume,
            isPlaying = true
        }
    end
    
    return {
        isPlaying = _currentBackgroundMusic ~= nil,
        currentMusic = currentMusic,
        stackSize = #_backgroundMusicStack,
        stack = _backgroundMusicStack
    }
end

-- ========== 背景音乐播放器私有方法（栈模式） ==========

---将背景音乐推入栈顶
---@param soundAssetId string 音效资源ID
---@param musicKey string 音乐标识键
---@param volume number 音量
function SoundPool._PushBackgroundMusic(soundAssetId, musicKey, volume)
    --gg.log("[SoundPool] 准备将音乐推入栈：" .. soundAssetId .. " 键值：" .. musicKey)
    
    -- 先移除栈中已存在的相同键值音乐（避免重复）
    SoundPool._RemoveFromMusicStack(musicKey)
    
    -- 【关键修正】如果当前有播放的音乐，暂停它而不是销毁
    --gg.log("当前播放的音乐", _currentBackgroundMusic)
    --gg.log("_backgroundMusicStack",_backgroundMusicStack)
    if _currentBackgroundMusic then
        --gg.log("[SoundPool] 暂停当前播放音乐：" .. (_currentBackgroundMusic.SoundPath or "未知"))
        _currentBackgroundMusic:StopSound() -- 暂停而不是停止
    end
    
    -- 创建新的音乐节点
    local newMusicNode = SandboxNode.new("Sound", game.Players.LocalPlayer.Character) ---@type Sound
    newMusicNode.Name = "BackgroundMusic_" .. musicKey
    newMusicNode.SoundPath = soundAssetId
    newMusicNode.Volume = volume
    newMusicNode.IsLoop = true
    
    -- 将新音乐信息推入栈顶
    table.insert(_backgroundMusicStack, {
        soundAssetId = soundAssetId,
        musicKey = musicKey,
        volume = volume,
        musicNode = newMusicNode, -- 【关键】保存音乐节点引用
        addTime = gg.GetTimeStamp()
    })
    
    --gg.log("[SoundPool] 音乐入栈，当前栈大小：" .. #_backgroundMusicStack)
    SoundPool._logMusicStack()
end

---从音乐栈中移除指定键值的音乐
---@param musicKey string 音乐标识键
---@return boolean 是否成功移除
function SoundPool._RemoveFromMusicStack(musicKey)
    for i = #_backgroundMusicStack, 1, -1 do
        if _backgroundMusicStack[i].musicKey == musicKey then
            local removedMusic = table.remove(_backgroundMusicStack, i)
            
            -- 【关键修正】销毁被移除的音乐节点
            if removedMusic.musicNode then
                removedMusic.musicNode:StopSound()
                removedMusic.musicNode:Destroy()
            end
            
            --gg.log("[SoundPool] 从栈中移除音乐：" .. removedMusic.soundAssetId .. " 键值：" .. musicKey)
            SoundPool._logMusicStack()
            return true
        end
    end
    return false
end

---播放栈顶音乐
function SoundPool._PlayTopMusic()
    -- 先停止当前播放的音乐
    if _currentBackgroundMusic then
        --gg.log("[SoundPool] 停止当前播放音乐：" .. (_currentBackgroundMusic.SoundPath or "未知"))
        _currentBackgroundMusic:StopSound()
        _currentBackgroundMusic:Destroy()
        _currentBackgroundMusic = nil
    end
    
    -- 获取栈顶音乐
    local topMusic = _backgroundMusicStack[#_backgroundMusicStack]
    
    if not topMusic then
        --gg.log("[SoundPool] 音乐栈为空，无音乐播放")
        return
    end
    
    -- 创建新的背景音乐节点
    _currentBackgroundMusic = SandboxNode.new("Sound", game.Players.LocalPlayer.Character) ---@type Sound
    _currentBackgroundMusic.Name = "BackgroundMusic_" .. topMusic.musicKey
    _currentBackgroundMusic.SoundPath = topMusic.soundAssetId
    _currentBackgroundMusic.Volume = topMusic.volume
    _currentBackgroundMusic.IsLoop = true
    
    -- 播放栈顶音乐
    _currentBackgroundMusic:PlaySound()
    
    --gg.log("[SoundPool] 播放栈顶音乐：" .. topMusic.soundAssetId .. " 键值：" .. topMusic.musicKey)
end

---打印当前音乐栈状态（调试用）
function SoundPool._logMusicStack()
    if #_backgroundMusicStack == 0 then
        --gg.log("[SoundPool] 音乐栈：空")
        return
    end
    
    --gg.log("[SoundPool] 音乐栈状态（从栈底到栈顶）：")
    for i, music in ipairs(_backgroundMusicStack) do
        local status = ""
        if i == #_backgroundMusicStack then
            status = " <- 栈顶(播放中)"
        else
            status = " (暂停)"
        end
        
        local nodeStatus = music.musicNode and "存在" or "已销毁"
        --gg.log("  " .. i .. ". [" .. music.musicKey .. "] " .. music.soundAssetId .. status .. " 节点:" .. nodeStatus)
    end
    
    -- 显示当前播放状态
    local currentStatus = _currentBackgroundMusic and "播放中" or "无"
    --gg.log("[SoundPool] 当前播放状态：" .. currentStatus)
end
-- ========== 原有功能方法 ==========

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
    
    -- 停止所有背景音乐（使用修正版方法）
    SoundPool.StopAllBackgroundMusic()
    
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
    
    --gg.log("[SoundPool] 清理完成")
end

---获取音效池状态信息
---@return table 状态信息
function SoundPool.GetStatus()
    local bgmStatus = SoundPool.GetBackgroundMusicStatus()
    return {
        isInitialized = _isInitialized,
        poolSize = #_soundNodePoolReady,
        keyedSoundsCount = SoundPool._GetTableLength(_keyedSounds),
        lastPlayTimesCount = SoundPool._GetTableLength(_lastPlayTimes),
        backgroundMusic = bgmStatus
    }
end

-- ========== 便捷接口方法 ==========

---播放地图背景音乐
---@param soundAssetId string 音效资源ID
---@param volume number|nil 音量，默认0.5
function SoundPool.PlayMapMusic(soundAssetId, volume)
    SoundPool.PlayBackgroundMusic(soundAssetId, "MapMusic", volume)
end

---播放场景背景音乐
---@param soundAssetId string 音效资源ID
---@param volume number|nil 音量，默认0.5
function SoundPool.PlaySceneMusic(soundAssetId, volume)
    SoundPool.PlayBackgroundMusic(soundAssetId, "SceneMusic", volume)
end

---播放UI背景音乐
---@param soundAssetId string 音效资源ID
---@param volume number|nil 音量，默认0.5
function SoundPool.PlayUIMusic(soundAssetId, volume)
    SoundPool.PlayBackgroundMusic(soundAssetId, "UIMusic", volume)
end

---播放事件背景音乐
---@param soundAssetId string 音效资源ID
---@param volume number|nil 音量，默认0.5
function SoundPool.PlayEventMusic(soundAssetId, volume)
    SoundPool.PlayBackgroundMusic(soundAssetId, "EventMusic", volume)
end

---停止地图音乐
function SoundPool.StopMapMusic()
    SoundPool.StopBackgroundMusic("MapMusic")
end

---停止场景音乐
function SoundPool.StopSceneMusic()
    SoundPool.StopBackgroundMusic("SceneMusic")
end

---停止UI音乐
function SoundPool.StopUIMusic()
    SoundPool.StopBackgroundMusic("UIMusic")
end

---停止事件音乐
function SoundPool.StopEventMusic()
    SoundPool.StopBackgroundMusic("EventMusic")
end

-- ========== 原有私有方法 ==========

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
        --gg.log("[SoundPool] 警告：没有可用的音效节点")
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
    soundNode.RollOffMaxDistance = data.maxdistance or DEFAULT_RANGE
    soundNode.RollOffMinDistance = data.mindistance or DEFAULT_RANGE
    
    -- 关键修复：确保3D音效设置正确
    soundNode.RollOffMode = Enum.RollOffMode.Linear  -- 使用线性衰减模式
    soundNode.RollOffMinDistance = 300 -- 最小衰减距离设为300，确保近距离能听到
    if data.transObject then
        soundNode.TransObject = data.transObject
    end
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
        local pos = Vector3.New(data.position[1], data.position[2], data.position[3])
        soundNode.FixPos = pos
    else
        -- 如果没有提供位置信息，默认绑定到本地玩家对象
        local localPlayer = game:GetService("Players").LocalPlayer
        if localPlayer and localPlayer.Character then
            soundNode.TransObject = localPlayer.Character
        end
    end
    
    -- 验证3D设置
    SoundPool._Validate3DSound(soundNode, data)
end

---验证3D音效设置
---@param soundNode Sound 音效节点
---@param data table 音效数据
function SoundPool._Validate3DSound(soundNode, data)
    if soundNode.FixPos or soundNode.TransObject then
        -- 3D音效验证通过
    else
        -- 作为2D全局音效播放
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

return SoundPool