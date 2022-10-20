[CmdletBinding()]
PARAM()

Function Run-VerboseMeasured {
    PARAM (
        $scriptFullPath
    )
    Write-Host "INFO: Running:  . '$($scriptFullPath)' -Verbose" -ForegroundColor Green
    
    $m = Measure-Command {Invoke-Expression -Command ". '$($scriptFullPath)' -Verbose"}

    if( $m.TotalSeconds -gt 10) {
        Write-Host "INFO: Script took $($m.TotalSeconds) sec to run" -ForegroundColor Green
    } else {
        Write-Host "INFO: Script took $($m.TotalMilliseconds) ms to run" -ForegroundColor Green
    }

}

$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Run with -Verbose (measured)', { Run-VerboseMeasured $psISE.CurrentFile.FullPath }, 'Ctrl+F5') | Out-Null

$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Run with -Verbose', { Invoke-Expression -Command ". '$($psISE.CurrentFile.FullPath)' -Verbose" }, 'Ctrl+F6') | Out-Null
$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Run with -Verbose -WhatIf', { Invoke-Expression -Command ". '$($psISE.CurrentFile.FullPath)' -Verbose -WhatIf" }, 'Ctrl+F7') | Out-Null
$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Run with -Debug',   { Invoke-Expression -Command ". '$($psISE.CurrentFile.FullPath)' -Debug" }, 'Ctrl+F8') | Out-Null
