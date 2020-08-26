$host.ui.RawUI.WindowTitle = “WWiU Script”
$version = "0.7"
$githubver = "https://raw.githubusercontent.com/Pakobbix/AutoToolkitPscript/master/currentversion.txt"
$updatefile = "https://github.com/Pakobbix/AutoToolkitPscript/blob/master/update.ps1"
# WWiU Steht für Windows with integrated Updates. 
# Dieses Skript ist aus neugierde und aus dem Mangel an Automatismus unserer Firma entstanden.
# Selbst unsere NAS-Server Lösung ist eher träge und erfordert zu oft einschreiten seitens der Techniker.
# Das Skript soll abhilfe schaffen.
#
# Was genau macht das Skript?
#
# Das Skript Verbindet verschiedene Tools um am ende eine Windows 10 Iso zuu erstellen, die alle updates beinhaltet.
# Man kann entweder direkt ein USB-Stick damit bespielen, oder die ISO einfach auf die Zielcomputer kopieren und von da aus bereitstellen.
# Anders als bei WSUSoffline muss nicht erst das Funktionsupdate gemacht werden, dann WSUS Client gestartet werden und dann hoffen, dass man kein TempAdmin
# Account vorfindet. Außer natürlich bei Windows S Mode Geräte. Da geht WSUS sowieso nicht. 
#
# Bei der Erstellten Windows ISO muss nichts weiter getan werden, als das Setup.exe ausgeführt werden. Das Setup führt automatisch das Funktions-Update aus, 
# und installiert anschließend ohne fremde Einwirkung die Windows Kumulativen Updates. 
#
#
# Im Moment funktioniert das Skript soweit schonmal. Geplant ist noch:
# 
# Eine Auto-Update funktion, um den prozess weiter zu automatisieren
#
# Das einfügen einer Setup.exe mit Parametern (/auto upgrade /dynamicupdate disable). Damit auch das Automatisch abläuft.
#
# Das Automatische hinzufügen einer alle 2 Wochen auszuführenden Aufgabenplanung in Windows.
#
# Optimierungen der InVoke-WebRequest Befehle mit Progress Anzeige (Write-Progress funktioniert nicht mit der StopLoop function)

function UpdatesAvailable()
{
	$updateavailable = $false
	$nextversion = $null
	try
	{
		$nextversion = (New-Object System.Net.WebClient).DownloadString($githubver).Trim([Environment]::NewLine)
	}
	catch [System.Exception] 
	{
		Write-Message $_ "debug"
	}
	
	Write-Message "Aktuelle Version: $version" "debug"
	Write-Message "Neuere Version: $nextversion" "debug"
	if ($nextversion -ne $null -and $version -ne $nextversion)
	{
		#An update is most likely available, but make sure
		$updateavailable = $false
		$curr = $version.Split('.')
		$next = $nextversion.Split('.')
		for($i=0; $i -le ($curr.Count -1); $i++)
		{
			if ([int]$next[$i] -gt [int]$curr[$i])
			{
				$updateavailable = $true
				break
			}
		}
	}
	return $updateavailable
}

function Process-Updates()
{
	if (Test-Connection 8.8.8.8 -Count 1 -Quiet)
	{
		$updatepath = "$($PWD.Path)\update.ps1"
		if (Test-Path -Path $updatepath)	
		{
			#Remove-Item $updatepath
		}
		if (UpdatesAvailable)
		{
			Write-Message "Update available. Do you want to update luckystrike? Your payloads/templates will be preserved." "success"
			$response = Read-Host "`nPlease select Y or N"
			while (($response -match "[YyNn]") -eq $false)
			{
				$response = Read-Host "This is a binary situation. Y or N please."
			}

			if ($response -match "[Yy]")
			{	
				(New-Object System.Net.Webclient).DownloadFile($updatefile, $updatepath)
				Start-Process PowerShell -Arg $updatepath
				exit
			}
		}
	}
	else
	{
		Write-Message "Es konnte nicht nach Aktualisierungen geprüft werden." "WARNUNG!"
	}
}



#Wir testen erstmal, ob noch genug Speicher vorhanden ist, um alles vorzubereiten.

$drives = @("C");
 
# The minimum disk size to check for raising the warning
$minSize = 50GB;
 
