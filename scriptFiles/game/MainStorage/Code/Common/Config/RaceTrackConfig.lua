---@class RaceTrackConfig
local RaceTrackConfig = {}

-- 赛道路径配置
RaceTrackConfig.trackPaths = {
    "Ground/init_map/terrain/Scene/race_track/地面赛道",
    "Ground/map2/terrain/Scene/race_track/地面赛道",
    "Ground/map3/terrain/Scene/race_track/地面赛道"
}

-- 克隆参数配置
RaceTrackConfig.cloneSettings = {
    cloneCount = 350,        -- 每个赛道的克隆数量
    xOffset = 0,          -- X轴偏移量
    zOffset = 4150,          -- Z轴偏移量
    transparency = 0.8      -- 空气墙透明度
}

return RaceTrackConfig
