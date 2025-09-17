--- V109 miniw-haima
--所有配置( 其他所有的配置文件将汇总到这个模块里 )

local pairs = pairs

local EquipmentSlot = {
    ["主卡"] = {
        [1] = "主卡"
    },
    ["副卡"] = {
        [2] = "副卡1",
        [3] = "副卡2",
        [4] = "副卡3",
        [5] = "副卡4"
    }
}

local ItemTypeEnum = {
    ["武器"] = 1,
    ["装备"] = 2,
    ["消耗品"] = 3,
    ["材料"] = 4,
    ["任务"] = 5,
    ["货币"] = 6
}

-- 反向映射：数字到名称
local ItemTypeNames = {
    [1] = "武器",
    [2] = "装备", 
    [3] = "消耗品",
    [4] = "材料",
    [5] = "任务",
    [6] = "货币"
}

-- 指令执行配置
local CommandExecutionConfig = {
    'variable { "操作类型": "清空来源", "变量名": "加成_百分比_训练加成", "其他加成": [  ] }',
    'variable { "操作类型": "设置", "变量名": "加成_百分比_训练加成", "数值": 0, "其他加成": [  ] }', 
}


-- 变量区间/阈值命令配置
-- 说明：
-- - key 为变量名
-- - comparator 为比较符（支持 ">", ">=", "<", "<=", "==", "~="）
-- - value 为阈值；支持十进制或科学计数法字符串（如 "1.2e13"），为避免 LuaJIT 浮点精度问题建议使用字符串
-- - command 为满足条件时需要执行的指令字符串（交由命令系统解析执行）
local VariableIntervalConfig = {
    ["数据_固定值_历史最大战力值"] = {
        { comparator = ">=", value = 6e20, command = 'B指令' },
        { comparator = ">=", value = 1.2e13, command = 'A指令' },
    },
}


--所有配置( 其他所有的配置文件将汇总到这里， 游戏逻辑代码只需要require这个文件即可 )
---@class common_config
---@field EquipmentSlot table<string, table<number, string>> 装备槽位配置
---@field ItemTypeEnum table<string, number> 物品类型枚举 (名称 -> 编号)
---@field ItemTypeNames table<number, string> 物品类型名称 (编号 -> 名称)
---@field VariableIntervalConfig table<string, table> 变量区间/阈值命令配置
local common_config = {
    EquipmentSlot = EquipmentSlot,
    ItemTypeEnum = ItemTypeEnum,
    ItemTypeNames = ItemTypeNames,
    CommandExecutionConfig = CommandExecutionConfig,
    VariableIntervalConfig = VariableIntervalConfig,
}



return common_config
