-- feel free to use this wherever!
do 
	local r,g,b,a = 0,0,0,0
	
	local ax,ay,az = 0,0,0
	local bx,by,bz = 0,0,0
	local adx,ady,adz = 0,0,0
	local bdx,bdy,bdz = 0,0,0
	
	local frac = 0
	local wave = 0
	local bendmult = 0
	
	local StartBeam = render.StartBeam
	local AddBeam = render.AddBeam
	local EndBeam = render.EndBeam
	
	local pi = math.pi
	local sin = math.sin
	
	local color_white = color_white
	
	local vector = Vector()
	local color = Color(255, 255, 255, 255)
	
	local lerp = function(m, a, b) return (b - a) * m + a end

	function pac.DrawBeam(veca, vecb, dira, dirb, bend, res, width, start_color, end_color, frequency, tex_stretch, tex_scroll, width_bend, width_bend_size)
		
		if not veca or not vecb or not dira or not dirb then return end
		
		ax = veca.x; ay = veca.y; az = veca.z
		bx = vecb.x; by = vecb.y; bz = vecb.z
		
		adx = dira.x; ady = dira.y; adz = dira.z
		bdx = dirb.x; bdy = dirb.y; bdz = dirb.z
		
		bend = bend or 10
		res = math.max(res or 32, 2)
		width = width or 10
		start_color = start_color or color_white
		end_color = end_color or color_white
		frequency = frequency or 1
		tex_stretch = tex_stretch or 1
		width_bend = width_bend or 0
		width_bend_size = width_bend_size or 1
		tex_scroll = tex_scroll or 0
		
		StartBeam(res + 1)
					
			for i = 0, res do
			
				frac = i / res
				wave = frac * pi * frequency
				bendmult = sin(wave) * bend
				
				vector.x = lerp(frac, ax, bx) + lerp(frac, adx * bendmult, bdx * bendmult)
				vector.y = lerp(frac, ay, by) + lerp(frac, ady * bendmult, bdy * bendmult)
				vector.z = lerp(frac, az, bz) + lerp(frac, adz * bendmult, bdz * bendmult)
										
				color.r = start_color.r == end_color.r and start_color.r or lerp(frac, start_color.r, end_color.r)
				color.g = start_color.g == end_color.g and start_color.g or lerp(frac, start_color.g, end_color.g)
				color.b = start_color.b == end_color.b and start_color.b or lerp(frac, start_color.b, end_color.b)
				color.a = start_color.a == end_color.a and start_color.a or lerp(frac, start_color.a, end_color.a)
				
				AddBeam(
					vector, 					
					width + ((sin(wave) ^ width_bend_size) * width_bend), 					
					(i / tex_stretch) + tex_scroll, 					
					color
				)
				
			end
					
		EndBeam()
	end
end

local PART = {}

PART.ClassName = "beam"

pac.StartStorableVars()
	pac.SetupPartName(PART, "EndPoint")
	pac.GetSet(PART, "Bend", 10)
	pac.GetSet(PART, "Frequency", 1)
	pac.GetSet(PART, "Resolution", 16)
	pac.GetSet(PART, "Width", 1)
	pac.GetSet(PART, "WidthBend", 0)
	pac.GetSet(PART, "WidthBendSize", 1)	
	
	pac.GetSet(PART, "Material", "cable/rope")
	pac.GetSet(PART, "TextureStretch", 1)
	pac.GetSet(PART, "TextureScroll", 0)
	pac.GetSet(PART, "StartColor", Vector(255, 255, 255))
	pac.GetSet(PART, "EndColor", Vector(255, 255, 255))
	pac.GetSet(PART, "StartAlpha", 1)
	pac.GetSet(PART, "EndAlpha", 1)
pac.EndStorableVars()

function PART:GetNiceName()
	return pac.PrettifyName(("/".. self:GetMaterial()):match(".+/(.+)"):gsub("%..+", "")) or "error"
end

function PART:Initialize()
	self:SetMaterial(self.Material)
	
	self.StartColorC = Color(255, 255, 255, 255)	
	self.EndColorC = Color(255, 255, 255, 255)
end

function PART:SetStartColor(v)
	self.StartColorC = self.StartColorC or Color(255, 255, 255, 255)
	
	self.StartColorC.r = v.r
	self.StartColorC.g = v.g
	self.StartColorC.b = v.b
	
	self.StartColor = v
end

function PART:SetEndColor(v)
	self.EndColorC = self.EndColorC or Color(255, 255, 255, 255)
	
	self.EndColorC.r = v.r
	self.EndColorC.g = v.g
	self.EndColorC.b = v.b
	
	self.EndColor = v
end

function PART:SetStartAlpha(n)
	self.StartColorC = self.StartColorC or Color(255, 255, 255, 255)
	
	self.StartColorC.a = n * 255
	
	self.StartAlpha = n
end

function PART:SetEndAlpha(n)
	self.EndColorC = self.EndColorC or Color(255, 255, 255, 255)
	
	self.EndColorC.a = n * 255
	
	self.EndAlpha = n
end

function PART:FixMaterial()
	local mat = self.Materialm
	
	if not mat then return end
	
	local shader = mat:GetShader()
	
	if shader == "VertexLitGeneric" or shader == "Cable" then
		local tex_path = mat:GetString("$basetexture")
		
		if tex_path then		
			local params = {}
			
			params["$basetexture"] = tex_path
			params["$vertexcolor"] = 1
			params["$vertexalpha"] = 1
			
			self.Materialm = CreateMaterial(tostring(self) .. "_pac_trail", "UnlitGeneric", params)
		end		
	end
end

function PART:SetMaterial(var)
	var = var or ""
	
	self.Material = var
	
	if not pac.Handleurltex(self, var) then
		if type(var) == "string" then
			self.Materialm = pac.Material(var, self)
			self:FixMaterial()
			self:CallEvent("material_changed")
		elseif type(var) == "IMaterial" then
			self.Materialm = var
			self:FixMaterial()
			self:CallEvent("material_changed")
		end
	end	
end

function PART:OnDraw(owner, pos, ang)
	local part = self.EndPoint
	if self.Materialm and self.StartColorC and self.EndColorC and part:IsValid() then
		render.SetMaterial(self.Materialm)
		--(veca, vecb, dira, dirb, bend, res, width, start_color, end_color, frequency, tex_stretch, width_bend, width_bend_size)
		pac.DrawBeam(
		
			pos, 
			part.cached_pos, 
			
			ang:Forward(), 			
			part.cached_ang:Forward(), 
			
			self.Bend, 
			self.Resolution, 
			self.Width, 
			self.StartColorC, 
			self.EndColorC, 
			self.Frequency, 
			self.TextureStretch, 
			self.TextureScroll, 
			self.WidthBend, 
			self.WidthBendSize
		)
	end
end

pac.RegisterPart(PART)