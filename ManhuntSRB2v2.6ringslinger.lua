--[[Manhunt SRB2 mod made by @retryaarosu]]--
G_AddGametype({
	name = "Manhunt",
	identifier = "mah",
	typeoflevel = TOL_RACE|TOL_COMPETITION,
	rules = GTR_SPECTATORS|GTR_NOTITLECARD|GTR_TEAMS|GTR_SPAWNENEMIES|GTR_CAMPAIGN|GTR_ALLOWEXIT|GTR_HURTMESSAGES,
	intermissiontype = int_race,
	headercolor = 104,
	description = "SRB2 Manhunt. 1 speedrunner and a certain amount of hunters. Can you make it?"
})	
 
local speedpass = false	
local person = player_t
local speedrunner = {}
local hunters = {}
local ForcedSpectate = true
local TeamsMade = false
local ChoosingTeams = false
local FirstMatch = false
local MHringsling = false
local SpeedrunnerHP = 4
local Tries = 3
local CanRestoreTries = false
local ringslingon = false
local HunterCheckpoint = 0
local srCheckpoint
local easymode = false
local setback = 0
local startupTimer = 0

local Difficulty
Difficulty = CV_RegisterVar({
	name = "ezmode",
	defaultvalue = "Off",
	flags = CV_NETVAR|CV_CALL|CV_NOINIT,
	PossibleValue = CV_OnOff,
	func = function()
		TeamsMade = false 
		ChoosingTeams = true
		if Difficulty.value == 0 then
			Tries = 3
			SpeedrunnerHP = 4
			easymode = false
			print("easy mode disabled.")
		elseif Difficulty.value == 1 then
			Tries = 5
			SpeedrunnerHP = 4
			easymode = true
			print("easy mode enabled.")
		end
	end
})


local Diffi = Difficulty.value



local function ResetStuff()
	setback = 0
	if easymode == false then
		Tries = 3
		SpeedrunnerHP = 4
	elseif easymode == true then
		Tries = 5
		SpeedrunnerHP = 4
	end
end

local function IndependentChoose()
	TeamsMade = false 
	ChoosingTeams = true
	ResetStuff()
	for player in players.iterate() do
		player.powers[pw_nocontrol] = 324
	end
end




--UI and other setup

local function SetupStuff()
	if gametype == GT_MAH and ringslingon == false then
		COM_BufInsertText(players[0], "ringslinger on")
		hud.disable("teamscores")
		ringslingon = true
	elseif gametype ~= GT_MAH and ringslingon == true then
		hud.enable("teamscores")
		ringslingon = false
	end
end

local function keepringsling()
	if gametype == GT_MAH then
		print("Disabling this would disable ringslinger for this mode! Don't do it here!")
	end
end

hud.add(function(v, player, cam)
    if gametype == GT_MAH and TeamsMade == false then
		v.drawFill()
		v.drawString(160, 70, "\130Pick your teams.", flags, "center")
		v.drawString(160, 100, "\132Blue is the speedrunner team.", flags, "center")
		v.drawString(160, 110, "\133Red is the hunter team.", flags, "center")
		v.drawString(0, 160, "The round will begin when the host says 'rdy'")
		if easymode == true then
			v.drawString(155, 180, "\131(EASY MODE)", flags, "center")	
		end
	end
end, "game")


--easy mode stuff on menu


hud.add(function(v, player, cam)
    if gametype == GT_MAH and ChoosingTeams == false then
		v.drawString(152, 10, "\130Tries:", flags, "center")
		v.drawString(180, 10, Tries, flags, "center")
		v.drawString(200, 160, "\132SpeedrunnerHP:")
		v.drawString(310, 160, SpeedrunnerHP)
		if easymode == true then
			v.drawString(235, 180, "\131(Easy mode)")
		end
	end
end, "game")



hud.add(function(v, player, cam)
    if gametype == GT_MAH and ChoosingTeams == false then
		v.drawString(260, 180, "\130Tries:")
		v.drawString(310, 180, Tries)
end
end, "intermission")

local function helpstuff(player)
	CONS_Printf(player, "ezmode - changes the difficulty of manhunt for the speedrunner. 1 for easy, 0 for normal. (HOST ONLY)")
	CONS_Printf(player, "manhuntteams - allows you to setup teams again mid-stage and mid-session. Allows joiners in middle of stages. (HOST ONLY)")
	CONS_Printf(player, "Hunters, if someone obtained a new starpost, then use the 'suicide' command to die and respawn at it to save time.")
end

COM_AddCommand("ringslinger off", keepringsling, COM_ADMIN)
addHook("MapChange", SetupStuff)
COM_AddCommand("mhhelp", helpstuff, COM_LOCAL)


