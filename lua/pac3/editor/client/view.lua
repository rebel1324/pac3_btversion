local acsfnc = function(key, def) 
	pace["View" .. key] = def
	pace["SetView" .. key] = function(val) pace["View" .. key] = val end 
	pace["GetView" .. key] = function() return pace["View" .. key] or def end 
end

acsfnc("Entity", NULL)
acsfnc("Pos", Vector(5,5,5))
acsfnc("Angles", Angle(0,0,0))
acsfnc("FOV", 75)

function pace.GetViewEntity()
	return pace.ViewEntity:IsValid() and pace.ViewEntity or LocalPlayer()
end

function pace.ResetView()
	if pace.Focused then
		local ent = pace.GetViewEntity()
		
		if not ent:IsValid() then
			local _, part = next(pac.GetParts(true))
			if part then
				ent = part:GetOwner()
			end
		end
		
		if ent:IsValid() then
			pace.ViewPos = ent:EyePos() + Vector(50, 0, 0)
			pace.ViewAngles = (ent:EyePos() - pace.ViewPos):Angle()
		end
	end
end

function pace.OnMouseWheeled(delta)
	local mult = 5
	
	if input.IsKeyDown(KEY_LCONTROL) then
		mult = 1
	end

	if input.IsKeyDown(KEY_LSHIFT) then
		mult = 10
	end
	
	delta = delta * mult
	
	pace.ViewFOV = math.Clamp(pace.ViewFOV - delta, 1, 75)
end

local held_ang = Angle(0,0,0)
local held_mpos = Vector(0,0,0)
local mcode

function pac.GUIMousePressed(mc)
	if pace.mctrl.GUIMousePressed(mc) then return end
	
	if mc == MOUSE_LEFT and not pace.editing_viewmodel then
		held_ang = pace.ViewAngles*1
		held_mpos = Vector(gui.MousePos())
	end

	if mc == MOUSE_RIGHT then
		pace.Call("OpenMenu")
	end

	mcode = mc
end

function pac.GUIMouseReleased(mc)
	if pace.mctrl.GUIMouseReleased(mc) then return end
	
	if pace.editing_viewmodel then return end

	mcode = nil
end

local function CalcDrag()
	if 
		pace.BusyWithProperties:IsValid() or
		pace.ActiveSpecialPanel:IsValid() or
		pace.editing_viewmodel 
	then return end

	
	local ftime = FrameTime() * 50
	local mult = 5
	
	if input.IsKeyDown(KEY_LCONTROL) then
		mult = 0.1
	end
	
	if pace.current_part:IsValid() then		
		local origin
		
		local owner = pace.current_part:GetOwner(true)
		
		if owner == pac.WorldEntity then
			if pace.current_part:HasChildren() then
				for key, child in pairs(pace.current_part:GetChildren()) do
					if not child.NonPhysical then
						origin = child:GetDrawPosition()
						break
					end
				end
			else
				origin = LocalPlayer():GetPos()
			end			
			
			if not origin then
				origin = owner:GetPos()
			end
		elseif pace.current_part.NonPhysical and owner:IsValid() then
			origin = owner:GetPos()
		else
			origin = pace.current_part:GetDrawPosition()
		end
		
		mult = mult * (origin:Distance(pace.ViewPos) / 200)
	end
	
	if input.IsKeyDown(KEY_LSHIFT) then
		mult = mult + 5
	end
	
	if input.IsKeyDown(KEY_UP) or input.IsMouseDown(MOUSE_WHEEL_UP) then
		pace.OnMouseWheeled(0.25)
	elseif input.IsKeyDown(KEY_DOWN) or input.IsMouseDown(MOUSE_WHEEL_DOWN) then
		pace.OnMouseWheeled(-0.25)
	end
	
	if not pace.IsSelecting then
		if mcode == MOUSE_LEFT then
			local delta = (held_mpos - Vector(gui.MousePos())) / 5 * math.rad(pace.ViewFOV)
			pace.ViewAngles.p = math.Clamp(held_ang.p - delta.y, -90, 90)
			pace.ViewAngles.y = held_ang.y + delta.x
		end
	end

	if input.IsKeyDown(KEY_W) then
		pace.ViewPos = pace.ViewPos + pace.ViewAngles:Forward() * mult * ftime
	elseif input.IsKeyDown(KEY_S) then
		pace.ViewPos = pace.ViewPos - pace.ViewAngles:Forward() * mult * ftime
	end

	if input.IsKeyDown(KEY_D) then
		pace.ViewPos = pace.ViewPos + pace.ViewAngles:Right() * mult * ftime
	elseif input.IsKeyDown(KEY_A) then
		pace.ViewPos = pace.ViewPos - pace.ViewAngles:Right() * mult * ftime
	end

	if input.IsKeyDown(KEY_SPACE) then
		pace.ViewPos = pace.ViewPos + pace.ViewAngles:Up() * mult * ftime
	end
	
	--[[if input.IsKeyDown(KEY_LALT) then
		pace.ViewPos = pace.ViewPos + pace.ViewAngles:Up() * -mult * ftime
	end]]
