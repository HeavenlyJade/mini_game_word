--- 通用事件配置（仅定义事件名称，避免过度设计）
---@class CommonEventConfig
local CommonEventConfig = {}

-- 客户端请求事件
CommonEventConfig.REQUEST = {
    TELEPORT_TO = "TELEPORT_TO",   -- 客户端请求传送
}

-- 服务器响应事件（预留，可按需扩展）
CommonEventConfig.RESPONSE = {}

-- 服务器通知事件（预留，可按需扩展）
CommonEventConfig.NOTIFY = {}

return CommonEventConfig


