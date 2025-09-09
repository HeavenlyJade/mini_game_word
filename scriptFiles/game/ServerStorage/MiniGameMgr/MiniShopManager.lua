
local store = game:GetService("DeveloperStoreService")
local MainStorage = game:GetService("MainStorage")
local ServerStorage = game:GetService("ServerStorage")
local ClassMgr = require(MainStorage.Code.Untils.ClassMgr) ---@type ClassMgr
local gg = require(MainStorage.Code.Untils.MGlobal) ---@type gg
local MS = require(MainStorage.Code.Untils.MS) ---@type MS

---@class MiniShopManager : Class
local MiniShopManager = ClassMgr.Class("MiniShopManager")

-- 商店商品映射表：迷你商品ID -> 游戏内商品对象
MiniShopManager.miniId2ShopGood = {}

-- 错误码映射表
MiniShopManager.ErrorCodes = {
    [0] = "购买成功",
    [1001] = "地图未上传",
    [1002] = "用户取消购买", 
    [1003] = "商品查询失败",
    [1004] = "请求失败",
    [1005] = "迷你币不足",
    [710] = "商品不存在",
    [711] = "商品状态异常",
    [712] = "不能购买自己的商品",
    [713] = "已购买该商品，不能重复购买",
    [714] = "购买失败，购买数量已达上限"
}

function MiniShopManager:OnInit()
    -- 注册购买回调事件
    self:RegisterPurchaseCallback()
    --gg.log("MiniShopManager 初始化完成")
    return self
end

-- 注册购买回调事件
function MiniShopManager:RegisterPurchaseCallback()
    store.RemoteBuyGoodsCallBack:Connect(function(uin, goodsid, code, msg, num)
        self:OnPurchaseCallback(uin, goodsid, code, msg, num)
    end)
end

-- 处理购买回调
function MiniShopManager:OnPurchaseCallback(uin, goodsid, code, msg, num)
    gg.log("迷你商品兑回调:", code, "错误信息:", msg, "购买数量:", num,uin,goodsid)
    if code ~= 0 then
        local errorMsg = self.ErrorCodes[code] or "未知错误"
        gg.log("迷你商品兑换失败！错误码:", code, "错误信息:", errorMsg, "原始消息:", msg, "购买数量:", num,uin,goodsid)
        gg.log("错误详情 - UIN:", uin, "商品ID:", goodsid, "购买数量:", num)
        return
    end
    
    -- 使用 ConfigLoader 检查迷你币商品映射
    local ConfigLoader = require(game:GetService("MainStorage").Code.Common.ConfigLoader) ---@type ConfigLoader
    if not ConfigLoader.HasMiniShopItem(goodsid) then
        gg.log("迷你商品兑换失败！未配置于Unity的商品ID:", goodsid)
        return
    end
    
    local MServerDataManager = require(ServerStorage.Manager.MServerDataManager) ---@type MServerDataManager
    local player = MServerDataManager.getPlayerByUin(uin)
    if not player then
        gg.log("迷你商品兑换失败！不存在的玩家UIN:", uin)
        return
    end
    
    -- code=0 购买成功
    gg.log("迷你商品购买成功！")
    gg.log("RemoteBuyGoodsCallBack - uin:", uin)
    gg.log("RemoteBuyGoodsCallBack - goodsid:", goodsid) 
    gg.log("RemoteBuyGoodsCallBack - num:", num)
    gg.log("玩家信息:", player.name)
    
    -- 购买成功，转交商城系统发奖与记录
    local ShopMgr = require(game:GetService("ServerStorage").MSystems.Shop.ShopMgr) ---@type ShopMgr
    ShopMgr.HandleMiniPurchaseCallback(uin, goodsid, num)
end

-- 注册商品到商店系统
function MiniShopManager:RegisterGoods(miniId, shopGood)
    if not miniId or not shopGood then
        --gg.log("注册商品失败：参数无效")
        return false
    end
    
    if self.miniId2ShopGood[miniId] then
        --gg.log(string.format("商品ID %d 已存在，将被覆盖", miniId))
    end
    
    self.miniId2ShopGood[miniId] = shopGood
    --gg.log(string.format("成功注册商品，迷你ID: %d", miniId))
    return true
