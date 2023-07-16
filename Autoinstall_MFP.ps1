# a1mas 21/10/2022 (last update - 06/2023)

cls

#-----------------------------------------------------------[Functions]-----------------------------------------------------------
function Get-DateSortable {
		$Script:datesortable = (Get-Date).toString("yyyy/MM/dd HH:mm:ss") #Get-Date -Format "dd.MM.yyyy-HH':'mm':'ss"
}

# использование: write-log -level INFO -message "Cant connect" -logfile pathToLog
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory = $True)]
        [string]
        $Message,
        [Parameter(Mandatory = $False)]
        [string]
        $Logfile
    )
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "[$Stamp] $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line -Encoding "utf8"
    }
    Else {
        Write-Output $Line
    }
}

function Install-Printer {

    try {
        Add-PrinterPort -Name $PrinterPort -PrinterHostAddress $MFUadr -ErrorAction Stop
    }
    catch {
        Get-DateSortable
        $ErrorMessage = $_.Exception.Message
        write-log -level ERROR -message "Adding Printer Port: $PrinterPort - Error: $ErrorMessage" -logfile $logfilepath
    }

    try {
        Add-PrinterDriver -Name $DriverName -ErrorAction Stop
    }
    catch {
        Get-DateSortable
        $ErrorMessage = $_.Exception.Message
        write-log -level ERROR -message "Adding Printer Driver: $DriverName - Error: $ErrorMessage" -logfile $logfilepath
    }

    try {
        Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PrinterPort -ErrorAction Stop
    }
    catch {
        Get-DateSortable
        $ErrorMessage = $_.Exception.Message
        write-log -level ERROR -message "Adding Printer: $PrinterName - Error: $ErrorMessage" -logfile $logfilepath
    }
}


#----------------------------------------------------------[Declarations]----------------------------------------------------------
$Script:path2distrib = 'path_to_distributive' # замените на свой путь к дистрибутивам устаналиваемых МФУ
$Script:logfilepath = 'C:\Temp\mfuinst.log'
$Script:pnputilver = (([System.Diagnostics.FileVersionInfo]::GetVersionInfo("c:\Windows\System32\pnputil.exe").FileVersion) -split(' '))[0]

if ( Test-Path -Path "C:\Temp\mfu.csv")  
     { $MfuDataFile = "C:\Temp\mfu.csv"
       $mfu = Import-Csv $MfuDataFile -Delimiter ";" }
else { exit }

$Script:MFUadr = $mfu.mfuadr
$Script:model = $mfu.model
$Script:serialnumber = $mfu.serial
$Script:MFUMAC = $mfu.mac
$Script:scandel = $mfu.rm_scans

$MfuDataFileParsed = 'C:\Temp\mfu_parsed.csv'
if ([System.IO.File]::Exists($MfuDataFileParsed)) { Remove-Item $MfuDataFileParsed -Force -Confirm:$false }

    
        if ($model | Select-String "425" ) 
            { $Script:driverpath = "$path2distrib\LJPro-MFP-M425_full_solution_15188\hpcm425u.inf"
              $Script:DriverName = "HP LaserJet 400 MFP M425 PCL 6"
              $Script:PrinterPort = "HP425_" + $MFUadr
              $Script:scandriverpath = "$path2distrib\scaninst_v12200"
        }elseif ( $model | Select-String "426" ) 
            { $Script:driverpath = "$path2distrib\HP_LJ_Pro_MFP_M426f-M427f-Full_Solution_19133\hpma5a2a_x64.inf"
              $Script:DriverName = "HP LaserJet Pro MFP M426f-M427f PCL 6"
              $Script:PrinterPort = "HP426_" + $MFUadr
              $Script:scandriverpath = "$path2distrib\scaninst_hp426-427"
        }else{write-log -level ERROR -message "Device is not supported" -logfile $logfilepath
              exit }


#----------------------------------------------------------[Install printer]----------------------------------------------------------
    $PrinterName = $serialnumber
    write-log -level INFO -message "pnputil ver.$pnputilver" -logfile $logfilepath

try {        
    $InstalledPrinters = (Get-WmiObject Win32_Printer | Select Name).Name
    if ($InstalledPrinters | Select-String $PrinterName) 
         { write-log -level ERROR -message "Printer SN $serialnumber already installed" -logfile $logfilepath
           exit
    }else{ 
           pnputil /add-driver $driverpath /install
           Start-Sleep -Seconds 5
           Install-Printer
           write-log -level INFO -message "Printer $PrinterName successfully installed" -logfile $logfilepath
    }
  }
