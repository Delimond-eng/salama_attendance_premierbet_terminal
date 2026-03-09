adb shell dpm set-device-owner com.salama_drc.terminal/.MdmDeviceAdminReceiver

# uninstall

adb shell am force-stop com.salama_drc.terminal
adb shell pm clear com.salama_drc.terminal

# disallow

adb shell dpm remove-active-admin com.salama_drc.terminal/.MdmDeviceAdminReceiver
