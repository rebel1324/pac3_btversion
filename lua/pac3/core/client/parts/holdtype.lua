local PART = {}

PART.ClassName = "holdtype"
PART.NonPhysical = true
PART.ThinkTime = 0

local act_mods =
{
	"ACT_MP_STAND_IDLE",
	"ACT_MP_WALK",
	"ACT_MP_RUN",
	"ACT_MP_CROUCH_IDLE",
	"ACT_MP_CROUCHWALK",
	"ACT_MP_ATTACK_STAND_PRIMARYFIRE",
	"ACT_MP_ATTACK_CROUCH_PRIMARYFIRE",
	"ACT_MP_RELOAD_STAND",
	"ACT_MP_RELOAD_CROUCH",
	"ACT_MP_JUMP",
	"ACT_LAND",
	"ACT_RANGE_ATTACK1",
	"ACT_MP_SWIM_IDLE",
	"ACT_MP_SWIM",
}

do
	local temp = {}

	for key, act in pairs(act_mods) do

		local key = act
		key = "_" .. key
		key = key:gsub("ACT_MP_", "")
		key = key :lower()
		key = key:gsub("_(.)", function(char) 
			return char:upper() 
		end)
		
		temp[key] = _G[act]
	end
	
	-- ew
	if temp.Crouchwalk then
		temp.CrouchWalk = temp.Crouchwalk
		temp.Crouchwalk = nil
	end
	
	act_mods = temp
end

PART.ActMods = act_mods

pac.StartStorableVars()
	for name in pairs(act_mods) do
		pac.GetSet(PART, name, "")
	end
	
	pac.GetSet(PART, "Fallback", "")
	pac.GetSet(PART, "Noclip", "")
	pac.GetSet(PART, "Air", "")
	pac.GetSet(PART, "Sitting", "")
	pac.GetSet(PART, "AlternativeRate", false)
pac.EndStorableVars()

for name, act in pairs(act_mods) do
	PART["Set" .. name] = function(self, str)
		self[name] = str
		
		self:UpdateActTable()
	end
end

function PART:SetFallback(str)
	self.Fallback = str
	self:UpdateActTable()
end

function PART:UpdateActTable()
	self.ActTable = self.ActTable or {}
	
	local ent = self:GetOwner(true)
	
	if ent:IsValid() then
		ent.pac_holdtype_alternative_animation_rate = self.AlternativeRate
		
		for name, act in pairs(act_mods) do
			self.ActTable[act] = ent:GetSequenceActivity(ent:LookupSequence(self[name]))
		end
		
		ent.pac_acttable = self.ActTable
		
		-- custom acts
		ent.pac_acttable.fallback = ent:GetSequenceActivity(ent:LookupSequence(self.Fallback))
		ent.pac_acttable.noclip = ent:GetSequenceActivity(ent:LookupSequence(self.Noclip))
		ent.pac_acttable.air = ent:GetSequenceActivity(ent:LookupSequence(self.Air))
		ent.pac_acttable.sitting = ent:GetSequenceActivity(ent:LookupSequence(self.Sitting))
		
		ent.pac_holdtype_part = self
	end
end

function PART:GetSequenceList()
	local ent = self:GetOwner()

	if ent:IsValid() then	
		return ent:GetSequenceList()
	end
	return {"none"}
end

function PART:Disable()
	local ent = self:GetOwner(true)

	if ent:IsValid() and ent.pac_holdtype_part == self then
		ent.pac_acttable = nil
		ent.pac_holdtype_alternative_animation_rate = nil
	end
end

function PART:Enable()
	self:UpdateActTable()
end

function PART:OnHide()
	self:Disable()
	self.invalidate = true
end

function PART:OnShow(from_event, from_drawing)
	self:Enable()
	self.invalidate = true
end

function PART:OnThink()
	if self.invalidate then
		if self:IsHidden() then
			self:Disable()
		else
			self:Enable()
		end
		self.invalidate =  false
	end
end

pac.RegisterPart(PART)