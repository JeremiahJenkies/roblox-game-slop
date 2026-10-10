-- PITCH Halloween Cartoon Main Menu
-- Built with native Roblox UI so it works without external image assets.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("PitchHalloweenMenu")
if old then old:Destroy() end

local C = {
  bg = Color3.fromRGB(10, 9, 21), panel = Color3.fromRGB(18, 15, 32),
  orange = Color3.fromRGB(255, 105, 24), orange2 = Color3.fromRGB(255, 163, 42),
  purple = Color3.fromRGB(174, 55, 255), red = Color3.fromRGB(255, 55, 83),
  green = Color3.fromRGB(38, 235, 135), white = Color3.fromRGB(255, 242, 231),
  muted = Color3.fromRGB(190, 174, 207), black = Color3.fromRGB(17, 9, 19)
}
local gui = Instance.new("ScreenGui")
gui.Name = "PitchHalloweenMenu"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(obj, px)
  local u = Instance.new("UICorner"); u.CornerRadius = UDim.new(0, px); u.Parent = obj
end
local function outline(obj, color, thickness)
  local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness or 2; s.Parent = obj
end
local function text(parent, value, size, pos, fontSize, color, font, align)
  local t = Instance.new("TextLabel")
  t.BackgroundTransparency = 1; t.Text = value; t.Size = size; t.Position = pos
  t.Font = font or Enum.Font.FredokaOne; t.TextSize = fontSize; t.TextColor3 = color or C.white
  t.TextXAlignment = align or Enum.TextXAlignment.Left
  t.TextWrapped = true; t.Parent = parent
  return t
end
local function panel(parent, name, pos, size, color, edge)
  local f = Instance.new("Frame"); f.Name = name; f.Position = pos; f.Size = size
  f.BackgroundColor3 = color; f.BorderSizePixel = 0; f.Parent = parent
  corner(f, 15); outline(f, edge or C.orange, 2); return f
end
local function button(parent, title, pos, size, color, icon)
  local b = Instance.new("TextButton"); b.Name = title:gsub("%W","") .. "Button"
  b.Position = pos; b.Size = size; b.BackgroundColor3 = color; b.BorderSizePixel = 0
  b.Text = (icon and icon .. "  " or "") .. title; b.TextColor3 = C.white
  b.Font = Enum.Font.FredokaOne; b.TextSize = 20; b.TextWrapped = true; b.AutoButtonColor = false
  b.Parent = parent; corner(b, 13); outline(b, Color3.fromRGB(255, 205, 136), 2)
  local scale = Instance.new("UIScale"); scale.Scale = 1; scale.Parent = b
  b.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(.12), {Scale=1.035}):Play() end)
  b.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(.12), {Scale=1}):Play() end)
  return b
end

