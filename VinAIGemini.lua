--[[
	VinAI  -  heavyweight Lua / Luau coding assistant  (single file)
	Made by Vincent (Evilmorty_143)

	HOW TO USE
	1. Put this file in a LocalScript (StarterPlayer > StarterPlayerScripts).
	2. Create a Gemini API key in Google AI Studio, then paste it into CONFIG.API_KEY below.
	3. Press Play. Click the logo bubble or press RightShift to show / hide VinAI.

	NOTES
	- The "brain" is a large language model reached over HTTP; the UI, memory,
	  language system, code highlighter and offline helper are all pure Lua.
	- With no API key (or no HTTP) VinAI runs in OFFLINE mode and answers from its
	  built-in Lua snippet library.
	- Normal Roblox LocalScripts cannot make web requests. Run this where a
	  request()/http_request function exists, or send calls through a server script.
	- Never publish this file with your key inside - anyone could use it. For a public game, proxy API calls through a server you control.
]]

------------------------------------------------------------------ CONFIG
local CONFIG = {
	API_KEY = "",                              -- your API key
	API_URL = "https://generativelanguage.googleapis.com/v1beta/models/",
	MODEL = "gemini-3.8-flash",
	MAX_TOKENS = 8000000,
	WEB_SEARCH = true,                         -- Gemini Google Search grounding (model/account support required)
	LOGO = "rbxassetid://72694888911234",
	TOGGLE_KEY = Enum.KeyCode.RightShift,
	DEFAULT_LANGUAGE = "English",
}

------------------------------------------------------------------ SERVICES
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("VinAI")
if oldGui then oldGui:Destroy() end

------------------------------------------------------------------ THEME
local C = {
	bg = Color3.fromHex("212121"), side = Color3.fromHex("171717"), input = Color3.fromHex("2F2F2F"),
	line = Color3.fromHex("3C3C3C"), text = Color3.fromHex("ECECEC"), sub = Color3.fromHex("A0A0A0"),
	code = Color3.fromHex("141414"), white = Color3.fromHex("FFFFFF"),
}
local GEMINI = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("4285F4")),
	ColorSequenceKeypoint.new(0.5, Color3.fromHex("9B72CB")),
	ColorSequenceKeypoint.new(1, Color3.fromHex("D96570")),
})
local FONT, FONT_B = Enum.Font.BuilderSans, Enum.Font.BuilderSansBold

