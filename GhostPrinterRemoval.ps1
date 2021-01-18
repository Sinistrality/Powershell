#Sets the variable to pull all the bad entries from the user IDs
#You want to run this as the local system account to get the second half to work (PDQ Deploy)

#You'll want to use this as a last resort to remove "Ghost" or "Amoeba" printers that keep coming back after being removed.

#GNU General Public License v2.0
#Author: Mike Kisiel
#Last Update: 6/29/2019

#If you're unable to run this using a tool to run as system then use PSEXEC to get a System powershell console going.
#SERIOUSLY RUN THIS AS SYSTEM INSTEAD OF ADMIN

#Removes targeted printers from the computer based on the Printer Name and Print Server.  (Use this with PDQ Deploy as it needs to run as the system account to go deep into the registry)

#For parameters the printer name can be partial
#For example if printers you want to remove begin with Printer- you can use that as a parameter
#Example:     GhostPrinterRemoval.ps1 "Printer-" "Server-Print"

#Be sure to modify the $PrintServer variable if you want to default it.


[CmdLetBinding()]
Param
(
    [Parameter(Mandatory=$True)]
    [string]$PrinterName,
    [Parameter(Mandatory=$false)]
    [string]$PrintServer
)

#Auto Fills default print server if parameter is empty
If ($PrintServer -eq "" -or $null){
$PrintServer = "Put your print server here to default to it if you're not going to feed it in the parameters"}

$CleanDeadGUIDsOn = $true
$DebugModeOn = $false


Write-Host "Removing $PrinterName on $PrintServer entries." -ForegroundColor Green

Function CarriageReturn{
#Puts Spaces in the Output so PDQ Deploy Output Logs look clean
Write-Output `r`n
}
CarriageReturn

#Prints a seperator line in output
Function SpacerLine{
Write-Host '________________________________________________________________________________________________' -ForegroundColor DarkYellow
CarriageReturn
}

If ($DebugModeOn -eq $true){
SpacerLine
Write-Host "DEBUG MODE ENABLED: Generating extra output"
CarriageReturn
SpacerLine
}


#Cleans out the user SID list
$BadPrinters = get-childitem -path "hklm:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider" -recurse -ErrorAction SilentlyContinue | Where-Object {$_.Name -like "*,,$PrintServer,$PrinterName*"}
#Checks if it found anything
If ($BadPrinters -ne $null){

$RemovedCounter = 0
foreach ($name in $BadPrinters){
Write-Host "Key Found: " -ForegroundColor Yellow -NoNewline; Write-Host $name -ForegroundColor Magenta
CarriageReturn


#Removes Key
Remove-Item -Path Registry::$name -Confirm:$false -Recurse
#Counts
$RemovedCounter = $RemovedCounter + 1
}
Write-Host "User Keys Removed:" $RemovedCounter -ForegroundColor Green
CarriageReturn
}
Else
{Write-Host "No User Keys Found" -ForegroundColor Cyan}
CarriageReturn

SpacerLine

$ServerRemovedCounter = 0
Try{
#Cleans out the print server list
$PrintServerList = get-childitem -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers\$PrintServer\Printers" -ErrorAction Stop
foreach ($entry in $PrintServerList){
#Checks the description field for printer info
$DescriptionInfo = Get-ItemProperty -Path Registry::$entry

#If it finds the server\printer combo it deletes the key
If ($DescriptionInfo.Description -like "*$PrintServer\$PrinterName*"){
Write-Host "Server Key Found for" $DescriptionInfo.Description "in GUID key" $DescriptionInfo.PSChildName -ForegroundColor Green
CarriageReturn

#Increases Counter
$ServerRemovedCounter = $ServerRemovedCounter + 1
$GUIDPath = $DescriptionInfo.PSPath
#Removes Key
Remove-Item -Path $GUIDPath -Confirm:$false -Recurse

}



#End of for each
}
}Catch{
Write-Host "Could not find/edit path: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers\$PrintServer\Printers"
}


