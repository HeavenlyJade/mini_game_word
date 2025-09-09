

local MiniApiFriendsService = {}

-- 获取好友服务实例
local friendsService = game:GetService("FriendsService")

--- 获取好友数量
--- @return number 好友数量
function MiniApiFriendsService.GetSize()
    return friendsService:GetSize()
end

--- 根据索引获取好友信息
--- @param index number 好友索引
--- @return number, string, boolean 返回好友的uin、昵称、是否在线
function MiniApiFriendsService.GetFriendsInfoByIndex(index)
    return friendsService:GetFriendsInfoByIndex(index)
end

--- 判断某人是否是好友
--- @param playerUin number 玩家UIN
--- @return boolean, string, boolean 是否为好友、昵称、是否在线
function MiniApiFriendsService.IsFriend(playerUin)
    local friendsNum = friendsService:GetSize()
    for i = 0, friendsNum - 1, 1 do
        local uin, nickName, onLine = friendsService:GetFriendsInfoByIndex(i)
        if playerUin == uin then
            return true, nickName, onLine
        end
    end
    return false, "", false
end

--- 获取所有好友信息
--- @return table 好友信息列表，每个元素包含uin、nickName、onLine
function MiniApiFriendsService.GetAllFriends()
    local friendsList = {}
    local friendsNum = friendsService:GetSize()
    
    for i = 0, friendsNum - 1, 1 do
        local uin, nickName, onLine = friendsService:GetFriendsInfoByIndex(i)
        table.insert(friendsList, {
            uin = uin,
            nickName = nickName,
            onLine = onLine
        })
    end
    
    return friendsList
end

--- 获取在线好友数量
--- @return number 在线好友数量
function MiniApiFriendsService.GetOnlineFriendsCount()
    local count = 0
    local friendsNum = friendsService:GetSize()
    
    for i = 0, friendsNum - 1, 1 do
        local uin, nickName, onLine = friendsService:GetFriendsInfoByIndex(i)
        if onLine then
            count = count + 1
        end
    end
    
    return count
end

return MiniApiFriendsService
