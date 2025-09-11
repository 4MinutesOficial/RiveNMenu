local frozenTable = table.freeze({
    "Variables", "Functions", "Core", "Remote", "UI", "Process", "Anti"
})
local globalEnv = _G
local gameService = game
local scriptInstance = script
local getFuncEnv = getfenv
local setFuncEnv = setfenv
local workspaceService = workspace
local getMeta = getmetatable
local setMeta = setmetatable
local loadStr = loadstring
local coroutineLib = coroutine
local rawEqual = rawequal
local typeOf = typeof
local printFunc = print
local mathLib = math
local warnFunc = warn
local errorFunc = error
local pcallFunc = pcall
local xpcallFunc = xpcall
local selectFunc = select
local rawSet = rawset
local rawGet = rawget
local ipairsFunc = ipairs
local pairsFunc = pairs
local nextFunc = next
local rectClass = Rect
local axesClass = Axes
local osLib = os
local timeFunc = time
local facesClass = Faces
local unpackTable = table.unpack
local stringLib = string
local color3Class = Color3
local newProxy = newproxy
local toString = tostring
local toNumber = tonumber
local instanceClass = Instance
local tweenInfoClass = TweenInfo
local brickColorClass = BrickColor
local numberRangeClass = NumberRange
local colorSequenceClass = ColorSequence
local numberSequenceClass = NumberSequence
local colorSequenceKeypointClass = ColorSequenceKeypoint
local numberSequenceKeypointClass = NumberSequenceKeypoint
local physicalPropertiesClass = PhysicalProperties
local region3int16Class = Region3int16
local vector3int16Class = Vector3int16
local requireFunc = require
local tableLib = table
local typeFunc = type
local waitTask = task.wait
local enumClass = Enum
local udimClass = UDim
local udim2Class = UDim2
local vector2Class = Vector2
local vector3Class = Vector3
local region3Class = Region3
local cframeClass = CFrame
local rayClass = Ray
local delayTask = task.delay
local deferTask = task.defer
local taskLib = task
local tickFunc = tick

local function assertOrError(value, message)
    return value or error(message or "assertion failed!", 2)
end

local frozenServices = tableLib.freeze({
    "Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst",
    "ScriptContext", "JointsService", "LogService", "Teams", "SoundService",
    "StarterGui", "StarterPack", "StarterPlayer", "GroupService",
    "MarketplaceService", "HttpService", "TestService", "RunService", "NetworkClient"
})

local function logAdonis(...)
    printFunc(":: Adonis ::", ...)
end

local function warnAdonis(...)
    warnFunc(":: Adonis ::", ...)
end

local logTable = {}

local function dumpLogs()
    logAdonis("Dumping client log...")
    for _, log in logTable do
        logAdonis(log)
    end
end

local function appendLog(...)
    tableLib.insert(logTable, tableLib.concat({ ... }, " "))
end

local parentFolder = scriptInstance.Parent
local isStudio = gameService:GetService("RunService"):IsStudio()

gameService:GetService("NetworkClient").ChildRemoved:Connect(function()
    if not isStudio or parentFolder:FindFirstChild("ADONIS_DEBUGMODE_ENABLED") then
        logAdonis("~! PLAYER DISCONNECTED/KICKED! DUMPING ADONIS CLIENT LOG!")
        dumpLogs()
    end
end)

local protectedMeta = {}
local origEnv = getFuncEnv()
setFuncEnv(1, setMeta({}, { __metatable = protectedMeta }))
timeFunc()

local newInstance = instanceClass.new
local origRequire = requireFunc
local envTable = {}
local clientTable = {}
local serviceTable = {}
local serviceCache = {}

local function isModuleApproved(module)
    for _, approved in clientTable.Modules do
        if rawEqual(module, approved) then
            return true
        end
    end
    return false
end

local function logError(...)
    warnAdonis("ERROR: ", ...)
    tableLib.insert(logTable, tableLib.concat({ "ERROR:", ... }, " "))
    if clientTable and clientTable.Remote then
        clientTable.Remote.Send("LogError", tableLib.concat({ ... }, " "))
    end
end

local function safePcall(func, ...)
    local success, result = pcallFunc(func, ...)
    if not success and result then
        logError(toString(result))
    end
    return success, result
end

local function safeCoroutine(func, ...)
    return coroutineLib.resume(coroutineLib.create(func), ...)
end

