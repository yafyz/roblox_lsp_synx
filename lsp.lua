local HttpService = game:GetService("HttpService")
local Toolbar = plugin:CreateToolbar("Roblox LSP")

local ConnectButton = Toolbar:CreateButton("Connect", "Connects to Roblox LSP", "http://www.roblox.com/asset/?id=5968099519")
local SettingsButton = Toolbar:CreateButton("Settings", "Open Settings", "http://www.roblox.com/asset/?id=5342589000")

-- This is just used as a hidden storage
local AnalyticsService = game:GetService("AnalyticsService")

local SettingsModule = AnalyticsService:FindFirstChild("RobloxLSP_Settings")
if not SettingsModule then
    SettingsModule = script.Parent.DefaultSettings:Clone()
    SettingsModule.Name = "RobloxLSP_Settings"
	SettingsModule.Parent = AnalyticsService
end

pcall(function()
	local info = game:GetService("MarketplaceService"):GetProductInfo(5969291145)
	local version = tonumber(info.Description:match("version: (%d+)"))
	if script.Parent.CurrentVersion.Value < version then
		warn("[Roblox LSP] Plugin is outdated! please install the new version.")
	end
end)

local Connected = false
local Settings = nil

local function IsValidName(name)
	return true--name:match("^[%a_][%w_]*$")
end

local function AddChild(child, parent)
	if not IsValidName(child.Name) then
		return
	end
	for _, exclude in pairs(Settings.exclude) do
		if child == exclude then
			return
		end
	end
	parent[child.Name] = {
		className = child.ClassName
	}
	local children = child:GetChildren()
	if #children ~= 0 then
		parent[child.Name].children = {}
		for _, child2 in pairs(children) do
			AddChild(child2, parent[child.Name].children)
		end
	end
end

local LastUpdate = nil
local ShouldUpdate = false

local Services = {
	game:GetService("Workspace"),
	game:GetService("Players"),
	game:GetService("Lighting"),
	game:GetService("ReplicatedFirst"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerScriptService"),
	game:GetService("ServerStorage"),
	game:GetService("StarterGui"),
	game:GetService("StarterPack"),
	game:GetService("StarterPlayer"),
	game:GetService("SoundService"),
	game:GetService("Chat"),
	game:GetService("LocalizationService"),
	game:GetService("TestService")
}

local function Update(force)
    if not Connected or not Settings then
        return
	end
	local start = tick()
    local tree = {children = {}}
	for _, service in pairs(Services) do
		AddChild(service, tree.children)
	end
	--print("tree took", tick() - start)
	start = tick()
    local datamodel = HttpService:JSONEncode(tree)
	--print("json took", tick() - start)
    if not force and datamodel == LastUpdate then
        return
	end
	LastUpdate = datamodel
	local success, ret = pcall(function()
		return HttpService:RequestAsync({
			Url = "http://127.0.0.1:" .. Settings.port .. "/update/",
			Method = 'POST',
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = HttpService:JSONEncode({
				DataModel = tree
			}),
		})
	end)
	if not success then
		warn("[Roblox LSP] Failed to connect: " .. tostring(ret))
		warn("Make sure the VSCode Extension is running and hosting: http://127.0.0.1:" .. Settings.port)
	end
end

local function HttpEnabled()
    local success, err = pcall(function()
        HttpService:GetAsync('http://www.google.com/')
	end)
    return success
end

local function LoadSettings()
    local result, parseError = loadstring(SettingsModule.Source)
    if result == nil then
        warn("[Roblox LSP] Could not load settings: " .. parseError)
        Settings = nil
        return
	end
	pcall(function()
		Settings = result()
	end)
    if type(Settings) ~= "table"
    or type(Settings.port) ~= "number"
    or type(Settings.startAutomatically) ~= "boolean"
    or type(Settings.exclude) ~= "table" then
        Settings = nil
        warn("[Roblox LSP] Could not load settings: invalid settings")
    end
end

local function IsOnPath(instance)
    if not Settings then
        return
	end
	local _, ret = pcall(function()
		for _, exclude in pairs(Settings.exclude) do
			if typeof(exclude) ~= "Instance" then
				warn("[Roblox LSP] " .. tostring(exclude) .. " is not an Instance")
				continue
			end
			if instance:IsDescendantOf(exclude) then
				return false
			end
		end
		for _, service in pairs(Services) do
			if instance:IsDescendantOf(service) then
				return true
			end
		end
	end)
    return ret or false
end

LoadSettings()

if Settings and Settings.startAutomatically then
	if not HttpEnabled() then
		warn("[Roblox LSP] HttpService.Enabled is false, run in the command bar: game.HttpService.HttpEnabled = false")
    else
		Connected = true
		ConnectButton:SetActive(true)
		print("[Roblox LSP] Connecting")
		Update()
    end
end

ConnectButton.Click:Connect(function()
    if not Connected then
        if not HttpEnabled() then
			warn("[Roblox LSP] HttpService.Enabled is false, run in the command bar: game.HttpService.HttpEnabled = false")
		else
			print("[Roblox LSP] Connecting")
            Connected = true
			Update(true)
        end
	else
		print("[Roblox LSP] Disconnected")
        Connected = false
    end
    ConnectButton:SetActive(Connected)
end)

SettingsButton.Click:Connect(function()
    plugin:OpenScript(SettingsModule)
end)

SettingsModule.Changed:Connect(LoadSettings)

local function ListenToChanges(instance)
	instance:GetPropertyChangedSignal("Name"):Connect(function()
		if Connected then
			ShouldUpdate = true
		end
	end)
	instance.AncestryChanged:Connect(function()
		if not instance.Parent then
			return
		end
		if Connected then
			ShouldUpdate = true
		end
	end)
end

game.DescendantAdded:Connect(function(descendant)
    if not Connected then
        return
    end
	if IsOnPath(descendant) then
        pcall(ListenToChanges, descendant)
		ShouldUpdate = true
    end
end)

game.DescendantRemoving:Connect(function(descendant)
    if not Connected then
        return
    end
	if IsOnPath(descendant) then
		ShouldUpdate = true
    end
end)

if Settings then
    for _, service in pairs(Services) do
		for _, descendant in pairs(service:GetDescendants()) do
            if IsOnPath(descendant) then
                pcall(ListenToChanges, descendant)
            end
        end
    end
end

coroutine.wrap(function()
	while wait(0.5) do
		if Connected and ShouldUpdate then
			ShouldUpdate = false
			Update()
		end
	end
end)()

while wait(1) do
	if Connected then
		pcall(function()
			local last = HttpService:GetAsync("http://127.0.0.1:" .. Settings.port .. "/last/")
			if last == "" then
				wait(3)
				print("[Roblox LSP] Reconnecting")
				Update(true)
			end
		end)
	end
end