if ($drives -eq $null -Or $drives -lt 1) {
    $localVolumes = Get-WMIObject win32_volume;
    $drives = @();
    foreach ($vol in $localVolumes) {
        if ($vol.DriveType -eq 3 -And $vol.DriveLetter -ne $null ) {
            $drives += $vol.DriveLetter[0];
        }
    }
}

foreach ($d in $drives) {
    Write-Host ("`r`n");
    Write-Host ("Teste ob auf " + $d + " genug Speicher vorhanden ist...");
    $disk = Get-PSDrive $d;
    if ($disk.Free -lt $minSize) {
        Write-Host
		Write-Host -ForegroundColor red ("Laufwerk " + $d + " hat weniger als " + [math]::Round($minSize) /1Gb `
            + " GigaByte frei (" + [math]::Round($disk.free) /1Gb + ")");
		Write-Host
		Write-Host -ForegroundColor red "========================== Vorgang wird abgebrochen. =========================="
		Write-Host
			pause
			exit
    }
    else {
		Write-Host
        Write-Host ("Laufwerk " + $d + " hat noch mehr als " + [math]::Round($minSize) /1Gb + " GigaByte frei.");
		Write-Host
		Write-Host -ForegroundColor Green "Alles in Ordnung, Script wird gestartet"
    }
}

## Als erstes Entfernen wir alte Dateien. Für die Automatisierung müsste WSUS Offline und Toolkit entfernt werden. Man könnte auch alte dateien überschreiben
# Aber dies könnte in zukunft probleme Verursachen, daher machen wir das system erstmal sauber.


gci C:\WWiU\wsusoffline -Recurse -Exclude @('*.cab','builddate.txt','catalogdate.txt','ndp*.exe', '*.msu') | ? { ! $_.PSIsContainer } | Remove-Item -Force
rmdir "C:\WWiU\Toolkit_v10.2" -r
rmdir "C:\WWiU\Toolkit_v10.3" -r

# Wir erstellen erstmal einen neuen Ordner damit es einfacher ist

mkdir > $null "C:\WWiU" 
Write-Host
mkdir > $null "C:\WWiU\Toolkit_v10.3" 

#Diese Beiden Skripte sind Anpassung an das Toolkit, damit man keine eingaben Vornehmen muss. 
#StartAuto.cmd wird benötigt um die Umgebungsvariablen fürs Toolkit zu setzen. Damit die Auto unud nicht die normale version geladen wird, habe ich hier eigentlich nur den Befehl entsprechend angepasst.
#ToolkitAuto.cmd ist die wirkliche Arbeit gewesen. Im Grunde habe ich nur überall die "choice" befehle durch direkte angaben ersetzt. Dadurch muss man keine eingaben per Hand mehr eingeben und kann einfach 
#darauf warten, das der Laptop/PC alles abgearbeitet hat. Die Fertige Windows ISO wird dann ins ISO verzeichnis vom Toolkit erstellt. Am Ende wird diese dann auf den Desktop kopiert, damit sie einfach zu finden ist.

#copy StartAuto.cmd "C:\WWiU\Toolkit_v10.3\"
#Write-Host
#copy ToolkitAuto.cmd "C:\WWiU\Toolkit_v10.3\"

set-location C:\

# Es scheint so, als ob die Fortschrittsanzeige den Download immens verlangsamt. Daher schalten wir diese mit dem Befehl
# Für alle folgenden InVoke-WebRequest anfragen aus.
#$ProgressPreference = 'SilentlyContinue'

# Hier Laden wir das Toolkit und WSUSoffline Programm runter.
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow =========================== Lade Toolkit 10.3  herunter ============================
Write-Host
Write-Host
$Stoploop = $false
[int]$Retrycount = "0"

do {
try {
InVoke-WebRequest "https://securedl.cdn.chip.de/downloads/84514730/ToolKit_v10.3.zip?cid=135294416&platform=chip&1598456903-1598464403-38a3e0-B-836cb96a8133dd78c13c5d8f8455ca5b" -o "C:\WWiU/Toolkit.zip" 
Write-Host -ForegroundColor Green "=========================== Toolkit 10.3 heruntergeladen ============================"
$Stoploop = $true
}
catch {
if ($Retrycount -gt 3){
Write-Host
Write-Host -ForegroundColor Red "Es wurde mehr als 3x die Verbindung beim Downloaden unterbrochen. Teste eure Internetverbindung oder probiere es Später noch einmal"
Write-Host
pause
exit
$Stoploop = $true
}
else {
Write-Host -ForegroundColor Red "Download ist fehlgeschlagen. Es wird 30 Sekunden gewartet und erneut probiert."
Start-Sleep -Seconds 30
$Retrycount = $Retrycount + 1
}
}
}
While ($Stoploop -eq $false)

# Hier nicht wundern, wir benutzen die 12.2 Community Edition, da diese die Win 10 2004 Version unterstuetzt. Sie wird wieder gegen die Offizielle getauscht, sobald diese das ebenfalls tut.
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======================== Lade WSUSoffline CE 12.2 herunter. =======================
Write-Host
Write-Host
$Stoploop = $false
[int]$Retrycount = "0"

do {
try {
InVoke-WebRequest "https://gitlab.com/wsusoffline/wsusoffline/uploads/8fbaf41f8cc974c8cf9fa1a4642ba49c/wsusofflineCE122.zip" -o "C:\WWiU/wsusoffline.zip"
Write-Host -ForegroundColor Green "=========================== WSUSoffline 12.2 heruntergeladen ============================"
$Stoploop = $true
}
catch {
if ($Retrycount -gt 3){
Write-Host
Write-Host -ForegroundColor Red "Es wurde mehr als 3x die Verbindung beim Downloaden unterbrochen. Teste eure Internetverbindung oder probiere es Später noch einmal"
Write-Host
pause
exit
$Stoploop = $true
}
else {
Write-Host "Download ist fehlgeschlagen. Es wird 30 Sekunden gewartet und erneut probiert."
Start-Sleep -Seconds 30
$Retrycount = $Retrycount + 1
}
}
}
While ($Stoploop -eq $false)
# Rufus wird später benötigt für die Erstellung eines Windows10 USB-Sticks. Daher laden wir hier die Portable Version runter damit diese dann einfach ausgeführt werden kann.
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======================== Lade Rufus 3.11 Portable herunter. =======================
Write-Host
Write-Host
$Stoploop = $false
[int]$Retrycount = "0"

do {
try {
InVoke-WebRequest "https://github.com/pbatard/rufus/releases/download/v3.11/rufus-3.11p.exe" -o "C:\WWiU\rufus-3.11p.exe"
Write-Host -ForegroundColor Green "=========================== Rufus 3.11p heruntergeladen ============================"
$Stoploop = $true
}
catch {
if ($Retrycount -gt 3){
Write-Host
Write-Host -ForegroundColor Red "Es wurde mehr als 3x die Verbindung beim Downloaden unterbrochen. Teste eure Internetverbindung oder probiere es Später noch einmal"
Write-Host
pause
exit
$Stoploop = $true
}
else {
Write-Host "Download ist fehlgeschlagen. Es wird 30 Sekunden gewartet und erneut probiert."
Start-Sleep -Seconds 30
$Retrycount = $Retrycount + 1
}
}
}
While ($Stoploop -eq $false)

#Write-Host
#Write-Host
#Write-Host
#Write-Host -ForegroundColor Yellow ===================== Lade das MediaCreationTool 2004 herunter. ====================
#Write-Host
#Write-Host
#Write-Host
#InVoke-WebRequest "https://software-download.microsoft.com/download/pr/8d71966f-05fd-4d64-900b-f49135257fa5/MediaCreationTool2004.exe" -o "C:\WWiU\MediaCreationTool2004.exe"
# Jetzt wird es noch entpackt und nicht relevante Daten entfernt (Die ZIP und die MACOSX Daten werden nicht weiter benoetigt)
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======================== Extrahiere Toolkit 10.3 ZIP-Datei. =======================
Write-Host
Write-Host

Expand-Archive "C:\WWiU/Toolkit.zip" -DestinationPath "C:\WWiU/"
Write-Host -ForegroundColor Green ================ Extraktion von Toolkit 10.3 ZIP-Datei erfolgreich. ================

Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======================== Erstelle Backup der Toolkit.cmd =======================
Write-Host
Write-Host
Write-Host
copy C:\WWiU\Toolkit_v10.3\Toolkit.cmd C:\WWiU\Toolkit_v10.3\ToolkitOriginal.cmd
Write-Host
Write-Host
Write-Host -ForegroundColor Green ======================== Backup der Toolkit.cmd Erstellt =======================
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow =================== Entferne Eingabeaufforderungen aus der Toolkit.cmd ==================
Write-Host
# Hier geben wir die Toolkit.cmd an, um diese im nächsten Schritt zu verändern.
$file = "C:\WWiU\Toolkit_v10.3\Toolkit.cmd"

# Der Befehl dient dazu, die CMD durch die Powershell lesbar zu machen und lädt deren Inhalt.
$content = Get-Content -Path $file

# Jetzt werden die einzelnen Zeilen der Toolkit.cmd so verändert, dass jegliche User eingabe durch automatische Eingaben ersetzt wird, bzw. es für User eingaben keine Möglichkeit mehr gibt.
# Wichtig zu beachten ist, das es immer -1 Zeile ist. Will man also den Text in Zeile 24 ändern, so setzt man die Zahl 23 in eckige Klammern.

$content[175] = "::choice /C AR /N /M ::::::::::::::::::::::::::::::::::::::::::::::::::::::[ 'A'ccept / 'R'eject ]::::::::::::::::::::::::::::::::::::::::::::::::::::::::"
$content[176] = '::if errorlevel 2 ('
$content[177] = '::	reg delete "HKCU\Console\%%SystemRoot%%_system32_cmd.exe" /f >nul'
$content[178] = '::'
$content[179] = '::	color 00'
$content[180] = '::	endlocal EnableExtensions'
$content[181] = '::	endlocal EnableDelayedExpansion'
$content[182] = '::'
$content[183] = '::	exit'
$content[184] = '::)'
$content[192] = 'echo.Entferne erstmal nicht verwendbare Dateien. Einen Moment bitte...'
$content[238] = '::pause >nul'
$content[270] = 'goto :SourceMenu'
$content[332] = 'goto :SelectSourceISO'
$content[2850] = 'goto :MakeISO'
$content[2903] = 'echo.               MSMG ToolKit - Waehle Windows Version aus dem DVD Ordner'
$content[2937] = 'echo.########################## Waehle die Version ##########################'
$content[2944] = '::if "%ImageIndexNo%" equ "1" ('
$content[2945] = '::	echo.'
$content[2946] = '::	echo.Invalid Index # Entered, Valid Range is [1-%ImageCount%]'
$content[2947] = '::	echo.'
$content[2948] = '::	echo.Press Enter to Try Again...'
$content[2949] = '::	pause >nul'
$content[2950] = '::	goto :SelectSourceDVD'
$content[2951] = '::)'
$content[2954] = '::if "%ImageIndexNo%" neq "*" if "%ImageIndexNo%" lss "1" ('
$content[2955] = '::	echo.'
$content[2956] = '::	echo.Invalid Index # Entered, Valid Range is [1-%ImageCount%]'
$content[2957] = '::	echo.'
$content[2958] = '::	echo.Press Enter to Try Again...'
$content[2959] = '::	pause >nul'
$content[2960] = '::	goto :SelectSourceDVD'
$content[2961] = '::)'
$content[2964] = '::if "%ImageIndexNo%" neq "*" if "%ImageIndexNo%" gtr %ImageCount% ('
$content[2965] = '::	echo.'
$content[2966] = '::	echo.Invalid Index # Entered, Valid Range is [1-%ImageCount%]'
$content[2967] = '::	echo.'
$content[2968] = '::	echo.Press Enter to Try Again...'
$content[2969] = '::	pause >nul'
$content[2970] = '::	goto :SelectSourceDVD'
$content[2971] = '::)'
$content[2974] = 'if "1" equ "*" call :GetImageIndexInfo "%InstallWim%", 1 >nul'
$content[2975] = 'if "1" neq "*" call :GetImageIndexInfo "%InstallWim%", %ImageIndexNo% >nul'

$content[2992] = '::choice /C:YN /N /M "Do you want to mount Windows Setup Boot Image ? [Yes/No] : "'
$content[2993] = '::if "%errorlevel%" equ "1" set "IsBootImageSelected=Yes"'
$content[2994] = '::if "%errorlevel%" equ "2" set "IsBootImageSelected=No"'
$content[2995] = 'set "IsBootImageSelected=Yes"'
$content[2996] = 'echo.'
$content[2997] = '::choice /C:YN /N /M "Do you want to mount Windows Recovery Image ? [Yes/No] : "'
$content[2998] = 'if "%errorlevel%" equ "1" set "IsRecoveryImageSelected=Yes"'
$content[2999] = '::if "%errorlevel%" equ "2" set "IsRecoveryImageSelected=No"'
$content[3000] = 'set "IsRecoveryImageSelected=Yes"'

$content[3090] = '::Stop'
$content[3094] = '::pause'
$content[3096] = 'goto :IntUpdatesMenu'

$content[3200] = '	echo.Das Quell DVD verzeichnis ist nicht leer....'

$content[3216] = 'echo.#### Starte das Entpacken der Windows 10.iso Datei ##############'
$content[3220] = 'echo.#### Hole DVD ISO Image Optionen ##############################################'
$content[3224] = 'echo.#### Hole DVD ISO Image Optionen ##############################################'
$content[3220] = 'echo.#### Hole DVD ISO Image Optionen ##############################################'

$content[3224] = ':: set /p ISOFileName=Enter the ISO Image filename without .iso : '
$content[3227] = 'set "ISOFileName=Windows 10.iso"'

$content[3239] = 'echo.#### Extrahiere die Windows 10.iso ins DVD Image Verzeichnis #######################'
$content[3243] = 'echo.Extrahiere die Windows 10.iso ins DVD Image Verzeichnis...'
$content[3245] = 'echo.Das Entpacken der ISO Datei kann ein wenig Zeit beanspruchen...'

$content[3255] = 'echo.#### Das Entpacken der Windows 10.iso ist Fertig ##############'
$content[3258] = '::Stop'
$content[3262] = '::pause'
$content[3269] = 'goto :SelectSourceDVD'

$content[3356] = 'goto :IntegrateMenu'
$content[3391] = 'echo.Lese die Windows Versionen aus...'

$content[3796] = '::pause'
$content[3798] = 'goto :MakeISO'

$content[5925] = 'goto :SaveSource'

$content[13564] = 'if "%IsDialogsEnabled%" equ "No" ('

$content[13618] = '::choice /C:12X /N /M "Enter Your Choice : "'
$content[13619] = '::if errorlevel 3 goto :IntegrateMenu'
$content[13620] = '::if errorlevel 2 goto :IntWHDUpdatesMenu'
$content[13621] = '::if errorlevel 1 call :IntUpdates WUpdates'
$content[13622] = 'call :IntUpdates WUpdates'

$content[18255] = '::pause'
$content[18279] = 'goto :SaveSource'

$content[22866] = '::choice /C:YN /N /M "Do you want to cleanup Image Windows folder ? [Yes/No] : "'

$content[23005] = '::pause'
$content[23007] = 'goto :ConvertWim2Esd'

$content[23197] = 'set ISOLabel=Windows 10 WU'
$content[23201] = 'set ISOFileName=Windows 10 WU'

$content[23226] = '::pause'
$content[23236] = 'goto :Quit'

$content[25745] = '::if "%ImageCount%" equ "1" ( '
$content[25746] = ':: set /p ImageIndexNo=1'
$content[25747] = '::) else set /p ImageIndexNo=Gebe die Versionsnummer ein # [Range : 1-%ImageCount%, * - All] : '
$content[25748] = 'set ImageIndexNo=1'

$content[26364] = 'call :RemoveFolder "%DVD%"'
$content[26355] = 'echo.'

$content[26402] = '::pause'





# Set the new content
$content | Set-Content -Path $file
Write-Host
Write-Host -ForegroundColor Green =================== Eingabeaufforderungen aus der Toolkit.cmd Entfernt ==================
Write-Host
Write-Host
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======================== Extrahiere WSUSoffline ZIP-Datei. ========================
Write-Host
Write-Host

Expand-Archive "C:\WWiU/wsusoffline.zip" -DestinationPath "C:\WWiU/"
Write-Host -ForegroundColor Green ============ Extraktion von WSUSoffline 12.2 CE ZIP-Datei erfolgreich. =============

Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ========================= Lösche nicht benötigte Daten. ===========================
Write-Host
Write-Host

rmdir "C:\WWiU/__MACOSX" -r
rm "C:\WWiU/Toolkit.zip"
rm "C:\WWiU/wsusoffline.zip"

Write-Host -ForegroundColor Green ========================= Löschung war erfoglreich. ===========================


# Hier laden wir die Aktuelle Windows 10 Version runter, direkt von Microsoft.
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ================ Lade die Windows 10 Iso von den Microsoft Servern ================
Write-Host
Write-Host
Write-Host
$Stoploop = $false
[int]$Retrycount = "0"

do {
try {
InVoke-WebRequest "https://software-download.microsoft.com/db/Win10_2004_German_x64.iso?t=4be51806-204a-4e64-933a-8661221eec2d&e=1598508126&h=03e35ffcd88ef8e55ffcf68a3d0d1c98" -o "C:\WWiU\Toolkit_v10.3\ISO\Windows 10.iso"
Write-Host -ForegroundColor Green "=========================== Windows 10 ISO heruntergeladen ============================"
$Stoploop = $true
}
catch {
if ($Retrycount -gt 3){
Write-Host
Write-Host -ForegroundColor Red "Es wurde mehr als 3x die Verbindung beim Downloaden unterbrochen. Teste eure Internetverbindung oder probiere es Später noch einmal"
Write-Host
pause
exit
$Stoploop = $true
}
else {
Write-Host "Download ist fehlgeschlagen. Es wird 30 Sekunden gewartet und erneut probiert."
Start-Sleep -Seconds 30
$Retrycount = $Retrycount + 1
}
}
}
While ($Stoploop -eq $false)


#.\WWiU\MediaCreationTool2004.exe /Eula Accept /Retail /MediaLangCode de-de /MediaArch x64 /MediaEdition Home

# Dann starten wir mal WSUSoffline und laden die Updates runter
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ============================ Starte WSUSoffline Update =============================
Write-Host
Write-Host
Write-Host

.\WWiU\wsusoffline\cmd\DownloadUpdates.cmd w100-x64 glb /includedotnet /verify /exitonerror

# Nun kopieren wir die runtergeladenen Updates zum MSMG Toolkit Updates Ordner damit toolkit diese Einbinden kann.

# Parameter Erkärung:
# /f = Zeige kopierende Dateien an.
# /v = überprüft die Dateien, ob diese Identisch sind.
# /y = Überschreibt automatisch bereits vorhandene Dateien ohne abfrage (Für die Automatisierung)

Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ============================ Kopiere die Win10 Updates =============================
Write-Host
Write-Host
Write-Host

xcopy /f /v /y "C:\WWiU\wsusoffline\client\w100-x64\glb\*.*" "C:\WWiU\Toolkit_v10.3\Updates\w10\x64\"

#Und nun wird das Toolkit gestartet und eine Windows ISO mit allen Updates erstellt. 
Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ======== Starte die Erstellung einer Windows ISO mit Updates durch Toolkit =========
Write-Host
Write-Host

Start-Process "C:\WWiU\Toolkit_v10.3\Start.cmd" -NoNewWindow -Wait

Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ====================== Kopiere die Windows 10 ISO zum Desktop =======================
Write-Host
Write-Host

xcopy /f /v /y "C:\WWiU\Toolkit_v10.3\ISO\Windows 10 WU.iso" "C:\Users\Public\Desktop\"

Write-Host
Write-Host
Write-Host -ForegroundColor Yellow ==================== Starte Rufus zum erstellen eines USB Sticks ====================
Write-Host
Write-Host

C:\WWiU\rufus-3.11p.exe




## Sollte ein Download abbrechen, oder nicht funktionieren, bis zu 3x wiederholen. Muss noch getestet werden.
#
#$Stoploop = $false
#[int]$Retrycount = "0"
#
#do {
#try {
#InVoke-WebRequest "https://securedl.cdn.chip.de/downloads/84514730/Toolkit_v10.3.zip?cid=135294416&platform=chip&1598173116-1598180616-99e7d8-B-4aa8bc1b5a06fc4635846d6c7a3c82ce" -o "C:\WWiU/Toolkit.zip"
#Write-Host -ForegroundColor Green "=========================== Toolkit 10.2 heruntergeladen ============================"
#$Stoploop = $true
#}
#catch {
#if ($Retrycount -gt 3){
#Write-Host "Es wurde mehr als 3x die Verbindung beim Downloaden unterbrochen. Teste eure Internetverbindung oder probiere es Später noch einmal"
#$Stoploop = $true
#}
#else {
#Write-Host "Download ist fehlgeschlagen. Es wird 30 Sekunden gewartet und erneut probiert."
#Start-Sleep -Seconds 30
#$Retrycount = $Retrycount + 1
#}
#}
#}
#While ($Stoploop -eq $false)