end

local follow_entity = CreateConVar("pac_camera_follow_entity", "0")

function pac.CalcView(ply, pos, ang, fov)
	if pace.editing_viewmodel then 
		pace.ViewPos = pos
		pace.ViewAngles = ang
		pace.ViewFOV = fov
	return end

	if follow_entity:GetBool() then
		local ent = pace.GetViewEntity()
		pace.ViewPos = pace.ViewPos + (ent:GetVelocity() * FrameTime())
	end
	
	if pac.GetRestrictionLevel() > 0 then
		local ent = pace.GetViewEntity()
		local dir = pace.ViewPos - ent:EyePos()
		local dist = ent:BoundingRadius() * ent:GetModelScale() * 4
				
		if dir:Length() > dist then
			pace.ViewPos = ent:EyePos() + (dir:GetNormalized() * dist)
		end
		
		local res = util.TraceHull({start = ent:EyePos(), endpos = pace.ViewPos, filter = ent, mins = Vector(1,1,1)*-8, maxs = Vector(1,1,1)*8})
		if res.Hit then
			pace.ViewPos = res.HitPos
		end
	end	

	return
	{
		origin = pace.ViewPos,
		angles = pace.ViewAngles,
		fov = pace.ViewFOV,
	}
end

function pac.ShouldDrawLocalPlayer()
	if not pace.editing_viewmodel then
		return true
	end
end

function pace.EnableView(b)
	if b then
		pac.AddHook("GUIMousePressed")
		pac.AddHook("GUIMouseReleased")
		pac.AddHook("ShouldDrawLocalPlayer")
		pac.AddHook("CalcView")
		pac.AddHook("HUDPaint")
		pac.AddHook("HUDShouldDraw")
		pace.Focused = true
		pace.ResetView()
	else
		pac.RemoveHook("GUIMousePressed")
		pac.RemoveHook("GUIMouseReleased")
		pac.RemoveHook("ShouldDrawLocalPlayer")
		pac.RemoveHook("CalcView")
		pac.RemoveHook("HUDPaint")
		pac.RemoveHook("HUDShouldDraw")
		pace.SetTPose(false)
		pace.SetBreathing(false)
	end
end

local function CalcAnimationFix(ent)
	if ent.SetEyeAngles then
		ent:SetEyeAngles(Angle(0,0,0))
	end
end

local reset_pose_params =
{
	"body_rot_z",
	"spine_rot_z",
	"head_rot_z",
	"head_rot_y",
	"head_rot_x",
	"walking",
	"running",
	"swimming",
	"rhand",
	"lhand",
	"rfoot",
	"lfoot",
	"move_yaw",
	"aim_yaw",
	"aim_pitch",
	"breathing",
	"vertical_velocity",
	"vehicle_steer",
	"body_yaw",
	"spine_yaw",
	"head_yaw",
	"head_pitch",
	"head_roll",
}

function pace.GetTPose()
	return pace.tposed
end

function pace.SetViewPart(part, reset_campos)	
	pace.SetViewEntity(part:GetOwner())

	if reset_campos then
		pace.ResetView()
	end	
end

function pac.HUDPaint()
	if mcode and not input.IsMouseDown(mcode) then
		mcode = nil
	end
	
	local ent = pace.GetViewEntity()
	
	if pace.IsFocused() then
		CalcDrag()
	
		if ent:IsValid() then
			pace.Call("Draw", ScrW(), ScrH())
		end
	end
end

function pac.HUDShouldDraw(typ)
	if 
		typ == "CHudEPOE" or
		(typ == "CHudCrosshair" and pace.editing_viewmodel)
	then
		return false
	end
end