------------------------------------------------------------------ LANGUAGES
local LANGS = { "English", "Spanish", "Cebuano", "Tagalog", "Portuguese", "Russian" }
local STR = {
	English = { native = "English", hello = "Hello", welcome = "How can I help you today?",
		sub = "Ask me anything. Lua scripting is my specialty.", newChat = "New chat",
		placeholder = "Message VinAI...", thinking = "VinAI is thinking", language = "Language",
		made = "Made by Vincent (Evilmorty_143)", copy = "Copy", copied = "Copied!", select = "Select",
		chips = { "Write a Lua inventory system", "Explain RemoteEvents simply", "Search the web: latest tech news" } },
	Spanish = { native = "Español", hello = "Hola", welcome = "¿En qué puedo ayudarte hoy?",
		sub = "Pregúntame lo que quieras. El scripting en Lua es mi especialidad.", newChat = "Nuevo chat",
		placeholder = "Escribe a VinAI...", thinking = "VinAI está pensando", language = "Idioma",
		made = "Hecho por Vincent (Evilmorty_143)", copy = "Copiar", copied = "¡Copiado!", select = "Seleccionar",
		chips = { "Crea un sistema de inventario en Lua", "Explica los RemoteEvents fácil", "Busca en la web: últimas noticias de tecnología" } },
	Cebuano = { native = "Cebuano", hello = "Kumusta", welcome = "Unsaon nako pagtabang nimo karon?",
		sub = "Pangutana bisan unsa. Ang Lua scripting akong espesyalidad.", newChat = "Bag-ong chat",
		placeholder = "Mensahe para kang VinAI...", thinking = "Nag-huna-huna si VinAI", language = "Pinulongan",
		made = "Gihimo ni Vincent (Evilmorty_143)", copy = "Kopyaha", copied = "Nakopya!", select = "Pili",
		chips = { "Himoa ang inventory system sa Lua", "Ipasabot ang RemoteEvents nga sayon", "Pangita sa web: pinakabag-ong tech balita" } },
	Tagalog = { native = "Tagalog", hello = "Kumusta", welcome = "Paano kita matutulungan ngayon?",
		sub = "Magtanong ng kahit ano. Ang Lua scripting ang espesyalidad ko.", newChat = "Bagong chat",
		placeholder = "Magmensahe kay VinAI...", thinking = "Nag-iisip si VinAI", language = "Wika",
		made = "Ginawa ni Vincent (Evilmorty_143)", copy = "Kopyahin", copied = "Nakopya!", select = "Piliin",
		chips = { "Gumawa ng inventory system sa Lua", "Ipaliwanag ang RemoteEvents nang simple", "Maghanap sa web: pinakabagong balita sa tech" } },
	Portuguese = { native = "Português", hello = "Olá", welcome = "Como posso ajudar você hoje?",
		sub = "Pergunte qualquer coisa. Scripting em Lua é minha especialidade.", newChat = "Novo chat",
		placeholder = "Mensagem para o VinAI...", thinking = "O VinAI está pensando", language = "Idioma",
		made = "Feito por Vincent (Evilmorty_143)", copy = "Copiar", copied = "Copiado!", select = "Selecionar",
		chips = { "Crie um sistema de inventário em Lua", "Explique RemoteEvents de forma simples", "Pesquise na web: últimas notícias de tecnologia" } },
	Russian = { native = "Русский", hello = "Привет", welcome = "Чем могу помочь сегодня?",
		sub = "Спрашивайте о чём угодно. Моя специализация — скрипты на Lua.", newChat = "Новый чат",
		placeholder = "Сообщение для VinAI...", thinking = "VinAI думает", language = "Язык",
		made = "Создано Vincent (Evilmorty_143)", copy = "Копировать", copied = "Скопировано!", select = "Выделить",
		chips = { "Напиши систему инвентаря на Lua", "Объясни RemoteEvents простыми словами", "Найди в интернете: свежие новости технологий" } },
}
local lang = STR[CONFIG.DEFAULT_LANGUAGE] and CONFIG.DEFAULT_LANGUAGE or "English"
local function L() return STR[lang] end

local binds = {}
local function bind(fn) fn() table.insert(binds, fn) end
local function refreshLang() for _, fn in ipairs(binds) do fn() end end

