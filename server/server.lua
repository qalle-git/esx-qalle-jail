ESX                = nil

ESX = exports['es_extended']:getSharedObject()

-- Permission Check
local allowedJobs = Config.AllowedJobs

function hasPermission(xPlayer)(xPlayer)
	local xPlayer = xPlayer
	local allowed = false
	local playerJob = xPlayer["job"]["name"]
	
	for k, v in pairs(allowedJobs) do
		if v == playerJob then
			allowed = true
		end
	end
	return allowed
end
-- Permission Check

RegisterCommand("jail", function(src, args, raw)

	local xPlayer = ESX.GetPlayerFromId(src)

	if hasPermission(xPlayer) then

		local jailPlayer = args[1]
		local jailTime = tonumber(args[2])
		local jailReason = args[3]

		if GetPlayerName(jailPlayer) ~= nil then

			if jailTime ~= nil then
				JailPlayer(jailPlayer, jailTime)

				TriggerClientEvent("esx:showNotification", src, GetPlayerName(jailPlayer) .. " Jailed for " .. jailTime .. " minutes!")
				
				if args[3] ~= nil then
					GetRPName(jailPlayer, function(Firstname, Lastname)
						TriggerClientEvent('chat:addMessage', -1, { args = { "JUDGE",  Firstname .. " " .. Lastname .. " Is now in jail for the reason: " .. args[3] }, color = { 249, 166, 0 } })
					end)
				end
			else
				TriggerClientEvent("esx:showNotification", src, "This time is invalid!")
			end
		else
			TriggerClientEvent("esx:showNotification", src, "This ID is not online!")
		end
	else
		TriggerClientEvent("esx:showNotification", src, "You are not an officer!")
	end
end)

RegisterCommand("unjail", function(src, args)

	local xPlayer = ESX.GetPlayerFromId(src)

	if hasPermission(xPlayer) then

		local jailPlayer = args[1]

		if GetPlayerName(jailPlayer) ~= nil then
			UnJail(jailPlayer)
		else
			TriggerClientEvent("esx:showNotification", src, "This ID is not online!")
		end
	else
		TriggerClientEvent("esx:showNotification", src, "You are not an officer!")
	end
end)

RegisterServerEvent("esx-qalle-jail:jailPlayer")
AddEventHandler("esx-qalle-jail:jailPlayer", function(targetSrc, jailTime, jailReason)
	local src = source
	local xPlayer = ESX.GetPlayerFromId(src)
		
	if hasPermission(xPlayer) thenm
		local targetSrc = tonumber(targetSrc)

		JailPlayer(targetSrc, jailTime)

		GetRPName(targetSrc, function(Firstname, Lastname)
			TriggerClientEvent('chat:addMessage', -1, { args = { "JUDGE",  Firstname .. " " .. Lastname .. " Is now in jail for the reason: " .. jailReason }, color = { 249, 166, 0 } })
		end)

		TriggerClientEvent("esx:showNotification", src, GetPlayerName(targetSrc) .. " Jailed for " .. jailTime .. " minutes!")
	end
end)

RegisterServerEvent("esx-qalle-jail:unJailPlayer")
AddEventHandler("esx-qalle-jail:unJailPlayer", function(targetIdentifier)
	local src = source
	local xUnjailer = ESX.GetPlayerFromId(src)
		
	if hasPermission(xUnjailer) then
		local xPlayer = ESX.GetPlayerFromIdentifier(targetIdentifier)

		if xPlayer ~= nil then
			UnJail(xPlayer.source)
		else
			MySQL.Async.execute(
				"UPDATE users SET jail = @newJailTime WHERE identifier = @identifier",
				{
					['@identifier'] = targetIdentifier,
					['@newJailTime'] = 0
				}
			)
		end

		TriggerClientEvent("esx:showNotification", src, xPlayer.name .. " Unjailed!")
	end
end)

RegisterServerEvent("esx-qalle-jail:updateJailTime")
AddEventHandler("esx-qalle-jail:updateJailTime", function(newJailTime)
	local src = source

	EditJailTime(src, newJailTime)
end)

local blacklistedSources = {}
local inCooldown = {}

function resetCooldown(source)
	local source = source
	Citizen.Wait(1250)	
	inCooldown[source] = false
end

RegisterServerEvent("esx-qalle-jail:prisonWorkReward")
AddEventHandler("esx-qalle-jail:prisonWorkReward", function()
	local src = source
	if blacklistedSources[src] == nil or blacklistedSources[src] == false then
		if inCooldown[src] == true then
			blacklistedSources[src] = true
		end
		inCooldown[src] = true
		local xPlayer = ESX.GetPlayerFromId(src)

		xPlayer.addMoney(math.random(13, 21))

		TriggerClientEvent("esx:showNotification", src, "Thanks, here you have som cash for food!")
		resetCooldown(src)
	end
end)

function JailPlayer(jailPlayer, jailTime)
	TriggerClientEvent("esx-qalle-jail:jailPlayer", jailPlayer, jailTime)

	EditJailTime(jailPlayer, jailTime)
end

function UnJail(jailPlayer)
	TriggerClientEvent("esx-qalle-jail:unJailPlayer", jailPlayer)

	EditJailTime(jailPlayer, 0)
end

function EditJailTime(source, jailTime)

	local src = source

	local xPlayer = ESX.GetPlayerFromId(src)
	local Identifier = xPlayer.identifier

	MySQL.Async.execute(
       "UPDATE users SET jail = @newJailTime WHERE identifier = @identifier",
        {
			['@identifier'] = Identifier,
			['@newJailTime'] = tonumber(jailTime)
		}
	)
end

function GetRPName(playerId, data)
	local Identifier = ESX.GetPlayerFromId(playerId).identifier

	MySQL.Async.fetchAll("SELECT firstname, lastname FROM users WHERE identifier = @identifier", { ["@identifier"] = Identifier }, function(result)

		data(result[1].firstname, result[1].lastname)

	end)
end

ESX.RegisterServerCallback("esx-qalle-jail:retrieveJailedPlayers", function(source, cb)
	
	local jailedPersons = {}

	MySQL.Async.fetchAll("SELECT firstname, lastname, jail, identifier FROM users WHERE jail > @jail", { ["@jail"] = 0 }, function(result)

		for i = 1, #result, 1 do
			table.insert(jailedPersons, { name = result[i].firstname .. " " .. result[i].lastname, jailTime = result[i].jail, identifier = result[i].identifier })
		end

		cb(jailedPersons)
	end)
end)

ESX.RegisterServerCallback("esx-qalle-jail:retrieveJailTime", function(source, cb)

	local src = source

	local xPlayer = ESX.GetPlayerFromId(src)
	local Identifier = xPlayer.identifier


	MySQL.Async.fetchAll("SELECT jail FROM users WHERE identifier = @identifier", { ["@identifier"] = Identifier }, function(result)

		local JailTime = tonumber(result[1].jail)

		if JailTime > 0 then

			cb(true, JailTime)
		else
			cb(false, 0)
		end

	end)
end)
