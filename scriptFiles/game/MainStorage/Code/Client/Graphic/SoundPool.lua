local MainStorage = game:GetService("MainStorage")
local WorkSpace = game:GetService("WorkSpace")
local gg              = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local ClientEventManager = require(MainStorage.Code.Client.Event.ClientEventManager) ---@type ClientEventManager

local  soundNodePoolReady = {}
-- 记录每个声音的最后播放时间，防止0.1秒内重复播放
local lastPlayTimes = {}

local keyedSounds = {}

local function PlaySound(data)
    local sound = data.soundAssetId
    if not sound or sound == "" then
        return
    end
    local key = data.key
    if type(sound) == "string" then
        sound = sound:gsub("%[(%d+)~(%d+)%]", function(a, b)
            local n, m = tonumber(a), tonumber(b)
            if n and m and n <= m then
                return tostring(math.random(n, m))
            end
            return a .. "~" .. b
        end)
    end

    local soundNode
    if key then
        if keyedSounds[key] then
            soundNode = keyedSounds[key]
            -- 如果素材一样且正在播放，则无事发生
            if soundNode.SoundPath == sound then
                return
            end
            soundNode:StopSound()
        else
            -- 创建新的Sound节点
            soundNode = SandboxNode.new("Sound", game.Players.LocalPlayer.Character) ---@type Sound
            soundNode.Name = "KeyedSound_" .. tostring(key)
            soundNode.IsLoop = true
            keyedSounds[key] = soundNode
        end
    else
        soundNode = soundNodePoolReady[1]
        if soundNode == nil then
            print("No available sound nodes")
            return
        end
    end

    -- 检查是否在0.1秒内重复播放同一个声音
    local currentTime = gg.GetTimeStamp()
    local lastPlayTime = lastPlayTimes[sound]
    if lastPlayTime and (currentTime - lastPlayTime) < 0.1 then
        return
    end
    lastPlayTimes[sound] = currentTime

    -- 设置音效参数
    soundNode.SoundPath = sound
    soundNode.Volume = data.volume or 1
    soundNode.Pitch = data.pitch or 1
    soundNode.RollOffMaxDistance = data.range or 6000

    if not key then
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

    -- 播放音效
    soundNode:PlaySound()

    if not key then
        table.remove(soundNodePoolReady, 1)
        table.insert(soundNodePoolReady, soundNode)
    end
end

local function ActivateSoundNode(soundAssetID, parent, localPosition)
    PlaySound({
        soundAssetId = soundAssetID,
        boundTo = parent,
        volume = 1.0,
        pitch = 1.0,
        range = 6000,
        position = localPosition
    })
end

local SoundPool = SandboxNode.new("Transform", WorkSpace)
SoundPool.Name = "SoundPool"
for i = 1, 50 do
    local soundNode = SandboxNode.new("Sound", SoundPool)
    soundNode.Name = "SoundNode" .. i
    table.insert(soundNodePoolReady, soundNode)
end
ClientEventManager.Subscribe("PlaySound", function(data)
    PlaySound(data)
end)
