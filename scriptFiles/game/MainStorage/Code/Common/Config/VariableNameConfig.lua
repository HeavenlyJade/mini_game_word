-- VariableNameConfig.lua
-- Generated from VariableNames.json. Any custom code will be overwritten.

local VariableNameConfig = {Data = {}}

VariableNameConfig.VariableNames = {
    '加成_百分比_双倍训练',
    '加成_百分比_奖杯加成',
    '解锁_固定值_重生',
    '数据_固定值_战力值',
    '数据_固定值_历史最大战力值',
    '数据_固定值_重生次数',
    '加成_百分比_训练加成',
    '加成_百分比_速度加成',
    '特权_百分比_双倍训练',
    '加成_百分比_金币加成',
    '加成_百分比_移动加成',
    '加成_百分比_加速度加成',
    '特权_固定值_特权标识',
    '特权_百分比_金币加成',
    '特权_百分比_训练加成',
    '特权_百分比_奖杯加成',
    '特权_固定值_最大重生',
    '特权_固定值_高级抽蛋运气',
    '特权_固定值_超级抽蛋运气',
    '天赋_百分比_训练加成',
    '天赋_百分比_奖杯加成',
    '数据_固定值_宠物背包次数',
    '数据_固定值_伙伴背包次数',
    '数据_固定值_翅膀背包次数',
    '数据_固定值_广告播放次数',
    '数据_固定值_邀请数量',
    '数据_固定值_飞行币当日获取上限',
}

VariableNameConfig.StatNames = {
    '数据_固定值_攻击力',
    '数据_固定值_移动速度',
    '数据_固定值_加速度',
}

VariableNameConfig.PlayerAttributeNames = {
    '速度',
    '攻击',
    '防御',
}

VariableNameConfig.DependencyRules = {
    ['数据_固定值_战力值'] = {
        ['目标变量'] = '数据_固定值_历史最大战力值',
        ['条件'] = '大于',
        ['动作'] = '设置为源值',
        ['固定值'] = 0,
        ['倍率'] = 0
    },
}

return VariableNameConfig
