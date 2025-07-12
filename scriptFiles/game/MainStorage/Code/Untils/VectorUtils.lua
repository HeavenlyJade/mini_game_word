-- VectorUtils.lua
-- 向量计算工具类 - 从 MGlobal 中提取的所有向量和数学计算函数
-- 提供统一的向量操作接口，避免重复代码

local MainStorage = game:GetService("MainStorage")
local Vec2 = require(MainStorage.Code.Untils.Math.Vec2) ---@type Vec2
local Vec3 = require(MainStorage.Code.Untils.Math.Vec3) ---@type Vec3
local Vec4 = require(MainStorage.Code.Untils.Math.Vec4) 
local Quat = require(MainStorage.Code.Untils.Math.Quat) 

---@class VectorMath
local VectorMath = {}

-- =============================================
-- 基础数学工具函数
-- =============================================

--求半径内的随机点
function VectorMath.RandomPointInRadius(center, radius)
    local angle = math.random(0, 360)
    local x = center.x + radius * math.cos(angle)
    local z = center.z + radius * math.sin(angle)
    return Vector3.New(x, center.y, z)
end

--平滑阻尼插值
function VectorMath.SmoothDamp(current, target, velocity, smoothTime, maxSpeed, deltaTime)
    -- 防止除以零
    if smoothTime == 0 then
        return target
    end

    -- 计算减速度常数
    local timeConstant = math.sqrt(2.0 / smoothTime)

    -- 计算最大速度
    local maxVelocity = maxSpeed * timeConstant

    -- 限制速度
    velocity = math.min(velocity, maxVelocity)
    velocity = math.max(velocity, -maxVelocity)

    -- 计算新的位置
    local remainingTime = smoothTime - deltaTime
    local t = 1 - math.exp(-timeConstant * deltaTime)

    -- 使用线性插值（lerp）来平滑移动
    local smoothedValue = current + (target - current) * t

    -- 更新速度
    velocity = velocity - (target - smoothedValue) / remainingTime

    return smoothedValue, velocity
end

--范围随机数
function VectorMath.Random(min, max)
    return min + math.random() * (max - min)
end

--随机数加偏移
function VectorMath.RandomDeviation(value, dev)
    return value + VectorMath.Random(-dev, dev)
end

--在一个圈内随机
function VectorMath.RandomInsideUnitCircle()
    local x = math.random() * 2 - 1
    local y = math.random() * 2 - 1
    local ret = Vector2.New(x, y)
    return ret:Normalize()
end

--判断一个数字是否在某个范围内
function VectorMath.IsInRange(value, min, max)
    return value >= min and value <= max
end

--几乎等于
function VectorMath.IsAlmostEqual(a, b, epsilon)
    return math.abs(a - b) < epsilon
end

--补间
function VectorMath.Lerp(a, b, t)
    return a + (b - a) * t
end

--判断是否为NaN
function VectorMath.IsNaN(x)
    return x ~= x
end

--判断数字是否无穷大
function VectorMath.IsInfinity(x)
    return x == math.huge or x == -math.huge
end

--判断浮点是否等于0，接近即可
function VectorMath.IsZero(x)
    local r = 0.001
    return math.abs(x) <= r
end

--角度差
function VectorMath.DeltaAngle(a, b)
    local delta = (b - a) % 360
    if delta < -180 then
        delta = delta + 360
    elseif delta > 180 then
        delta = delta - 360
    end
    return delta
end

--根据一个向量方向，返回的左边方向
function VectorMath.GetLeftDirection(direction)
    return VectorMath.GetRightDirection(direction):Negate()
end

--根据一个向量方向，返回的右边方向
function VectorMath.GetRightDirection(direction)
    if direction.x == 0 and direction.z == 0 then
        return Vector3.New(0, 0, 1)
    end
    local orient = Quaternion.lookAt(direction)
    return orient * Vector3.New(1, 0, 0)
end

-- =============================================
-- 向量计算核心类
-- =============================================

---@class VectorCalc
local VectorCalc = {}

-- 数学常量
VectorCalc.M_EPSILON = 0.000001
VectorCalc.M_PI = 3.14159265358979323846
VectorCalc.M_DEGTORAD = VectorCalc.M_PI / 180.0
VectorCalc.M_DEGTORAD_2 = VectorCalc.M_PI / 360.0
VectorCalc.M_RADTODEG = 1.0 / VectorCalc.M_DEGTORAD
VectorCalc.Rad2Deg = 180.0 / VectorCalc.M_PI
VectorCalc.Deg2Rad = VectorCalc.M_PI / 180.0

