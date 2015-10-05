Console = (function()
	
	-- Imports
	local when = Core.when
	local getSelfName = Core.getSelfName

	local _lastConsoleMessage = nil
	
	local function log(message)
		if message == _lastConsoleMessage then
			return
		end
		_lastConsoleMessage = message
		xeno.luaSendChannelMessage(_script.channel, CHANNEL_ORANGE, ':', message)
	end
	
	local function info(message)
		if message == _lastConsoleMessage then
			return
		end
		_lastConsoleMessage = message
		xeno.luaSendChannelMessage(_script.channel, CHANNEL_YELLOW, ':', message)
	end

	local function warn(message)
		if message == _lastConsoleMessage then
			return
		end
		_lastConsoleMessage = message
		xeno.luaSendChannelMessage(_script.channel, CHANNEL_RED, ':', message)
	end

	local function error(message)
		xeno.luaSendChannelMessage(_script.channel, CHANNEL_RED, ':', 'ERROR :: ' .. message)
		assert(false, message)
	end

	local function prompt(message, callback)
		_lastConsoleMessage = nil
		log(message)
		when(EVENT_COMMAND, nil, function(response)
			callback(response)
		end)
	end

	local function openConsole()
		_script.channel = xeno.luaOpenCustomChannel('XenoBot')
		-- Welcome message
		log(string.rep('\n ', 54) .. '\n' .. string.rep(':', 190) .. '\n:::::   X E N O B O T   :::::           ' .. _script.name .. '  ('.. LIB_REVISION ..')\n' .. string.rep(':', 190) .. ' \n ')
		warn('You can control your script from this channel. Type /help for a list of available commands.')
		warn('Configure this script in the file: "Documents/XenoBot/[' .. getSelfName() .. '] ' .. _script.name .. '.ini"')
	end

	local function openPrivateMessageConsole()
		_script.historyChannel = xeno.luaOpenCustomChannel('History')
	end

	-- Export global functions
	return {
		log = log,
		info = info,
		warn = warn,
		error = error,
		prompt = prompt,
		openConsole = openConsole,
		openPrivateMessageConsole = openPrivateMessageConsole
	}
end)()