------------------------------------------------------------------ TEXT FORMATTING
local function esc(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- tiny markdown -> RichText (bold, inline code, bullets, headings)
local function rich(s)
	local out = {}
	for line in (esc(s) .. "\n"):gmatch("(.-)\n") do
		line = line:gsub("^%s*#+%s*(.+)$", "<b>%1</b>")
		line = line:gsub("^(%s*)[%-%*]%s+", "%1• ")
		line = line:gsub("%*%*(.-)%*%*", "<b>%1</b>")
		line = line:gsub("`([^`]+)`", '<font color="#F2A365">%1</font>')
		out[#out + 1] = line
	end
	return table.concat(out, "\n")
end

-- Lua syntax highlighter
local KW, BI = {}, {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while continue"):gmatch("%S+") do KW[w] = true end
for w in ("game workspace script print warn error task Instance Vector3 Vector2 CFrame Color3 UDim2 Enum pcall require typeof tostring tonumber ipairs pairs table string math"):gmatch("%S+") do BI[w] = true end

local function highlight(code)
	local out, i, n = {}, 1, #code
	local function add(t, color)
		out[#out + 1] = color and ('<font color="' .. color .. '">' .. esc(t) .. "</font>") or esc(t)
	end
	while i <= n do
		local c = code:sub(i, i)
		if code:sub(i, i + 3) == "--[[" then
			local e = select(2, code:find("]]", i + 4, true)) or n
			add(code:sub(i, e), "#6A9955"); i = e + 1
		elseif code:sub(i, i + 1) == "--" then
			local e = code:find("\n", i, true) or (n + 1)
			add(code:sub(i, e - 1), "#6A9955"); i = e
		elseif c == '"' or c == "'" then
			local j = i + 1
			while j <= n do
				local d = code:sub(j, j)
				if d == "\\" then j += 2 elseif d == c or d == "\n" then break else j += 1 end
			end
			add(code:sub(i, j), "#CE9178"); i = j + 1
		elseif c:match("%d") then
			local _, e = code:find("^[%d%.]+", i)
			add(code:sub(i, e), "#B5CEA8"); i = e + 1
		elseif c:match("[%a_]") then
			local _, e = code:find("^[%w_]+", i)
			local w = code:sub(i, e)
			add(w, KW[w] and "#C586C0" or BI[w] and "#4FC1FF" or nil); i = e + 1
		else
			add(c); i += 1
		end
	end
	return table.concat(out)
end

local function parseBlocks(text)
	local blocks, pos = {}, 1
	while true do
		local s, e, bl = text:find("```([%w_%-]*)[ \t]*\n?", pos)
		if not s then break end
		if s > pos then table.insert(blocks, { type = "text", text = text:sub(pos, s - 1) }) end
		local cs, ce = text:find("```", e + 1, true)
		local code
		if cs then code = text:sub(e + 1, cs - 1); pos = ce + 1 else code = text:sub(e + 1); pos = #text + 1 end
		table.insert(blocks, { type = "code", lang = bl, text = (code:gsub("\n+$", "")) })
	end
	if pos <= #text then table.insert(blocks, { type = "text", text = text:sub(pos) }) end
	return blocks
end

------------------------------------------------------------------ UI HELPERS
local function new(class, props, kids)
	local o = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do o[k] = v end
	for _, k in ipairs(kids or {}) do k.Parent = o end
	o.Parent = parent
	return o
end
local function txt(class, props, kids)
	local d = { BackgroundTransparency = 1, BorderSizePixel = 0, Font = FONT, TextColor3 = C.text, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left }
	for k, v in pairs(props) do d[k] = v end
	return new(class, d, kids)
end
local function round(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke() return new("UIStroke", { Color = C.line, Thickness = 1 }) end
local function pad(v, h) return new("UIPadding", { PaddingTop = UDim.new(0, v), PaddingBottom = UDim.new(0, v), PaddingLeft = UDim.new(0, h), PaddingRight = UDim.new(0, h) }) end
local function vlist(gap) return new("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }) end
local function hover(btn, base, over)
	btn.MouseEnter:Connect(function() btn.BackgroundTransparency = over end)
	btn.MouseLeave:Connect(function() btn.BackgroundTransparency = base end)
end
local clip = setclipboard or toclipboard or (Clipboard and Clipboard.set)

------------------------------------------------------------------ WINDOW
local SIDEW = 210
local gui = new("ScreenGui", { Name = "VinAI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, Parent = PlayerGui })

local launcher = new("ImageButton", { Image = CONFIG.LOGO, BackgroundColor3 = C.input, Size = UDim2.fromOffset(52, 52),
	Position = UDim2.new(0, 16, 1, -72), Visible = false, Parent = gui }, { round(26), stroke() })

local main = new("Frame", { Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.72, 0.8), BackgroundColor3 = C.bg, BorderSizePixel = 0, ClipsDescendants = true, Parent = gui },
	{ round(14), stroke(), new("UISizeConstraint", { MinSize = Vector2.new(300, 320), MaxSize = Vector2.new(920, 580) }) })

local sidebar = new("Frame", { BackgroundColor3 = C.side, BorderSizePixel = 0, Size = UDim2.new(0, SIDEW, 1, 0), ZIndex = 5, Parent = main })
local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(SIDEW, 0), Size = UDim2.new(1, -SIDEW, 1, 0), Parent = main })

local function isNarrow()
	local cam = workspace.CurrentCamera
	return math.clamp((cam and cam.ViewportSize.X or 1000) * 0.72, 300, 920) < 560
end
local function setSidebar(open)
	sidebar.Visible = open
	local push = open and not isNarrow()
	content.Position = UDim2.fromOffset(push and SIDEW or 0, 0)
	content.Size = UDim2.new(1, push and -SIDEW or 0, 1, 0)
end

-- top bar
local top = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 48), Parent = content })
new("Frame", { BackgroundColor3 = C.line, BorderSizePixel = 0, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), Parent = top })
local menuBtn = new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = C.input, BackgroundTransparency = 1,
	Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(10, 7), Parent = top }, { round(8) })
for i = 0, 2 do
	new("Frame", { BackgroundColor3 = C.text, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 2), Position = UDim2.fromOffset(9, 10 + i * 6), Parent = menuBtn }, { round(1) })
