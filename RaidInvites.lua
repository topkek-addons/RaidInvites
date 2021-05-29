--[[
  written by topkek
--]]
local default = {
  spamInterval = "120",
  spamMessage = "123 for invite",
  inviteChannels = "guild, whisper",
  inviteKeyword = "123",
  raidSize = 40,
  assist = false,
  caseSensitive = false,
}

local RaidInvites = LibStub("AceAddon-3.0"):NewAddon("RaidInvites", "AceEvent-3.0")
saved = saved or default
local frame = CreateFrame("Frame")
local hidden = true
local enabled = false -- this setting should persist across sessions for world bosses
local TimeSinceLastUpdate = 0
local UpdateInterval = 1
local InviteTimeout = 60
local TimeStarted = 0
local TimeEnded = 0
local Updates = 0
local numInRaid = 1
local assists = {}

function initialize()
  spamIntervalEditbox:SetText(saved.spamInterval or "")
  spamMessageEditbox:SetText(saved.spamMessage)
  inviteChannelsEditbox:SetText(saved.inviteChannels)
  inviteKeywordEditbox:SetText(saved.inviteKeyword)
  raidSizeEditbox:SetText(saved.raidSize)
  caseSensitiveCheckbox:SetChecked(saved.caseSensitive)
  assistCheckBox:SetChecked(saved.assist)
  if hidden then
    root:Hide()
  end
  TimeStarted = tonumber(saved.spamInterval) or 0
  UpdateInterval = tonumber(saved.spamInterval) or nil
  RaidInvites:RegisterMessage("RaidInvite_WorldBoss", worldBoss)
end

function loadRoot(this)
  root = this
  root:EnableKeyboard(false)
  root:SetBackdrop({
    bgFile="Interface\\TutorialFrame\\TutorialFrameBackground",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize=16,
    tileSize=32,
    tile=true,
  })
end


-- register comm event for unit_scan alert
-- create a raid invite blocker comm message and send back
-- if you have invites enabled for a world boss

function worldBoss(message, payload)
  print("world boss spawned")
end

function updateAssists()
  if saved.assist then
    for unit in pairs(assists) do
      if assists[unit] then
        local realm = GetRealmName()
        local name = unit:gsub("-" .. realm, "")
        PromoteToAssistant(name)
      end
    end
  end
end

function announce()
  numInRaid = GetNumGroupMembers() or numInRaid
  if numInRaid == 0 then
    numInRaid = 1
  end
  if IsInGroup() then
    if saved.raidSize > 5 then
      SendChatMessage(saved.spamMessage .. " - (" .. numInRaid .. "/" .. saved.raidSize .. ") in group", "RAID")
    else
      SendChatMessage(saved.spamMessage .. " - (" .. numInRaid .. "/" .. saved.raidSize .. ") in group", "PARTY")
    end
  end
  if IsInGuild() then
    SendChatMessage(saved.spamMessage .. " - (" .. numInRaid .. "/" .. saved.raidSize ..") in group", "GUILD")
  end
end

function update(self, elapsed)
  TimeStarted = TimeStarted + elapsed
  TimeEnded = TimeEnded + elapsed
  TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed
  while (TimeSinceLastUpdate > 1) do
    updateAssists()
    print(TimeEnded)
    if TimeEnded / InviteTimeout > 1 then
      print("timeout reached")
      if not enabled then
        frame:SetScript("OnUpdate", nil)
      end
    end
    if UpdateInterval then
      if math.floor(TimeStarted / UpdateInterval) > Updates then
        if enabled and saved.spamMessage ~= "" then
          announce()
        end
        Updates = math.floor(TimeStarted / UpdateInterval)
      end
    end
    TimeSinceLastUpdate = 0
  end
end
frame:SetScript("OnUpdate", update)

function containsKeyword(msg)
  if saved.inviteKeyword == nil then
    return false
  end
  if saved.caseSensitive then
    if string.match(msg, saved.inviteKeyword) then
      return true
    else
      return false
    end
  else
    if string.match(string.lower(msg), string.lower(saved.inviteKeyword)) then
      return true
    else
      return false
    end
  end
end

function converter()
  local max = tonumber(saved.raidSize) or 40
  if max > 5 then
    ConvertToRaid()
  else
    ConvertToParty()
  end
end

