-- PlayerInitConfig.lua
-- 自动生成的玩家初始化配置。自定义代码将被覆盖。

---@class PlayerInitConfig
---@field Data table<string, table>

---@type PlayerInitConfig
local PlayerInitConfig = {Data = {}}

-- --- 自动生成配置开始 ---
PlayerInitConfig.Data = {
    ['默认玩家初始化'] = {
        ['配置名称'] = '默认玩家初始化',
        ['描述'] = '新玩家首次进入游戏时的初始化配置',
        ['货币初始化'] = {
            {
                ['货币名称'] = '金币',
                ['初始数量'] = 0,
            },
            {
                ['货币名称'] = '奖杯', 
                ['初始数量'] = 0,
            },
        },
        ['变量初始化'] = {
            {
                ['变量名称'] = '数据_固定值_重生次数',
                ['初始值'] = 0,
            },
            {
                ['变量名称'] = '数据_固定值_战力值',
                ['初始值'] = 0,
            },
        },
        ['其他设置'] = {
            ['是否新手'] = true,
            ['初始等级'] = 1,
        },
    },
}
-- --- 自动生成配置结束 ---

return PlayerInitConfig 