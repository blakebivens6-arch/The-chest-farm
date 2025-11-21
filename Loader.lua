-- Loader.lua
-- Fully auto-execute safe loader for chest farm

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local task = task

local player = Players.LocalPlayer

-- 🔹 Repeated check until the game is fully ready
repeat
    task.wait(0.2)
until player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame

local character = player.Character
local root = character:WaitForChild("HumanoidRootPart")
local cam = Workspace.CurrentCamera

-- 🔹 SafeZone
local safeZone = Workspace:WaitForChild("Map"):WaitForChild("PrairieVillage"):WaitForChild("Statue")

-- 🔹 Communication event for ChestFarm
local chestFarmSignal = ReplicatedStorage:FindFirstChild("ChestFarmSignal")
if not chestFarmSignal then
    chestFarmSignal = Instance.new("BindableEvent")
    chestFarmSignal.Name = "ChestFarmSignal"
    chestFarmSignal.Parent = ReplicatedStorage
end

-- 🔹 Helper to get any BasePart from a model or part
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

-- 🔹 Load save data (run twice, 5s interval)
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

-- 🔹 Wait for game load signal (Settings or Block remote fired)
local function waitForGameLoadSignal()
    print("Loader: Waiting for Settings or Block remote to signal game load...")
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

-- 🔹 Start loader
loadSaveData()
waitForGameLoadSignal()
