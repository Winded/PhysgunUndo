
local Entrylimit = CreateConVar("physgun_history_entrylimit",15,{FCVAR_REPLICATED})

local function Message(ply,text,icon,error)
	if SERVER then
		ply:SendLua("GAMEMODE:AddNotify('"..text.."', "..icon..", 5)")
		if error then
			ply:SendLua("surface.PlaySound('vo/k_lab/kl_fiddlesticks.wav')")
		else
			ply:SendLua("surface.PlaySound('ambient/water/drip"..math.random(1, 4)..".wav')")
		end
	end
end

physundo = {}

function physundo.Create(ent,ply)
	if !ply.pgun_history then ply.pgun_history = {} end
	local entry = {}
	entry.entity = ent
	if ent:GetClass() == "prop_ragdoll" then
		entry.bones = {}
		for i=0,ent:GetPhysicsObjectCount()-1 do
			local obj = ent:GetPhysicsObjectNum(i)
			entry.bones[i] = {}
			entry.bones[i].pos = obj:GetPos()
			entry.bones[i].ang = obj:GetAngles()
			entry.bones[i].frozen = !obj:IsMoveable()
		end
	else
		entry.pos = ent:GetPos()
		entry.ang = ent:GetAngles()
		entry.frozen = false
		if ent:GetPhysicsObjectCount() > 0 then
			entry.frozen = !ent:GetPhysicsObjectNum(0):IsMoveable()
		end
	end
	table.insert(ply.pgun_history,entry)
	if #ply.pgun_history > Entrylimit:GetInt() then
		table.remove(ply.pgun_history,1)
	end
end

local function PerformUndo(ent,entry)
	if ent:GetClass() == "prop_ragdoll" then
		for i=0,ent:GetPhysicsObjectCount()-1 do
			local obj = ent:GetPhysicsObjectNum(i)
			local pos = entry.bones[i].pos
			local ang = entry.bones[i].ang
			obj:EnableMotion(true)
			obj:Sleep()
			obj:SetPos(pos)
			obj:SetAngles(ang)
			obj:EnableMotion(false)
			obj:Wake()
			obj:SetVelocity(Vector(0,0,0))
		end
		for i=0,ent:GetPhysicsObjectCount()-1 do
			if !entry.bones[i].frozen then
				ent:GetPhysicsObjectNum(i):EnableMotion(true)
			end
		end
	else
		local pos = entry.pos
		local ang = entry.ang
		ent:SetPos(pos)
		ent:SetAngles(ang)
		local frozen = entry.frozen
		if ent:GetPhysicsObjectCount() > 0 then
			local obj = ent:GetPhysicsObjectNum(0)
			if frozen then
				obj:EnableMotion(false)
			else
				obj:EnableMotion(true)
			end
			obj:Wake()
			obj:SetVelocity(Vector(0,0,0))
		end
	end
end

hook.Add("PhysgunPickup","physgun_history_pick",function(ply,ent)
	if !IsValid(ent) then return end
	physundo.Create(ent,ply)
end)

concommand.Add("physgun_undo",function(pl,cmd,args)
	if !pl.pgun_history or !pl.pgun_history[#pl.pgun_history] then
		Message(pl,"No physgun history found.",1,true)
		return
	end
	local entry = pl.pgun_history[#pl.pgun_history]
	local ent = entry.entity
	if !IsValid(ent) then
		table.remove(pl.pgun_history,#pl.pgun_history)
		Message(pl,"Physgun movement undone.",0)
		return
	end
	PerformUndo(ent,entry)
	table.remove(pl.pgun_history,#pl.pgun_history)
	Message(pl,"Physgun movement undone.",2)
end)

concommand.Add("physgun_undo_entity",function(pl,cmd,args)
	local ent = pl:GetEyeTrace().Entity
	if !IsValid(ent) then return end
	if !pl.pgun_history or !pl.pgun_history[#pl.pgun_history] then
		Message(pl,"No physgun history found.",1,true)
		return
	end
	local history = pl.pgun_history
	local entry = false
	local id = 1
	for idx=0,#history do
		local i = #history-idx
		if history[i] and history[i].entity == ent then
			entry = history[i]
			id = i
			break
		end
	end
	if !entry then
		Message(pl,"No physgun history found on "..ent:GetClass(),1,true)
		return
	end
	PerformUndo(ent,entry)
	table.remove(pl.pgun_history,id)
	Message(pl,"Physgun movement undone on "..ent:GetClass(),2)
end)