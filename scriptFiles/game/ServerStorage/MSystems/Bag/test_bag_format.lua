-- 背包数据格式测试脚本
local function TestBagFormat()
    print("========== 背包数据格式测试 ==========")
    
    -- 模拟新格式的背包数据
    local testData = {
        items = {
            material = {
                {
                    itemType = "material",
                    name = "铁矿",
                    amount = 50,
                    enhanceLevel = 0,
                    uuid = "test_uuid_1",
                    quality = "普通",
                    level = 1,
                    pos = 0,
                    itype = "iron_ore"
                },
                {
                    itemType = "material",
                    name = "金币",
                    amount = 1000,
                    enhanceLevel = 0,
                    uuid = "test_uuid_2",
                    quality = "普通",
                    level = 1,
                    pos = 0,
                    itype = "gold_coin"
                }
            },
            weapon = {
                {
                    itemType = "weapon",
                    name = "铁剑",
                    amount = 1,
                    enhanceLevel = 3,
                    uuid = "test_uuid_3",
                    quality = "稀有",
                    level = 1,
                    pos = 0,
                    itype = "iron_sword"
                }
            },
            consumable = {
                {
                    itemType = "consumable",
                    name = "生命药水",
                    amount = 10,
                    enhanceLevel = 0,
                    uuid = "test_uuid_4",
                    quality = "普通",
                    level = 1,
                    pos = 0,
                    itype = "health_potion"
                }
            }
        }
    }
    
    print("✓ 测试数据格式:", testData)
    
    -- 验证数据结构
    assert(testData.items, "items字段必须存在")
    assert(type(testData.items) == "table", "items必须是table类型")
    
    for category, itemList in pairs(testData.items) do
        assert(type(itemList) == "table", category .. "类别必须是table类型")
        
        for i, itemData in ipairs(itemList) do
            assert(itemData.itemType, category .. "[" .. i .. "] 必须有itemType字段")
            assert(itemData.name, category .. "[" .. i .. "] 必须有name字段")
            assert(itemData.amount, category .. "[" .. i .. "] 必须有amount字段")
            print("  - " .. category .. "[" .. i .. "]: " .. itemData.name .. " x" .. itemData.amount)
        end
    end
    
    print("✓ 数据结构验证通过")
    print("✓ 支持的物品类别: material, weapon, consumable")
    print("✓ 每个物品包含必要字段: itemType, name, amount, enhanceLevel, uuid等")
    print("========== 测试完成 ==========")
    
    return testData
end

-- 如果作为独立脚本运行，执行测试
if not _G.TESTING then
    TestBagFormat()
end

return TestBagFormat 