function shouldInvite(msg, sender)
  numInRaid = GetNumGroupMembers() or numInRaid
  local max = tonumber(saved.raidSize) or 40
  local player = UnitName("player")
  local realm = GetRealmName()
  local name = player.."-"..realm
  if names ~= sender and numInRaid >= max and saved.debug then
    print("|cffFF0000Raid full.|r")
    return
  end
  if name ~= sender and containsKeyword(msg) then
    InviteToGroup(sender)
    if enabled and saved.assist and not assists[sender] then
      assists[sender] = true
    end
  end
end

function parse(...)
  local msg, sender = ...
  if not enabled then
    return
  end
  shouldInvite(msg, sender)
end

function handleEvent(self, event, ...)
  if event == "PLAYER_STARTED_MOVING" then
    root:EnableKeyboard(false)
    clearEditboxFocus()
  elseif event == "CURSOR_UPDATE" then
    root:EnableKeyboard(false)
    clearEditboxFocus()
  elseif event == "PLAYER_LOGIN" then
    initialize()
    frame:SetScript("OnUpdate", nil)
  elseif event == "CHAT_MSG_SYSTEM" then
    if saved.assist then
      local msg = ...
      if string.find(msg, " declines your group invitation.") then
        local name = msg:gsub(" declines your group invitation.", "")
        local realm = GetRealmName()
        assists[name .. "-" .. realm] = nil
      end
    end
  elseif event == "CHAT_MSG_SAY" then
    if isChannel("say") then
      parse(...)
    end
  elseif event == "CHAT_MSG_YELL" then
    if isChannel("yell") then
      parse(...)
    end
  elseif event == "CHAT_MSG_WHISPER" then
    if isChannel("whisper") then
      parse(...)
    end
  elseif event == "CHAT_MSG_GUILD" then
    if isChannel("guild") then
      parse(...)
    end
  elseif event == "CHAT_MSG_CHANNEL" then
    local channel = select(9, ...)
    if isChannel(channel) then
      parse(...)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    if enabled then
      converter()
    end
  end
end

function initCaseSensitiveCheckbox(this)
  caseSensitiveCheckbox = this
  caseSensitiveCheckbox:SetChecked(saved.caseSensitive)
  getglobal(caseSensitiveCheckbox:GetName().."Text"):SetText("Case Sensitive")
end

function initAssistCheckbox(this)
  assistCheckBox = this
  assistCheckBox:SetChecked(saved.assist)
  getglobal(assistCheckBox:GetName().."Text"):SetText("Assist on invite")
end

function initEnabledCheckbox(this)
  enabledCheckBox = this
  enabledCheckBox:SetChecked(enabled)
  getglobal(enabledCheckBox:GetName().."Text"):SetText("Invites Enabled")
end

function initSpamIntervalEditbox(this)
  spamIntervalEditbox = this
  spamIntervalEditbox:ClearFocus()
  spamIntervalEditbox:SetText(saved.spamInterval)
end

function initSpamMessageEditbox(this)
  spamMessageEditbox = this
  spamMessageEditbox:ClearFocus()
  spamMessageEditbox:SetText(saved.spamMessage)
end

function initInviteChannelsEditbox(this)
  inviteChannelsEditbox = this
  inviteChannelsEditbox:ClearFocus()
  inviteChannelsEditbox:SetText(saved.inviteChannels)
end

function initInviteKeywordEditbox(this)
  inviteKeywordEditbox = this
  inviteKeywordEditbox:ClearFocus()
  inviteKeywordEditbox:SetText(saved.inviteKeyword)
end

function initRaidSizeEditbox(this)
  raidSizeEditbox = this
  raidSizeEditbox:ClearFocus()
  raidSizeEditbox:SetText(saved.raidSize)
end

function toggle()
  hidden = not hidden
  if hidden then
    root:Hide()
  else
    root:Show()
  end
  root:EnableKeyboard(false)
end

function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function split(s, delimiter)
  result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    if trim(match) ~= "" then
      table.insert(result, trim(match));
    end
  end
  return result;
end

function isChannel(name)
  local text = inviteChannelsEditbox:GetText()
  local names = split(text, ",")
  for i = 1, #names do
    if string.lower(name) == string.lower(names[i]) then
      return true
    end
  end
  return false
end

function captureInputs()
  saved.spamInterval = tonumber(spamIntervalEditbox:GetText())
  saved.spamMessage = spamMessageEditbox:GetText()
  Updates = 0
  TimeStarted = tonumber(saved.spamInterval) or 0
  UpdateInterval = tonumber(saved.spamInterval) or nil
  saved.raidSize = tonumber(raidSizeEditbox:GetText())
  saved.raidSize = saved.raidSize or 40
  if saved.raidSize > 40 then
    saved.raidSize = 40
  end
  saved.inviteChannels = inviteChannelsEditbox:GetText()
  saved.inviteKeyword = inviteKeywordEditbox:GetText()