end
hover(menuBtn, 1, 0.3)
new("ImageLabel", { Image = CONFIG.LOGO, BackgroundColor3 = C.input, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(54, 10), Parent = top }, { round(14) })
txt("TextLabel", { Text = "VinAI", Font = FONT_B, TextSize = 19, TextColor3 = C.white, Size = UDim2.fromOffset(52, 48), Position = UDim2.fromOffset(90, 0), Parent = top },
	{ new("UIGradient", { Color = GEMINI }) })
txt("TextLabel", { Text = "Heavy", TextSize = 12, TextColor3 = C.sub, Size = UDim2.fromOffset(50, 48), Position = UDim2.fromOffset(146, 0), Parent = top })
local closeBtn = txt("TextButton", { Text = "×", TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, AutoButtonColor = false,
	BackgroundColor3 = C.input, BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -44, 0, 7), Parent = top }, { round(8) })
hover(closeBtn, 1, 0.3)

-- dragging
do
	local dragging, startPos, dragStart
	top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- chat area
local scroll = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 1, -140), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.line, Parent = content }, { vlist(16), pad(14, 16) })

local welcome = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -140), Parent = content }, {
	new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
new("ImageLabel", { Image = CONFIG.LOGO, BackgroundColor3 = C.input, Size = UDim2.fromOffset(52, 52), LayoutOrder = 1, Parent = welcome }, { round(26) })
local helloLbl = txt("TextLabel", { TextColor3 = C.white, Font = FONT_B, TextSize = 26, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X,
	LayoutOrder = 2, Parent = welcome }, { new("UIGradient", { Color = GEMINI }) })
local subLbl = txt("TextLabel", { TextSize = 14, TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = welcome })
local chipBox = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = welcome },
	{ vlist(6), new("UISizeConstraint", { MaxSize = Vector2.new(420, 1000) }) })
local chips = {}
for i = 1, 3 do
	chips[i] = txt("TextButton", { TextSize = 13, TextColor3 = C.sub, AutoButtonColor = false, BackgroundColor3 = C.input, BackgroundTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, TextTruncate = Enum.TextTruncate.AtEnd, Parent = chipBox }, { round(16), stroke(), pad(0, 14) })
	hover(chips[i], 0.4, 0)
end
welcome:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() chipBox.Visible = welcome.AbsoluteSize.Y >= 250 end)

-- input
local inputArea = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 0, 1, -92), Size = UDim2.new(1, 0, 0, 92), Parent = content })
local inputBox = new("Frame", { BackgroundColor3 = C.input, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.new(1, -32, 0, 54), Parent = inputArea }, { round(27), stroke(), new("UISizeConstraint", { MaxSize = Vector2.new(740, 54) }) })
local box = txt("TextBox", { Text = "", MultiLine = true, TextWrapped = true, ClearTextOnFocus = false, PlaceholderColor3 = C.sub,
	TextYAlignment = Enum.TextYAlignment.Center, Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -68, 1, 0), Parent = inputBox })
local sendBtn = txt("TextButton", { Text = "↑", Font = FONT_B, TextSize = 22, TextColor3 = C.bg, TextXAlignment = Enum.TextXAlignment.Center,
	AutoButtonColor = false, BackgroundColor3 = C.white, BackgroundTransparency = 0.7, AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(36, 36), Parent = inputBox }, { round(18) })
box:GetPropertyChangedSignal("Text"):Connect(function()
	sendBtn.BackgroundTransparency = box.Text:match("%S") and 0 or 0.7
end)
local online = CONFIG.API_KEY ~= ""
txt("TextLabel", { Text = (online and "Online · Gemini AI + Google Search" or "Offline mode · add your Gemini API key in CONFIG") .. "  ·  Enter sends, Shift+Enter new line",
	TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18), Parent = inputArea })

------------------------------------------------------------------ SIDEBAR
local newBtn = txt("TextButton", { TextSize = 14, AutoButtonColor = false, BackgroundColor3 = C.input, BackgroundTransparency = 0.5,
	Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 40), Parent = sidebar }, { round(10), stroke(), pad(0, 14) })
hover(newBtn, 0.5, 0.1)
bind(function() newBtn.Text = "+  " .. L().newChat end)

local historyList = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 60),
	Size = UDim2.new(1, 0, 1, -150), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.line, Parent = sidebar }, { vlist(2), pad(0, 10) })