catch {
    Get-DateSortable
    $ErrorMessage = "[$Script:datesortable] - " + $_.Exception.Message  + " - " + $_.ScriptStackTrace |
    out-file $logfilepath -Append -Encoding utf8
}

#----------------------------------------------------------[Install scaner]----------------------------------------------------------

function Install-Scaner425 {
try {
    if ($scandel -eq $true) { $dev = Get-PnpDevice -FriendlyName "HP LJ400 M425*"
                $dev.InstanceId | foreach { pnputil.exe /remove-device $_ } }
    
    Push-Location $scandriverpath
    $process = Start-Process hpbniscan64.exe -ArgumentList '-f hppasc_lj425.inf','-m VID_03F0&PID_142a&IP_SCAN',"-a $MFUadr" -Wait -PassThru

    if ($process.ExitCode -eq '0') { write-log -level INFO -message "Scaner 425 successfully installed" -logfile $logfilepath }
    Pop-Location
        
    if ( -not(Test-Path -Path "C:\Program Files (x86)\HP\HP LaserJet 400 MFP M425\bin"))
       { Start-Process $scandriverpath\Scan_App\HPScanLJ425.msi -ArgumentList '/quiet' -Wait }
    }
catch {
    Get-DateSortable
    $ErrorMessage = "[$Script:datesortable] - " + $_.Exception.Message  + " - " + $_.ScriptStackTrace |
    out-file $logfilepath -Append -Encoding utf8
    }
}

function Install-Scaner426 {
try {    
    if ($scandel -eq $true) { $dev = Get-PnpDevice -FriendlyName "HP LJ M426*"
                $dev.InstanceId | foreach { pnputil /remove-device $_ } }

    Push-Location $scandriverpath
    $process = Start-Process hpbniscan64.exe -ArgumentList '-f hppasc_lj426427f.inf','-m VID_03F0&PID_5a2a&IP_SCAN',"-a $MFUadr" -Wait -PassThru
    #$process.HasExited  #$process.ExitTime
    if ($process.ExitCode -eq '0') { write-log -level INFO -message "Scaner 426 successfully installed" -logfile $logfilepath }
    Pop-Location
    
    if ( -not(Test-Path -Path "C:\Program Files (x86)\HP\HP LaserJet Pro MFP M426f-M427f\bin"))
       { Start-Process $scandriverpath\Scan_App\HPScanLJ426427f.msi -ArgumentList '/quiet' -Wait }
    }
catch {
    Get-DateSortable
    $ErrorMessage = "[$Script:datesortable] - " + $_.Exception.Message  + " - " + $_.ScriptStackTrace |
    out-file $logfilepath -Append -Encoding utf8
    }
}
    
    if ($model | Select-String "425" ) { Install-Scaner425 }
    if ($model | Select-String "426" ) { Install-Scaner426 }

#rename mfu.csv to mfu_parsed.csv
Rename-Item -path $MfuDataFile -NewName $MfuDataFileParsed


#-------------------------------------------------------[Write scaner in reg]-------------------------------------------------------
    $regmacname = $MFUMAC -replace(":","")
    $regpath = "registry::HKEY_USERS\S-1-5-19\SOFTWARE\Hewlett-Packard\DigitalImaging\NetworkScanners"
    if (Test-Path -Path $regpath ) 
        { 
          try {
            New-Item -Path $regpath\$regmacname -Force
            New-ItemProperty -Path $regpath\$regmacname -Name "IpAddress" -Value $MFUadr -PropertyType "String"
            write-log -level INFO -message "Scaner successfully added in registry" -logfile $logfilepath
          }
          catch {
            Get-DateSortable
            $ErrorMessage = $_.Exception.Message
            "[$Script:datesortable] - Adding Reg Path (MAC) : " + "$regpath\$regmacname" | Out-file -FilePath $logfilepath -Force -NoClobber -Append 
            "Error  :"+$ErrorMessage | Out-File -FilePath $logfilepath -Force -NoClobber -Append
          }

    }else{ write-log -level INFO -message "Path $regpath non exist" -logfile $logfilepath }