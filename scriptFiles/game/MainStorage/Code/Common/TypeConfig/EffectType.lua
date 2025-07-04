-- EffectType.lua
-- 定义了特效（Effect）的数据结构，由 EffectTypeConfig 中的数据实例化而来

local MainStorage = game:GetService("MainStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr)
local Vec3 = require(MainStorage.Code.Untils.Math.Vec3)

---@class EffectType
---@field Name string # 特效名, 对应配置表中的key
---@field Prefab string # 特效预制体的资源路径
---@field Duration number # 特效的持续时间（秒），0表示瞬时
---@field FollowTarget boolean # 特效是否需要跟随挂载的目标移动
---@field PositionOffset Vec3 # 特效生成时的位置偏移量
---@field RotationOffset Vec3 # 特效生成时的旋转偏移量
---@field Scale number # 特效的缩放倍率
---@field CastSound string # 施法时播放的音效资源路径
---@field HitSound string # 击中时播放的音效资源路径
---@field ShakePower number # 屏幕震动的强度
---@field ShakeTime number # 屏幕震动的持续时间
local EffectType = ClassMgr.Class("EffectType")

---构造函数，从配置表中读取原始数据进行初始化
---@param data table # 来自 EffectTypeConfig 的单条数据
function EffectType:Init(data)
    self.Name = data["特效名"]
    self.Prefab = data["特效预制体"]
    self.Duration = data["持续时间"] or 0
    self.FollowTarget = data["跟随目标"] or false

    if data["位置偏移"] then
        self.PositionOffset = Vec3.New(data["位置偏移"][1] or 0, data["位置偏移"][2] or 0, data["位置偏移"][3] or 0)
    else
        self.PositionOffset = Vec3.New(0,0,0)
    end

    if data["旋转偏移"] then
        self.RotationOffset = Vec3.New(data["旋转偏移"][1] or 0, data["旋转偏移"][2] or 0, data["旋转偏移"][3] or 0)
    else
        self.RotationOffset = Vec3.New(0,0,0)
    end

    self.Scale = data["缩放倍率"] or 1
    self.CastSound = data["施法音效"]
    self.HitSound = data["击中音效"]
    self.ShakePower = data["震荡强度"] or 0
    self.ShakeTime = data["震荡时间"] or 0
end

return EffectType 