-- =============================================
-- Vector2 操作函数
-- =============================================

---@param v Vector2 要标准化的向量
---@return Vector2 标准化后的向量
function VectorCalc.Normalize2(v)
    return Vector2.Normalize(v)
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量之间的距离
function VectorCalc.Distance2(v1, v2)
    return math.sqrt(VectorCalc.DistanceSq2(v1, v2))
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量之间距离的平方
function VectorCalc.DistanceSq2(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return dx * dx + dy * dy
end

---@param v1 Vector2 第一个向量
---@param v2 Vector2 第二个向量
---@return number 两个向量的点积
function VectorCalc.Dot2(v1, v2)
    return Vector2.Dot(v1, v2)
end

---@param v1 Vector2 起始向量
---@param v2 Vector2 目标向量
---@param percent number 插值比例(0-1)
---@return Vector2 插值后的向量
function VectorCalc.Lerp2(v1, v2, percent)
    return Vector2.Lerp(v1, v2, percent)
end

---@param v1 Vector2 向量
---@param x number x坐标
---@param y number y坐标
---@return Vector2 相加后的向量
function VectorCalc.Add2(v1, x, y)
    return Vector2.New(v1.x + x, v1.y + y)
end

---@param v Vector2 向量
---@param scalar_or_vec number|Vector2 标量值或向量
---@return Vector2 相乘后的向量
function VectorCalc.Multiply2(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector2.New(v.x * scalar_or_vec, v.y * scalar_or_vec)
    else
        return Vector2.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y)
    end
end

-- =============================================
-- Vector3 操作函数
-- =============================================

---@param v Vector3 要标准化的向量
---@return Vector3 标准化后的向量
function VectorCalc.Normalize3(v)
    return Vector3.Normalize(v)
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量之间的距离
function VectorCalc.Distance3(v1, v2)
    return math.sqrt(VectorCalc.DistanceSq3(v1, v2))
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量之间距离的平方
function VectorCalc.DistanceSq3(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    local dz = v1.z - v2.z
    return dx * dx + dy * dy + dz * dz
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return number 两个向量的点积
function VectorCalc.Dot3(v1, v2)
    return Vector3.Dot(v1, v2)
end

---@param v1 Vector3 起始向量
---@param v2 Vector3 目标向量
---@param percent number 插值比例(0-1)
---@return Vector3 插值后的向量
function VectorCalc.Lerp3(v1, v2, percent)
    return Vector3.Lerp(v1, v2, percent)
end

---@param v1 Vector3 第一个向量
---@param v2 Vector3 第二个向量
---@return Vector3 两个向量的叉积
function VectorCalc.Cross3(v1, v2)
    return Vector3.Cross(v1, v2)
end

---@param v1 Vector3 向量
---@param x number x坐标
---@param y number y坐标
---@param z number z坐标
---@return Vector3 相加后的向量
function VectorCalc.Add3(v1, x, y, z)
    return Vector3.New(v1.x + x, v1.y + y, v1.z + z)
end

---@param v Vector3 向量
---@param scalar_or_vec number|Vector3 标量值或向量
---@return Vector3 相乘后的向量
function VectorCalc.Multiply3(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector3.New(v.x * scalar_or_vec, v.y * scalar_or_vec, v.z * scalar_or_vec)
    else
        return Vector3.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y, v.z * scalar_or_vec.z)
    end
end

-- =============================================
-- Vector4 操作函数
-- =============================================

---@param v Vector4 要标准化的向量
---@return Vector4 标准化后的向量
function VectorCalc.Normalize4(v)
    return Vector4.Normalize(v)
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量之间的距离
function VectorCalc.Distance4(v1, v2)
    return math.sqrt(VectorCalc.DistanceSq4(v1, v2))
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量之间距离的平方
function VectorCalc.DistanceSq4(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    local dz = v1.z - v2.z
    local dw = v1.w - v2.w
    return dx * dx + dy * dy + dz * dz + dw * dw
end

---@param v1 Vector4 第一个向量
---@param v2 Vector4 第二个向量
---@return number 两个向量的点积
function VectorCalc.Dot4(v1, v2)
    return Vector4.Dot(v1, v2)
end

---@param v1 Vector4 起始向量
---@param v2 Vector4 目标向量
---@param percent number 插值比例(0-1)
---@return Vector4 插值后的向量
function VectorCalc.Lerp4(v1, v2, percent)
    return Vector4.Lerp(v1, v2, percent)
end

---@param v1 Vector4 向量
---@param x number x坐标
---@param y number y坐标
---@param z number z坐标
---@param w number w坐标
---@return Vector4 相加后的向量
function VectorCalc.Add4(v1, x, y, z, w)
    return Vector4.New(v1.x + x, v1.y + y, v1.z + z, v1.w + w)
end

---@param v Vector4 向量
---@param scalar_or_vec number|Vector4 标量值或向量
---@return Vector4 相乘后的向量
function VectorCalc.Multiply4(v, scalar_or_vec)
    if type(scalar_or_vec) == "number" then
        return Vector4.New(v.x * scalar_or_vec, v.y * scalar_or_vec, v.z * scalar_or_vec, v.w * scalar_or_vec)
    else
        return Vector4.New(v.x * scalar_or_vec.x, v.y * scalar_or_vec.y, v.z * scalar_or_vec.z, v.w * scalar_or_vec.w)
    end
end

-- =============================================
-- 特殊转换和工具函数
-- =============================================

---@param target Vector3|Entity|Vec3
---@return Vector3
function VectorCalc.ToVector3(target)
    if type(target) == "userdata" then
        return target
    else
        if type(target) == "table" and target.Is and target:Is("Entity") then
            return target:GetPosition():ToVector3()
        else
            return target:ToVector3()
        end
    end
end

function VectorCalc.ToDirection(v1)
    -- Convert angles to radians
    local pitch = v1.x * VectorCalc.M_DEGTORAD
    local yaw = v1.y * VectorCalc.M_DEGTORAD

    -- Calculate direction vector components
    local x = math.sin(yaw) * math.cos(pitch)
    local y = -math.sin(pitch)
    local z = math.cos(yaw) * math.cos(pitch)

    -- Return normalized direction vector
    return Vector3.New(x, y, z)
end

-- =============================================
-- 距离判断工具函数
-- =============================================

-- 快速判断一个xyz的每个轴距都在len的范围内
---@param dir_ Vector3 方向向量
---@param len number 长度
---@return boolean 是否在范围内
function VectorCalc.FastInDistance(dir_, len)
    if dir_.x > 0 - len and dir_.x < len and dir_.y > 0 - len and dir_.y < len and dir_.z > 0 - len and dir_.z < len then
        return true
    else
        return false
    end
end

-- 快速判断两个点是否超距离
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@param len number 距离
---@return boolean 是否超出距离
function VectorCalc.FastOutDistance(pos1, pos2, len)
    local xx_ = math.abs(pos1.x - pos2.x)
    local yy_ = math.abs(pos1.y - pos2.y)
    local zz_ = math.abs(pos1.z - pos2.z)
    if zz_ > len or xx_ > len or yy_ > len then
        return true
    else
        return false
    end
end

-- 快速判断两个点是否超距离(length)
---@param pos1 Vector3 位置1
---@param pos2 Vector3 位置2
---@param len number 距离
---@return boolean 是否超出距离
function VectorCalc.OutDistance(pos1, pos2, len)
    local dis_ = (pos1 - pos2).length
    return dis_ > len
end

-- Vector2.Normalize
---@param x number X坐标
---@param y number Y坐标
---@return number, number 标准化后的X,Y坐标
function VectorCalc.Normalize2Coords(x, y)
    local len = math.sqrt(x * x + y * y)
    if len > 0 then
        return x / len, y / len
    else
        return 0, 0
    end
end

-- =============================================
-- 导出接口
-- =============================================

---@class VectorUtils
local VectorUtils = {
    -- 数学工具
    Math = VectorMath,
    
    -- 向量计算
    Vec = VectorCalc,
    
    -- 类型引用
    Vec2 = Vec2,
    Vec3 = Vec3,
    Vec4 = Vec4,
    Quat = Quat,
    
    -- 常用向量常量
    VECUP = Vector3.New(0, 1, 0),    -- 向上方向 y+
    VECDOWN = Vector3.New(0, -1, 0), -- 向下方向 y-
}

return VectorUtils 