@echo off
title ADB Tool
chcp 65001 > nul
set "PATH=%~dp0adb;%PATH%" & REM Add ADB temporarely on the PATH, in case it's not installed
setlocal EnableDelayedExpansion
if not exist logs mkdir logs
if not exist in mkdir in
if not exist out mkdir out
set DEBUG=0
set RELOAD=0
::the DEBUG var is only for debugging, don't enable it for normal use
set "ESC="
set "R=%ESC%[0m"
set "BLK=%ESC%[30m"
set "RED=%ESC%[31m"
set "GRN=%ESC%[32m"
set "YLW=%ESC%[33m"
set "BLU=%ESC%[34m"
set "MGN=%ESC%[35m"
set "CYN=%ESC%[36m"
set "WHT=%ESC%[37m"

REM Code from https://github.com/AtexBg/adb-tool

REM check if the device is plugged in
:check_device
if %DEBUG%==1 goto window1
adb get-state >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :no_device
	goto check_device
) else (
	REM HERE'S ALL THE COMMANDS TO INITIALIZE THE VARIABLES AT STARTUP, SOME WILL BE RECALCULATED AT RUNTIME
	echo [%GRN%+%R%] %GRN%Device detected%R%
	ping -n 1 127.0.0.1>nul
    echo [%BLU%+%R%] %BLU%Calculating variables...%R%
	for /f "delims=" %%a in ('adb shell getprop ro.product.model') do set MODEL=%%a > nul
	for /f "tokens=1 delims=." %%a in ('adb shell getprop ro.build.version.release') do set API_VER=%%a & REM fetch Android version
	for /f "delims=" %%a in ('adb shell getprop ro.product.manufacturer') do set MANUFACTURER=%%a & REM fetch device manufacturer
	for /f "tokens=9" %%i in ('adb shell ip route ^| findstr "src"') do set IP=%%i & REM Extract IP address 
	for /f "tokens=2" %%a in ('adb shell cat /proc/meminfo ^| findstr "MemTotal"') do set RAM_KB=%%a & set /a RAM=%RAM_KB:~0,-4%
	for /f "tokens=2" %%a in ('adb shell cat /proc/meminfo ^| findstr "MemAvailable"') do set RAM_AVBL_KB=%%a & set /a RAM_AVBL=%RAM_AVBL_KB:~0,-4%
	for /F "tokens=5" %%a in ('adb shell df /data ^| findstr "\/dev"') do set STORAGE_USED=%%a & REM fetch used storage percentage
	for /f "tokens=2" %%a in ('adb shell df /data ^| findstr /i /c:"\/dev"') do set STORAGE_KB=%%a
	for /f %%b in ('powershell -Command "[math]::Round(%STORAGE_KB% / 1048576, 2)"') do set STORAGE=%%b
	for /f "tokens=2 delims=:" %%a in ('adb shell dumpsys battery ^| findstr /c:"  level:"') do set BATTERY_LEVEL=%%a
	for /f "tokens=2 delims=:" %%a in ('adb shell dumpsys battery ^| findstr "USB"') do set USB_PWRD=%%a & REM fetch battery state
	if "%USB_PWRD%"==" false" set CHRG=Not Charging & if "%USB_PWRD%"==" true" set CHRG="Charging" & REM parse output
	for /f "tokens=2 delims=:" %%a in ('adb shell dumpsys battery ^| findstr /c:"  temperature:"') do set TEMP_RAW=%%a
	for /f %%b in ('powershell "Write-Output ([math]::Round(%TEMP_RAW% / 10, 1))"') do set TEMP_C=%%b
	if not defined IP set IP=Not Detected
	goto ConnectivityCheck
)

:root_check
adb shell su -c "id" >nul 2>&1
if "%ERRORLEVEL%"=="0" set IS_ROOT=%GRN%TRUE%R% & goto window1
set IS_ROOT=%RED%FALSE%R%
net session >nul 2>&1 && set "CURRENT_USER=%RED%Administrator%R%" || set "CURRENT_USER=%GRN%%USERNAME%%R%"
goto window1

