-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local CombatCore = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))

function CombatCore.CalculateDamage(attacker, defender, skillMult, targetLimb)
	local atkBuff = 1.0
	local defBuff = 1.0

	if attacker.Statuses then
		if (tonumber(attacker.Statuses.Buff_Strength) or 0) > 0 then atkBuff = 1.5 end
		if (tonumber(attacker.Statuses.Weakened) or 0) > 0 then atkBuff = atkBuff * 0.5 end
	end

	if defender.Statuses then
		if (tonumber(defender.Statuses.Buff_Defense) or 0) > 0 then defBuff = 1.5 end
		if (tonumber(defender.Statuses.Crippled) or 0) > 0 then defBuff = defBuff * 0.5 end
	end

	local atkStrength = tonumber(attacker.TotalStrength) or 10
	local defArmor = tonumber(defender.TotalDefense) or 10

	local isAttackerTransformed = attacker.Statuses and (tonumber(attacker.Statuses.Transformed) or 0) > 0
	local isDefenderTransformed = defender.Statuses and (tonumber(defender.Statuses.Transformed) or 0) > 0

	-- [[ REBALANCE: Reduced the scaling division to heavily nerf the Titan Multiplier ]]
	if attacker.IsPlayer and isAttackerTransformed then
		local titanPower = tonumber(attacker.PlayerObj:GetAttribute("Titan_Power_Val")) or 10
		atkStrength = atkStrength * (1.0 + (titanPower / 35.0))
	end
	if defender.IsPlayer and isDefenderTransformed then
		local titanHardening = tonumber(defender.PlayerObj:GetAttribute("Titan_Hardening_Val")) or 10
		defArmor = defArmor * (1.0 + (titanHardening / 35.0))
	end

	skillMult = tonumber(skillMult) or 1.0
	local baseDmg = atkStrength * atkBuff * skillMult
	targetLimb = tostring(targetLimb or "Body")

	if targetLimb == "Nape" then
		if defender.Statuses and (tonumber(defender.Statuses.NapeGuard) or 0) > 0 then
			return 1
		else
			baseDmg = baseDmg * 1.5 
		end
	elseif targetLimb == "Legs" or targetLimb == "Arms" then 
		baseDmg = baseDmg * 0.5
	elseif targetLimb == "Eyes" then 
		baseDmg = baseDmg * 0.2 
	end

	local effectiveArmor = defArmor * defBuff

	if attacker.AwakenedStats and (tonumber(attacker.AwakenedStats.IgnoreArmor) or 0) > 0 then
		effectiveArmor = effectiveArmor * (1.0 - (tonumber(attacker.AwakenedStats.IgnoreArmor) or 0))
	end
	effectiveArmor = math.max(0, effectiveArmor)

	local defenseMultiplier = 1.0

	if defender.IsPlayer then
		local dClanFull = tostring(defender.Clan or "None")
		local dIsAwakened = string.find(dClanFull, "Awakened") ~= nil
		local dBaseClan = string.gsub(dClanFull, "Awakened ", "")
		local dTitan = tostring(defender.Titan or "None")

		if dBaseClan == "Braun" then 
			effectiveArmor = effectiveArmor * (dIsAwakened and 1.40 or 1.20) 
		end

		if dBaseClan == "Braun" and string.find(dTitan, "Armored Titan") and isDefenderTransformed then
			effectiveArmor = effectiveArmor * 1.50 
		end
	end

	if attacker.IsPlayer then
		baseDmg = baseDmg * 4.0 
		local clanDmgMult = 1.0

		local aClanFull = tostring(attacker.Clan or "None")
		local aIsAwakened = string.find(aClanFull, "Awakened") ~= nil
		local aBaseClan = string.gsub(aClanFull, "Awakened ", "")
		local aTitan = tostring(attacker.Titan or "None")

		if aBaseClan == "Galliard" then clanDmgMult += (aIsAwakened and 0.15 or 0.05) end

		if isAttackerTransformed then
			if aBaseClan == "Tybur" then clanDmgMult += (aIsAwakened and 0.40 or 0.20) end
			if aBaseClan == "Yeager" then clanDmgMult += (aIsAwakened and 0.50 or 0.25) end

			if aBaseClan == "Yeager" and string.find(aTitan, "Attack Titan") then clanDmgMult += 0.30 end 
			if aBaseClan == "Tybur" and string.find(aTitan, "War Hammer") then clanDmgMult += 0.30 end 
		else
			if aBaseClan == "Ackerman" then clanDmgMult += (aIsAwakened and 0.50 or 0.25) end
		end
		baseDmg = baseDmg * clanDmgMult

		local expiry = attacker.PlayerObj and tonumber(attacker.PlayerObj:GetAttribute("Buff_Damage_Expiry")) or 0
		if expiry > os.time() then baseDmg = baseDmg * 1.5 end

		defenseMultiplier = math.clamp(300 / (300 + effectiveArmor), 0.15, 1.0)
	else
		baseDmg = baseDmg * 0.75 
		defenseMultiplier = math.clamp(150 / (150 + (effectiveArmor * 3)), 0.05, 1.0)
	end

	if defender.IsPlayer and isDefenderTransformed then
		baseDmg = baseDmg * 0.50
	end

	if attacker.AwakenedStats and (tonumber(attacker.AwakenedStats.DmgMult) or 1.0) > 1.0 then
		baseDmg = baseDmg * (tonumber(attacker.AwakenedStats.DmgMult) or 1.0)
	end

	local finalDmg = baseDmg * defenseMultiplier
	return math.max(1, finalDmg)
