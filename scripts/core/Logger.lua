local Constants = require("core.Constants")

local Logger = {
    enabled = Constants.DEBUG_ENABLED,
}

function Logger.SetEnabled(enabled)
    Logger.enabled = enabled == true
end

function Logger.Info(scope, message)
    if Logger.enabled then
        print(string.format("[%s] %s", scope, message))
    end
end

function Logger.Error(scope, message)
    print(string.format("[%s][ERROR] %s", scope, message))
end

return Logger