local langBtn = txt("TextButton", { TextSize = 13, AutoButtonColor = false, BackgroundColor3 = C.input, BackgroundTransparency = 0.5,
	Position = UDim2.new(0, 10, 1, -78), Size = UDim2.new(1, -20, 0, 36), TextTruncate = Enum.TextTruncate.AtEnd, Parent = sidebar }, { round(10), pad(0, 12) })
hover(langBtn, 0.5, 0.1)
bind(function() langBtn.Text = L().language .. ": " .. L().native end)
txt("TextLabel", { Text = "", TextSize = 11, TextColor3 = C.sub, TextWrapped = true, Position = UDim2.new(0, 14, 1, -38), Size = UDim2.new(1, -28, 0, 32), Parent = sidebar })
local madeLbl = sidebar:FindFirstChildWhichIsA("TextLabel")
bind(function() madeLbl.Text = L().made end)

local langMenu = new("Frame", { BackgroundColor3 = C.input, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -82),
	Size = UDim2.new(1, -20, 0, #LANGS * 32 + 8), Visible = false, ZIndex = 10, Parent = sidebar }, { round(10), stroke(), pad(4, 4), vlist(0) })
local langItems = {}
for i, name in ipairs(LANGS) do
	local b = txt("TextButton", { AutoButtonColor = false, BackgroundColor3 = C.line, BackgroundTransparency = 1, TextSize = 14,
		Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i, ZIndex = 11, Parent = langMenu }, { round(7), pad(0, 10) })
	hover(b, 1, 0.3)
	langItems[name] = b
	bind(function() b.Text = STR[name].native; b.TextColor3 = (name == lang) and C.white or C.sub; b.Font = (name == lang) and FONT_B or FONT end)
	b.MouseButton1Click:Connect(function() lang = name; langMenu.Visible = false; refreshLang() end)
end
langBtn.MouseButton1Click:Connect(function() langMenu.Visible = not langMenu.Visible end)

------------------------------------------------------------------ MESSAGE RENDERING
local order = 0
local function scrollDown()
	task.defer(function()
		RunService.Heartbeat:Wait()
		scroll.CanvasPosition = Vector2.new(0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y))
	end)
end

local function addCode(col, blang, code, idx)
	local frame = new("Frame", { BackgroundColor3 = C.code, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = idx, Parent = col },
		{ round(8), stroke(), vlist(0) })
	local head = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = frame })
	txt("TextLabel", { Text = (blang ~= "" and blang or "lua"), TextSize = 12, TextColor3 = C.sub, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 1, 0), Parent = head })
	local copyBtn = txt("TextButton", { TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Right, AutoButtonColor = false,
		Position = UDim2.new(1, -92, 0, 0), Size = UDim2.fromOffset(80, 28), Parent = head })
	bind(function() copyBtn.Text = clip and L().copy or L().select end)
	local body = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = frame },
		{ pad(8, 12), vlist(0) })
	local isLua = (blang == "" or blang == "lua" or blang == "luau") and #code < 8000
	local view = txt("TextLabel", { Text = isLua and highlight(code) or esc(code), RichText = true, Font = Enum.Font.Code, TextSize = 13,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1, Parent = body })
	local raw = txt("TextBox", { Text = code, Font = Enum.Font.Code, TextSize = 13, TextWrapped = true, MultiLine = true, TextEditable = false,
		ClearTextOnFocus = false, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false, LayoutOrder = 2, Parent = body })
	copyBtn.MouseButton1Click:Connect(function()
		if clip then
			pcall(clip, code)
			copyBtn.Text = L().copied
			task.delay(1.5, function() copyBtn.Text = L().copy end)
		else
			raw.Visible = not raw.Visible; view.Visible = not raw.Visible
		end
	end)
end

local function renderInto(col, text)
	for idx, blk in ipairs(parseBlocks(text)) do
		if blk.type == "code" then
			addCode(col, blk.lang, blk.text, idx)
		elseif blk.text:match("%S") then
			txt("TextLabel", { Text = rich((blk.text:gsub("^\n+", ""):gsub("\n+$", ""))), RichText = true, TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.15, Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = idx, Parent = col })
		end
	end
end

