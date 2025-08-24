local MainStorage = game:GetService("MainStorage")
local Vec2 = require(MainStorage.Code.Untils.Math.Vec2) ---@type Vec2
local Vec3 = require(MainStorage.Code.Untils.Math.Vec3) ---@type Vec3
local Vec4 = require(MainStorage.Code.Untils.Math.Vec4)
local Quat = require(MainStorage.Code.Untils.Math.Quat)
local json = require(MainStorage.Code.Untils.json) ---@type json

local inputservice = game:GetService("UserInputService")
local Players = game:GetService('Players')

---@class NetworkChannel
---@field OnClientNotify Event<fun(self, event: string, data: table)>
---@field FireServer fun(self, data: table)
---@field fireClient fun(self, uin: number, data: table)
---@
---@class gg      --存放自定义的global全局变量和函数
local gg = {
    isServer = nil,
    opUin = {[1995296726]= true, [1999522565]= true, [1997748985] = true, [1831921352] = true, [1995494850] = true, [1997807412] = true, [1972857840] = true},

    -- 【移除】不再通过 gg 重定向向量计算函数，请直接使用 VectorUtils 模块
    Vec2 = Vec2, ---@type Vec2
    Vec3 = Vec3, ---@type Vec3
    Vec4 = Vec4, ---@type Vec4
    Quat = Quat, ---@type Quat
    VECUP = Vector3.New(0, 1, 0), -- 向上方向 y+
    VECDOWN = Vector3.New(0, -1, 0), -- 向下方向 y-

    noise = require(MainStorage.Code.Untils.Math.PerlinNoise),
    json = json, ---@type json
    uuid_start = nil,
    CommandManager = nil, ---@type CommandManager
    GlobalMailManager = nil, ---@type GlobalMailManager
    network_channel = nil, ---@type NetworkChannel
    cloudMailData = nil, ---@type CloudMailDataAccessor
    -- 客户端使用(p1)
    client_scene_name = 'init_map', -- 当前客户端的场景

    -- 【新增】玩家场景节点映射表，存储玩家uin和对应的场景名字
    player_scene_map = {}, -- {[uin] = scene_name}

    lockClientCharactor = false, -- 是否锁定玩家

}

---@param node SandboxNode
function gg.GetFullPath(node)
    local path = node.Name
    local parent = node.Parent

    while parent do
        path = parent.Name .. "/" .. path
        parent = parent.Parent
        if parent.Name == "WorkSpace" then
           break
        end
    end

    return path
end

function gg.ProcessVariables(formula, caster, target)
    if not formula then
        return nil
    end
    local processedFormula = formula:gsub("%[(.-)%]", function(varName)
        local value = target:GetVariable(varName)
        return tostring(value)
    end)
    return processedFormula
end

--- 内部辅助函数：执行两个数字的比较运算
---@param left number 左操作数
---@param operator string 比较运算符
---@param right number 右操作数
---@return boolean 比较结果
local function _compareNumbers(left, operator, right)
    if operator == "<" then
        return left < right
    elseif operator == "<=" then
        return left <= right
    elseif operator == ">" then
        return left > right
    elseif operator == ">=" then
        return left >= right
    elseif operator == "==" then
        return left == right
    elseif operator == "~=" then
        return left ~= right
    else
        --gg.log("错误: [gg.evaluateCondition] 未知的比较运算符:", operator)
        return false
    end
end