:ConnectivityCheck
for /f "skip=1 tokens=1" %%A in ('adb devices') do (
    set "device=%%A"
    echo !device! | find ":" >nul
    if errorlevel 1 (
        set CONNECT=USB
    ) else (
        set CONNECT=TCPIP
    )
)
REM if "%RunOverUSB%"=="TRUE" if "%RunOverTCPIP%"=="TRUE" goto RunConflict
REM _BROKEN, TO FIX LATER
goto trimEmptyEnds

:trimEmptyEnds
set /a API_VER=%API_VER:~0,-1%
set MODEL=%MODEL:~0,-1%
set IP=%IP:~0,-1%
set MANUFACTURER=%MANUFACTURER:~0,-1%
set STORAGE_USED=%STORAGE_USED:~0,-1%
set BATTERY_LEVEL=%BATTERY_LEVEL: =%
set TEMP_RAW=%TEMP_RAW: =%
goto login

:RunConflict
cls
echo ADB is enabled over USB and TCPIP at the same time.
echo 1: Unplug Device (use Wi-Fi)
echo 2: Keep using USB
set /p connectivity="Choose an option : "
if "%connectivity%"=="2" adb usb & goto check_device
if "%connectivity%"=="1" echo Please unplug device and press Enter...
pause>nul
goto check_device

:UptimeParser
for /f "tokens=1-8 delims=, " %%a in ('adb shell uptime -p') do (
    set "UP_WEEKS=%%b"
    set "UP_DAYS=%%d"
    set "UP_HOURS=%%f"
    set "UP_MINS=%%h"
)
goto root_check

:no_device
cls
echo [%RED%x%R%] %RED%No device detected, please connect your phone/tablet and press Enter...%R%
pause > nul
goto check_device

:login
if %RELOAD%=="0" echo [%date% %time%] Device %MODEL% running Android %API_VER% connected. >> logs/login.log
goto UptimeParser

:window1
cls
set RELOAD=1
for /f "tokens=*" %%i in ('adb shell dumpsys window ^| findstr "mDreamingLockscreen"') do set LOCK_LINE=%%i
for /f "tokens=2 delims==" %%j in ("%LOCK_LINE%") do set IS_LOCKED=%%j
set /a RAM_USED=%RAM% - %RAM_AVBL%
set /a RAM_PERC=100 * %RAM_USED% / %RAM%
set ACTIVE_WINDOW=1
set choice=
if "%RAM%"=="-1" echo [%RED%x%R%] %RED%An error has occured, program will reload...%R% & ping -n 2 127.0.0.1>nul & goto :check_device
REM
echo.
echo.
echo    █████╗ ██████╗ ██████╗     ████████╗ ██████╗  ██████╗ ██╗     
echo   ██╔══██╗██╔══██╗██╔══██╗    ╚══██╔══╝██╔═══██╗██╔═══██╗██║     
echo   ███████║██║  ██║██████╔╝       ██║   ██║   ██║██║   ██║██║          Executed as %CURRENT_USER%
echo   ██╔══██║██║  ██║██╔══██╗       ██║   ██║   ██║██║   ██║██║       
echo   ██║  ██║██████╔╝██████╔╝       ██║   ╚██████╔╝╚██████╔╝███████╗
echo   ╚═╝  ╚═╝╚═════╝ ╚═════╝        ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝
echo.
echo      •1- Advanced Screen Config   •2- Boot Options               ¦   [%YLW%Device%R%]  : %MODEL%
echo      •3- Device Info              •4- Extract DCIM               ¦   [%YLW%OS%R%]      : Android %API_VER%
echo      •5- Share Screen             •6- Logcat Dump                ¦   [%YLW%Root%R%]    : %IS_ROOT%
echo      •7- Dump Full Device         •8- Clear App Cache            ¦   [%YLW%IP%R%]      : %IP%
echo      •9- Screenshot               •10- Install APK               ¦   [%YLW%Brand%R%]   : %MANUFACTURER%
echo      •11- Upload File             •12- Crash Phone               ¦   [%YLW%RAM%R%]     : %RAM_AVBL% MB free of %RAM% MB (%RAM_PERC%%% used)
echo      •13- APK Extractor           •14- Change Brightness         ¦   [%YLW%Storage%R%] : %STORAGE_USED% used out of %STORAGE% GB
echo      •15- Linux Shell             •16- nothing yet...            ¦   [%YLW%Battery%R%] : Charged at %BATTERY_LEVEL%%%
echo      •17- Wireless ADB            •18- Next Page                 ¦   [%YLW%Temps%R%]   : %TEMP_C%°C
echo                                                                  ¦   [%YLW%Uptime%R%]  : %UP_WEEKS%w %UP_DAYS%d %UP_HOURS%h %UP_MINS%m 
echo      •0- Help                     •00- Settings                  ¦   [%YLW%Connect%R%] : Over %CONNECT%
echo.
set /p choice="Enter your choice : "
goto process_choice