If ($ServerRemovedCounter -gt 0){
Write-Host "Server Keys Removed:" $ServerRemovedCounter -ForegroundColor Green
CarriageReturn
}
Else
{Write-Host "No Server Keys Found" -ForegroundColor Cyan}
CarriageReturn



If ($CleanDeadGUIDsOn -eq $true){
SpacerLine
Write-Host "Checking Servers key for inactive GUIDs and removing them." -ForegroundColor Yellow
CarriageReturn
#Remove Dead GUIDs
$ServerRemovedCounter = 0
$ServerGoodCounter = 0
Try{
#Cleans out the print server list
$PrintServerList = get-childitem -path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers\$PrintServer\Printers" -ErrorAction Stop
foreach ($entry in $PrintServerList){
#Checks the description field for printer info
$DescriptionInfo = Get-ItemProperty -Path Registry::$entry

#If it finds the server\printer combo it deletes the key
If ($DescriptionInfo.Description -notlike "*$PrintServer\*"){
Write-Host "Bad GUID Found in $PrintServer GUID key" $DescriptionInfo.PSChildName -ForegroundColor Green
CarriageReturn

#Increases Counter
$ServerRemovedCounter = $ServerRemovedCounter + 1
$GUIDPath = $DescriptionInfo.PSPath
#Removes Key
Remove-Item -Path $GUIDPath -Confirm:$false -Recurse

}


#Displays good GUID's for debugging
If ($DebugModeOn -eq $true){
If ($DescriptionInfo.Description -like "*$PrintServer\*"){
Write-Host "Good GUID Found in $PrintServer GUID key" $DescriptionInfo.PSChildName -ForegroundColor Yellow
CarriageReturn
#Increases Counter
$ServerGoodCounter = $ServerGoodCounter + 1
$GUIDPath = $DescriptionInfo.PSPath

}

#End Debug Mode
}


#End of for each
}
}Catch{
Write-Host "Could not find/edit path: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers\$PrintServer\Printers"
}
If ($DebugModeOn -eq $true){
If ($ServerRemovedCounter -gt 0){
Write-Host "Correct Format GUID Keys Found:" $ServerGoodCounter -ForegroundColor Yellow
CarriageReturn
}
Else
{Write-Host "No Correct Format GUID Keys Found" -ForegroundColor Cyan}
CarriageReturn
}

If ($ServerRemovedCounter -gt 0){
Write-Host "Inactive GUID Keys Removed:" $ServerRemovedCounter -ForegroundColor Green
CarriageReturn
}
Else
{Write-Host "No Inactive GUID Keys Found" -ForegroundColor Cyan}
CarriageReturn
#End Dead GUIDs On
}

SpacerLine

#Cleans out the system PRINTENUM List
$SystemRemovedCounter = 0
$SystemStandardCounter = 0
Try{
#Cleans out the print server list
$PrintServerList = get-childitem -path "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM" -ErrorAction Stop
foreach ($systementry in $PrintServerList){
#Checks the description field for printer info
$SysDescriptionInfo = Get-ItemProperty -Path Registry::$systementry

#If it finds the server\printer combo it deletes the key if it's not redirected through RDP
If ($SysDescriptionInfo.FriendlyName -like "*$PrintServer\$PrinterName*" -and $SysDescriptionInfo.FriendlyName -notlike "*Redirected*" -and $SysDescriptionInfo.FriendlyName -notlike "Root Print Queue"){
Write-Host "System Key Found for" $SysDescriptionInfo.FriendlyName "in GUID key" $SysDescriptionInfo.PSChildName -ForegroundColor Green
CarriageReturn

#Increases Counter
$SystemRemovedCounter = $SystemRemovedCounter + 1
$GUIDPath = $SysDescriptionInfo.PSPath
#Removes Key
Remove-Item -Path $GUIDPath -Confirm:$false -Recurse

}

#Lists all other keys for debugging (but ignores redirected printers)
If ($DebugModeOn -eq $True){
If ($SysDescriptionInfo.FriendlyName -notlike "Redirected" -and $SysDescriptionInfo.FriendlyName -notlike "Root Print Queue"){
Write-Host "Normal Key found for" $SysDescriptionInfo.FriendlyName "in GUID key" $SysDescriptionInfo.PSChildName -ForegroundColor Yellow
CarriageReturn

#Increases Counter
$SystemStandardCounter = $SystemStandardCounter + 1
$GUIDPath = $SysDescriptionInfo.PSPath

}
#End Debug Mode On
}


#End of for each
}
}Catch{
Write-Host "Could not find/edit path: HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers\$PrintServer\Printers"
}