--Intermission stuff below. First is to force team choosing when you start the gamemode for the first time.
	
addHook("PlayerSpawn", function(player)
	if gametype == GT_MAH and TeamsMade == false then
		ChoosingTeams = true
        player.powers[pw_nocontrol] = 324
	end
end)

addHook("PreThinkFrame", function()
   if gametype == GT_MAH and ChoosingTeams == true then
       for player in players.iterate() do
            player.powers[pw_nocontrol] = 324
			player.powers[pw_invulnerability] = 324
      --Keep setting the immovable state until intermission is done
		end
	end
end)


addHook("PlayerMsg", function(source, type, target, msg)
  if msg == "rdy" and #source == 0 and gametype == GT_MAH and ChoosingTeams == true then
	TeamsMade = true
	ChoosingTeams = false
	G_SetCustomExitVars(01)
	for player in players.iterate() do
		player.exiting = 1
    end
	G_ExitLevel()
	FirstMatch = true
	end
end)

local function ActivateTeamChoose()
    if gametype ~= GT_MAH then
		TeamsMade = false
		FirstMatch = false
		ResetStuff()
	end
end

addHook("MapChange", ActivateTeamChoose)
COM_AddCommand("ManhuntTeams", IndependentChoose, COM_ADMIN)


-- Spectate forcing things below and HP reset

addHook("IntermissionThinker", function()
	if gametype == GT_MAH then							
		ForcedSpectate = false
end
end)

addHook("MapLoad", function()
	ForcedSpectate = true
	SpeedrunnerHP = 4
end)
--HP is the only thing that can regenerate with each map try.

--Team Switch handling below

addHook("TeamSwitch", function(player, team, fromspectators, autobalance, scramble)
	if gametype == GT_MAH and #speedrunner >= 1 and team == 2 and TeamsMade == true then
		chatprintf(player, "There's already a speedrunner. If you're trying to join in middle of a round as well,  you have to wait for the round to end.")
		return false
	end
end)

addHook("TeamSwitch", function(player, team, fromspectators, autobalance, scramble)
	if fromspectators == true and gametype == GT_MAH and ForcedSpectate == true and TeamsMade == true 
		chatprintf(player, "If you're trying to join in middle of a round, then you have to wait for the round to end.")
		return false
end
end)

--Actual player stuff below


addHook("PreThinkFrame", function()
	if gametype == GT_MAH and TeamsMade == true and leveltime == 0 and ChoosingTeams == false then
		for player in players.iterate() do
			player.powers[pw_invulnerability] = 4*TICRATE
			if player.ctfteam == 1 then
				if easymode == false then
					player.powers[pw_nocontrol] = 4*TICRATE
				elseif easymode == true then
					player.powers[pw_nocontrol] = 6*TICRATE
				end
			end
		end
	end
end)--this is the handler for making the hunter team wait slightly longer as well as the overall startup countdown.

addHook("PlayerSpawn", function(player)
	if gametype == GT_MAH and player.ctfteam == 1 then
		player.ringweapons = 1+2+4+8+16+32
		player.powers[pw_infinityring] = 999
		player.powers[pw_automaticring] = 200
		player.powers[pw_bouncering] = 30
		player.powers[pw_scatterring] = 50
		player.powers[pw_grenadering] = 150
		player.powers[pw_explosionring] = 50
		player.powers[pw_railring] = 50
		player.rings = 30
	elseif gametype == GT_MAH and player.ctfteam == 2
		player.ringweapons = 1+2+4+8+16+32
		player.powers[pw_infinityring] = 999
		player.powers[pw_automaticring] = 100
	end
end) --give the players this everytime they respawn

--[[originally both the teams would get all of these items. but I decided that only the hunter team gets it, because the hunters could be a speedrunner's infinite resource if played right, especially since
hunters lose rings but speedrunners don't unless it's from stage objects.]]-- 

addHook("MapChange", function()
	if gametype == GT_MAH and TeamsMade == true then
		HunterCheckpoint = 0
		srCheckpoint = 0
		for player in players.iterate() do
			if FirstMatch == true then
				if player.ctfteam == 1 then
					chatprintf(player, "\133You are a hunter!")
					chatprintf(player, "Hunt down the speedrunners on blue team!")
					chatprintf(player, "In 3 seconds the chase begins.")
					chatprintf(player, "\133Don't complete the level. You'll spawn back at the last starpost.")
				elseif player.ctfteam == 2 then
					chatprintf(player, "\131You are a speedrunner!")
					chatprintf(player, "The people on Red Team are the hunters!")
					chatprintf(player, "Be as fast as you can! You have a 3 second head start!")
		FirstMatch = false
				end
			end
		end
	end
end) --FirstMatch makes sure it only gives the text the first time the player is playing. Then it's outside of the function so that setting it back to false isn't always looped.
--Your "first match" counts as when you first entered the game mode. afterwards it is not giving anymore.