--- 通用条件表达式求值器
--- 专门处理比较运算符的布尔表达式，如 "0 < 1 < 100" 或 "x >= 1000"
---@param expression string 条件表达式
---@return boolean 条件是否成立
function gg.evaluateCondition(expression)
    if not expression or expression == "" then
        return true -- 空条件默认为真
    end

    -- 移除多余空格
    expression = expression:gsub("%s+", "")

    -- 检查是否包含比较运算符
    local hasComparison = expression:match("[<>=~]")
    if not hasComparison then
        -- 如果没有比较运算符，当作数值表达式处理，非0即为true
        local result = gg.eval(expression)
        return result and result ~= 0
    end

    -- 处理链式比较：A op1 B op2 C (如 0 < 1 < 100)
    local chainPattern = "^([%d%.%-]+)%s*([<>=]+)%s*([%d%.%-]+)%s*([<>=]+)%s*([%d%.%-]+)$"
    local a, op1, b, op2, c = expression:match(chainPattern)

    if a and op1 and b and op2 and c then
        -- 链式比较
        a, b, c = tonumber(a), tonumber(b), tonumber(c)
        if not (a and b and c) then
            --gg.log("警告: [gg.evaluateCondition] 链式比较中包含无效数字:", expression)
            return false
        end

        local result1 = _compareNumbers(a, op1, b)
        local result2 = _compareNumbers(b, op2, c)

        return result1 and result2
    end

    -- 处理单个比较：A op B
    local singlePattern = "^([%d%.%-]+)%s*([<>=~]+)%s*([%d%.%-]+)$"
    local left, op, right = expression:match(singlePattern)

    if left and op and right then
        left, right = tonumber(left), tonumber(right)
        if not (left and right) then
            --gg.log("警告: [gg.evaluateCondition] 单个比较中包含无效数字:", expression)
            return false
        end

        return _compareNumbers(left, op, right)
    end

    -- 如果无法识别模式，记录警告并返回false
    --gg.log("警告: [gg.evaluateCondition] 无法解析的条件表达式:", expression)
    return false
end

