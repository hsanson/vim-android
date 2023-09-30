local M = {}
local health = vim.health

local vimscript = function(name)
  return vim.api.nvim_call_function(name, {})
end

local check = function(name)
  if vimscript(name) then
    return 'yes'
  else
    return 'no'
  end
end

M.check = function()
  health.start("vim-android report")

  if vimscript('gradle#isGradleProject') == 1 then
    health.ok('Gradle poject detected')
  else
    health.info('No gradle project detected')
    return
  end

  local gradle_binary = vimscript('gradle#bin')

  if vim.fn.executable(gradle_binary) == 1 then
    health.ok(
      'Gradle binary \n' ..
      '  Path: ' .. gradle_binary .. '\n' ..
      '  Version: ' .. vimscript('gradle#version')
    )
  else
    health.warn('Missing gradle binary')
  end

  health.ok(
    'Configuration: \n' ..
    '  Async build: ' .. check('gradle#isAsyncEnabled') .. '\n' ..
    '  Daemon: ' .. check('gradle#isDaemonEnabled')
  )

  if vimscript('android#isAndroidProject') == 1 then
    health.ok(
      'Android poject detected \n' ..
      '  Manifest: ' .. vimscript('android#manifestFile')
    )
  else
    health.info('No Android project detected')
    return
  end

  if vimscript('android#checkAndroidHome') == 1 then
    health.ok(
      'Android SDK: \n' ..
      '  Path: ' .. vim.g.android_sdk_path .. '\n' ..
      '  Emulator: ' .. vimscript('android#emulatorbin') .. '\n' ..
      '  Adb: ' .. vimscript('adb#bin') .. '\n' ..
      '  Build Tools: ' .. vimscript('android#buildToolsPath')
    )
  else
    health.error(
      'Android SDK home not set \n' ..
      'Ensure to set g:android_sdk_path variable correctly\n' ..
      'or that ANDROID_HOME environment variable is set.'
    )
  end
end
return M