end

function editboxChanged()
  if enabled then
    enabled = false
    enabledCheckBox:SetChecked(false)
  end
  saved.spamInterval = spamIntervalEditbox:GetText()
  saved.spamMessage = spamMessageEditbox:GetText()
  saved.inviteChannels = inviteChannelsEditbox:GetText()
  saved.inviteKeyword = inviteKeywordEditbox:GetText()
  saved.raidSize = raidSizeEditbox:GetText()
  captureInputs()
end

function clearEditboxFocus()
  spamIntervalEditbox:ClearFocus()
  spamIntervalEditbox:HighlightText(0, 0)
  spamMessageEditbox:ClearFocus()
  spamMessageEditbox:HighlightText(0, 0)
  inviteChannelsEditbox:ClearFocus()
  inviteChannelsEditbox:HighlightText(0, 0)
  inviteKeywordEditbox:ClearFocus()
  inviteKeywordEditbox:HighlightText(0, 0)
  raidSizeEditbox:ClearFocus()
  raidSizeEditbox:HighlightText(0, 0)
  root:EnableKeyboard(false)
end

function escapePressed()
  clearEditboxFocus()
end

function handleKey(key)
  if key == "ESCAPE" then
    escapePressed()
  end
end

function caseSensitiveChecked()
  saved.caseSensitive = not saved.caseSensitive
end

function assistChecked()
  saved.assist = not saved.assist
  if saved.assist then
    assists = {}
  else
    TimeEnded = 0
  end
end

function enabledChecked(type)
  initialize()
  if type == "click" then
    enabled = not enabled
  elseif type == "slash" then
    enabled = true
  end
  if enabled then
    converter()
    Updates = 0
    TimeStarted = tonumber(saved.spamInterval) or 0
    frame:SetScript("OnUpdate", update)
  end
  enabledCheckBox:SetChecked(enabled)
end

function focusEditbox()
  root:EnableKeyboard(true)
end

function isEscaped(msg, i)
  if i > 2 and string.sub(msg, i - 1, i - 1) == "\\" then
    return true
  end
end

function getArguments(msg)
  if string.sub(msg, 1, 1) ~= "\"" then
    return "", ""
  end
  local keyword = ""
  local gmsg = ""
  local inQuote = false
  local firstArg = false
  for i = 1, #msg do
    if string.sub(msg, i, i) == "\"" and not inQuote then
      if firstArg then
        if string.sub(msg, i - 1, i - 1) ~= " " then
          return "", ""
        end
      end
      inQuote = true
    elseif string.sub(msg, i, i) == "\"" and inQuote and not isEscaped(msg, i) then
      inQuote = false
      if not firstArg then
        if string.sub(msg, i + 1, i + 1) ~= " " then
          return "", ""
        end
        firstArg = true
      else
        return keyword, gmsg
      end
    elseif inQuote then
      if not firstArg then
        if not (string.sub(msg, i, i) == "\\" and string.sub(msg, i + 1, i + 1) == "\"") then
          keyword = keyword .. string.sub(msg, i, i)
        end
      else
        if not (string.sub(msg, i, i) == "\\" and string.sub(msg, i + 1, i + 1) == "\"") then
          gmsg = gmsg .. string.sub(msg, i, i)
        end
      end
    end
  end
  return "", ""
end

function slashCommand(msg)
  if (msg ~= "") then
    saved.inviteKeyword, saved.spamMessage = getArguments(msg)
    if saved.inviteKeyword == "" or saved.spamMessage == "" then
      print("Incorrect arguments.")
      return
    end
    print("Invites enabled: " .. saved.inviteKeyword)
    enabledChecked("slash")
    return
  end
  toggle()
  enabledCheckBox:SetChecked(enabled)
end

SLASH_RAIDINVITE1 = "/rinv"
SLASH_RAIDINVITE2 = "/rinvs"
SLASH_RAIDINVITE3 = "/raidinv"
SLASH_RAIDINVITE4 = "/raidinvs"
SLASH_RAIDINVITE5 = "/rinvite"
SLASH_RAIDINVITE6 = "/rinvites"
SLASH_RAIDINVITE7 = "/raidinvite"
SLASH_RAIDINVITE8 = "/raidinvites"
SlashCmdList["RAIDINVITE"] = slashCommand