local function addUser(text)
	order += 1
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
	local maxW = math.max(120, scroll.AbsoluteSize.X * 0.78 - 60)
	local ok, b = pcall(TextService.GetTextSize, TextService, text, 15, FONT, Vector2.new(maxW, 10000))
	local w = (ok and math.ceil(math.min(maxW, b.X)) or maxW) + 30
	local bubble = new("Frame", { BackgroundColor3 = C.input, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(w, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row }, { round(16), pad(10, 14) })
	txt("TextLabel", { Text = text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = bubble })
end

local function addAssistant(text)
	order += 1
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, Parent = scroll })
	new("ImageLabel", { Image = CONFIG.LOGO, BackgroundColor3 = C.input, Size = UDim2.fromOffset(28, 28), Parent = row }, { round(14) })
	local col = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -40, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = row }, { vlist(8) })
	if text then renderInto(col, text) end
	return row, col
end

local function addThinking()
	local row, col = addAssistant()
	local lbl = txt("TextLabel", { TextColor3 = C.sub, Size = UDim2.new(1, 0, 0, 28), Parent = col })
	local alive = true
	task.spawn(function()
		local n = 0
		while alive do
			n = n % 3 + 1
			lbl.Text = L().thinking .. string.rep(".", n)
			task.wait(0.4)
		end
	end)
	scrollDown()
	return function() alive = false; row:Destroy() end
end

