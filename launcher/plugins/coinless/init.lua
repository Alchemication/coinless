-- Coinless's quit request. Library.arguments enables this plugin on every launch.
-- When the file named in COINLESS_QUIT_FILE appears, MAME exits the way Esc does, so
-- -autosave still writes auto.sta. Signals aren't reliable for this: MAME on macOS often
-- ignores SIGTERM. It's a plugin, not an -autoboot_script, because MAME never runs the
-- autoboot script when -autosave resumes a save. Without the variable (./play) it does nothing.
local exports = {
	name = "coinless",
	version = "1.0",
	description = "Quits cleanly when Coinless asks",
	license = "MIT",
	author = { name = "Coinless" } }

local coinless = exports
local frame_subscription

function coinless.startplugin()
	local path = os.getenv("COINLESS_QUIT_FILE")
	if not path then return end
	local frames = 0
	-- Runs on emulated frames, so a paused warning screen doesn't hear it.
	frame_subscription = emu.add_machine_frame_notifier(function ()
		frames = frames + 1
		if frames % 15 ~= 0 then return end
		local request = io.open(path, "r")
		if request then
			request:close()
			os.remove(path)
			manager.machine:exit()
		end
	end)
end

return exports