local killRoutine = (function(...)
    local routine = coroutineLib.wrap(function(...)
        while true do
            coroutineLib.yield(...)
        end
    end)
    routine(...)
    return routine
end)(function(reason)
    deferTask(safePcall, function() end)
    deferTask(safePcall, function()
        taskLib.wait(1)
        serviceTable.Player:Kick(reason)
    end)
    if not isStudio then
        deferTask(safePcall, function()
            taskLib.wait(5)
            if clientTable.Core and clientTable.Core.RemoteEvent then
                deferTask(safePcall, tableLib.clear, clientTable.Core.RemoteEvent)
                deferTask(safePcall, tableLib.freeze, clientTable.Core.RemoteEvent)
                clientTable.Core.RemoteEvent = nil
            end
            deferTask(safePcall, tableLib.clear, envTable)
            deferTask(safePcall, tableLib.freeze, envTable)
            clientTable = nil
            envTable = nil
            while true do end
        end)
    end
end)

local function createEnv(original, extra)
    local newEnv = {}
    local meta = {
        __index = function(_, key)
            return envTable[key] or (original or origEnv)[key]
        end,
        __metatable = parentFolder:FindFirstChild("ADONIS_DEBUGMODE_ENABLED") and nil or protectedMeta
    }
    local env = setMeta(newEnv, meta)
    if extra and typeFunc(extra) == "table" then
        for key, value in extra do
            env[key] = value
        end
    end
    return env
end

local function getClientService()
    return { Client = clientTable, Service = serviceTable }
end

local function loadModule(module, isCore, envExtra, noEnv)
    local isString = typeFunc(module) == "string"
    local isStringValue = not isString and module:IsA("StringValue")
    local success, result
    if isString then
        success, result = safePcall(assertOrError(
            assertOrError(clientTable.Core.Loadstring, "Cannot compile plugin due to Core.Loadstring missing")
            (module, createEnv(nil, envExtra)), "Failed to compile module"))
    elseif isStringValue then
        success, result = safePcall(clientTable.Core.LoadCode or function(...)
            return origRequire(clientTable.Shared.FiOne, true)(...)
        end, clientTable.Functions.Base64Decode(module.Value), createEnv(nil, envExtra))
    else
        success, result = safePcall(origRequire, module)
    end
    if success then
        if typeFunc(result) == "function" then
            local env = noEnv and result or setFuncEnv(result, createEnv(getFuncEnv(result), envExtra))
            local taskName = isCore and ("Plugin: %s"):format(module) or ("Thread: Plugin: %s"):format(module)
            serviceTable.TrackTask(taskName, env, function(err)
                warnAdonis(("Module encountered an error while loading: %s\n%s\n%s"):format(module, err, debug.traceback()))
            end, getClientService(), createEnv)
        else
            clientTable[module.Name] = result
        end
    else
        warnAdonis("Error while loading client module", module, result)
    end
end

appendLog("Client setmetatable")
clientTable = setMeta({
    Handlers = {},
    Modules = {},
    Service = serviceTable,
    Module = scriptInstance,
    Print = logAdonis,
    Warn = warnAdonis,
    Deps = {},
    Pcall = safePcall,
    Routine = safeCoroutine,
    OldPrint = printFunc,
    LogError = logError,
    Disconnect = function(reason)
        serviceTable.Player:Kick(reason or "Disconnected from server")
    end
}, {
    __index = function(_, key)
        if key == "Kill" then
            local success, func = safePcall(function()
                return killRoutine()
            end)
            if success and typeFunc(func) == "function" then
                return func
            end
            serviceTable.Players.LocalPlayer:Kick("1x00353 Adonis (PlrClientIndexKlErr)")
            warnAdonis("Failed to retrieve Kill function")
            return function() end
        end
    end
})

envTable = {
    Pcall = safePcall,
    GetEnv = createEnv,
    client = clientTable,
    Folder = parentFolder,
    Routine = safeCoroutine,
    service = serviceTable,
    logError = logError,
    origEnv = origEnv,
    log = appendLog,
    dumplog = dumpLogs
}

appendLog("Create service metatable")
local clientWrapper = { client = clientTable }
serviceTable = origRequire(parentFolder.Parent.Shared.Service)(
    function(event, err, ...)
        if event == "MethodError" then
            logError("Client", ("Method Error Occurred: %s"):format(err))
        elseif event == "ServerError" then
            logError("Client", toString(err))
        elseif event == "ReadError" then
            killRoutine()(toString(err))
        end
    end,
    function(module, _, unhook)
        if not isModuleApproved(module) and module ~= scriptInstance and module ~= parentFolder then
            unhook.UnHook()
        end
    end,
    serviceCache,
    createEnv(nil, clientWrapper)
)