local backdrop = Instance.new("Frame")
backdrop.Name = "HalloweenBackdrop"; backdrop.Size = UDim2.fromScale(1,1)
backdrop.BackgroundColor3 = C.bg; backdrop.BorderSizePixel = 0; backdrop.Parent = gui
local gradient = Instance.new("UIGradient"); gradient.Color = ColorSequence.new({
  ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 12, 49)),
  ColorSequenceKeypoint.new(.48, Color3.fromRGB(12, 12, 29)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 17, 22))
}); gradient.Rotation = 25; gradient.Parent = backdrop
-- Atmospheric illustrated shapes: moons, stadium lights, bats and floating pumpkins.
local moon = Instance.new("Frame"); moon.AnchorPoint = Vector2.new(.5,.5)
moon.Position = UDim2.fromScale(.53,.37); moon.Size = UDim2.fromScale(.28,.49)
moon.BackgroundColor3 = Color3.fromRGB(255, 111, 37); moon.BackgroundTransparency = .12
moon.BorderSizePixel = 0; moon.Parent = backdrop; corner(moon, 300)
local mg = Instance.new("UIGradient"); mg.Color = ColorSequence.new(Color3.fromRGB(255,190,65), Color3.fromRGB(244,54,27)); mg.Rotation=90; mg.Parent=moon
text(backdrop, "✦      ☾       🦇       ✦       🦇", UDim2.fromScale(.65,.06), UDim2.fromScale(.19,.12), 24, C.purple, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
text(backdrop, "🎃", UDim2.fromScale(.08,.1), UDim2.fromScale(.015,.015), 45, C.orange)
text(backdrop, "👻", UDim2.fromScale(.07,.1), UDim2.fromScale(.61,.51), 37, C.white)
text(backdrop, "🎃", UDim2.fromScale(.07,.1), UDim2.fromScale(.51,.79), 36, C.orange)
text(backdrop, "🏰  🦇  🏰  🦇  🏰", UDim2.fromScale(.6,.12), UDim2.fromScale(.22,.47), 38, C.black, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
text(backdrop, "PITCH", UDim2.fromScale(.27,.09), UDim2.fromScale(.025,.025), 30, C.orange2)
text(backdrop, "HALLOWEEN CUP", UDim2.fromScale(.3,.04), UDim2.fromScale(.027,.087), 12, C.muted)

local top = panel(backdrop, "Navigation", UDim2.fromScale(.22,.025), UDim2.fromScale(.59,.075), C.panel, C.orange)
local navNames = {{"⌂","PLAY"}, {"♟","KITS"}, {"▤","SHOP"}, {"▣","INVENTORY"}, {"▥","STATS"}, {"🏆","LEADERBOARDS"}, {"⚙","SETTINGS"}}
for i, n in ipairs(navNames) do
  local w = 1/#navNames
  local b = button(top, n[2], UDim2.new((i-1)*w,3,0,5), UDim2.new(w,-6,1,-10), i==1 and C.orange or C.panel, n[1])
  b.TextSize = 11
  b.Activated:Connect(function()
    if n[2] == "PLAY" then
      gui.Enabled = false
    else
      status.Text = n[2] .. " section selected — full feature integration can be added here."
      status.TextColor3 = C.orange2
    end
  end)
end
local gems = panel(backdrop, "Currency", UDim2.fromScale(.83,.025), UDim2.fromScale(.15,.075), C.panel, C.purple)
text(gems, "💎  3,250   ＋", UDim2.fromScale(1,1), UDim2.new(), 19, Color3.fromRGB(226,157,255), Enum.Font.FredokaOne, Enum.TextXAlignment.Center)

local profile = panel(backdrop, "Profile", UDim2.fromScale(.025,.14), UDim2.fromScale(.245,.13), C.panel, C.purple)
text(profile, "🎃", UDim2.fromScale(.27,.8), UDim2.fromScale(.025,.1), 39, C.orange)
text(profile, "ROOKIE", UDim2.fromScale(.64,.25), UDim2.fromScale(.32,.12), 21, C.white)
text(profile, "LEVEL 1  •  NEW PLAYER", UDim2.fromScale(.64,.2), UDim2.fromScale(.32,.4), 11, C.orange2)
local xp = panel(profile, "XPBar", UDim2.fromScale(.32,.68), UDim2.fromScale(.59,.13), Color3.fromRGB(54,43,61), C.black)
local fill = Instance.new("Frame"); fill.Size=UDim2.fromScale(.38,1); fill.BackgroundColor3=C.orange; fill.BorderSizePixel=0; fill.Parent=xp; corner(fill,8)

local left = Instance.new("Frame"); left.BackgroundTransparency=1
left.Position=UDim2.fromScale(.025,.31); left.Size=UDim2.fromScale(.28,.48); left.Parent=backdrop
local play = button(left, "PLAY", UDim2.fromScale(0,0), UDim2.fromScale(1,.22), C.orange, "⚽"); play.TextSize=31
local ranked = button(left, "RANKED", UDim2.fromScale(0,.25), UDim2.fromScale(1,.19), C.purple, "♛")
local custom = button(left, "CUSTOM MATCH", UDim2.fromScale(0,.47), UDim2.fromScale(1,.19), C.red, "👥"); custom.TextSize=17
local practice = button(left, "PRACTICE", UDim2.fromScale(0,.69), UDim2.fromScale(1,.19), C.green, "◎"); practice.TextColor3=C.black
local status = text(left, "Choose your mode and enter the haunted pitch!", UDim2.fromScale(1,.09), UDim2.fromScale(0,.9), 11, C.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
play.Activated:Connect(function() gui.Enabled=false end)
ranked.Activated:Connect(function() status.Text="RANKED selected — matchmaking is not connected to this menu yet."; status.TextColor3=C.purple end)
custom.Activated:Connect(function() status.Text="CUSTOM MATCH selected — lobby creation is not connected yet."; status.TextColor3=C.red end)
practice.Activated:Connect(function() status.Text="PRACTICE selected — use the existing practice controls in-game."; status.TextColor3=C.green end)

local map = panel(backdrop, "FeaturedMap", UDim2.fromScale(.70,.14), UDim2.fromScale(.275,.22), C.panel, C.orange)
text(map, "🏰  🎃  🦇", UDim2.fromScale(1,.49), UDim2.new(0,0,0,.03), 34, C.orange2, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
text(map, "HAUNTED STADIUM", UDim2.fromScale(.94,.22), UDim2.fromScale(.03,.51), 20, C.orange2, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
text(map, "LIMITED-TIME MAP", UDim2.fromScale(.94,.13), UDim2.fromScale(.03,.75), 11, C.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)

local quests = panel(backdrop, "DailyQuests", UDim2.fromScale(.70,.385), UDim2.fromScale(.275,.29), C.panel, C.orange)
text(quests, "🎃  DAILY QUESTS", UDim2.fromScale(.92,.16), UDim2.fromScale(.04,.025), 19, C.orange2)
local questRows = {{"⚽","Score 10 Goals","4/10","+250"}, {"🏆","Win 5 Matches","2/5","+400"}, {"👟","Make 20 Tackles","7/20","+300"}}
for i,q in ipairs(questRows) do
  local row = panel(quests, "Quest"..i, UDim2.new(.035,0,.19+(i-1)*.255,0), UDim2.new(.93,0,.22,0), Color3.fromRGB(29,23,43), C.purple)
  text(row, q[1].."  "..q[2], UDim2.fromScale(.73,.45), UDim2.fromScale(.04,.04), 12, C.white, Enum.Font.GothamBold)
  text(row, q[3].."   "..q[4].." 💎", UDim2.fromScale(.7,.4), UDim2.fromScale(.04,.51), 11, C.orange2, Enum.Font.GothamBold)
end

local bottom = panel(backdrop, "CosmeticsStrip", UDim2.fromScale(.025,.81), UDim2.fromScale(.95,.16), C.panel, C.orange)
local cosmetics = {{"🎃","KITS",C.orange},{"👻","EMOTES",C.purple},{"⚽","BALLS",C.orange2},{"☄","TRAILS",C.purple},{"🔥","GOAL FX",C.red}}
for i,item in ipairs(cosmetics) do
  local w = .19
  local card = panel(bottom, item[2], UDim2.new((i-1)*.2,.005,0,.08), UDim2.new(w,-.005,.84,0), Color3.fromRGB(28,19,41), item[3])
  text(card, item[1], UDim2.fromScale(1,.6), UDim2.new(0,0,0,.02), 28, item[3], Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
  text(card, item[2], UDim2.fromScale(1,.25), UDim2.fromScale(0,.65), 13, C.white, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
end

local reopen = button(backdrop, "MENU", UDim2.new(0,14,1,-45), UDim2.fromOffset(95,32), C.purple, "🎃")
reopen.TextSize=13
reopen.Activated:Connect(function() gui.Enabled=true end)