addHook("PlayerThink", function(player)
	if player.ctfteam == 2 and player.pflags >= 1073741824 and gametype == GT_MAH then 
		G_ExitLevel()
		setback = gamemap
		chatprint("\131The speedrunner has completed the level!", true) 
		if easymode == false and Tries < 3 then
			Tries = Tries + 1 
		elseif easymode == true and Tries < 5 then
			Tries = Tries + 1 
		end
	end
end)

addHook("PlayerThink", function(player)
	if player.ctfteam == 1 and gametype == GT_MAH and player.mo ~= nil then
		local points = R_PointInSubsector(player.mo.x, player.mo.y)
		if points.sector.special == 8192 then 
			G_DoReborn(#player)
			player.exiting = 0
			player.pflags = 5
			chatprintf(player, "\130Psst... you're a hunter. You're not supposed to finish the stage...")
		end
	end
end)

addHook("PlayerThink", function(redpl)
    if gametype == GT_MAH and redpl.ctfteam == 1 and redpl.starpostnum > HunterCheckpoint then
        HunterCheckpoint = redpl.starpostnum
        chatprint("\$redpl.name\ got a new starpost for the hunters!")
        for player in players.iterate() do
            if player.ctfteam == 1 then
                player.starpostnum = redpl.starpostnum
                player.starpostx = redpl.starpostx
                player.starposty = redpl.starposty
                player.starpostz = redpl.starpostz
                player.starpostnum = redpl.starpostnum
                player.starpostscale = redpl.starpostscale
                player.starpostangle = redpl.starpostangle
                player.starposttime = redpl.starposttime
			end
		end
	end
end)

--check if blue player has finished the level
--while making sure that the red player *doesn't* finish the level.
--this executes everytime a player runs its thinker, so it's better to just put this all in one since there's no condition overlap.
--[[ unfortunately this was just done for an earlier version back when it was last played. couldn't think of a way to prevent a player from finishing the stage aside from respawning
but would most likely rewrite it nowadays with more time]]--
--THe player earns 1 try for finishing the level as long as their tries isn't already 3.

addHook("MobjDamage", function(target, inflictor, source, damage, type)
	if target.player.ctfteam == 2 and source ~= nil and source.type == 3 and gametype == GT_MAH and ChoosingTeams == false then
		P_DoPlayerPain(target.player)
		SpeedrunnerHP = SpeedrunnerHP - 1
		print("\$source.player.name\ hit the speedrunner!")
		if SpeedrunnerHP == 0 then
			G_SetCustomExitVars(01)
			G_ExitLevel()
			chatprint("\133The speedrunner ran out of HP and was killed by the hunters. Restarting session...", true)
			ResetStuff()
		end
		return true
	end
end, MT_PLAYER) --source ~= nil checks if the source actually exists as a condition.

addHook("MobjDeath", function(target, inflictor, source, type)
    if target.player.ctfteam == 2 and ChoosingTeams == false and Tries > 1 and ForcedSpectate == true and gametype == GT_MAH then
		Tries = Tries - 1
		if easymode == false then
			G_SetCustomExitVars(gamemap)
			G_ExitLevel()
			chatprint("\130The speedrunner died to an unfortunate stage-specific circumstance. Giving them another go..", true)
		elseif easymode == true then
			chatprint("\130A Speedrunner died. Lost 1 try.")
		end
	elseif target.player.ctfteam == 2 and ChoosingTeams == false and Tries == 1 and ForcedSpectate == true and gametype == GT_MAH then
		if easymode == false then
			G_SetCustomExitVars(01)
			G_ExitLevel()
			chatprint("\133The speedrunner ran out of tries on this stage and now they have to start all over again! Restarting session...", true)
			ResetStuff()
		elseif easymode == true then
			print(gamemap)
			print (setback)
			if setback ~= 0 then
				G_SetCustomExitVars(setback)
			elseif setback == 0 then
				G_SetCustomExitVars(01)
			G_ExitLevel()
			chatprint("\133The speedrunner ran out of tries on this stage and now they have to start all over again! Going back to the previously completed stage. (EASY MODE)", true)
			ResetStuff()
			end
		end
    end
end, MT_PLAYER)

chatprint("\131Manhunt gamemode loaded!")
chatprint("Type 'mhhelp' in the console to see all the commands")
print("Manhunt gamemode loaded!")
print("Type 'mhhelp' in the console to see all the commands")