appendLog("Localize")
local localize = serviceTable.Localize
local osLocalized = localize(osLib)
local mathLocalized = localize(mathLib)
tableLib = localize(tableLib)
local stringLocalized = localize(stringLib)
coroutineLib = localize(coroutineLib)
localize(instanceClass)
local vector2Localized = localize(vector2Class)
local vector3Localized = localize(vector3Class)
local cframeLocalized = localize(cframeClass)
local udim2Localized = localize(udim2Class)
local enumLocalized = localize(enumClass)
local rayLocalized = localize(rayClass)
local rectLocalized = localize(rectClass)
local facesLocalized = localize(facesClass)
local color3Localized = localize(color3Class)
local numberRangeLocalized = localize(numberRangeClass)
local numberSequenceLocalized = localize(numberSequenceClass)
local numberSequenceKeypointLocalized = localize(numberSequenceKeypointClass)
local colorSequenceKeypointLocalized = localize(colorSequenceKeypointClass)
local physicalPropertiesLocalized = localize(physicalPropertiesClass)
local colorSequenceLocalized = localize(colorSequenceClass)
local region3int16Localized = localize(region3int16Class)
local vector3int16Localized = localize(vector3int16Class)
local brickColorLocalized = localize(brickColorClass)
local tweenInfoLocalized = localize(tweenInfoClass)
local axesLocalized = localize(axesClass)
taskLib = localize(taskLib)

appendLog("Wrap")
local wrapService = serviceTable.Wrap
local unwrapService = serviceTable.UnWrap
local envWrapper = envTable
local folderWrapper = parentFolder
local scriptWrapper = scriptInstance
local logWrapper = logAdonis
local taskWrapper = taskLib
local warnWrapper = warnAdonis
local coroutineWrapper = coroutineLib
local clientWrapperTable = clientTable
local tableWrapper = tableLib
local serviceWrapper = serviceTable

for key, value in serviceTable do
    if typeFunc(value) == "userdata" then
        serviceWrapper[key] = wrapService(value, true)
    end
end

parentFolder = wrapService(folderWrapper, true)
local enumWrapped = wrapService(enumClass, true)
rawEqual = serviceWrapper.RawEqual
scriptInstance = wrapService(scriptWrapper, true)
local gameWrapped = wrapService(gameService, true)
local workspaceWrapped = wrapService(workspaceService, true)

requireFunc = function(module, raw)
    return raw and origRequire(unwrapService(module)) or wrapService(origRequire(unwrapService(module)), true)
end

clientWrapperTable.Service = serviceWrapper
clientWrapperTable.Module = wrapService(clientWrapperTable.Module, true)

appendLog("Setting things up")
local origScript = scriptInstance
local origFolder = parentFolder

for key, value in {
    _G = globalEnv,
    game = gameWrapped,
    spawn = deferTask,
    script = scriptInstance,
    getfenv = getFuncEnv,
    setfenv = setFuncEnv,
    workspace = workspaceWrapped,
    getmetatable = getMeta,
    setmetatable = setMeta,
    loadstring = loadStr,
    coroutine = coroutineWrapper,
    rawequal = rawEqual,
    typeof = typeOf,
    print = logWrapper,
    math = mathLocalized,
    warn = warnWrapper,
    error = errorFunc,
    assert = assertOrError,
    pcall = pcallFunc,
    xpcall = xpcallFunc,
    select = selectFunc,
    rawset = rawSet,
    rawget = rawGet,
    ipairs = ipairsFunc,
    pairs = pairsFunc,
    next = nextFunc,
    Rect = rectLocalized,
    Axes = axesLocalized,
    os = osLocalized,
    time = timeFunc,
    Faces = facesLocalized,
    delay = delayTask,
    unpack = unpackTable,
    string = stringLocalized,
    Color3 = color3Localized,
    newproxy = newProxy,
    tostring = toString,
    tonumber = toNumber,
    Instance = {
        new = function(class, parent)
            return wrapService(newInstance(class, unwrapService(parent)), true)
        end
    },
    TweenInfo = tweenInfoLocalized,
    BrickColor = brickColorLocalized,
    NumberRange = numberRangeLocalized,
    ColorSequence = colorSequenceLocalized,
    NumberSequence = numberSequenceLocalized,
    ColorSequenceKeypoint = colorSequenceKeypointLocalized,
    NumberSequenceKeypoint = numberSequenceKeypointLocalized,
    PhysicalProperties = physicalPropertiesLocalized,
    Region3int16 = region3int16Localized,
    Vector3int16 = vector3int16Localized,
    require = requireFunc,
    table = tableWrapper,
    type = typeFunc,
    wait = waitTask,
    Enum = enumWrapped,
    UDim = udimClass,
    UDim2 = udim2Localized,
    Vector2 = vector2Localized,
    Vector3 = vector3Localized,
    Region3 = region3Class,
    CFrame = cframeLocalized,
    Ray = rayLocalized,
    task = taskWrapper,
    tick = tickFunc,
    service = serviceWrapper
} do
    envWrapper[key] = value
