local L = pace.LanguageString

function pace.WearParts(file, clear)
	if file then
		pace.LoadParts(file, clear)
	end

	for key, part in pairs(pac.GetParts(true)) do
		if not part:HasParent() then
			pace.SendPartToServer(part)
		end
	end
end

function pace.ClearParts()
	pac.RemoveAllParts(true, true)
	pace.RefreshTree()
	
	timer.Simple(0.1, function()
		if not pace.Editor:IsValid() then return end
	
		if table.Count(pac.GetParts(true)) == 0 then
			pace.Call("CreatePart", "group", L"my outfit", L"add parts to me!")
		end	
			
		pace.TrySelectPart()
	end)
end

function pace.OnCreatePart(class_name, name, desc, mdl)
	local part = pac.CreatePart(class_name)
	
	if name then part:SetName(name) end
	
	local parent = pace.current_part
	
	if parent:IsValid() then	
		part:SetParent(parent)
	end
	
	if desc then part:SetDescription(desc) end
	if mdl then part:SetModel(mdl) end
	
	local ply = LocalPlayer()
	
	if part:GetPlayerOwner() == ply then
		pace.SetViewPart(part)
	end

	pace.Call("PartSelected", part)
	
	part.newly_created = true
		
	if not part.NonPhysical and parent:IsValid() and not parent:HasParent() and parent.OwnerName == "world" and part:GetPlayerOwner() == ply then
		local data = ply:GetEyeTrace()
		
		if data.HitPos:Distance(ply:GetPos()) < 1000 then
			part:SetPosition(data.HitPos)
		else
			part:SetPosition(ply:GetPos())
		end
	end
	
	pace.RefreshTree()	
end

function pace.OnPartSelected(part, is_selecting)
	local parent = part:GetRootPart()
	if parent:IsValid() and parent.OwnerName == "viewmodel" then
		pace.editing_viewmodel = true
	elseif pace.editing_viewmodel then
		pace.editing_viewmodel = false
	end

	pace.PopulateProperties(part)
	pace.mctrl.SetTarget(part)
	pace.current_part = part
	
	pace.SetViewPart(part)
	
	pace.Editor:InvalidateLayout()
	
	pace.SafeRemoveSpecialPanel()
	
	if pace.tree:IsValid() then
		pace.tree:SelectPart(part)
	end
	
	pace.current_part_uid = part.UniqueID
	
	if not is_selecting then
		pace.StopSelect()
	end
end

function pace.OnVariableChanged(obj, key, val, undo_delay)
	local func = obj["Set" .. key]
	if func then
	
		if key == "OwnerName" then
			if val == "viewmodel" then
				pace.editing_viewmodel = true
			elseif obj[key] == "viewmodel" then
				pace.editing_viewmodel = false
			end
		end
		
		func(obj, val)
	
		pace.CallChangeForUndo(obj, key, val, undo_delay)
		
		local node = obj.editor_node
		if IsValid(node) then		
			if key == "Name" then
				if not obj:HasParent() then
					pace.RemovePartOnServer(obj:GetUniqueID(), false, true)
				end
				node:SetText(val)
			elseif key == "Model" and val and val ~= "" then
				node:SetModel(val)
			elseif key == "Parent" then
				local tree = obj.editor_node
				if IsValid(tree) then
					node:Remove()
					tree = tree:GetRoot()
					if tree:IsValid() then
						tree:SetSelectedItem(nil)
						pace.RefreshTree(true)
					end
				end
			end
						
			if obj.Name == "" then
				node:SetText(obj:GetName())
			end
		end		
	end
	
	timer.Create("autosave_Parts", 0.5, 1, function()
		for k,v in pairs(pac.GetParts(true)) do
			if v:HasChildren() then
				pace.SaveParts("autosave")
				break
			end
		end
	end)
end