------------------------------------------------------------------ OFFLINE BRAIN (pure Lua)
local KB = {
	{ keys = { "loop", "for ", "while", "iterate", "ulit" }, text = [==[Here are the loops you'll use most in Luau:

```lua
-- numeric for
for i = 1, 10 do
	print(i)
end

-- array
local fruits = {"apple", "banana", "cherry"}
for index, fruit in ipairs(fruits) do
	print(index, fruit)
end

-- dictionary
local stats = {Health = 100, Speed = 16}
for key, value in pairs(stats) do
	print(key, value)
end

-- repeating loop (always yield inside)
while task.wait(1) do
	print("tick")
end
```]==] },
	{ keys = { "remote", "fireserver", "client", "server" }, text = [==[**RemoteEvents** let the client and server talk. Never trust what the client sends.

Server Script:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("BuyItem")

remote.OnServerEvent:Connect(function(player, itemName)
	if typeof(itemName) ~= "string" then return end -- validate everything
	print(player.Name, "wants", itemName)
end)
```

LocalScript:
```lua
local remote = game:GetService("ReplicatedStorage"):WaitForChild("BuyItem")
remote:FireServer("Sword")
```]==] },
	{ keys = { "tween", "animate", "smooth" }, text = [==[Smoothly move and fade a part with TweenService:

```lua
local TweenService = game:GetService("TweenService")
local part = workspace:WaitForChild("Part")

local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local goal = {Position = part.Position + Vector3.new(0, 10, 0), Transparency = 0.5}
TweenService:Create(part, info, goal):Play()
```]==] },
	{ keys = { "datastore", "save", "data" }, text = [==[Saving player data safely (always wrap in pcall):

```lua
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local store = DataStoreService:GetDataStore("PlayerData")

Players.PlayerAdded:Connect(function(player)
	local ok, data = pcall(store.GetAsync, store, tostring(player.UserId))
	print(ok and data or "no saved data yet")
end)

Players.PlayerRemoving:Connect(function(player)
	local ok, err = pcall(store.SetAsync, store, tostring(player.UserId), {Coins = 100})
	if not ok then warn(err) end
end)
```]==] },
	{ keys = { "leaderstat", "coins", "cash", "money" }, text = [==[A leaderboard with a Coins stat:

```lua
game:GetService("Players").PlayerAdded:Connect(function(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = folder
end)
```]==] },
	{ keys = { "touched", "kill", "brick", "part" }, text = [==[Detect a player touching a part:

```lua
local part = script.Parent
local debounce = false

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid and not debounce then
		debounce = true
		humanoid.Health = 0
		task.wait(1)
		debounce = false
	end
end)
```]==] },
}

local function offlineBrain(userText)
	local lower = userText:lower()
	for _, entry in ipairs(KB) do
		for _, key in ipairs(entry.keys) do
			if lower:find(key, 1, true) then
				return entry.text .. "\n\n(Offline mode: put your API key in CONFIG.API_KEY for Gemini AI.)"
			end
		end
	end
	return "I'm in **offline mode** (no API key set), so I only know a few Lua topics: loops, RemoteEvents, tweens, DataStores, leaderstats and Touched events. Try asking about one of those.\n\nTo unlock the full heavyweight VinAI with deep thinking, web search and every language, paste your Gemini API key into `CONFIG.API_KEY` at the top of the script."
end

------------------------------------------------------------------ ONLINE BRAIN
local function systemPrompt()
	return table.concat({
		"You are VinAI, a heavyweight AI assistant created by Vincent (also known as Evilmorty_143). When asked who made you, say Vincent, also known as Evilmorty_143.",
		"You combine the best of ChatGPT and Gemini: warm, clear, accurate and genuinely helpful on any topic.",
		"Your specialty is Lua and Luau (Roblox). Work like a hardworking senior engineer: think the problem through carefully before you answer, consider edge cases, performance and security (for example, never trust the client in RemoteEvents), and deliver complete, correct, well-commented, production-quality scripts. Mentally test your code before showing it. Use modern Luau (the task library, types where useful) and avoid deprecated APIs like wait() and spawn(). Always say where a script belongs (Script, LocalScript or ModuleScript, and in which service).",
		"For facts, news, prices or anything that may have changed, use Google Search grounding when it is enabled and available. Never pretend you searched if no search results were returned. Lua ideas and code you answer directly from your own knowledge.",
		"You are fluent in English, Spanish, Cebuano, Tagalog (including Taglish), Portuguese and Russian and understand all of them. The user picked " .. lang .. " as their language, so reply in " .. lang .. " unless they write in a different language, in which case match theirs. Keep code and code comments in English unless asked otherwise.",
		"Formatting: the chat supports **bold**, `inline code`, '-' bullet lists and fenced code blocks (```lua). Do not use markdown tables or # headings.",
		"Be honest. If you are unsure, say so. If someone sincerely asks which model powers you, say you are built on a third-party large language model.",
		"Today's date is " .. os.date("!%Y-%m-%d") .. " (UTC).",
	}, "\n\n")
end

local function httpPost(url, headers, body)
	local fn = (typeof(request) == "function" and request) or (typeof(http_request) == "function" and http_request)
		or (typeof(syn) == "table" and syn.request) or (typeof(http) == "table" and http.request)
	local res
	if fn then
		res = fn({ Url = url, Method = "POST", Headers = headers, Body = body })
	else
		res = HttpService:RequestAsync({ Url = url, Method = "POST", Headers = headers, Body = body })
	end
	return res.StatusCode, res.Body
end

local function apiMessages(msgs)
	local out = {}
	for _, m in ipairs(msgs) do
		if not m.err then
			local role = (m.role == "assistant") and "model" or "user"
			local last = out[#out]
			if last and last.role == role then
				last.parts[1].text ..= "\n\n" .. m.content
			else
				out[#out + 1] = { role = role, parts = { { text = m.content } } }
			end
		end
	end
	return out
end

local function ask(history, userText)
	if CONFIG.API_KEY == "" then return offlineBrain(userText) end

	local convo = apiMessages(history)
	local body = {
		contents = convo,
		systemInstruction = { parts = { { text = systemPrompt() } } },
		generationConfig = { maxOutputTokens = CONFIG.MAX_TOKENS },
	}
	if CONFIG.WEB_SEARCH then
		body.tools = { { google_search = {} } }
	end

	local status, raw = httpPost(CONFIG.API_URL .. CONFIG.MODEL .. ":generateContent", {
		["Content-Type"] = "application/json",
		["x-goog-api-key"] = CONFIG.API_KEY,
	}, HttpService:JSONEncode(body))

	local okJ, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not okJ then error("Unreadable Gemini response (HTTP " .. tostring(status) .. ")", 0) end
	if status < 200 or status >= 300 then
		local message = data.error and data.error.message or ("HTTP " .. tostring(status))
		error(message, 0)
	end

	local candidate = data.candidates and data.candidates[1]
	if not candidate then
		local reason = data.promptFeedback and data.promptFeedback.blockReason
		error(reason and ("Gemini blocked the prompt: " .. tostring(reason)) or "Gemini returned no answer", 0)
	end

	local parts = {}
	for _, part in ipairs((candidate.content and candidate.content.parts) or {}) do
		if part.text then parts[#parts + 1] = part.text end
	end
	local reply = table.concat(parts, "\n")
	if not reply:match("%S") then reply = "Gemini returned an empty response. Try rephrasing your message." end

	-- Include grounded web sources when Google Search grounding was used.
	local sources = {}
	local grounding = candidate.groundingMetadata
	for _, chunk in ipairs((grounding and grounding.groundingChunks) or {}) do
		local web = chunk.web
		if web and web.uri and #sources < 5 then
			sources[#sources + 1] = (web.title or "Source") .. " - " .. web.uri
		end
	end
	if #sources > 0 then reply ..= "\n\n**Sources**\n- " .. table.concat(sources, "\n- ") end
	return reply
end

local function friendlyError(e)
	e = tostring(e)
	if e:find("game server") or e:find("HttpService") or e:find("HTTP requests") then
		return "Roblox blocks web requests from LocalScripts in normal games. Run VinAI where a request()/http_request function exists, or route the call through a server script. Details: " .. e
	end
	return "Couldn't get a reply: " .. e
end

------------------------------------------------------------------ CHAT LOGIC
local sessions, cur = {}, nil
local busy = false
local renderAll, refreshHistory

renderAll = function()
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	order = 0
	welcome.Visible = #cur.msgs == 0
	for _, m in ipairs(cur.msgs) do
		if m.role == "user" then addUser(m.content) else addAssistant(m.content) end
	end
	scrollDown()
end

refreshHistory = function()
	for _, c in ipairs(historyList:GetChildren()) do
		if c:IsA("TextButton") then c:Destroy() end
	end
	for i, s in ipairs(sessions) do
		if #s.msgs > 0 then
			local b = txt("TextButton", { Text = s.title, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = false,
				BackgroundColor3 = C.input, BackgroundTransparency = (s == cur) and 0.3 or 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i,
				Parent = historyList }, { round(8), pad(0, 10) })
			b.MouseButton1Click:Connect(function()
				cur = s; renderAll(); refreshHistory()
				if isNarrow() then setSidebar(false) end
			end)
		end
	end
end

local function newChat()
	if not cur or #cur.msgs > 0 then
		cur = { title = "", msgs = {} }
		table.insert(sessions, 1, cur)
		if #sessions > 30 then table.remove(sessions) end
	end
	renderAll(); refreshHistory()
end

local function send(raw)
	local text = (raw:gsub("^%s+", ""):gsub("%s+$", ""))
	if text == "" or busy then return end
	busy = true
	box.Text = ""
	task.delay(0.05, function() if not box.Text:match("%S") then box.Text = "" end end)

	local session = cur
	if #session.msgs == 0 then
		local cut = utf8.offset(text, 31)
		session.title = cut and (text:sub(1, cut - 1) .. "...") or text
	end
	welcome.Visible = false
	table.insert(session.msgs, { role = "user", content = text })
	refreshHistory()
	addUser(text)
	scrollDown()
	local stop = addThinking()

	task.spawn(function()
		local ok, reply = pcall(ask, session.msgs, text)
		stop()
		local entry = ok and { role = "assistant", content = reply } or { role = "assistant", content = friendlyError(reply), err = true }
		table.insert(session.msgs, entry)
		if session == cur then addAssistant(entry.content); scrollDown() end
		busy = false
	end)
end

------------------------------------------------------------------ WIRING
bind(function()
	helloLbl.Text = L().hello .. ", " .. LocalPlayer.DisplayName
	subLbl.Text = L().sub
	box.PlaceholderText = L().placeholder
	for i, chip in ipairs(chips) do chip.Text = L().chips[i] end
end)
for i, chip in ipairs(chips) do
	chip.MouseButton1Click:Connect(function() send(L().chips[i]) end)
end

sendBtn.MouseButton1Click:Connect(function() send(box.Text) end)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Return and box:IsFocused()
		and not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and not UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		task.defer(function() send(box.Text) end)
	end
end)

newBtn.MouseButton1Click:Connect(function()
	newChat()
	if isNarrow() then setSidebar(false) end
end)
local sidebarOpen = not isNarrow()
menuBtn.MouseButton1Click:Connect(function() sidebarOpen = not sidebarOpen; setSidebar(sidebarOpen) end)

local function setVisible(v) main.Visible = v; launcher.Visible = not v end
closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)
launcher.MouseButton1Click:Connect(function() setVisible(true) end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == CONFIG.TOGGLE_KEY then setVisible(not main.Visible) end
end)

setSidebar(sidebarOpen)
newChat()
