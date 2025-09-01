---@class CardIcon
-- 卡片图标配置
local CardIcon = {}

-- 品质默认图标
CardIcon.qualityDefIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩.png",
}

-- 品质点击图标
CardIcon.qualityClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏绿_1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏蓝_1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏紫_1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏橙_1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/主要框体/物品栏彩_1.png",
}

-- 品质底图默认图标
CardIcon.qualityBaseMapDefIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图.png",
}

-- 品质底图点击图标
CardIcon.qualityBaseMapClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏绿_底图1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏蓝_底图1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏紫_底图1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏橙_底图1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/物品栏彩_底图1.png",
}


CardIcon.qualityBaseMapboxIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/绿卡.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/蓝卡.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/紫卡.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/橙卡.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/彩卡.png",
}

CardIcon.qualityBaseMapboxClickIcon = {
    ["N"] = "sandboxId://textures/ui/主界面UI/快捷栏/蓝卡_1.png",
    ["R"] = "sandboxId://textures/ui/主界面UI/快捷栏/绿卡_1.png",
    ["SR"] = "sandboxId://textures/ui/主界面UI/快捷栏/紫卡_1.png",
    ["SSR"] = "sandboxId://textures/ui/主界面UI/快捷栏/橙卡_1.png",
    ["UR"] = "sandboxId://textures/ui/主界面UI/快捷栏/彩卡_1.png",
}
CardIcon.qualityBackGroundIcon = {
    ["N"] = "sandboxId://FlyUi/迷你界面/商城UI/绿色品质底图.png",
    ["R"] = "sandboxId://FlyUi/迷你界面/商城UI/蓝色品质底图.png",
    ["SR"] = "sandboxId://FlyUi/迷你界面/商城UI/紫色品质底图.png",
    ["SSR"] = "sandboxId://FlyUi/迷你界面/商城UI/橙色品质底图.png",
    ["UR"] = "sandboxId://FlyUi/迷你界面/商城UI/彩色品质底图.png",
}

CardIcon.qualityNoticeIcon = {
    ["N"] = "sandboxId://FlyUi/迷你界面/获得物品通告UI/绿物品栏.png",
    ["R"] = "sandboxId://FlyUi/迷你界面/获得物品通告UI/蓝物品栏.png",
    ["SR"] = "sandboxId://FlyUi/迷你界面/获得物品通告UI/紫物品栏.png",
    ["SSR"] = "sandboxId://FlyUi/迷你界面/获得物品通告UI/橙物品栏.png",
    ["UR"] = "sandboxId://FlyUi/迷你界面/获得物品通告UI/彩物品栏.png",
}
-- 品质优先级配置
CardIcon.qualityPriority = {
    ["UR"] = 5,
    ["SSR"] = 4,
    ["SR"] = 3,
    ["R"] = 2,
    ["N"] = 1
}

-- 品质列表配置
CardIcon.qualityList = {"UR", "SSR", "SR", "R", "N", "ALL"}

-- 品质映射配置
CardIcon.qualityListMap = {
    ["品质_5"] = "N",
    ["品质_4"] = "R",
    ["品质_3"] = "SR",
    ["品质_2"] = "SSR",
    ["品质_1"] = "UR",
    ["品质_6"] = "ALL"
}

-- 物品图标资源配置
CardIcon.itemIconResources = {
    ["128元"] = "sandboxId://FlyUi/迷你界面/物品图标/128元.png",
    ["2一堆奖杯"] = "sandboxId://FlyUi/迷你界面/物品图标/2一堆奖杯.png",
    ["30元"] = "sandboxId://FlyUi/迷你界面/物品图标/30元.png",
    ["328元"] = "sandboxId://FlyUi/迷你界面/物品图标/328元.png",
    ["3一大堆奖杯"] = "sandboxId://FlyUi/迷你界面/物品图标/3一大堆奖杯.png",
    ["4非常多奖杯"] = "sandboxId://FlyUi/迷你界面/物品图标/4非常多奖杯.png",
    ["5一大袋奖杯"] = "sandboxId://FlyUi/迷你界面/物品图标/5一大袋奖杯.png",
    ["648元"] = "sandboxId://FlyUi/迷你界面/物品图标/648元.png",
    ["68元"] = "sandboxId://FlyUi/迷你界面/物品图标/68元.png",
    ["6一箱子奖杯"] = "sandboxId://FlyUi/迷你界面/物品图标/6一箱子奖杯.png",
    ["6元"] = "sandboxId://FlyUi/迷你界面/物品图标/6元.png",
    ["双倍训练"] = "sandboxId://FlyUi/迷你界面/物品图标/双倍训练.png",
    ["奖杯速度"] = "sandboxId://FlyUi/迷你界面/物品图标/奖杯速度.png",
    ["提升箭头"] = "sandboxId://FlyUi/迷你界面/物品图标/提升箭头.png",
    ["移速加成"] = "sandboxId://FlyUi/迷你界面/物品图标/移速加成.png",
    ["能力值"] = "sandboxId://FlyUi/迷你界面/物品图标/能力值.png",
    ["训练加成"] = "sandboxId://FlyUi/迷你界面/物品图标/训练加成.png",
    ["起飞速度"] = "sandboxId://FlyUi/迷你界面/物品图标/起飞速度.png",
    ["迷你币"] = "sandboxId://FlyUi/迷你界面/物品图标/迷你币.png",
    ["迷你豆"] = "sandboxId://FlyUi/迷你界面/物品图标/迷你豆.png",
    ["重生档位"] = "sandboxId://FlyUi/迷你界面/物品图标/重生档位.png",
    ["金币加成"] = "sandboxId://FlyUi/迷你界面/物品图标/金币加成.png",
    ["至尊会员"] ="sandboxId://FlyUi/迷你界面/物品图标/至尊VIP图标.png",
    ["宠物立绘"]="sandboxId://FlyUi/迷你界面/宠物立绘/飘飘小灵.png"

}

-- 音效资源配置
CardIcon.soundResources = {
    ["翅膀扇动音效1"] = "sandboxId://音效资源/翅膀扇动音效1.ogg",
    ["翅膀扇动音效2"] = "sandboxId://音效资源/翅膀扇动音效2.ogg",
    ["翅膀扇动音效3"] = "sandboxId://音效资源/翅膀扇动音效3.ogg",
    ["能量获得音效1"] = "sandboxId://音效资源/能量获得音效1.ogg",
    ["能量获得音效2"] = "sandboxId://音效资源/能量获得音效2.ogg",
    ["能量获得音效3"] = "sandboxId://音效资源/能量获得音效3.ogg"
}

return CardIcon
