-- Coinless's quit request (MAME runs it with -autoboot_script on every launch).
-- When the file named in COINLESS_QUIT_FILE appears, MAME exits the way Esc does,
-- so -autosave still writes auto.sta. Signals aren't reliable for this: MAME on
-- macOS often ignores SIGTERM. Without the variable (./play, previews) it does nothing.
local path = os.getenv("COINLESS_QUIT_FILE")
if path then
  local frames = 0
  coinless_quit = emu.add_machine_frame_notifier(function()
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
