-- ChestFarm.lua (updated with retry TP and safe server hop)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer
local task = task

local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")

local SAFEZONE = Workspace.Map.PrairieVillage.Statue
local SAFEZONE_WAIT = 5
local SCAN_INTERVAL = 0.5
local MAX_CHEST_RUNS = 10
local MIN_OPEN_SLOTS = 2  -- NEVER joins a full server

---------------------------------------------------------------------
-- PART FINDER (works for any model)
---------------------------------------------------------------------
local function getAnyPart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart end
        for _, v in ipairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then return v end
        end
    end
    return nil
end

---------------------------------------------------------------------
-- RELIABLE TELEPORT (12 retries)
---------------------------------------------------------------------
local function TryTP(target)
    local part = getAnyPart(target)
    if not part then return false end

    local success = false
    for i = 1, 12 do
        pcall(function()
            root.CFrame = part.CFrame
        end)

        -- Check if close enough after TP
        if (root.Position - part.Position).Magnitude < 6 then
            success = true
            break
        end

        task.wait(0.25)
    end

    -- emergency reposition if still failing
    if not success then
        pcall(function()
            root.CFrame = SAFEZONE.PrimaryPart and SAFEZONE.PrimaryPart.CFrame or getAnyPart(SAFEZONE).CFrame
        end)
        task.wait(0.5)

        -- Retry TP after emergency reset
        local part2 = getAnyPart(target)
        if part2 then
            pcall(function()
                root.CFrame = part2.CFrame
            end)
        end
    end

    return true
end

local function TPToSafe()
    TryTP(SAFEZONE)
end

---------------------------------------------------------------------
-- CHEST CHECK
---------------------------------------------------------------------
local function isChestReady(chest)
    return chest:FindFirstChild("Body") and chest:FindFirstChild("ProximityPrompt")
end

---------------------------------------------------------------------
-- BANK DEPOSIT AFTER OPEN
---------------------------------------------------------------------
local function deposit()
    local remote = ReplicatedStorage.Remotes.Bank
    pcall(function()
        remote:InvokeServer(true, 1)
    end)
end

---------------------------------------------------------------------
-- OPEN SINGLE CHEST
---------------------------------------------------------------------
local function openChest(chest)
    if not isChestReady(chest) then return false end

    local body = chest.Body
    local prompt = chest.ProximityPrompt

    if not TryTP(body) then return false end
    task.wait(0.35)

    pcall(function()
        fireproximityprompt(prompt, 1)
    end)

    deposit()

    TPToSafe()
    task.wait(SAFEZONE_WAIT)

    return true
end

---------------------------------------------------------------------
-- SAFE SERVER HOP (never joins full)
-- + retry if hop fails
---------------------------------------------------------------------
local function serverHop()
    local placeId = game.PlaceId
    local API = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"

    local success, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(API))
    end)

    local available = {}

    if success and data and data.data then
        for _, server in ipairs(data.data) do
            local openSlots = server.maxPlayers - server.playing
            if openSlots >= MIN_OPEN_SLOTS and server.id ~= game.JobId then
                table.insert(available, server.id)
            end
        end
    end

    -- retry logic if no servers found
    if #available == 0 then
        warn("No good servers found. Retrying...")
        task.wait(2)

        local s2, d2 = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(API))
        end)

        if s2 and d2 and d2.data then
            for _, server in ipairs(d2.data) do
                local openSlots = server.maxPlayers - server.playing
                if openSlots >= MIN_OPEN_SLOTS and server.id ~= game.JobId then
                    table.insert(available, server.id)
                end
            end
        end
    end

    -- fallback: teleport to place (fresh instance)
    if #available == 0 then
        TeleportService:Teleport(placeId, Players.LocalPlayer)
        return
    end

    -- normal hop
    local chosen = available[math.random(1, #available)]
    for i = 1, 3 do
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, chosen, Players.LocalPlayer)
        end)
        if ok then return end
        task.wait(1)
    end

    -- final fallback
    TeleportService:Teleport(placeId, Players.LocalPlayer)
end

---------------------------------------------------------------------
-- MAIN LOOP
---------------------------------------------------------------------
local loaderFlag = ReplicatedStorage:WaitForChild("LoaderReady")
repeat task.wait(0.25) until loaderFlag.Value

local chestRuns = 0

while true do
    local chestFolder = Workspace:FindFirstChild("Chests")
    if not chestFolder then
        task.wait(SCAN_INTERVAL)
        continue
    end

    local list = {}
    for _, c in ipairs(chestFolder:GetChildren()) do
        if isChestReady(c) then table.insert(list, c) end
    end

    if #list == 0 then
        task.wait(SCAN_INTERVAL)
        continue
    end

    local chosen = list[math.random(1, #list)]
    openChest(chosen)

    chestRuns += 1
    if chestRuns >= MAX_CHEST_RUNS then
        serverHop()
        break
    end
end
