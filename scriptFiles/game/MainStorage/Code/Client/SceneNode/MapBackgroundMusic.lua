-- MapBackgroundMusic.lua
-- 地图背景音乐播放器
-- 负责在客户端初始化时播放地图的背景音乐
-- 使用现有的SoundPool系统来播放背景音乐

local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

---@class MapBackgroundMusic
local MapBackgroundMusic = {}

-- 当前播放的背景音乐键值，用于控制播放
local currentBackgroundMusicKey = "MapBackgroundMusic"
-- 保存当前播放的音效路径，用于恢复播放
local currentMusicAssetPath = ""

--- 初始化并播放地图背景音乐
function MapBackgroundMusic.InitializeBackgroundMusic()
    --gg.log("开始初始化地图背景音乐")
    
    -- 查找当前场景的背景音乐配置
    local currentSceneMusic = MapBackgroundMusic.FindCurrentSceneMusic()
    
    if currentSceneMusic then
        MapBackgroundMusic.PlayBackgroundMusic(currentSceneMusic)
    else
        --gg.log("未找到 Ground/init_map 节点的背景音乐配置")
    end
end

--- 查找当前场景的背景音乐配置
---@return string|nil 背景音乐资源路径
function MapBackgroundMusic.FindCurrentSceneMusic()
    -- 固定获取 Ground/init_map 节点的背景音乐属性
    local initMapNode = gg.GetChild(WorkSpace, "Ground/init_map")
    if not initMapNode then
        --gg.log("错误：找不到 Ground/init_map 节点")
        return nil
    end
    
    -- 获取背景音乐属性
    local backgroundMusic = initMapNode:GetAttribute("背景音乐")
    if backgroundMusic and backgroundMusic ~= "" then
        return backgroundMusic
    end
    
    -- 如果没有找到背景音乐属性，可以返回默认背景音乐
    --gg.log("Ground/init_map 节点没有配置背景音乐属性")
    return nil
end

--- 播放背景音乐
---@param musicAssetPath string 音乐资源路径
function MapBackgroundMusic.PlayBackgroundMusic(musicAssetPath)
    if not musicAssetPath or musicAssetPath == "" then
        --gg.log("错误：音乐资源路径为空")
        return
    end
    
    -- 停止当前播放的背景音乐
    MapBackgroundMusic.StopBackgroundMusic()
    
    -- 保存当前音效路径
    currentMusicAssetPath = musicAssetPath
    
    -- 使用SoundPool系统播放背景音乐
    -- 通过ClientEventManager触发PlaySound事件
    local soundData = {
        soundAssetId = musicAssetPath,
        key = currentBackgroundMusicKey,  -- 使用固定键值，确保只有一个背景音乐在播放
        volume = 0.5,  -- 背景音乐音量
        pitch = 1.0,   -- 正常音调
        range = 10000  -- 较大的播放范围，确保整个地图都能听到
    }
    
    -- 触发播放音效事件
    ClientEventManager.Publish("PlaySound", soundData)
    
    --gg.log("开始播放地图背景音乐:", musicAssetPath)
end

--- 停止背景音乐
function MapBackgroundMusic.StopBackgroundMusic()
    -- 通过重新播放空音效来停止背景音乐
    -- SoundPool系统会自动处理keyedSounds的停止
    local soundData = {
        soundAssetId = "",  -- 空音效路径
        key = currentBackgroundMusicKey,
        volume = 0,
        pitch = 1.0,
        range = 10000
    }
    
    ClientEventManager.Publish("PlaySound", soundData)
    
    -- 清空当前音效路径
    currentMusicAssetPath = ""
    
    --gg.log("背景音乐已停止")
end

--- 设置背景音乐音量
---@param volume number 音量值 (0.0 - 1.0)
function MapBackgroundMusic.SetVolume(volume)
    local clampedVolume = math.max(0.0, math.min(1.0, volume))
    
    -- 通过重新播放当前音效来设置音量
    if currentMusicAssetPath and currentMusicAssetPath ~= "" then
        local soundData = {
            soundAssetId = currentMusicAssetPath,
            key = currentBackgroundMusicKey,
            volume = clampedVolume,
            pitch = 1.0,
            range = 10000
        }
        
        ClientEventManager.Publish("PlaySound", soundData)
        --gg.log("背景音乐音量设置为:", clampedVolume)
    end
end

--- 暂停背景音乐
function MapBackgroundMusic.PauseBackgroundMusic()
    -- 通过停止音效来实现暂停效果
    MapBackgroundMusic.StopBackgroundMusic()
    
    --gg.log("背景音乐已暂停")
end

--- 恢复背景音乐播放
function MapBackgroundMusic.ResumeBackgroundMusic()
    -- 重新播放当前音效
    if currentMusicAssetPath and currentMusicAssetPath ~= "" then
        MapBackgroundMusic.PlayBackgroundMusic(currentMusicAssetPath)
        --gg.log("背景音乐已恢复播放")
    end
end

--- 切换背景音乐
---@param newMusicAssetPath string 新的音乐资源路径
function MapBackgroundMusic.SwitchBackgroundMusic(newMusicAssetPath)
    if newMusicAssetPath and newMusicAssetPath ~= "" then
        MapBackgroundMusic.PlayBackgroundMusic(newMusicAssetPath)
    end
end

return MapBackgroundMusic