end

appendLog("Return init function")
return serviceWrapper.NewProxy({
    __call = function(_, data)
        appendLog("Begin init")
        local remoteName, depsName = stringLocalized.match(data.Name, "(.*)\\(.*)")
        parentFolder = serviceWrapper.Wrap(data.Folder or origFolder)
        data.DebugMode = parentFolder:FindFirstChild("ADONIS_DEBUGMODE_ENABLED") and true or false

        appendLog("Adding ACLI logs to the client logs")
        if data.acliLogs then
            for _, log in data.acliLogs do
                appendLog(log)
            end
        end

        appendLog("Clearing environment")
        setFuncEnv(1, setMeta({}, { __metatable = protectedMeta }))

        appendLog("Loading necessary client values")
        clientWrapperTable.Folder = parentFolder
        clientWrapperTable.UIFolder = parentFolder:WaitForChild("UI", 9000000000)
        clientWrapperTable.Shared = parentFolder.Parent:WaitForChild("Shared", 9000000000)
        clientWrapperTable.Loader = data.Loader
        clientWrapperTable.Module = data.Module
        clientWrapperTable.DepsName = depsName
        clientWrapperTable.TrueStart = data.Start
        clientWrapperTable.LoadingTime = data.LoadingTime
        clientWrapperTable.RemoteName = remoteName
        clientWrapperTable.DebugMode = data.DebugMode
        clientWrapperTable.Typechecker = origRequire(unwrapService(clientWrapperTable.Shared.Typechecker))
        clientWrapperTable.Changelog = origRequire(unwrapService(clientWrapperTable.Shared.Changelog))
        clientWrapperTable.FormattedChangelog = tableWrapper.create(#clientWrapperTable.Changelog)

        local function formatChangelog(line)
            local prefix = line:sub(1, 2)
            if prefix == "[v" or prefix == "[1" or prefix == "[0" or prefix == "1." or line:sub(1, 1) == "v" then
                return ("<font color='#8FAEFF'>%s</font>"):format(line)
            elseif line:sub(1, 6) == "[Patch" then
                return ("<font color='#F0B654'>%s</font>"):format(line)
            elseif line:sub(1, 9) == "Version: " then
                return ("<b>%s</b>"):format(line)
            elseif line:sub(1, 2) == "# " then
                return ("<b>%s</b>"):format(stringLocalized.sub(line, 3))
            else
                return line
            end
        end

        appendLog("Formatting changelog")
        for i, line in ipairsFunc(clientWrapperTable.Changelog) do
            clientWrapperTable.FormattedChangelog[i] = formatChangelog(line)
        end

        appendLog("Setting up material icons")
        local matIconsRaw = origRequire(unwrapService(clientWrapperTable.Shared.MatIcons))
        clientWrapperTable.MatIcons = setMeta({}, {
            __index = function(t, key)
                local id = matIconsRaw[key]
                if id then
                    t[key] = ("rbxassetid://%s"):format(id)
                    return t[key]
                end
            end,
            __metatable = data.DebugMode and protectedMeta or "Adonis"
        })

        appendLog("Get dependencies")
        for _, dep in parentFolder:WaitForChild("Dependencies", 9000000000):GetChildren() do
            clientWrapperTable.Deps[dep.Name] = dep
        end

        appendLog("Destroy script object")
        origScript.Parent = nil

        appendLog("Initial services caching")
        for _, service in frozenServices do
            local _ = serviceWrapper[service]
        end

        appendLog("Add service specific")
        serviceCache.Player = serviceWrapper.Players.LocalPlayer or (function()
            serviceWrapper.Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
            return serviceWrapper.Players.LocalPlayer
        end)()
        serviceCache.PlayerGui = serviceCache.Player:FindFirstChildWhichIsA("PlayerGui")
        if not serviceCache.PlayerGui then
            safeCoroutine(function()
                local gui = serviceCache.Player:WaitForChild("PlayerGui", 120)
                if gui then
                    serviceCache.PlayerGui = gui
                else
                    logError("PlayerGui unable to be fetched? [Waited 120 Seconds]")
                end
            end)
        end

        function serviceCache.Filter(value, from, to)
            return clientWrapperTable.Remote.Get("Filter", value, to and from or serviceWrapper.Player, to or from)
        end

        function serviceCache.LaxFilter(value, player)
            return serviceWrapper.Filter(value, player or serviceWrapper.Player, player or serviceWrapper.Player)
        end

        function serviceCache.BroadcastFilter(value, player)
            return clientWrapperTable.Remote.Get("BroadcastFilter", value, player or serviceWrapper.Player)
        end

        function serviceCache.IsMobile()
            return serviceWrapper.UserInputService.TouchEnabled and not serviceWrapper.UserInputService.MouseEnabled and not serviceWrapper.UserInputService.KeyboardEnabled
        end

        function serviceCache.LocalContainer()
            local vars = clientWrapperTable.Variables
            if not (vars.LocalContainer and vars.LocalContainer.Parent) then
                vars.LocalContainer = serviceWrapper.New("Folder", {
                    Parent = workspaceWrapped,
                    Archivable = false,
                    Name = ("__ADONIS_LOCALCONTAINER_%s"):format(serviceWrapper.HttpService:GenerateGUID(false))
                })
            end
            return vars.LocalContainer
        end

        serviceCache.IncognitoPlayers = {}

        appendLog("Loading core modules")
        for _, moduleName in frozenTable do
            local module = parentFolder.Core:FindFirstChild(moduleName)
            if module then
                appendLog(("~! Loading Core Module: %s"):format(moduleName))
                loadModule(module, true, { script = origScript }, true)
            end
        end

        local runAfterLoaded = {}
        local runLast = {}

        function clientWrapperTable.Finish_Loading()
            appendLog("Client fired finished loading")
            if clientWrapperTable.Core.Key then
                appendLog("~! Doing run after loaded")
                for _, func in runAfterLoaded do
                    safePcall(func, data)
                end
                appendLog("~! Doing run last")
                for _, func in runLast do
                    safePcall(func, data)
                end
                appendLog("Finish loading")
                clientWrapperTable.Finish_Loading = function() end
                clientWrapperTable.LoadingTime()
                serviceWrapper.Events.FinishedLoading:Fire(osLocalized.time())
                appendLog("~! FINISHED LOADING!")
            else
                appendLog("Client missing remote key")
                clientWrapperTable.Kill()("Missing remote key")
            end
        end

        appendLog("~! Init cores")
        local runAfterInit = {}
        local runAfterPlugins = {}
        for _, moduleName in frozenTable do
            local module = clientWrapperTable[moduleName]
            appendLog(("~! INIT: %s"):format(moduleName))
            if module and (typeFunc(module) == "table" or typeFunc(module) == "userdata" and getMeta(module) == "ReadOnly_Table") then
                if module.RunLast then
                    tableWrapper.insert(runLast, module.RunLast)
                    module.RunLast = nil
                end
                if module.RunAfterInit then
                    tableWrapper.insert(runAfterInit, module.RunAfterInit)
                    module.RunAfterInit = nil
                end
                if module.RunAfterPlugins then
                    tableWrapper.insert(runAfterPlugins, module.RunAfterPlugins)
                    module.RunAfterPlugins = nil
                end
                if module.RunAfterLoaded then
                    tableWrapper.insert(runAfterLoaded, module.RunAfterLoaded)
                    module.RunAfterLoaded = nil
                end
                if module.Init then
                    appendLog(("Run init for %s"):format(moduleName))
                    safePcall(module.Init, data)
                    module.Init = nil
                end
            end
        end

        appendLog("~! Running after init")
        for _, func in runAfterInit do
            safePcall(func, data)
        end

        appendLog("~! Running plugins")
        for _, plugin in parentFolder.Plugins:GetChildren() do
            if plugin.Name ~= "README" then
                taskWrapper.defer(loadModule, plugin, false, { script = plugin, cPcall = clientWrapperTable.cPcall })
            end
        end

        appendLog("~! Running after plugins")
        for _, func in runAfterPlugins do
            safePcall(func, data)
        end

        appendLog("Initial loading complete")
        clientWrapperTable.AllModulesLoaded = true
        serviceWrapper.Events.AllModulesLoaded:Fire(osLocalized.time())
        serviceWrapper.Events.ClientInitialized:Fire()
        appendLog("~! Return success")
        return "SUCCESS"
    end,
    __metatable = parentFolder:FindFirstChild("ADONIS_DEBUGMODE_ENABLED") and protectedMeta or "Adonis",
    __tostring = function()
        return "Adonis"
    end
})