end

function CombatCore.TakeDamage(combatant, damage, attackerStyle)
	local actualDmg = tonumber(damage) or 0
	local hitGate = false
	local gateBroken = false
	local gateName = tostring(combatant.GateType or "Shield")

	local gateHP = tonumber(combatant.GateHP) or 0
	if gateHP > 0 then
		hitGate = true
		if combatant.GateType == "Steam" then actualDmg = 0 
		else
			if combatant.GateType == "Reinforced Skin" and tostring(attackerStyle) == "Thunder Spears" then actualDmg = actualDmg * 3.0 end
			if actualDmg >= gateHP then
				actualDmg = actualDmg - gateHP; combatant.GateHP = 0; gateBroken = true
			else 
				combatant.GateHP = gateHP - actualDmg; actualDmg = 0 
			end
		end
	end

	local survivalTriggered = false
	if actualDmg > 0 then
		local currentHP = tonumber(combatant.HP) or 0
		if (currentHP - actualDmg) < 1 then
			local resolveStat = tonumber(combatant.TotalResolve) or 10
			local cClanFull = tostring(combatant.Clan or "None")
			local cIsAwakened = string.find(cClanFull, "Awakened") ~= nil
			local cBaseClan = string.gsub(cClanFull, "Awakened ", "")

			if combatant.IsPlayer and cBaseClan == "Arlert" then resolveStat = resolveStat * (cIsAwakened and 1.30 or 1.15) end

			local survivalChance = math.clamp(resolveStat * 0.7, 0, 45)
			local maxSurvivals = 1
			if combatant.IsPlayer and cBaseClan == "Ackerman" then 
				survivalChance = 100; maxSurvivals = cIsAwakened and 3 or 1 
			end

			local usedSurvivals = tonumber(combatant.ResolveSurvivals) or 0
			if usedSurvivals < maxSurvivals and math.random(1, 100) <= survivalChance then
				combatant.HP = 1; combatant.ResolveSurvivals = usedSurvivals + 1; survivalTriggered = true 
			else 
				combatant.HP = currentHP - actualDmg 
			end
		else 
			combatant.HP = currentHP - actualDmg 
		end
	end
	return survivalTriggered, hitGate, gateBroken, actualDmg, gateName
end

