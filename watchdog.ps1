# Region Variables
$ErrorActionPreference = "Stop"
$date = Get-Date -Format "dd-MM-yyyy"
$logPath = "C:\Scripts\ProcessWatcher\Logs\Watchdog_" + $date + ".log"
$processWatcherPath = "C:\Scripts\ProcessWatcher\ProcessFilesTemp"
$ptsrJSONPath = "C:\Scripts\ProcessWatcher\ptsrConfig.json"
$location = "Watchdog Main"
# End Region

# Region Functions
function  Start-ProcessToRun {

    param(
        $processthatShouldRun
    )

    $ptsr = $processthatShouldRun
    $ptsrExeToRun = $null
    $ptsrArgumentList = $null
    $ptsrFileName = $null
    $ptsrProcessName = $null
    
    $ptsrExeToRun = $ptsr.ExeToRun
    $ptsrArgumentList = $ptsr.ArgumentList
    $ptsrFileName = $ptsr.FileName
    $ptsrProcessName = $ptsr.ProcessName
    $ptsrWriteLog = $ptsr.WriteLog
    $ptsrLogPath = $ptsr.LogPath
    $workingDirectory = $ptsr.WorkingDirectory

    if ($ptsrWriteLog) {
        $writeLogFile = "$ptsrLogPath\Log_$($ptsrFileName)_$(Get-Date -Format 'dd.MM.yyy_HH.mm.ss').txt"
        $ptsrArgumentList += " >> $writeLogFile"
    }
    
    $processFile = $null
    $processFile = $runningProcessFiles | Where-Object { $_.Name -eq $ptsrFileName }
    
    if ($null -eq $processFile) {
        # Start process and save JSON
        $processObject = Start-Process $ptsrExeToRun -ArgumentList $ptsrArgumentList -PassThru -WorkingDirectory $workingDirectory
        $outPath = "$processWatcherPath\$ptsrFileName"
        $outDataFile = [PSCustomObject]@{
            ProcessName = $ptsrProcessName
            ProcessId   = $processObject.Id
        }
        $outDataFile | ConvertTo-Json | Out-File -FilePath $outPath -Force
        "Information: Process " + $ptsrFileName + " started " | Add-Content -Path $logPath -Force
    }
    else {
    
        #Load file and test if process with this ID is running
        #If no, start process and save JSON        
        $importedProcessObject = Get-Content -Path $processFile.FullName | ConvertFrom-Json
    
        if ($null -ne $importedProcessObject) {
    
            $importedPID = $importedProcessObject.ProcessId
            if ($null -ne $importedPID) {
    
                $processObject = $null
                $processObject = Get-Process -Id $importedPID -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq $ptsrProcessName }
    
                if ($null -eq $processObject) {
                    $processObject = Start-Process $ptsrExeToRun -ArgumentList $ptsrArgumentList -PassThru -WorkingDirectory $workingDirectory
                    $outPath = "$processWatcherPath\$ptsrFileName"
    
                    $outDataFile = [PSCustomObject]@{
                        ProcessName = $ptsrProcessName
                        ProcessId   = $processObject.Id
                    }
                    $outDataFile | ConvertTo-Json | Out-File -FilePath $outPath -Force
    
                    "Information: Process " + $ptsrFileName + " started " | Add-Content -Path $logPath -Force
                }
                else {
                    "Information: Process " + $ptsrFileName + " already running " | Add-Content -Path $logPath -Force
                }
            }
        }
    }
}
# End Region

# Region Setup

trap {
    "ERROR: " + $_.Exception + " Location: " + $location + " DateTime: " + 
    ((Get-Date).DateTime).ToString() | Add-Content -Path $logPath
    continue
}
# End Region

# Region Main
"###########################################" | Add-Content -Path $logPath
"Information: Watchdog started " + ((Get-Date).DateTime).ToString() | Add-Content -Path $logPath

$runningProcessFiles = Get-ChildItem -Path $processWatcherPath -Filter "*.json"

$ptsrJSON = $null
$ptsrJSON = Get-Content -Path $ptsrJSONPath -Raw

[array]$processesThatShouldRun = $null
$processesThatShouldRun = $ptsrJSON | ConvertFrom-JSON

foreach ($ptsr in $processesThatShouldRun) {
    $location = "Watchdog ForEach-Loop"
    trap {
        "ERROR: " + $_.Exception + " Location: " + $location + " DateTime: " + 
        ((Get-Date).DateTime).ToString() | Add-Content -Path $logPath
        continue
    }

    if ($null -ne $runningProcessFiles) {
        Start-ProcessToRun($ptsr)
    }
    else {
        $ptsrExeToRun = $null
        $ptsrArgumentList = $null
        $ptsrFileName = $null
        $ptsrProcessName = $null
        
        $ptsrExeToRun = $ptsr.ExeToRun
        $ptsrArgumentList = $ptsr.ArgumentList
        $ptsrFileName = $ptsr.FileName
        $ptsrProcessName = $ptsr.ProcessName
        $workingDirectory = $ptsr.WorkingDirectory

        # Start process and save JSON
        $processObject = Start-Process $ptsrExeToRun -ArgumentList $ptsrArgumentList -PassThru -WorkingDirectory $workingDirectory
        $outPath = "$processWatcherPath\$ptsrFileName"
        $outDataFile = [PSCustomObject]@{
            ProcessName = $ptsrProcessName
            ProcessId   = $processObject.Id
        }

        $outDataFile | ConvertTo-Json | Out-File -FilePath $outPath -Force
        "Information: Process " + $ptsrFileName + " started " | Add-Content -Path $logPath -Force
    }

}

# End Region
