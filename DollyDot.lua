-- DollyDot.lua (Say edition)
-- Queues Meerah's lyrics and lets you /say them one line at a time
-- via a floating "Sing!" button that appears when the toy is used.
--
-- Blizzard requires a hardware event (click/keypress) to call SendChatMessage.
-- We satisfy this by giving the player a click button per lyric line.

local ADDON_NAME = "DollyDot"

local LYRICS = {
    "Dolly and Dot are my best friends!",
    "They pull my wagon through dunes of sand!",
    "They have small teeth and they love to eat!",
    "THEY'RE THE BEST 'PACAS IN ALL THE LAND!",
}

local lyricQueue = {}
local singButton
local cancelButton

local LYRIC_TIMEOUT = 2.5

local enableSing = false

local autoAdvanceTimer = nil
local currentLyricIndex = 0

local enableTestMode = false

local DB_DEFAULTS = {
    cancelButton = { x = 0, y = -200 },
    enableButton = { x = 0, y = -200 },
}

local function SaveButtonPosition(name, btn)
    local point, _, relativePoint, x, y = btn:GetPoint()
    DollyDotDB[name] = { x = x, y = y }
end

local function LoadButtonPosition(name, btn, defaultX, defaultY)
    local saved = DollyDotDB[name]
    btn:ClearAllPoints()
    if saved then
        btn:SetPoint("CENTER", UIParent, "CENTER", saved.x, saved.y)
    else
        btn:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)
    end
end

local function CancelAutoAdvance()
    if autoAdvanceTimer then
        autoAdvanceTimer:Cancel()
        autoAdvanceTimer = nil
    end
end

local function AdvanceToLine(index)
    CancelAutoAdvance()

    -- Past the end, we're done
    if index > #lyricQueue then
        cancelButton:Hide()
        return
    end

    currentLyricIndex = index

    if enableSing then
        SendChatMessage(lyricQueue[currentLyricIndex], "SAY")
        SendChatMessage(lyricQueue[currentLyricIndex], "YELL")
    end

    C_Timer.After(LYRIC_TIMEOUT, function() AdvanceToLine(currentLyricIndex + 1) end)
end

local function QueueLyrics(casterName)
    wipe(lyricQueue)
    for _, line in ipairs(LYRICS) do
        table.insert(lyricQueue, line)
    end
    currentLyricIndex = 0

    DEFAULT_CHAT_FRAME:AddMessage(
        "|cff00FF99[DollyDot]|r " .. (casterName or "Someone") .. " started the jukebox!"
    )
    AdvanceToLine(1)  -- arm the timer for line 1 immediately, no dummy needed
end

-- Build the floating "Sing!" button (hidden until the toy fires)
local function CreateEnableButton()
    -- Sing button
    local btn = CreateFrame("Button", ADDON_NAME .. "EnableButton", UIParent, "UIPanelButtonTemplate")
    btn:SetSize(160, 40)
    btn:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", btn.StartMoving)
    btn:SetScript("OnDragStop", btn.StopMovingOrSizing)
    btn:SetText("Enable DollyDot Sing-along!")
    btn:Hide()

    btn:SetScript("OnClick", function()
        enableSing = true
        btn:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Enabled!")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r enter |cff00FF99/ddot help|r for commands")
    end)

    btn:SetScript("OnDragStop", function()
        btn:StopMovingOrSizing()
        SaveButtonPosition("enableButton", btn)
    end)

    return btn
end

local function CreateCancelButton()
    -- Cancel button
    local cancelBtn = CreateFrame("Button", ADDON_NAME .. "CancelButton", UIParent, "UIPanelButtonTemplate")
    cancelBtn:SetSize(160, 40)
    cancelBtn:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
    cancelBtn:SetMovable(true)
    cancelBtn:EnableMouse(true)
    cancelBtn:RegisterForDrag("LeftButton")
    cancelBtn:SetScript("OnDragStart", cancelBtn.StartMoving)
    cancelBtn:SetScript("OnDragStop", cancelBtn.StopMovingOrSizing)
    cancelBtn:SetText("Cancel Sing-along")
    cancelBtn:Hide()

    cancelBtn:SetScript("OnClick", function()
        CancelAutoAdvance()
        wipe(lyricQueue)
        currentLyricIndex = 0
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Singalong cancelled.")
        cancelBtn:Hide()
    end)

    cancelBtn:SetScript("OnDragStop", function()
        cancelBtn:StopMovingOrSizing()
        SaveButtonPosition("cancelButton", cancelBtn)
    end)

    return cancelBtn
end

-- Main frame
local frame = CreateFrame("Frame", ADDON_NAME .. "Frame", UIParent)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON_NAME then
        -- Initialize DB if first time
        if not DollyDotDB then
            DollyDotDB = {}
        end
        -- Fill in any missing keys with defaults
        for k, v in pairs(DB_DEFAULTS) do
            if not DollyDotDB[k] then
                DollyDotDB[k] = v
            end
        end
        singButton = CreateEnableButton()
        cancelButton = CreateCancelButton()

        -- Load saved positions
        LoadButtonPosition("enableButton", singButton, 0, -200)
        LoadButtonPosition("cancelButton", cancelButton, 0, -200)
        
        singButton:Show()

    elseif event == "CHAT_MSG_MONSTER_EMOTE" then
        if InCombatLockdown() then return end
        
        local msg = ...
        if msg and msg:find("sets out Meerah's Jukebox!") then
            if enableSing then
                local playerName = msg:match("^(.+) sets out Meerah's Jukebox!")
                cancelButton:Show()
                QueueLyrics(playerName or "Someone")
            end
        end
        if msg and msg:find("casted runes") and enableTestMode == true then
            if enableSing then
                cancelButton:Show()
                QueueLyrics("Someone")
            end
        end
    end
end)

-- Slash command
SLASH_DOLLYDOT1 = "/ddot"
SlashCmdList["DOLLYDOT"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "enable" then
        enableSing = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Sing-along enabled :)")
    elseif msg == "disable" then
        enableSing = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Sing-along disabled :(")
    elseif msg == "test-on" then
        enableTestMode = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Test mode enabled - test the addon using Ancient Korthian Runes")
    elseif msg == "test-off" then
        enableTestMode = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Test mode disabled")
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot enable|r - enable sing-along")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot disable|r - disable sing-along")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot test-on|r - enable test mode - triggers the sing-along by using the Ancient Korthian Runes toy")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot test-off|r - disable test mode")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot enable|r - enable sing-along")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot disable|r - disable sing-along")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot test-on|r - enable test mode - triggers the sing-along by using the Ancient Korthian Runes toy")
        DEFAULT_CHAT_FRAME:AddMessage("|cff00FF99[DollyDot]|r |cff00FF99/ddot test-off|r - disable test mode")
    end
end