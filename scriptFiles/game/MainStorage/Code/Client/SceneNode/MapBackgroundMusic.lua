-- MapBackgroundMusic.lua
-- 地图背景音乐播放器
-- 负责在客户端初始化时播放地图的背景音乐
-- 使用SoundPool的背景音乐播放器功能

local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local SoundPool = require(MainStorage.Code.Client.Graphic.SoundPool) ---@type SoundPool

---@class MapBackgroundMusic
local MapBackgroundMusic = {}

--- 初始化并播放地图背景音乐
function MapBackgroundMusic.InitializeBackgroundMusic()
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
    
    -- 使用SoundPool的地图音乐播放功能
    SoundPool.PlayMapMusic(musicAssetPath, 0.5)
    
    gg.log("开始播放地图背景音乐:", musicAssetPath)
end

--- 停止背景音乐
function MapBackgroundMusic.StopBackgroundMusic()
    SoundPool.StopMapMusic()
    --gg.log("地图背景音乐已停止")
end

--- 设置背景音乐音量
---@param volume number 音量值 (0.0 - 1.0)
function MapBackgroundMusic.SetVolume(volume)
    local clampedVolume = math.max(0.0, math.min(1.0, volume))
    
    -- 获取当前场景音乐并重新播放以应用新音量
    local currentSceneMusic = MapBackgroundMusic.FindCurrentSceneMusic()
    if currentSceneMusic then
        SoundPool.PlayMapMusic(currentSceneMusic, clampedVolume)
        --gg.log("地图背景音乐音量设置为:", clampedVolume)
    end
end

--- 暂停背景音乐
function MapBackgroundMusic.PauseBackgroundMusic()
    SoundPool.StopMapMusic()
    --gg.log("地图背景音乐已暂停")
end

--- 恢复背景音乐播放
function MapBackgroundMusic.ResumeBackgroundMusic()
    local currentSceneMusic = MapBackgroundMusic.FindCurrentSceneMusic()
    if currentSceneMusic then
        SoundPool.PlayMapMusic(currentSceneMusic, 0.5)
        --gg.log("地图背景音乐已恢复播放")
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
