--!strict
-- Ícones da UI em imagem (Universal Icons → icons/render.mjs → PNG com contorno Ink → Roblox).
-- A chave é o emoji que o ícone substitui: Style.glyph troca o emoji por imagem onde houver,
-- e o resto continua emoji (textos corridos como "💎 75" seguem em texto).
-- Para um ícone novo: adicione no icons/render.mjs, renderize, suba e cole o id aqui.

return table.freeze({
	["☄️"] = "rbxassetid://95905545389303", -- Meteor
	["🌪️"] = "rbxassetid://103980136458498", -- Tornado
	["⚡"] = "rbxassetid://132079362393780", -- Lightning
	["🔥"] = "rbxassetid://136286821909240", -- Fire
	["🏚️"] = "rbxassetid://85180361615683", -- Quake
	["🛒"] = "rbxassetid://94638679259084", -- Shop
	["🎡"] = "rbxassetid://77495916372424", -- Spin
	["🎁"] = "rbxassetid://78667097152483", -- Gift
	["⚔️"] = "rbxassetid://101623169583186", -- Class
	["⏱️"] = "rbxassetid://132431213829295", -- Recharge
	["🎯"] = "rbxassetid://117744580622720", -- Reach
	["⭐"] = "rbxassetid://85957081439184", -- Xp
	["💵"] = "rbxassetid://85137471308254", -- Cash
	["💎"] = "rbxassetid://138226624489861", -- Gem
	["🏆"] = "rbxassetid://130853023326881", -- Trophy
} :: { [string]: string })