end

-- 按需注册商城配置到回调映射（可由外部调用）
function MiniShopManager:RegisterShopItemByConfig(shopItem)
    if not shopItem or not shopItem.specialProperties then return false end
    local miniId = shopItem.specialProperties.miniItemId
    if not miniId or miniId <= 0 then return false end
    self.miniId2ShopGood[miniId] = { __fromShopConfig = true, configName = shopItem.configName }
    return true
end

-- 获取商品信息
function MiniShopManager:GetGoodsInfo(miniId)
    if not self.miniId2ShopGood[miniId] then
        return nil
    end
    return self.miniId2ShopGood[miniId]
end

-- 检查商品是否存在
function MiniShopManager:HasGoods(miniId)
    return self.miniId2ShopGood[miniId] ~= nil
end

-- 获取所有已注册商品
function MiniShopManager:GetAllGoods()
    local goods = {}
    for miniId, shopGood in pairs(self.miniId2ShopGood) do
        table.insert(goods, {
            miniId = miniId,
            shopGood = shopGood
        })
    end
    return goods
end

-- 获取商店商品数量
function MiniShopManager:GetGoodsCount()
    local count = 0
    for _ in pairs(self.miniId2ShopGood) do
        count = count + 1
    end
    return count
end

-- 清空所有商品
function MiniShopManager:ClearAllGoods()
    self.miniId2ShopGood = {}
    --gg.log("已清空所有商店商品")
end

-- 获取某个玩家已购买的商品列表（云服版本）
function MiniShopManager:GetPlayerPurchasedList(playerid)
    if not playerid then
        gg.log("获取玩家购买列表失败：玩家ID无效")
        return {}
    end
    
    local buyList = store:ServiceGetPlayerDeveloperProducts(playerid)
    gg.log(string.format("云服商店购买列表 = %s", tostring(buyList)))
    
    if not buyList then
        return {}
    end
    
    -- 处理购买列表数据
    local processedList = {}
    local count = 0
    
    -- 遍历购买列表，处理每个商品信息
    for _, value in pairs(buyList) do
        if type(value) == "table" then
            count = count + 1
            local buyItem = {}
            for key, info in pairs(value) do
                buyItem[key] = info
            end
            table.insert(processedList, buyItem)
        end
    end
    
    gg.log(string.format("处理后的购买列表，商品数量: %d", count))
    return processedList
end

function MiniShopManager:GetStoreList()
    local storeList = store:GetDeveloperStoreItems()

    if not storeList then
        return {}
    end
    
    -- 处理商店列表数据
    local processedList = {}
    local count = 0
    
    for _, value in pairs(storeList) do
        if type(value) == "table" then
            count = count + 1
            local storeItem = {}
            for key, info in pairs(value) do
                storeItem[key] = info
            end
            table.insert(processedList, storeItem)
        end
    end
    
    gg.log(string.format("处理后的商店列表，商品数量: %d", count))
    return processedList
end

-- 获取指定商品的详细信息
function MiniShopManager:GetProductInfo(productid)
    if not productid then
        return nil
    end
    
    local goodsInfo = store:GetProductInfo(productid)
    gg.log("获取商品信息", productid, goodsInfo)
    if not goodsInfo then
        return nil
    end
    
    return {
        name = goodsInfo.name,
        desc = goodsInfo.desc,
        goodId = goodsInfo.goodId,
        costType = goodsInfo.costType,
        costNum = goodsInfo.costNum,
        download = goodsInfo.download,
        cover = goodsInfo.cover
    }
end

-- 检查玩家是否已购买指定商品
function MiniShopManager:HasPlayerPurchasedGoods(playerid, goodsid)
    local buyList = self:GetPlayerPurchasedList(playerid)
    
    for _, item in ipairs(buyList) do
        if item.goodId == goodsid then
            return true
        end
    end
    
    return false
end

-- 获取玩家购买的商品数量
function MiniShopManager:GetPlayerPurchasedCount(playerid)
    local buyList = self:GetPlayerPurchasedList(playerid)
    return #buyList
end

return MiniShopManager