function gg.eval(expr)
    -- 自动修正常见中文符号为英文
    expr = expr
        :gsub("，", ",")
        :gsub("（", "(")
        :gsub("）", ")")
        :gsub("－", "-")
        :gsub("−", "-")
        :gsub("—", "-")
        :gsub("＋", "+")
        :gsub("×", "*")
        :gsub("＊", "*")
        :gsub("÷", "/")
        :gsub("／", "/")
        :gsub("．", ".")
    local ok, result = pcall(function()
        expr = expr:gsub("%s+", "")  -- 移除空格
        local pos = 1

        -- 先声明所有函数（避免未定义错误）
        local parseExpr, parseMulDiv, parsePower, parseAtom, parseNumber

        parseNumber = function()
            local start = pos
            if expr:sub(pos, pos) == "-" then pos = pos + 1 end
            while pos <= #expr and (expr:sub(pos, pos):match("%d") or expr:sub(pos, pos) == ".") do
                pos = pos + 1
            end
            return tonumber(expr:sub(start, pos - 1))
        end

        parseAtom = function()
            -- 支持 max/min/clamp 函数
            local func3 = expr:sub(pos, pos+2)
            local func5 = expr:sub(pos, pos+4)

            if func3 == "max" or func3 == "min" then
                pos = pos + 3
                -- 跳过函数名后的空白字符
                while pos <= #expr and expr:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end

                if pos > #expr or expr:sub(pos, pos) ~= "(" then
                    error("Missing '(' after function name")
                end
                pos = pos + 1

                local args = {}
                -- 解析第一个参数
                if pos <= #expr and expr:sub(pos, pos) ~= ")" then
                    args[1] = parseExpr()

                    -- 解析后续参数
                    while pos <= #expr and expr:sub(pos, pos) == "," do
                        pos = pos + 1
                        if pos <= #expr then
                            args[#args+1] = parseExpr()
                        end
                    end
                end

                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing ')' after function arguments")
                end
                pos = pos + 1

                if func3 == "max" then
                    return math.max(unpack(args))
                else
                    return math.min(unpack(args))
                end
            elseif func5 == "clamp" then
                pos = pos + 5
                -- 跳过函数名后的空白字符
                while pos <= #expr and expr:sub(pos, pos):match("%s") do
                    pos = pos + 1
                end

                if pos > #expr or expr:sub(pos, pos) ~= "(" then
                    error("Missing '(' after clamp function name")
                end
                pos = pos + 1

                local args = {}
                -- 解析第一个参数
                if pos <= #expr and expr:sub(pos, pos) ~= ")" then
                    args[1] = parseExpr()

                    -- 解析后续参数
                    while pos <= #expr and expr:sub(pos, pos) == "," do
                        pos = pos + 1
                        if pos <= #expr then
                            args[#args+1] = parseExpr()
                        end
                    end
                end

                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing ')' after clamp function arguments")
                end
                pos = pos + 1

                -- clamp(value, min, max) 函数实现
                if #args >= 3 then
                    local value, minVal, maxVal = args[1], args[2], args[3]
                    -- 使用与 math.clamp 相同的逻辑
                    if value < minVal then return minVal end
                    if value > maxVal then return maxVal end
                    return value
                else
                    error("clamp function requires 3 arguments: clamp(value, min, max)")
                end
            elseif expr:sub(pos, pos) == "(" then
                pos = pos + 1
                local val = parseExpr()
                if pos > #expr or expr:sub(pos, pos) ~= ")" then
                    error("Missing closing parenthesis")
                end
                pos = pos + 1
                return val
            else
                return parseNumber()
            end
        end

        parsePower = function()
            local left = parseAtom()
            while pos <= #expr and expr:sub(pos, pos) == "^" do
                pos = pos + 1
                left = left ^ parseAtom()  -- 右结合（如 2^3^2 = 2^(3^2)）
            end
            return left
        end

        parseMulDiv = function()
            local left = parsePower()
            while pos <= #expr do
                local op = expr:sub(pos, pos)
                if op == "*" or op == "/" then
                    pos = pos + 1
                    local right = parsePower()
                    if op == "*" then
                        left = left * right
                    else
                        left = left / right
                    end
                else
                    break
                end
            end
            return left
        end

        parseExpr = function()
            local left = parseMulDiv()
            while pos <= #expr do
                local op = expr:sub(pos, pos)
                if op == "+" or op == "-" then
                    pos = pos + 1
                    local right = parseMulDiv()
                    if op == "+" then
                        left = left + right
                    else
                        left = left - right
                    end
                else
                    break
                end
            end
            return left
        end

        return parseExpr()
    end)
    if ok then
        return result
    else
        --gg.log("[gg.eval] 公式计算失败: " .. tostring(result) .. "，表达式: " .. tostring(expr))
        return 0
    end
end

function gg.ProcessFormula(formula, caster, target)
    if not formula then
        return nil
    end
    -- 自动修正常见中文符号为英文
    formula = formula
        :gsub("，", ",")
        :gsub("（", "(")
        :gsub("）", ")")
        :gsub("－", "-")
        :gsub("−", "-")
        :gsub("—", "-")
        :gsub("＋", "+")
        :gsub("×", "*")
        :gsub("＊", "*")
        :gsub("÷", "/")
        :gsub("／", "/")
        :gsub("．", ".")
    formula = gg.ProcessVariables(formula, caster, target)
    if not formula then
        return 0
    end
    return gg.eval(formula)
end

-- 将table以json格式打印
---@param t table 要打印的表
---@param indent string? 缩进字符串(可选)
---@return string 格式化后的字符串
function gg.printTable(t, indent)
    indent = indent or ""

    if type(t) ~= "table" then
        return tostring(t)
    end

    local function escapeStr(str)
        str = string.gsub(str, '"', '\\"')
        str = string.gsub(str, '\n', '\\n')
        return str
    end

    local result = indent .. "{\n"
    for k, v in pairs(t) do
        local key = type(k) == "string" and '"' .. escapeStr(k) .. '"' or k
        if type(v) == "table" then
            result = result .. indent .. "  " .. key .. ": \n"
            result = result .. gg.printTable(v, indent .. "  ")
        else
            local val = type(v) == "string" and '"' .. escapeStr(v) .. '"' or tostring(v)
            result = result .. indent .. "  " .. key .. ": " .. val .. ",\n"
        end
    end
    result = result .. indent .. "}\n"
    return result
end



-- 获得当前场景（客户端侧）
---@return Workspace 当前工作空间
function gg.getClientWorkSpace()
    return game.WorkSpace
    -- return game:GetService("workspace")
end

-- -- 是否锁定视角，不允许转动
---@param flag_ boolean 是否锁定
function gg.lockCamera(flag_)

    if flag_ then
        gg.getClientWorkSpace().Camera.CameraType = Enum.CameraType.Fixed
        gg.lockClientCharactor = true
    else
        gg.getClientWorkSpace().Camera.CameraType = Enum.CameraType.Custom
        gg.lockClientCharactor = false
    end

end

-- 客户端获得怪物容器
---@return SandboxNode|nil 怪物容器
function gg.clentGetContainerMonster()
    if not gg.client_scene_name then
        --gg.log("警告：client_scene_name 未初始化，使用默认场景名 'terrain'")
        gg.client_scene_name = 'init_map'
    end

    local ground = game.WorkSpace["Ground"]
    if not ground then
        --gg.log("错误：未找到 WorkSpace.Ground")
        return nil
    end

    local scene = ground[gg.client_scene_name]
    if not scene then
        --gg.log("错误：未找到场景", gg.client_scene_name)
        return nil
    end

    local terrain = scene.terrain
    if not terrain then
        --gg.log("错误：场景中未找到 terrain", gg.client_scene_name)
        return nil
    end

    local container = terrain.Monster
    if not container then
        --gg.log("错误：terrain中未找到 Monster", gg.client_scene_name)
        return nil
    end

    return container
end



-- 获得当前玩家（客户端侧）
---@return Actor 当前玩家角色
function gg.getClientLocalPlayer()
    return Players.LocalPlayer.Character
end



-- 获取屏幕大小
---@return number, number 屏幕宽度和高度
function gg.get_ui_wwhh()
    local ui_size = gg.get_ui_size()
    return ui_size.x, ui_size.y
end

-- 获取屏幕大小
---@return Vector2 屏幕尺寸
function gg.get_ui_size()
    if not gg.ui_size then
        gg.ui_size = game:GetService('WorldService'):GetUISize()
        --gg.log('获取屏幕大小====', gg.ui_size)
    end
    return gg.ui_size
end

function gg.FormatTime(time, isShort)
    if isShort == nil then
        isShort = true
    end
    local s = ""
    local c = 0

    -- Handle days
    if time > 86400 then
        local days = math.floor(time / 86400)
        s = s .. days .. "天"
        time = time - days * 86400
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Handle hours
    if time > 3600 then
        local hours = math.floor(time / 3600)
        s = s .. hours .. "小时"
        time = time - hours * 3600
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Handle minutes
    if time > 60 then
        local minutes = math.floor(time / 60)
        s = s .. minutes .. "分"
        time = time - minutes * 60
        c = c + 1
        if c > 0 and isShort then
            return s
        end
    end

    -- Add seconds
    s = s .. math.floor(time) .. "秒"
    return s
end

-- 数字格式化函数
-- 扩展版本的大数字格式化函数
function gg.FormatLargeNumber(num)
    if num < 10000 then
        return tostring(num)
    end
    
    -- 完整的中文数字单位体系
    local units = {
        "", "万", "亿", "兆", "京", "垓", "秭", "穰", 
        "沟", "涧", "正", "载", "极"
    }
    
    local unitIndex = 1
    local result = num
    
    while result >= 10000 and unitIndex < #units do
        result = result / 10000
        unitIndex = unitIndex + 1
    end
    
    -- 保留一位小数
    result = math.floor(result * 10) / 10
    
    -- 格式化输出
    if result == math.floor(result) then
        return tostring(math.floor(result)) .. units[unitIndex]
    else
        local wholePart = math.floor(result)
        if wholePart >= 1000 then
            -- 四位数时去掉小数部分
            return tostring(wholePart) .. units[unitIndex]
        else
            return tostring(result) .. units[unitIndex]
        end
    end
end

-- 屏幕视角大小
---@return number, number 视角宽度和高度
function gg.get_camera_window_size()
    if not gg.camera_win_size then
        wait(1)
        gg.camera_win_size = game.WorkSpace.CurrentCamera.WindowSize
        --gg.log('camera_win_size====', gg.camera_win_size)
    end
    return gg.camera_win_size.x, gg.camera_win_size.y
end

-- 获得当前玩家 (只有client会使用)
---@return number 玩家ID
function gg.get_client_uin()
    return game.Players.LocalPlayer.UserId;
end


-- 获取ui_root
---@return SandboxNode UI根节点
function gg.get_ui_root()
    return Players.LocalPlayer.PlayerGui.ui_root
end


-- input 100 return  0 to 100
---@param int32 number 上限值
---@return number 随机数
function gg.rand_int(int32)
    -- return math.floor( math.random() * int32 + 0.5 )
    return math.random(int32 + 1) - 1
end

-- input 100 return  -100 to 100 (可以为负数)
---@param int32 number 范围值
---@return number 随机数
function gg.rand_int_both(int32)
    -- local ret_ = math.floor( math.random() * int32 + 0.5 )
    -- if  math.random() < 0.5 then
    -- ret_ = 0 - ret_
    -- end
    -- return  ret_
    return math.random(0 - int32, int32)
end

-- 获得两个整数之间的一个随机值
---@param int1_ number 第一个整数
---@param int2_ number 第二个整数
---@return number 随机数
function gg.rand_int_between(int1_, int2_)
    if int1_ > int2_ then
        return math.random(int2_, int1_)
    else
        return math.random(int1_, int2_)
    end
end

-- 从一个list中获得一个随机值
---@param list_ table 列表
---@return any 随机值
function gg.getRandFromList(list_)
    return list_[math.random(1, 65535) % #list_ + 1]
end

function gg.contains(list, target)
    for _, value in ipairs(list) do
        if value == target then
            return true
        end
    end
    return false
end

function gg.removeElement(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then
            table.remove(list, i)
        end
    end
end

-- 字符串分割函数，返回一个table   t_ = uu.split( "abc_cdf_dfd", "_" )
---@param s string 要分割的字符串
---@param delim string 分隔符
---@return table|nil 分割后的字符串数组
function gg.split(s, delim)
    if type(delim) ~= "string" or string.len(delim) <= 0 then
        return
    end
    local start = 1
    local t = {}
    while true do
        local pos = string.find(s, delim, start, true) -- plain find
        if not pos then
            break
        end

        table.insert(t, string.sub(s, start, pos - 1))
        start = pos + string.len(delim)
    end
    table.insert(t, string.sub(s, start))
    return t
end

-- lua-table 转字符串（打印日志使用）
---@param tbl table 要转换的表
---@param level_? number 递归层级
---@param visited? table 已访问的表
---@return string 转换后的字符串
function gg.table2str(tbl, level_, visited)
    if type(tbl) ~= "table" then
        return tostring(tbl)
    end
    level_ = level_ or 0
    if level_ >= 20 then
        --gg.log('ERROR table2str level>=10')
        return '' -- 层数保护
    end

    visited = visited or {} -- 防止两个table互相引用，互相循环

    local tab = {'{'}
    for k, v in pairs(tbl) do
        if type(v) == 'table' then
            if visited[v] then
                if v.uuid then
                    tab[#tab + 1] = 'VISITED uuid=' .. v.uuid
                else
                    tab[#tab + 1] = 'VISITED ' .. tostring(v)
                end
            else
                visited[v] = true -- table作为key等同于tostring(v)
                if v.ToString then
                    tab[#tab + 1] = tostring(k) .. '=' .. v:ToString()
                else
                    tab[#tab + 1] = tostring(k) .. gg.table2str(v, level_ + 1, visited)
                end
            end
        elseif type(v) == 'function' or type(v) == 'userdata' or type(v) == 'thread' then
            -- 忽略不打印
        else
            tab[#tab + 1] = tostring(k) .. '=' .. tostring(v)
        end
    end

    tab[#tab + 1] = '}'
    return table.concat(tab, ' ')
end

-- 打印一个lua-table
---@param t table 要打印的表
---@param info_ string 打印信息
function gg.print_table(t, info_)
    if type(t) == 'table' then
        print(info_, ' ' .. gg.table2str(t))
    else
        print(info_, ' not table= ', t)
    end
end

-- 浅拷贝 不拷贝meta
---@param ori_tab table 原始表
---@return table|nil 拷贝后的表
function gg.clone(ori_tab)
    if type(ori_tab) ~= "table" then
        return nil
    end
    local new_tab = {}
    for i, v in pairs(ori_tab) do
        if type(v) == "table" then
            new_tab[i] = gg.clone(v)
        else
            new_tab[i] = v
        end
    end
    return new_tab
end

function gg:ShallowCopy(orig, customCopy)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = Utils:ShallowCopy(orig_value, customCopy)
        end
    else -- number, string, boolean, etc
        if customCopy then
            copy = customCopy(orig)
        else
            copy = orig
        end
    end
    return copy
end

function gg.DeepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function gg.GetTimeStamp()
    return game.RunService:CurrentSteadyTimeStampMS() / 1000
end



-- 打印日志使用
---@param ... any 要打印的内容
function gg.log(...)
    local tab = {}
    local n = select('#', ...)
    for i = 1, n do
        local v = select(i, ...)
        if v == nil then
            tab[i] = "nil"
        elseif type(v) == 'table' then
            if v.ToString then
                tab[i] = v:ToString()
            else
                tab[i] = gg.table2str(v)
            end
        else
            tab[i] = tostring(v)
        end
    end
    print(table.concat(tab, ' '))
end

-- 【移除】距离计算函数已迁移到 VectorUtils 模块
-- 如需使用，请调用：
-- gg.vec.FastInDistance(dir_, len)
-- gg.vec.FastOutDistance(pos1, pos2, len)
-- gg.vec.OutDistance(pos1, pos2, len)
-- gg.vec.Normalize2Coords(x, y)

-- 克隆一个物体 template下对模型
---@param name_ string 模型名称
---@return Instance 克隆的模型
function gg.cloneFromTemplate(name_)
    if MainStorage.template[name_] then
        return MainStorage.template[name_]:Clone()
    elseif game.WorkSpace.template[name_] then
        return game.WorkSpace.template[name_]:Clone()
    else
        -- error
    end
end


---@param node SandboxNode
---@param path string
---@return SandboxNode|nil
function gg.GetChild(node, path)
    local root = node
    local cacheKey = path
    local fullPath = ""
    local lastPart = ""
    for part in path:gmatch("[^/]+") do -- 用/分割字符串
        if part ~= "" then
            lastPart = part
            if not node then
                -- gg.log(string.format("[%s]获取路径[%s]失败: 在[%s]处节点不存在", root.Name, path,fullPath))
                return nil
            end
            node = node[part]
            if fullPath == "" then
                fullPath = part
            else
                fullPath = fullPath .. "/" .. part
            end
        end
    end

    if not node then
        --gg.log(string.format("[%s]获取路径[%s]失败: 最终节点[%s]不存在", root.Name, path, lastPart))
        return nil
    end
    return node
end

-- 选择一个目标（客户端侧）(debug使用)
---@return SandboxNode|nil 选中的目标
function gg.clientPickObjectMiddle()
    local obj_list = {} -- 表示只在哪些obj里面查找
    if not gg.camera_mid_x then
        local win_size = game.WorkSpace.CurrentCamera.WindowSize
        gg.camera_mid_x = win_size.x * 0.5
        gg.camera_mid_y = win_size.y * 0.5
    end

    local ret_node_
    -- 从中间扩散选择，增大范围
    for xx = 0, 5 do
        ret_node_ = inputservice:PickObjects(gg.camera_mid_x + xx * 10, gg.camera_mid_y, obj_list)
        -- --gg.log( 'clientPickObjectMiddle===:[', ret_node_, ']' )
        if ret_node_ then
            return ret_node_
        end

        ret_node_ = inputservice:PickObjects(gg.camera_mid_x - xx * 10, gg.camera_mid_y, obj_list)
        if ret_node_ then
            return ret_node_
        end
    end

    return ret_node_
end

-- 使用鼠标和触屏点击选择目标（客户端侧）（debug）
function gg.clientPickPress()
    -- 按下
    local function inputBegan(inputObj, bGameProcessd)
        if inputObj.UserInputType == Enum.UserInputType.MouseButton1.Value then
            local obj_list = {} -- 表示只在哪些obj里面查找
            for k, v in pairs(gg.clentGetContainerMonster().Children) do
                obj_list[#obj_list + 1] = v -- 只找怪物
            end

            -- 屏幕中心点位置
            local win_size = game.WorkSpace.CurrentCamera.WindowSize
            local xx = math.floor(win_size.x * 0.5)
            local yy = math.floor(win_size.y * 0.5)

            local rets
            -- 从中间扩散选择，增大范围
            for x = 0, 5 do
                rets = inputservice:PickObjects(xx + x * 10, yy, obj_list)
                -- --gg.log( 'GetCursorPick[', #obj_list, '] [', rets, ']' )
                if rets then
                    break
                end

                rets = inputservice:PickObjects(xx - x * 10, yy, obj_list)
                -- --gg.log( 'GetCursorPick[', #obj_list, '] [', rets, ']' )
                if rets then
                    break
                end
            end

            if rets then
                -- 改动框的显示，明确是否被选中
                rets.CubeBorderEnable = not rets.CubeBorderEnable
            end

        end
    end
    inputservice.InputBegan:Connect(inputBegan)
end

-- alias
gg.thread_call = coroutine.work

-- 等同于下面定义
-- function gg.thread_call( func_ )
-- coroutine.work( func_ )
-- end

-- 文字框
---@param root_ SandboxNode 父节点
---@param title_ string 标题文本
---@return UITextLabel 创建的文本标签
function gg.createTextLabel(root_, title_)
    local textLabel_ = SandboxNode.new('UITextLabel', root_)
    textLabel_.Size = Vector2.New(1500, 800)
    textLabel_.Pivot = Vector2.New(0.5, 0.5)

    textLabel_.FontSize = 120

    textLabel_.TitleColor = ColorQuad.New(255, 255, 255, 255)
    textLabel_.FillColor = ColorQuad.New(0, 0, 0, 0)

    textLabel_.TextVAlignment = Enum.TextVAlignment.Center -- Top  Bottom
    textLabel_.TextHAlignment = Enum.TextHAlignment.Center -- Left Right

    -- textLabel_.Position   = Vector2.New( 0,  0 )
    textLabel_.Title = title_

    return textLabel_
end

function gg.createNpcImage(root_, args)
    local image_ = SandboxNode.new("UIImage")
    local icon_ = args.icon
    local size_ = args.size
    local name_ = args.name
    local active_ = args.active
    local click_pass_ = args.click_pass
    local pivot_ = args.pivot
    local position_ = args.position
    local rotation_ = args.rotation
    local scale_ = args.scale

    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    image_.Parent = root_

    if icon_ then
        image_.Icon = icon_
    end
    if size_ then
        image_.Size = Vector2.New(size_[1], size_[2])
    end
    if name_ then
        image_.Name = name_
    end
    if active_ then
        image_.Active = active_
    end
    if click_pass_ then
        image_.ClickPass = click_pass_
    end
    if pivot_ then
        image_.Pivot = Vector2.New(pivot_[1], pivot_[2])
    end
    if position_ then
        image_.Position = Vector3.New(position_[1], position_[2], position_[3])
    end
    if rotation_ then
        image_.Rotation = Quaternion.FromEuler(rotation_[1], rotation_[2], rotation_[3])
    end
    if scale_ then
        image_.Scale = Vector3.New(scale_[1], scale_[2], scale_[3])
    end
    return image_
end

-- 图片
function gg.createImage(root_, icon_)
    local image_ = SandboxNode.new("UIImage")
    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    image_.Parent = root_

    if icon_ then
        image_.Icon = icon_
    end

    -- image_.Name      = "xxx"
    -- image_.Active    = true
    -- image_.ClickPass = true

    -- image_.Size  = Vector2.New(100, 100)
    -- image_.Pivot = Vector2.New(0.5, 0.5)  --默认

    -- imgTouchBg.LayoutHRelation = Enum.LayoutHRelation.Left
    -- imgTouchBg.LayoutVRelation = Enum.LayoutVRelation.Top

    -- bar_.FillMethod = Enum.FillMethod.Horizontal
    -- bar_.FillAmount = 1

    -- bar_.FillColor = ColorQuad.New( 255,0,0,255 )

    return image_
end

function gg.createImageNode(root_, args)
    local image_ = SandboxNode.new("UIImage", root_)
    image_.LocalSyncFlag = Enum.NodeSyncLocalFlag.DISABLE
    -- image_.Parent    = root_
    image_.Name = args.name
    image_.Active = true
    image_.ClickPass = true
    image_.Visible = false
    if args.icon then
        image_.Icon = args.icon
    end
    if args.size then
        image_.Size = Vector2.New(args.size[1], args.size[2])
    end
    return image_
end
-- 按钮
function gg.createButton(root_, args)
    local button_ = SandboxNode.new("UIButton", root_)
    -- button_.Parent    = root_
    button_.Title = args.title
    if args.title_Size then
        button_.TitleSize = button_.title_Size
    end
    gg.formatButton(button_)
    return button_
end

-- 按客户端背包id，获得物品详情
---@param bag_id_ number 背包ID
---@return table|nil 物品详情
function gg.getClientBagItemByBagId(bag_id_)
    local uuid_
    if gg.client_bag_index[bag_id_] then
        uuid_ = gg.client_bag_index[bag_id_].uuid
    end
    if uuid_ and gg.client_bag_items[uuid_] then
        return gg.client_bag_items[uuid_]
    end
    return nil
end

-- 获得客户端背包中，某一个可堆叠物品的数量，魔力碎片1 神力碎片2
---@param mat_id_ number 材料ID
---@param quality_ number 品质
---@return number 数量
function gg.getClientBagMatNum(mat_id_, quality_)
    for k, v in pairs(gg.client_bag_items) do
        if v.mat_id == mat_id_ and v.quality == quality_ then
            return v.num or 0
        end
    end
    return 0
end

-- 客户端的背包是否全满
function gg.ifClientBagFull()
    for bag_id_ = 10000, 10035 do
        if gg.client_bag_index[bag_id_] then
            -- 有物品了
        else
            return false -- 没有物品
        end
    end
    return true
end

-- 添加table.contains函数
table.contains = function(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- 兼容性包装器 - 在服务端环境下提供对服务端数据管理器的访问
if gg.isServer then
    -- 延迟加载服务端数据管理器以避免循环依赖
    local function getServerDataMgr()
        if not gg._serverDataMgr then
            gg._serverDataMgr = require(game:GetService("ServerStorage").Manager.MServerDataManager)
        end
        return gg._serverDataMgr
    end

    -- 创建代理访问器
    gg.getPlayerInfoByUin = function(uin_)
        return getServerDataMgr().getPlayerInfoByUin(uin_)
    end

    gg.getLivingByName = function(name_)
        return getServerDataMgr().getLivingByName(name_)
    end


    gg.findMonsterByUuid = function(uuid_)
        return getServerDataMgr().findMonsterByUuid(uuid_)
    end

    gg.findMonsterClientContainer = function(scene_name_, uuid_)
        return getServerDataMgr().findMonsterClientContainer(scene_name_, uuid_)
    end

    gg.serverGetContainerWeapon = function(scene_name_)
        return getServerDataMgr().serverGetContainerWeapon(scene_name_)
    end

    gg.create_uuid = function(pre_)
        return getServerDataMgr().create_uuid(pre_)
    end

    gg.GetSceneNode = function(path)
        return getServerDataMgr().GetSceneNode(path)
    end

    -- 属性代理
    local mt = {
        __index = function(t, k)
            local serverDataMgr = getServerDataMgr()
            if k == "server_players_list" then
                return serverDataMgr.server_players_list
            elseif k == "server_players_name_list" then
                return serverDataMgr.server_players_name_list
            elseif k == "tick" then
                return serverDataMgr.tick
            elseif k == "game_stat" then
                return serverDataMgr.game_stat
            elseif k == "uuid_start" then
                return serverDataMgr.uuid_start
            elseif k == "equipSlot" then
                return serverDataMgr.equipSlot
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            local serverDataMgr = getServerDataMgr()
            if k == "tick" then
                serverDataMgr.tick = v
            elseif k == "game_stat" then
                serverDataMgr.game_stat = v
            elseif k == "uuid_start" then
                serverDataMgr.uuid_start = v
            else
                rawset(t, k, v)
            end
        end
    }
    setmetatable(gg, mt)
end

--- 科学计数法数字转换为标准格式
--- 将科学计数法格式的数字（如6e+20）转换为标准数字格式（如600000000000000000000）
---@param value any 要转换的值（可以是字符串、数字或其他类型）
---@return number 转换后的标准数字，失败时返回0
function gg.convertScientificNotation(value)
    if value == nil then
        return -1
    end
    
    if type(value) == 'string' then
        -- 字符串格式的科学计数法转换为数字
        local numValue = tonumber(value)
        if numValue and numValue >= 1e15 then
            -- 超大数字转换为标准格式，避免科学计数法问题
            return tonumber(string.format("%.0f", numValue)) or numValue
        else
            return numValue or -1
        end
    elseif type(value) == 'number' then
        -- 数字格式，检查是否为科学计数法
        if value >= 1e15 then
            -- 超大数字转换为标准格式，避免科学计数法问题
            return tonumber(string.format("%.0f", value)) or value
        else
            return value
        end
    else
        -- 其他类型，尝试转换为数字
        local numValue = tonumber(value)
        return numValue or -1
    end
end

--- 科学计数法数字转换为字符串格式（用于表达式替换）
--- 确保大数字在字符串替换时不会被tostring转换为科学计数法
---@param value number 要转换的数字
---@return string 转换后的字符串格式
function gg.numberToString(value)
    if type(value) == "number" and value >= 1e15 then
        return string.format("%.0f", value)
    else
        return tostring(value)
    end
end

return gg;