function CombatCore.ExecuteStrike(attacker, defender, skillName, targetLimb, logName, defName, logColor, defColor)
	skillName = tostring(skillName or "Brutal Swipe")
	targetLimb = tostring(targetLimb or "Body")

	local fallbackSkill = { Mult = 1.0, Cooldown = 0, Hits = 1, Effect = "None", Description = "A basic attack." }
	local skill = SkillData.Skills[skillName] or SkillData.Skills["Brutal Swipe"] or fallbackSkill

	local fLogName = "<font color='" .. tostring(logColor or "#FFFFFF") .. "'>" .. tostring(logName or "Attacker") .. "</font>"
	local fDefName = "<font color='" .. tostring(defColor or "#FF5555") .. "'>" .. tostring(defName or "Defender") .. "</font>"

	if attacker.Cooldowns then attacker.Cooldowns[skillName] = tonumber(skill.Cooldown) or 0 end

	local defGateHP = tonumber(defender.GateHP) or 0
	if (skill.Effect == "Block" or skillName == "Maneuver" or skillName == "Evasive Maneuver") and defender.GateType == "Steam" and defGateHP > 0 then 
		if attacker.Cooldowns then attacker.Cooldowns[skillName] = 0 end 
	end

	local isSequenceCombo = false; local comboMult = 1.0
	local lastAtkSkill = tostring(attacker.LastSkill or "None")

	if skill.ComboReq and lastAtkSkill == skill.ComboReq then 
		isSequenceCombo = true; comboMult = tonumber(skill.ComboMult) or 1.5 
	end

	if skill.Effect == "Block" or skillName == "Maneuver" or skillName == "Evasive Maneuver" then
		if not attacker.Statuses then attacker.Statuses = {} end
		local blind = tonumber(attacker.Statuses.Blinded) or 0
		local trueBlind = tonumber(attacker.Statuses.TrueBlind) or 0

		if blind > 0 or trueBlind > 0 then
			return fLogName .. " attempted to use <b>" .. skillName .. "</b>, but stumbled due to blindness!", false, "None"
		end
		attacker.Statuses["Dodge"] = 1; attacker.LastSkill = skillName 
		return fLogName .. " used <b>" .. skillName .. "</b>! " .. fLogName .. " maneuvers rapidly, dodging the next attack.", false, "None"
	elseif skill.Effect == "Rest" or skillName == "Recover" or skillName == "Regroup" then
		local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.30
		attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); attacker.LastSkill = skillName
		local regroupWord = attacker.IsPlayer and "regroup" or "regroups"
		return fLogName .. " used <b>" .. skillName .. "</b>! <font color='#55FF55'>" .. fLogName .. " " .. regroupWord .. ", recovering HP and Gas.</font>", false, "None"
	elseif skill.Effect == "Transform" then
		if not attacker.Statuses then attacker.Statuses = {} end
		attacker.Statuses["Transformed"] = 999; attacker.LastSkill = skillName; attacker.HP = tonumber(attacker.MaxHP) or 100
		attacker.TitanEnergy = tonumber(attacker.MaxTitanEnergy) or 100
		return fLogName .. " used <b>" .. skillName .. "</b>! Lightning strikes as " .. fLogName .. " shifts into a Titan! <font color='#55FF55'>[HP & HEAT Restored]</font>", false, "Heavy"
	elseif skill.Effect == "Eject" then
		if attacker.Statuses then attacker.Statuses["Transformed"] = nil end
		attacker.LastSkill = skillName
		return fLogName .. " used <b>" .. skillName .. "</b>! " .. fLogName .. " cuts themselves out of the nape, returning to human form.", false, "None"
	elseif skill.Effect == "TitanRest" or skillName == "Titan Recover" then
		local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.60
		attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); attacker.LastSkill = skillName
		return fLogName .. " used <b>" .. skillName .. "</b>! <font color='#55FF55'>" .. fLogName .. " uses immense steam to regenerate " .. math.floor(healAmount) .. " HP.</font>", false, "None"
	end

	local hitsToDo = tonumber(skill.Hits) or 1; local hitLogs = {}; local didHitAtAll = false; local overallShake = "None"
	local synergyTag = isSequenceCombo and " <font color='#FFD700'>[SYNERGY: " .. lastAtkSkill .. " -> " .. skillName .. "]</font>" or ""

	local atkSpd = tonumber(attacker.TotalSpeed) or 10
	local defSpd = tonumber(defender.TotalSpeed) or 10
	local atkRes = tonumber(attacker.TotalResolve) or 10

	if attacker.IsPlayer then
		local aClanFull = tostring(attacker.Clan or "None")
		local aIsAwakened = string.find(aClanFull, "Awakened") ~= nil
		local aBaseClan = string.gsub(aClanFull, "Awakened ", "")
		local aTitan = tostring(attacker.Titan or "None")

		if aBaseClan == "Braus" then atkSpd = atkSpd * (aIsAwakened and 1.20 or 1.10) end
		if aBaseClan == "Galliard" then atkSpd = atkSpd * (aIsAwakened and 1.30 or 1.15) end
		if aBaseClan == "Ackerman" and aIsAwakened then atkSpd = atkSpd * 1.50 end
		if aBaseClan == "Arlert" then atkRes = atkRes * (aIsAwakened and 1.30 or 1.15) end

		if aBaseClan == "Galliard" and string.find(aTitan, "Jaw Titan") then atkSpd = atkSpd * 1.25 end
	end
	if defender.IsPlayer then
		local dClanFull = tostring(defender.Clan or "None")
		local dIsAwakened = string.find(dClanFull, "Awakened") ~= nil
		local dBaseClan = string.gsub(dClanFull, "Awakened ", "")

		if dBaseClan == "Braus" then defSpd = defSpd * (dIsAwakened and 1.20 or 1.10) end
		if dBaseClan == "Galliard" then defSpd = defSpd * (dIsAwakened and 1.30 or 1.15) end
		if dBaseClan == "Ackerman" and dIsAwakened then defSpd = defSpd * 1.50 end
	end

	for i = 1, hitsToDo do
		local currentDefHP = tonumber(defender.HP) or 0
		if currentDefHP < 1 and i > 1 then break end 

		local isDodging = false
		if defender.Statuses then
			local dodgeVal = tonumber(defender.Statuses.Dodge) or 0
			if dodgeVal > 0 then isDodging = true end

			local cripVal = tonumber(defender.Statuses.Crippled) or 0
			if cripVal > 0 then defSpd = defSpd * 0.5 end

			local immobVal = tonumber(defender.Statuses.Immobilized) or 0
			if immobVal > 0 then defSpd = 0 end
		end

		local dodgeChance = math.clamp(5 + (defSpd - atkSpd) * 0.2, 5, 35) 

		local targetCrip = defender.Statuses and (tonumber(defender.Statuses.Crippled) or 0) > 0
		if targetLimb == "Nape" and not targetCrip then 
			dodgeChance = dodgeChance + 35 
		end

		if defender.IsPlayer and string.find(tostring(defender.Clan or "None"), "Springer") then dodgeChance = dodgeChance + 15 end

		if defender.AwakenedStats and (tonumber(defender.AwakenedStats.DodgeBonus) or 0) > 0 then
			dodgeChance = dodgeChance + tonumber(defender.AwakenedStats.DodgeBonus)
		end

		dodgeChance = math.clamp(dodgeChance or 0, 0, 80)
		if isDodging then dodgeChance = 100 end
		if defender.Statuses and (tonumber(defender.Statuses.Immobilized) or 0) > 0 then dodgeChance = 0 end

		if math.random(1, 100) <= (dodgeChance or 0) then
			if hitsToDo == 1 then 
				local dodgeMsg = isDodging and " (Maneuvered)" or ""
				if attacker.IsPlayer then table.insert(hitLogs, fLogName .. " aimed for the <b>" .. targetLimb .. "</b>, but " .. fDefName .. " dodged!" .. dodgeMsg)
				else table.insert(hitLogs, fLogName .. " attacked, but " .. fDefName .. " dodged!" .. dodgeMsg) end
			else table.insert(hitLogs, "<font color='#AAAAAA'>- Hit " .. i .. " missed!</font>") end
			continue
		end

		didHitAtAll = true

		local critChance = math.clamp(5 + (atkRes * 0.5), 5, 75)
		if attacker.AwakenedStats and (tonumber(attacker.AwakenedStats.CritBonus) or 0) > 0 then
			critChance = critChance + tonumber(attacker.AwakenedStats.CritBonus)
		end

		if attacker.IsPlayer then
			local aBaseClan = string.gsub(tostring(attacker.Clan or "None"), "Awakened ", "")
			local aTitan = tostring(attacker.Titan or "None")
			if aBaseClan == "Galliard" and string.find(aTitan, "Jaw Titan") then
				critChance = critChance + 25
			end
		end

		local isCrit = math.random(1, 100) <= (critChance or 0)
		local mult = (tonumber(skill.Mult) or 1.0) * (isCrit and 1.5 or 1.0) * comboMult
		local baseDmg = CombatCore.CalculateDamage(attacker, defender, mult, targetLimb)

		local survivalTriggered, hitGate, gateBroken, hpDmg, gateName = CombatCore.TakeDamage(defender, baseDmg, attacker.Style)

		local effectLog = ""
		local isArmored = defender.GateType == "Reinforced Skin" and (tonumber(defender.GateHP) or 0) > 0

		if skill.Effect and skill.Effect ~= "None" and skill.Effect ~= "Block" and skill.Effect ~= "Rest" and skill.Effect ~= "Flee" and skill.Effect ~= "Transform" and skill.Effect ~= "Eject" and skill.Effect ~= "TitanRest" and skill.Effect ~= "FallBack" and skill.Effect ~= "CloseGap" then
			if not defender.Statuses then defender.Statuses = {} end
			local safeEffect = tostring(skill.Effect)

			if safeEffect == "RestoreHeat" then
				if attacker.IsPlayer then
					local pNrg = tonumber(attacker.TitanEnergy) or 0
					local maxNrg = tonumber(attacker.MaxTitanEnergy) or 100
					attacker.TitanEnergy = math.min(maxNrg, pNrg + 40)

					local pHP = tonumber(attacker.HP) or 0
					local maxHP = tonumber(attacker.MaxHP) or 100
					local healAmt = maxHP * 0.15
					attacker.HP = math.min(maxHP, pHP + healAmt)

					effectLog = effectLog .. " <font color='#55FF55'>[+40 HEAT | +15% HP]</font>"
				end
			else
				local currentEffect = tonumber(defender.Statuses[safeEffect]) or 0
				local currentImmunity = tonumber(defender.Statuses[safeEffect .. "Immunity"]) or 0

				if isArmored and (safeEffect == "Stun" or safeEffect == "Bleed" or safeEffect == "Blinded" or safeEffect == "TrueBlind" or safeEffect == "Crippled" or safeEffect == "Weakened") then
					effectLog = effectLog .. " <font color='#888888'>[ARMOR RESISTS EFFECT]</font>"
				elseif currentEffect > 0 then
					effectLog = effectLog .. " <font color='#888888'>[ALREADY ACTIVE]</font>"
				elseif currentImmunity > 0 then
					effectLog = effectLog .. " <font color='#888888'>[IMMUNITY ACTIVE]</font>"
				elseif safeEffect == "GasDrain" then
					if defender.IsPlayer then
						defender.Gas = math.max(0, (tonumber(defender.Gas) or 0) - 40)
						effectLog = effectLog .. " <font color='#FF5555'>[-40 GAS]</font>"
					end
				elseif safeEffect == "NapeGuard" then
					defender.Statuses["NapeGuard"] = tonumber(skill.Duration) or 2
					effectLog = effectLog .. " <font color='#AA55FF'>[NAPE GUARDED]</font>"
				else
					defender.Statuses[safeEffect] = tonumber(skill.Duration) or 2
					effectLog = effectLog .. " <font color='#AA55FF'>[" .. safeEffect:upper() .. "]</font>"
				end
			end
		end

		if isArmored and (targetLimb == "Legs" or targetLimb == "Arms" or targetLimb == "Eyes") then
			effectLog = effectLog .. " <font color='#888888'>[ARMOR DEFLECTS DEBUFF]</font>"
		else
			if targetLimb == "Legs" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local cripStatus = tonumber(defender.Statuses["Crippled"]) or 0
				local immobStatus = tonumber(defender.Statuses["Immobilized"]) or 0
				local cripImm = tonumber(defender.Statuses["CrippledImmunity"]) or 0
				local immobImm = tonumber(defender.Statuses["ImmobilizedImmunity"]) or 0

				if cripStatus > 0 or immobStatus > 0 then
					if cripStatus > 0 and immobStatus == 0 then
						defender.Statuses["Immobilized"] = 2; defender.Statuses["Crippled"] = nil
						effectLog = effectLog .. " <font color='#00FF00'>[IMMOBILIZED]</font>"
					else
						effectLog = effectLog .. " <font color='#888888'>[ALREADY ACTIVE]</font>"
					end
				elseif cripImm > 0 or immobImm > 0 then
					effectLog = effectLog .. " <font color='#888888'>[IMMUNITY ACTIVE]</font>"
				else 
					defender.Statuses["Crippled"] = 3; effectLog = effectLog .. " <font color='#55FF55'>[CRIPPLED]</font>"
				end
			elseif targetLimb == "Arms" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local weakStatus = tonumber(defender.Statuses["Weakened"]) or 0
				local weakImm = tonumber(defender.Statuses["WeakenedImmunity"]) or 0

				if weakStatus > 0 then
					effectLog = effectLog .. " <font color='#888888'>[ALREADY ACTIVE]</font>"
				elseif weakImm > 0 then
					effectLog = effectLog .. " <font color='#888888'>[IMMUNITY ACTIVE]</font>"
				else
					defender.Statuses["Weakened"] = 3; effectLog = effectLog .. " <font color='#FFDD55'>[WEAKENED]</font>"
				end
			elseif targetLimb == "Eyes" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local tblBlind = tonumber(defender.Statuses["TrueBlind"]) or 0
				local blStatus = tonumber(defender.Statuses["Blinded"]) or 0
				local blImm = tonumber(defender.Statuses["BlindedImmunity"]) or 0
				local tblImm = tonumber(defender.Statuses["TrueBlindImmunity"]) or 0

				if tblBlind > 0 then
					effectLog = effectLog .. " <font color='#888888'>[ALREADY ACTIVE]</font>"
				elseif blImm > 0 or tblImm > 0 then
					effectLog = effectLog .. " <font color='#888888'>[IMMUNITY ACTIVE]</font>"
				else
					if blStatus > 0 then
						defender.Statuses["TrueBlind"] = 2; defender.Statuses["Blinded"] = nil
						effectLog = effectLog .. " <font color='#555555'>[TRUE BLINDNESS]</font>"
					else
						defender.Statuses["Blinded"] = 2
						effectLog = effectLog .. " <font color='#DDDDDD'>[BLINDED]</font>"
					end
				end
			end
		end

		if targetLimb == "Nape" and defender.Statuses and (tonumber(defender.Statuses["NapeGuard"]) or 0) > 0 then
			effectLog = effectLog .. " <font color='#AAAAAA'>[BLOCKED BY NAPE GUARD]</font>"
		end

		if isCrit or survivalTriggered then overallShake = "Heavy" elseif overallShake == "None" then overallShake = "Normal" end

		local hitMsg = ""
		if attacker.IsPlayer then
			hitMsg = hitsToDo == 1 and (fLogName .. " struck the <b>" .. targetLimb .. "</b>" .. synergyTag .. " for " .. math.floor(baseDmg) .. " dmg!" .. effectLog) or ("- Hit " .. i .. " dealt " .. math.floor(baseDmg) .. " damage" .. effectLog)
		else
			hitMsg = hitsToDo == 1 and (fLogName .. " struck you" .. synergyTag .. " for " .. math.floor(baseDmg) .. " dmg!" .. effectLog) or ("- Hit " .. i .. " dealt " .. math.floor(baseDmg) .. " damage" .. effectLog)
		end

		if isCrit then hitMsg = hitMsg .. " <font color='#FFAA00'>(CRIT!)</font>" end
		if defender.GateType == "Steam" and hitGate then hitMsg = hitMsg .. " <font color='#FFAAAA'>(Repelled by Steam!)</font>"
		elseif hitGate then hitMsg = hitMsg .. " <font color='#DDDDDD'>[Hit " .. tostring(gateName) .. "!]</font>" end
		if gateBroken then hitMsg = hitMsg .. " <font color='#FFFFFF'><b>[" .. tostring(gateName):upper() .. " SHATTERED!]</b></font>" end
		if survivalTriggered then hitMsg = hitMsg .. " <font color='#FF55FF'>...TATAKAE! (Refused to yield!)</font>" end

		table.insert(hitLogs, hitMsg)
	end

	local finalMsg = ""
	if hitsToDo > 1 then
		if not didHitAtAll then finalMsg = fLogName .. " unleashed <b>" .. skillName .. "</b>, but " .. fDefName .. " dodged completely!"
		else finalMsg = fLogName .. " used <b>" .. skillName .. "</b>!" .. synergyTag .. "\n" .. table.concat(hitLogs, "\n") end
	else finalMsg = hitLogs[1] or "" end

	attacker.LastSkill = skillName
	return finalMsg, didHitAtAll, overallShake
end

return CombatCore