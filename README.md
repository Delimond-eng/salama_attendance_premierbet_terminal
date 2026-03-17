adb shell dpm set-device-owner com.salama_drc.terminal/.MdmDeviceAdminReceiver

# uninstall

adb shell am force-stop com.salama_drc.terminal
adb shell pm clear com.salama_drc.terminal

# disallow

adb shell dpm remove-active-admin com.salama_drc.terminal/.MdmDeviceAdminReceiver


# 1. Lister le composant admin pour confirmer le nom
adb shell dumpsys device_policy

# 2. Retirer les droits d'administration (remplacez com.salama_drc.terminal par votre package name)
adb shell dpm remove-active-admin com.salama_drc.terminal/.MdmDeviceAdminReceiver

# 3. Désinstaller l'application
adb uninstall com.salama_drc.terminal
