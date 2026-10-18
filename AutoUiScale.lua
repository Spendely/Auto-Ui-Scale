-- AutoScaleUI: converts GuiObject Offset -> Scale (per axis, only when that axis has no Scale yet)
-- Open source, feel free to use, modify, republish, etc.
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SERVICES = {
	"StarterGui", "Workspace", "ReplicatedStorage", "ServerStorage",
	"StarterPack", "StarterPlayer", "ReplicatedFirst", "Lighting",
}

local toolbar = plugin:CreateToolbar("AutoScale UI")
local button = toolbar:CreateButton("AutoScale", "Toggle Offset -> Scale auto conversion", "rbxassetid://4458901886")
button.ClickableWhenViewportHidden = true

local enabled = false
local connections = {}

local function getParentSize(obj)
	local parent = obj.Parent
	if parent and (parent:IsA("GuiObject") or parent:IsA("LayerCollector")) then
		local size = parent.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			return size
		end
	end
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end

local function convertUDim2(value, parentSize)
	local xs, xo, ys, yo = value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset
	local changed = false
	if xs == 0 and xo ~= 0 then
		xs, xo, changed = xo / parentSize.X, 0, true
	end
	if ys == 0 and yo ~= 0 then
		ys, yo, changed = yo / parentSize.Y, 0, true
	end
	return changed and UDim2.new(xs, xo, ys, yo) or nil
end

local function convert(obj)
	if not obj:IsA("GuiObject") then return false end
	local ok, didChange = pcall(function()
		local parentSize = getParentSize(obj)
		local changed = false
		local newSize = convertUDim2(obj.Size, parentSize)
		if newSize then obj.Size = newSize; changed = true end
		local newPos = convertUDim2(obj.Position, parentSize)
		if newPos then obj.Position = newPos; changed = true end
		return changed
	end)
	return ok and didChange
end

-- Process parents before children so the parent's AbsoluteSize is already final
local function scanAll()
	local recording = ChangeHistoryService:TryBeginRecording("AutoScale UI scan")
	local count = 0
	for _, name in ipairs(SERVICES) do
		local ok, service = pcall(game.GetService, game, name)
		if ok and service then
			for _, obj in ipairs(service:GetDescendants()) do
				if convert(obj) then count += 1 end
			end
		end
	end
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
	print(("[AutoScaleUI] Converted %d UI element(s) to Scale"):format(count))
end

local function onAdded(obj)
	if not obj:IsA("GuiObject") then return end
	-- wait a frame so the inserting code/tool finishes setting properties
	task.defer(function()
		if enabled and obj.Parent then
			convert(obj)
			for _, d in ipairs(obj:GetDescendants()) do
				convert(d)
			end
		end
	end)
end

local function setEnabled(state)
	enabled = state
	button:SetActive(state)
	plugin:SetSetting("AutoScaleUI_Enabled", state)

	for _, c in ipairs(connections) do c:Disconnect() end
	table.clear(connections)

	if state then
		scanAll()
		for _, name in ipairs(SERVICES) do
			local ok, service = pcall(game.GetService, game, name)
			if ok and service then
				table.insert(connections, service.DescendantAdded:Connect(onAdded))
			end
		end
		print("[AutoScaleUI] ON - listening for new UI")
	else
		print("[AutoScaleUI] OFF")
	end
end

button.Click:Connect(function()
	setEnabled(not enabled)
end)

plugin.Unloading:Connect(function()
	for _, c in ipairs(connections) do c:Disconnect() end
end)

-- restore last state
if plugin:GetSetting("AutoScaleUI_Enabled") then
	task.defer(setEnabled, true)
end
