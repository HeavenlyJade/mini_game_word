-- FriendInviteService.lua
-- 好友邀请拉新服务模块
-- 继承自：Service
-- 描述：好友邀请拉新服务节点函数

local MainStorage = game:GetService("MainStorage")
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg

---@class MiniApiFriendsService
local MiniApiFriendsService = {}

-- 获取好友邀请服务实例
local friendInviteService = game:GetService("FriendInviteService")

--- 获取好友列表
--- @param nUin number 用户UIN
--- @param func function 回调函数
function MiniApiFriendsService.GetFriendList(nUin, func)
    if not nUin or nUin == 0 then
        gg.log("错误：获取好友列表时UIN为空或0")
        if func then func({}) end
        return
    end
    
    if not func then
        gg.log("错误：获取好友列表时回调函数为空")
        return
    end
    
    gg.log("请求获取好友列表（FriendsService），UIN: " .. tostring(nUin))
    local friendsService = game:GetService("FriendsService")
    friendsService:QueryFriendInfoWithCallback(function(ok)
        if not ok then
            gg.log("错误：FriendsService 查询好友信息失败")
            func({})
            return
        end
        local friendsNum = tonumber(friendsService:GetSize()) or 0
        local list = {}
        for i = 0, friendsNum - 1, 1 do
            local uin, nickName, onLine = friendsService:GetFriendsInfoByIndex(i)
            local item = {
                uin = uin,
                nickName = nickName ,
                onLine = onLine
            }
            list[#list + 1] = item
        end
        func(list)
    end)
end

--- 新玩家判断
--- @param nUin number 用户UIN
--- @param nMapID longlong 地图ID
--- @param func function 回调函数
function MiniApiFriendsService.IsNewToThisMap(nUin, nMapID, func)
    if not nUin or nUin == 0 then
        gg.log("错误：判断新玩家时UIN为空或0")
        if func then func(false) end
        return
    end
    
    if not nMapID then
        gg.log("错误：判断新玩家时地图ID为空")
        if func then func(false) end
        return
    end
    
    if not func then
        gg.log("错误：判断新玩家时回调函数为空")
        return
    end
    
    gg.log("判断新玩家，UIN: " .. tostring(nUin) .. ", 地图ID: " .. tostring(nMapID))
    friendInviteService:IsNewToThisMap(nUin, nMapID, func)
end

--- 邀请者设置
--- @param nUin1 number 邀请者UIN
--- @param nUin2 number 被邀请者UIN
--- @param nMapID longlong 地图ID
function MiniApiFriendsService.SetInvitePlayer(nUin1, nUin2, nMapID)
    if not nUin1 or nUin1 == 0 then
        gg.log("错误：设置邀请者时邀请者UIN为空或0")
        return
    end
    
    if not nUin2 or nUin2 == 0 then
        gg.log("错误：设置邀请者时被邀请者UIN为空或0")
        return
    end
    
    if not nMapID then
        gg.log("错误：设置邀请者时地图ID为空")
        return
    end
    
    gg.log("设置邀请关系，邀请者UIN: " .. tostring(nUin1) .. 
           ", 被邀请者UIN: " .. tostring(nUin2) .. 
           ", 地图ID: " .. tostring(nMapID))
    friendInviteService:SetInvitePlayer(nUin1, nUin2, nMapID)
end

--- 邀请者查询
--- @param nUin1 number 用户UIN
--- @param nMapID longlong 地图ID
--- @param func function 回调函数
function MiniApiFriendsService.GetInvitePlayer(nUin1, nMapID, func)
    if not nUin1 or nUin1 == 0 then
        gg.log("错误：查询邀请者时UIN为空或0")
        if func then func(nil) end
        return
    end
    
    if not nMapID then
        gg.log("错误：查询邀请者时地图ID为空")
        if func then func(nil) end
        return
    end
    
    if not func then
        gg.log("错误：查询邀请者时回调函数为空")
        return
    end
    
    gg.log("查询邀请者，UIN: " .. tostring(nUin1) .. ", 地图ID: " .. tostring(nMapID))
    friendInviteService:GetInvitePlayer(nUin1, nMapID, func)
end

--- 被邀请者设置
--- @param nUin number 用户UIN
--- @param nMapID longlong 地图ID
--- @param userData table 用户数据
--- @param nCount number 数量
function MiniApiFriendsService.SetInvitedPlayerList(nUin, nMapID, userData, nCount)
    if not nUin or nUin == 0 then
        gg.log("错误：设置被邀请者列表时UIN为空或0")
        return
    end
    
    if not nMapID then
        gg.log("错误：设置被邀请者列表时地图ID为空")
        return
    end
    
    if not userData then
        gg.log("错误：设置被邀请者列表时用户数据为空")
        return
    end
    
    -- 保障底层最少4参：未传入时用表长度兜底
    local count = nCount
    if count == nil then
        if type(userData) == "table" then
            count = #userData
        else
            count = 0
        end
    end
    
    gg.log("设置被邀请者列表，UIN: " .. tostring(nUin) .. 
           ", 地图ID: " .. tostring(nMapID) .. 
           ", 数量: " .. tostring(count))
    friendInviteService:SetInvitedPlayerList(nUin, nMapID, userData, count)
end

--- 被邀请者查询
--- @param nUin number 用户UIN
--- @param nMapID longlong 地图ID
--- @param func function 回调函数
function MiniApiFriendsService.GetInvitedPlayerList(nUin, nMapID, func)
    if not nUin or nUin == 0 then
        gg.log("错误：查询被邀请者列表时UIN为空或0")
        if func then func({}) end
        return
    end
    
    if not nMapID then
        gg.log("错误：查询被邀请者列表时地图ID为空")
        if func then func({}) end
        return
    end
    
    if not func then
        gg.log("错误：查询被邀请者列表时回调函数为空")
        return
    end
    
    gg.log("查询被邀请者列表，UIN: " .. tostring(nUin) .. ", 地图ID: " .. tostring(nMapID))
    friendInviteService:GetInvitedPlayerList(nUin, nMapID, func)
end

--- 好友跟随
--- @param nUin1 number 跟随者UIN
--- @param nUin2 number 被跟随者UIN
function MiniApiFriendsService.FriendFollow(nUin1, nUin2)
    if not nUin1 or nUin1 == 0 then
        gg.log("错误：好友跟随时跟随者UIN为空或0")
        return
    end
    
    if not nUin2 or nUin2 == 0 then
        gg.log("错误：好友跟随时被跟随者UIN为空或0")
        return
    end
    
    gg.log("好友跟随，跟随者UIN: " .. tostring(nUin1) .. ", 被跟随者UIN: " .. tostring(nUin2))
    friendInviteService:FriendFollow(nUin1, nUin2)
end

--- 打开邀请列表（客机操作）
function MiniApiFriendsService.OpenInviterList()
    gg.log("打开邀请列表（客机操作）")
    friendInviteService:OpenInviterList()
end

return MiniApiFriendsService