:process_choice
if "%choice%"=="1" call :gui_settings
if "%choice%"=="2" call :boot_options
if "%choice%"=="3" call :device_info
if "%choice%"=="4" call :extract_dcim
if "%choice%"=="5" call :scrcpy_start
if "%choice%"=="6" call :logcat_dump
if "%choice%"=="7" call :full_dump
if "%choice%"=="8" call :cache_clear
if "%choice%"=="9" call :screenshot
if "%choice%"=="10" call :install_apk
if "%choice%"=="11" call :upload_file
if "%choice%"=="12" call :crash
if "%choice%"=="13" call :apk_extractor
if "%choice%"=="14" call :change_brightness
if "%choice%"=="15" call :shell_init
REM if "%choice%"=="16" call :
if "%choice%"=="17" call :wireless_adb
if "%choice%"=="19" set ACTIVE_WINDOW=2 && goto :window2
if "%choice%"=="20" set ACTIVE_WINDOW=1 && goto :window1
if "%choice%"=="0" call :help
if "%choice%"=="00" call :settings
if "%choice%"=="" call :no_input
if "%choice%"=="reload" goto :check_device
if "%choice%"=="quit" cls & cmd
goto invalid_input

:save_settings
REM Unused for now
echo (
	AUTO_OPEN=0
	SCREEN_X=2340
	SCREEN_Y=1080
	DPI=380
	MODEL=%MODEL%
	OS=%API_VER%
	MANUFACTURER=%MANUFACTURER%
	ROOT=%IS_ROOT%
	IP=%IP%
) > settings.ini

:scrcpy_start
cd scripts/scrcpy
start scrcpy-noconsole.vbs
cd ../..
echo [%date% %time%] SCRCPY started. >> logs/%MODEL%.log
goto window%ACTIVE_WINDOW%

:boot_options
cls
echo Boot Menu :
echo [0] - Normal Reboot
echo [1] - Recovery Mode
echo [2] - Bootloader
set /p boot_opt="Choose an option : "
if "%boot_opt%"=="0" adb reboot
if "%boot_opt%"=="1" adb reboot recovery
if "%boot_opt%"=="2" adb reboot bootloader
echo Done ! Press Enter to exit...
echo [%date% %time%] Phone Rebooted >> logs/%MODEL%.log
pause > nul
exit

:device_info
cls
REM MAINLY BROKEN FUNCTION, TO FIX LATER
echo Screen Resolution : %SR%
for /f "delims=" %%a in ('adb shell cat /proc/meminfo') do set RAM=%%a
echo RAM %RAM%
for /f "delims=" %%a in ('adb shell dumpsys battery') do set BATTERY=%%a
echo Battery Level : %BATTERY%%
pause > nul
goto window%ACTIVE_WINDOW%

:extract_dcim
cls
echo Will dump pictures and videos to /out/DCIM
echo This may take a while...
adb pull /sdcard/DCIM out
echo Done ! Press Enter to continue...
if %AUTO_OPEN% EQU 1 cd out/DCIM & start explorer.exe & cd ../..
echo [%date% %time%] DCIM folder extracted. >> logs/%MODEL%.log
pause > nul
goto window%ACTIVE_WINDOW%

:help
cls
echo Error 501: Not Implemented.
pause
goto window%ACTIVE_WINDOW%

:settings
cls
echo Error 501: Not Implemented.
pause
goto window%ACTIVE_WINDOW%