If ($DebugModeOn -eq $True){
If ($SystemStandardCounter -gt 0){
Write-Host "Total GUID Keys Found:" $SystemStandardCounter -ForegroundColor Yellow
CarriageReturn
}
Else
{Write-Host "No Non-redirected GUID Keys Found" -ForegroundColor Cyan
CarriageReturn}}


If ($SystemRemovedCounter -gt 0){
Write-Host "System GUID Keys Removed:" $SystemRemovedCounter -ForegroundColor Green
CarriageReturn
}
Else
{Write-Host "No System GUID Keys Found" -ForegroundColor Cyan
CarriageReturn}

SpacerLine

#Cleans out the Control List
$ControlRemovedCounter = 0
$ControlStandardCounter = 0
Try{
#Cleans out the print server list
$ControlList = get-childitem -path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\{0ecef634-6ef0-472a-8085-5ad023ecbccd}" -ErrorAction Stop
foreach ($Controlentry in $ControlList){
#Checks the description field for printer info
$ControlDescriptionInfo = Get-ChildItem -Path Registry::"$Controlentry\#\Device Parameters\"
$ControlDescriptionInfo = Get-ItemProperty -path Registry::$ControlDescriptionInfo

#Sets Debug Flag to list other control keys
If ($DebugModeOn -eq $True){$Listthiskey = $True}


#If it finds the server\printer combo it deletes the key if it's not redirected through RDP
If ($ControlDescriptionInfo.FriendlyName -like "*$PrintServer\$PrinterName*" -and $ControlDescriptionInfo.FriendlyName -notlike "*Redirected*"){


Write-Host "Target Control Key Found for" $ControlDescriptionInfo.FriendlyName "in GUID key" $ControlEntry.PSChildName -ForegroundColor Green
CarriageReturn

#Increases Counter
$ControlRemovedCounter = $ControlRemovedCounter + 1
$GUIDPath = $ControlEntry.PSPath
#Removes Key
Remove-Item -Path $GUIDPath -Confirm:$false -Recurse

If ($DebugModeOn -eq $True){$Listthiskey = $false}

}

#Lists all other keys for debugging (but ignores redirected printers)
If ($DebugModeOn -eq $True){
If ($Listthiskey = $True){
If ($ControlDescriptionInfo.FriendlyName -notlike "*\$PrinterName" -and $ControlDescriptionInfo.FriendlyName -notlike "Redirected"){
Write-Host "Control Key found for" $ControlDescriptionInfo.FriendlyName "in GUID key" $ControlEntry.PSChildName -ForegroundColor Yellow
CarriageReturn

#Increases Counter
$ControlStandardCounter = $ControlStandardCounter + 1
$GUIDPath = $ControlDescriptionInfo.PSPath

}
}
}

#End of for each
}

}Catch{
Write-Host "Error cleaning control keys" -ForegroundColor Red
CarriageReturn
}

SpacerLine

If ($DebugModeOn -eq $True){
If ($ControlStandardCounter -gt 0){
Write-Host "Other Control Keys Found:" $ControlStandardCounter -ForegroundColor Yellow
CarriageReturn
}
Else
{Write-Host "No Non-$PrinterName Control GUID Keys Found" -ForegroundColor Cyan
CarriageReturn}}


If ($ControlRemovedCounter -gt 0){
Write-Host "Control GUID Keys Removed:" $ControlRemovedCounter -ForegroundColor Green
CarriageReturn
}
Else
{Write-Host "No Control GUID Keys Removed" -ForegroundColor Cyan
CarriageReturn}
