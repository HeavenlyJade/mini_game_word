---@class NodeConf
local NodeConf = { 
	["倒计时"] = {
		["init_map"] = "Ground/init_map/terrain/Scene/UIRoot3D/计时器",
		["map2"] = "Ground/map2/terrain/Scene/UIRoot3D/计时器",
		["map3"] = "Ground/map3/terrain/Scene/UIRoot3D/计时器",
	},
	
	-- 距离循环器配置
	["距离循环器"] = {
		-- init_map: 100万米周期
		["init_map"] = {
			cycleDistance = 1000000, -- 100万米为一个周期
			progressBars = {
				[1] = { start = 0, endDistance = 300000, range = 300000 },      -- 0-30万米
				[2] = { start = 300000, endDistance = 500000, range = 200000 }, -- 30万-50万米
				[3] = { start = 500000, endDistance = 1000000, range = 500000 } -- 50万-100万米
			}
		},
		
		-- map2: 400万米周期
		["map2"] = {
			cycleDistance = 4000000, -- 400万米为一个周期
			progressBars = {
				[1] = { start = 0, endDistance = 1200000, range = 1200000 },     -- 0-120万米
				[2] = { start = 1200000, endDistance = 2000000, range = 800000 }, -- 120万-200万米
				[3] = { start = 2000000, endDistance = 4000000, range = 2000000 } -- 200万-400万米
			}
		},
		
		-- map3: 默认使用init_map配置
		["map3"] = {
			cycleDistance = 1000000, -- 100万米为一个周期
			progressBars = {
				[1] = { start = 0, endDistance = 300000, range = 300000 },      -- 0-30万米
				[2] = { start = 300000, endDistance = 500000, range = 200000 }, -- 30万-50万米
				[3] = { start = 500000, endDistance = 1000000, range = 500000 } -- 50万-100万米
			}
		}
	}
}

return NodeConf
