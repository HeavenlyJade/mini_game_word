local MainStorage  = game:GetService('MainStorage')

local gg                = require(MainStorage.Code.Untils.MGlobal)    ---@type gg

---@class Class
---@field className string 类名
---@field super Class|nil 父类
---@field OnInit fun(self: Class, ...: any)|nil 初始化方法
---@field Destroy fun(self: Class)|nil 销毁方法
---@field ToString fun(self: Class): string 转字符串方法
---@field GetToStringParams fun(self: Class): table<number, any>|nil 获取ToString参数
---@field New fun(...: any): Class 创建实例
---@field Is fun(self: Class, className: string): boolean 判断是否继承自指定类

---@class ClassMgr        对class父子继承类的封装
---@field Class fun(name: string, ...: Class): Class
---@field Clone fun(object: table): table
---@field GetRegisterClass fun(classname: string): any
---@field Is fun(inst: table, className: string): boolean
---@field RegisterClass fun(classname: string, cls: any): void
if  _G.ClassMgr then
	--print( 'use cache ClassMgr' )
	return _G.ClassMgr
end

local ClassMgr = {}
_G.ClassMgr = ClassMgr

function ClassMgr.Clone(object)
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local newObject = {}
		lookup_table[object] = newObject
		for key, value in pairs(object) do
			newObject[_copy(key)] = _copy(value)
		end
		return setmetatable(newObject, getmetatable(object))
	end
	return _copy(object)
end

local s_register_class = {}
function ClassMgr.GetRegisterClass( classname )
	return s_register_class[classname]
end

function ClassMgr.RegisterClass( classname, cls)
	assert(s_register_class[classname] == nil, string.format("classname[%s]is exist", classname))
	s_register_class[classname] = cls
end


function ClassMgr.Is(inst, className)
    if type(inst) == "table" then
        return inst.Is and inst:Is(className)
    end
	return false
end

---@param name string 类名
---@param ... Class 父类
---@return Class 返回类定义
function ClassMgr.Class( name, ...)
	local cls = nil
	local super = ...

	if super then
		cls = ClassMgr.Clone(super)
		cls.super = super
	else
		cls = { OnInit = function() end, Destroy = function() end}
	end

	cls.__index = cls
	cls.className = name
	cls.ToString = function (instance)
		local paramsStr = {}
		if instance.GetToStringParams then
			local params = instance:GetToStringParams()
			for k, param in pairs(params) do
				if type(param) == "table" and param.className then
					paramsStr[k] = param:ToString()
				else
					paramsStr[k] = gg.table2str(param)
				end
			end
		end
		return instance.className .. gg.table2str(paramsStr)
	end

	cls.Is = function(instance, className)
		local current = instance
		while current do
			if current.className == className then
				return true
			end
			current = current.super
		end
		return false
	end

	-- 修复：显式初始化 create 函数为 nil，避免诊断警告
	local create = nil
	create = function(instance, c, ...)
		-- 增加 create 存在性检查，避免诊断工具警告
		if c.super and create then
			create(instance, c.super, ...)
		end
		-- 关键修复：只有当子类的OnInit和父类的OnInit不是同一个函数时，才调用子类的。
		-- 这可以防止在子类没有定义自己的OnInit时，重复调用父类的OnInit。
		if c.OnInit and (not c.super or c.OnInit ~= c.super.OnInit) then
			c.OnInit(instance, ...)
		end
	end

	function cls.New(...)
		local instance = setmetatable({}, cls)
		-- 调用修复后的递归创建函数
		if create then
			create(instance, cls, ...)
		end
		return instance
	end

    ClassMgr.RegisterClass(name, cls)

    return cls
end

function math.clamp(value, min, max)
	if value < min then return min end
	if value > max then return max end

	return value
end

return ClassMgr