:logcat_dump
cls
echo Will dump logcat contents to out/logcat.txt
echo This may take a while...
adb logcat -d > out/logcat.txt
echo Done ! Press Enter to continue...
echo [%date% %time%] Logcat dumped. >> logs/%MODEL%.log
pause > nul
goto window%ACTIVE_WINDOW%

:full_dump
cls
echo Will dump the full phone's storage to out/sdcard
echo This may take a while...
adb pull /sdcard out
echo Done ! Press Enter to continue...
echo [%date% %time%] Full storage dumped. >> logs/%MODEL%.log
pause > nul
goto window%ACTIVE_WINDOW%

:cache_clear
cls
echo Will clear app cached contents...
echo This may take a while...
echo.
echo ------------------ LOGS ------------------
adb shell rm -rf /sdcard/Android/data/*/cache/*
echo ------------------------------------------
echo.
echo Cache cleared, press Enter to continue...
echo [%date% %time%] Apps cache cleared. >> logs/%MODEL%.log
pause > nul
goto window%ACTIVE_WINDOW%

:upload_file
cls
echo Will send a file from in/ to the /Downloads folder
set /p file="Enter the name of the file to send : "
set /p ext="Enter the file extension : "
dir in\%file%.%ext% > nul
if %ERRORLEVEL% EQU 0 adb push "in\%file%.%ext%" /sdcard/Download & echo [%date% %time%] file %file%.%ext% uploaded. >> logs/%MODEL%.log & goto window%ACTIVE_WINDOW%
echo File in/%file%.%ext% does not exist.
echo Press Enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:screenshot
cls
adb shell mkdir /sdcard/temp
set now=%date:/=-%_%time::=-%
set now=%now: =0%
adb shell screencap -p /sdcard/temp/screen_%now%.png
adb pull /sdcard/temp/*.png out/screenshots/
adb shell rm -rf /sdcard/temp/*
echo Screenshot extracted to /out/screenshots.
echo [%date% %time%] Screenshot took. >> logs/%MODEL%.log
echo Press Enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:install_apk
cls
echo Will install an APK file from /in
set /p apk="Enter the name of the APK file : "
dir in\%apk%.apk
if %ERRORLEVEL% EQU 0 adb install "in\%apk%.apk" & echo [%date% %time%] App %apk%.apk installed. >> logs/%MODEL%.log & goto window%ACTIVE_WINDOW%
echo File %apk%.apk does not exist.
echo Press Enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:no_input
cls
echo You can't enter nothing...
pause
goto window%ACTIVE_WINDOW%

:invalid_input
echo Unrecognized command : %choice%.
echo Press Enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:gui_settings
echo [%date% %time%] -1- AdvancedDisplayOptions selected. >> logs/%MODEL%.log
cls
echo --- Advanced Display Options : ---
echo.
echo [1]- Change Screen Resolution
echo [2]- Change Screen Density
echo [3]- Reset Screen Resolution
echo [4]- Reset Screen Density
echo [5]- Reset all
echo [0]- Go back
echo.
set /p gui_cmd="Enter your choice : "
if "%gui_cmd%"=="0" goto window%ACTIVE_WINDOW%
if "%gui_cmd%"=="1" call :gui1
if "%gui_cmd%"=="2" call :gui2
if "%gui_cmd%"=="3" adb shell wm size reset & goto window%ACTIVE_WINDOW%
if "%gui_cmd%"=="4" adb shell wm density reset & goto window%ACTIVE_WINDOW%
if "%gui_cmd%"=="5" (
    adb shell wm size reset
    adb shell wm density reset
    goto window%ACTIVE_WINDOW%
)
echo Invalid input. Press Enter to retry.
pause > nul
goto gui_settings

:gui1
cls
set /p res_y="Enter a custom height (e.g. 1920) : "
set /p res_x="Enter a custom width (e.g. 1080) : "
if "%res_x%"=="0" adb shell wm size reset & goto window%ACTIVE_WINDOW%
if "%res_y%"=="0" adb shell wm size reset & goto window%ACTIVE_WINDOW%
REM if at least one of the vars are equal to 0, then reset the screen size
adb shell wm size %res_y%x%res_x%
echo Resolution changed to %res_y% x %res_x% pixels.
echo [%date% %time%] Resolution changed to %res_x%x%res_y%. >> logs/%MODEL%.log
echo Press Enter to continue...
pause > nul
goto :window%ACTIVE_WINDOW%

:gui2
cls
set /p dpi="Enter a custom DPI value (e.g. 400) : "
if "%dpi%"=="0" adb shell wm density reset & goto window%ACTIVE_WINDOW%
REM if %dpi% is equal to 0, then reset the value
adb shell wm density %dpi%
echo Screen density changed to %dpi% DPI.
echo [%date% %time%] Screen Density changed to %dpi% DPI. >> logs/%MODEL%.log
echo Press Enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:shell_init
echo [%date% %time%] LinuxShell selected. >> logs/%MODEL%.log
if not exist logs/shell_errors.log call :shellErrorsBase
cls
echo ====================================================================================
echo                                 %BLU%Android Linux Shell%R%                                 
echo ====================================================================================
echo.
if "%IS_ROOT%"=="%RED%FALSE%R%" echo Note : You can't use the "su/sudo" commands because your device isn't rooted.
echo.

:shell
set /p command="%MODEL%@user~#%GRN% " && echo %R%
for /f "tokens=1-2 delims= " %%i in ('echo %date% %time%') do set ts=%%i_%%j
if not defined command goto shell
echo [%ts%] %command% >> logs/shell_history.log
if "%command%"=="exit" goto window%ACTIVE_WINDOW%
if "%command%"=="reboot" adb reboot & exit 
if "%command%"=="clearlog" del logs/shell_history.log & goto shell 
if "%command%"=="rickroll" adb shell am start -a android.intent.action.VIEW -d "https://www.youtube.com/watch?v=xvFZjo5PgG0" & goto shell & REM Rickroll link without ads
adb shell %command%
if %ERRORLEVEL% NEQ 0 call :shellErrorHandler
goto shell

:shellErrorHandler
echo [%ts%] Error code %ERRORLEVEL% >> logs/shell_errors.log
if %ERRORLEVEL%==1 echo [%RED%ERROR 1%R%] %MGN%Generic error.%R%
if %ERRORLEVEL%==5 echo [%RED%ERROR 5%R%] %MGN%I/O Error.%R%
if %ERRORLEVEL%==12 echo [%RED%ERROR 12%R%] %MGN%Out of memory.%R%
if %ERRORLEVEL%==16 echo [%RED%ERROR 16%R%] %MGN%Ressource busy.%R%
if %ERRORLEVEL%==20 echo [%RED%ERROR 20%R%] %MGN%Not a directory.%R%
if %ERRORLEVEL%==21 echo [%RED%ERROR 21%R%] %MGN%Is a directory.%R%
if %ERRORLEVEL%==30 echo [%RED%ERROR 30%R%] %MGN%Read-only file system.%R%
if %ERRORLEVEL%==75 echo [%RED%ERROR 75%R%] %MGN%Data type overflow.%R%
if %ERRORLEVEL%==100 echo [%RED%ERROR 100%R%] %MGN%Network is down.%R%
if %ERRORLEVEL%==101 echo [%RED%ERROR 101%R%] %MGN%Network is unreachable.%R%
if %ERRORLEVEL%==126 echo [%RED%ERROR 126%R%] %MGN%Permission denied.%R%
if %ERRORLEVEL%==127 echo [%RED%ERROR 127%R%] %MGN%Command not found.%R%
if %ERRORLEVEL%==128 echo [%RED%ERROR 128%R%] %MGN%Invalid exit argument.%R%
if %ERRORLEVEL%==130 echo [%RED%ERROR 130%R%] %MGN%Cancelled by user.%R%
if %ERRORLEVEL%==255 echo [%RED%ERROR 255%R%] %MGN%Unrecognized error code.%R%
goto shell

:crash
cls
echo THIS WILL CRASH YOUR PHONE /!\
echo THERE IS SOME RISKS FOR DATA CORRUPTION
echo To confirm, type "crash" :
set /p confirm="#~ "
if /i "%confirm%"=="safe" (
 REM That's an easter egg
 echo You chose peace over violence. Good choice >ω<
 pause > nul
 goto window%ACTIVE_WINDOW%
)
if /i "%confirm%"=="crash" (
	echo [%date% %time%] CRASH COMMAND EXECUTED ON %MODEL% >> logs/adb.log
	REM A dumb animation
	ping localhost -n 2 > nul
	cls
	echo [▓░░░░░░░░░] 9%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓░░░░░░░░] 24%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓░░░░░░░] 37%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓░░░░░░] 48%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓▓░░░░░] 53%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓▓▓▓░░░] 74%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓▓▓▓▓░░] 88%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓▓▓▓▓▓░] 99%%
	ping localhost -n 2 > nul
	cls
	echo [▓▓▓▓▓▓▓▓▓▓] 100%%
	ping localhost -n 2 > nul
	echo Executing payload...
	adb push scripts/crash.sh /sdcard/adb_tool_temp > nul
	adb shell chmod +x /sdcard/adb_tool_temp/crash.sh > nul
	adb shell ./crash.sh > nul
	ping localhost -n 20 > nul
	exit
)

echo You typed the confirmation wrong, your phone is safe... :)
pause > nul
goto window%ACTIVE_WINDOW%

:apk_extractor
REM Nothing here for now...
goto window%ACTIVE_WINDOW%

:screen_recording
echo Recording... Press CTRL+C to stop...
adb shell screenrecord /sdcard/adb_tool_temp/recording.mp4
adb pull /sdcard/adb_tool_temp/recording.mp4 out
echo Recording extracted to /out.
goto window%ACTIVE_WINDOW%

REM THINGS TO TRY LATER:
REM NOTIFS adb shell cmd notification post testNotif 1337 "Test" "This is an ADB notification"
REM FULL_BACKUP adb backup -apk -obb -shared -all -f out/backup.ab

:change_brightness
setlocal enabledelayedexpansion
cls
set /p perc="Enter a percentage : "
if !perc! lss 0 set perc=0
if !perc! gtr 100 set perc=100
set /a temp_var=%perc% * 255 + 50 > nul
set /a brightness=%temp_var% / 100 > nul
adb shell settings put system screen_brightness !brightness!
echo Screen Brightness changed to %perc%% (!brightness!).
echo [%date% %time%] Brightness changed to %perc%%. >> logs/%MODEL%.log
echo Press Enter to go back...
pause > nul
goto window%ACTIVE_WINDOW%

:wireless_adb
REM BROKEN 
cls
echo [%YLW%~%R%] Starting TCPIP on port 5555...
adb tcpip 5555
echo [%YLW%Waiting for device to initialize%R%]
ping -n 8 127.0.0.1>nul
echo [%YLW%~%R%] Connecting to the phone...
adb connect %IP%:5555
if !ERRORLEVEL! EQU "0" goto TcpConnected
echo [%RED%x%R%] Unable to connect to %IP%:5555, press enter to continue...
pause > nul
goto window%ACTIVE_WINDOW%

:TcpConnected
cls
set RunOverUSB=0
set RunOverTCPIP=1
echo [+] Connected to %IP%:5555
echo Please unplug your device to continue...
pause >nul
exit

:shellErrorsBase
echo (
	------------------------------------------------------
					 ADB Shell Error log
		 (this file was auto-generated by adb tool)
	 ------------------------------------------------------
					  Common error codes : 
	 [ERROR 1]  Generic error. 
	 [ERROR 5]  I/O Error. 
	 [ERROR 12]  Out of memory. 
	 [ERROR 16]  Ressource busy. 
	 [ERROR 20]  Not a directory. 
	 [ERROR 21]  Is a directory. 
	 [ERROR 30]  Read-only file system. 
	 [ERROR 75]  Data type overflow. 
	 [ERROR 100]  Network is down. 
	 [ERROR 101]  Network is unreachable. 
	 [ERROR 126]  Permission denied. 
	 [ERROR 127]  Command not found. 
	 [ERROR 128]  Invalid exit argument. 
	 [ERROR 130]  Cancelled by user. 
	 [ERROR 255]  Unrecognized error code. 
	 ------------------------------------------------------
) >> logs/shell_errors.log
