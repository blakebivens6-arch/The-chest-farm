-- ChestFarm.lua
-- Fully auto-execute safe chest farm that waits for LoaderReady flag

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local task = task

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local safeZone = Workspace:WaitForChild("Map"):WaitForChild("PrairieVillage"):WaitForChild("Statue")

-- 🔹 Settings
local SAFEZONE_WAIT = 5
local SCAN_INTERVAL = 0.5
local MAX_CHEST_RUNS = 10

-- 🔹 Wait for LoaderReady flag
local loaderFlag = ReplicatedStorage:WaitForChild("LoaderReady")
repeat task.wait(0.2) until loaderFlag.Value
print("ChestFarm: LoaderReady detected, starting chest farm...")

-- 🔹 Helper functions
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

local function isChestReady(chest)
    return chest:FindFirstChild("Body") and chest:FindFirstChild("ProximityPrompt")
end

local function deposit()
    local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Bank")
    pcall(function()
        remote:InvokeServer(true,1)
    end)
end

local function openChest(chest)
    if not isChestReady(chest) then return false end
    local body = chest.Body
    local prompt = chest.ProximityPrompt
    local tpPart = body:IsA("BasePart") and body or (body.PrimaryPart or body:FindFirstChildWhichIsA("BasePart"))
    if not tpPart then return false end

    root.CFrame = tpPart.CFrame
    task.wait(0.3)

    if prompt:IsA("ProximityPrompt") then
        pcall(function()
            fireproximityprompt(prompt, 1)
        end)
    end

    deposit()
    teleportToSafeZone()
    task.wait(SAFEZONE_WAIT)
    return true
end

local function serverHop()
    local placeId = game.PlaceId
    local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"
    local goodServers = {}

    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)

    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                table.insert(goodServers, server.id)
            end
        end
    end

    if #goodServers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, goodServers[math.random(1,#goodServers)], player)
    else
        TeleportService:Teleport(placeId, player)
    end
end

local function startChestLoop()
    local chestRuns = 0
    while true do
        local chestFolder = Workspace:FindFirstChild("Chests")
        if not chestFolder then
            task.wait(SCAN_INTERVAL)
            continue
        end

        local chests = {}
        for _, chest in ipairs(chestFolder:GetChildren()) do
            if isChestReady(chest) then
                table.insert(chests, chest)
            end
        end

        if #chests == 0 then
            task.wait(SCAN_INTERVAL)
            continue
        end

        local chosen = chests[math.random(1,#chests)]
        openChest(chosen)

        chestRuns += 1
        if chestRuns >= MAX_CHEST_RUNS then
            serverHop()
            break
        end

        task.wait(0.1)
    end
end

-- 🔹 Start farming after LoaderReady
startChestLoop()