do -- menu
	function pace.AddRegisteredPartsToMenu(menu)
		local temp = {}
		
		for class_name, tbl in pairs(pac.GetRegisteredParts()) do
			
			if pace.IsInBasicMode() and not pace.BasicParts[class_name] then continue end
			if not pace.IsShowingDeprecatedFeatures() and pace.DeprecatedParts[class_name] then continue end
			
			if not tbl.Internal then
				table.insert(temp, class_name)
			end
		end
		
		table.sort(temp)
		
		for _, class_name in pairs(temp) do
			menu:AddOption(L(class_name), function()
				pace.Call("CreatePart", class_name)
			end):SetImage(pace.PartIcons[class_name])
		end
	end


	function pace.OnPartMenu(obj)
		local menu = DermaMenu()
		menu:SetPos(gui.MousePos())
			
		if not obj:HasParent() then
			menu:AddOption(L"wear", function()
				pace.SendPartToServer(obj)
			end):SetImage(pace.MiscIcons.wear)
		end

		menu:AddOption(L"copy", function()
			local tbl = obj:ToTable()
				tbl.self.Name = nil
				tbl.self.Description = nil
				tbl.self.ParentName = nil
				tbl.self.Parent = nil
				tbl.self.UniqueID = nil
				
				tbl.children = {}
			pace.Clipboard = tbl
		end):SetImage(pace.MiscIcons.copy)
	
		menu:AddOption(L"paste", function()
			if pace.Clipboard then
				obj:SetTable(pace.Clipboard)
			end
			--pace.Clipboard = nil
		end):SetImage(pace.MiscIcons.paste)
		
		menu:AddOption(L"clone", function()
			obj:Clone()
		end):SetImage(pace.MiscIcons.clone)		
		
		if not pace.IsInBasicMode() then
			menu:AddOption(L"copy global id", function()
				SetClipboardText("\""..obj.GlobalID.."\"")
			end):SetImage(pace.MiscIcons.globalid)
		end
		
		menu:AddOption(L"help", function()
			pace.ShowHelp(obj.ClassName)
		end):SetImage(pace.MiscIcons.help)
		
		menu:AddSpacer()

		pace.AddRegisteredPartsToMenu(menu)

		menu:AddSpacer()

		local save, pnl = menu:AddSubMenu(L"save", function() pace.SaveParts() end)
		pnl:SetImage(pace.MiscIcons.save)
		pace.AddSaveMenuToMenu(save, obj)	
		
		local load, pnl = menu:AddSubMenu(L"load", function() pace.LoadParts() end)
		pnl:SetImage(pace.MiscIcons.load)
		pace.AddSavedPartsToMenu(load, false, obj)
		
		menu:AddOption(L"load from url", function()
				Derma_StringRequest(
				L"load part",
				L"pastebin urls also work!",
				"",

				function(url)
					pace.LoadParts(url, true, obj)
				end
			)
		end):SetImage(pace.MiscIcons.url)
		
		menu:AddOption(L"remove", function()
			obj:Remove()
			pace.RefreshTree()
			if not obj:HasParent() and obj.ClassName == "group" then
				pace.RemovePartOnServer(obj:GetUniqueID(), false, true)
			end
		end):SetImage(pace.MiscIcons.clear)

		menu:Open()
		menu:MakePopup()
	end

	function pace.OnNewPartMenu()
		pace.current_part = pac.NULL
		local menu = DermaMenu()
		menu:MakePopup()
		menu:SetPos(gui.MousePos())
		
		pace.AddRegisteredPartsToMenu(menu)
		
		menu:AddSpacer()
			
		local load, pnl = menu:AddSubMenu(L"load", function() pace.LoadParts() end)
		pnl:SetImage(pace.MiscIcons.load)
		pace.AddSavedPartsToMenu(load, false, obj)
		
		menu:AddOption(L"clear", function()
			pace.ClearParts()
		end):SetImage(pace.MiscIcons.clear)	
		
	end
end

function pace.OnHoverPart(obj)
	obj:Highlight()
end

hook.Add("pac_OnPartParent", "pace_parent", function(parent, child)
	pace.Call("VariableChanged",parent, "Parent", child)
end)