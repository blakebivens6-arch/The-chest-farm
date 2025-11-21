-- Loader.lua
-- Responsible for loading save data and signaling ChestFarm

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local task = task

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local safeZone = Workspace:WaitForChild("Map"):WaitForChild("PrairieVillage"):WaitForChild("Statue")

-- Communication event for ChestFarm
local chestFarmSignal = ReplicatedStorage:FindFirstChild("ChestFarmSignal")
if not chestFarmSignal then
    chestFarmSignal = Instance.new("BindableEvent")
    chestFarmSignal.Name = "ChestFarmSignal"
    chestFarmSignal.Parent = ReplicatedStorage
end

-- Helper to find a part to teleport to
local function getAnyPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("BasePart") then return child end
        end
    end
end

local function instantTP(target)
    local part = getAnyPart(target)
    if part then
        root.CFrame = part.CFrame
        return true
    end
    return false
end

local function teleportToSafeZone()
    instantTP(safeZone)
end

-- Load save data
local function loadSaveData()
    local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LoadData")
    local args = {[1]=2}
    for i = 1, 2 do
        pcall(function()
            remote:InvokeServer(unpack(args))
        end)
        task.wait(5)
    end
end

-- Wait for game load signal
local function waitForGameLoadSignal()
    print("Loader: Waiting for Settings or Block remote...")
    while true do
        local success = false

        pcall(function()
            local settings = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Settings")
            settings:FireServer()
            success = true
        end)
        if success then break end

        pcall(function()
            local block = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Block")
            block:FireServer(false)
            success = true
        end)
        if success then break end

        task.wait(0.5)
    end

    print("Loader: Game load signal detected. Waiting 10 seconds for replication...")
    task.wait(10)

    teleportToSafeZone()
    print("Loader: Signaling ChestFarm to start...")
    chestFarmSignal:Fire()
end

-- Start loader
loadSaveData()
waitForGameLoadSignal()
