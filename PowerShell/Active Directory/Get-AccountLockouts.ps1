[CmdLetBinding()]
PARAM (
    [int] $maxEvents = 25,
    [int] $maxDaysBack = 3,
    [string] $ComputerName = ".",
    [string] $eventLogName = "ForwardedEvents"

)

Function Get-LockOutEvents {
    PARAM (
        [int] $maxEvents,
        [int] $maxDaysBack,
        [string] $eventLogName = "ForwardedEvents",
        [string] $ComputerName = "."
    )
    
    $events = Get-WinEvent -ComputerName $ComputerName -FilterHashtable @{ LogName=$eventLogName; StartTime=((Get-Date).AddDays(0 - $maxDaysBack)); Id='4740' }
    Write-Verbose "Found a total of $( ($events | Measure-Object).Count ) events, filtering down to $($maxEvents)"
    $events = $events | Sort-Object TimeCreated -Descending | Select-Object -First $maxEvents
    Write-Verbose "Filtered to $( ($events | Measure-Object).Count ) events"

    Return $events
}


Function Format-LockOutEvents {
    PARAM (
        [Parameter(ValueFromPipeline)]
        [System.Object[]]
        $eventLogData
    )
    Begin {
        Write-Verbose "Formating events"
        $properties = @(
            @{ Name='TimeCreated';        Expression={$_.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss") } },
            @{ Name='AccountName';        Expression={$_.Properties[0].Value.ToUpper().Trim() } },
            @{ Name='CallerComputerName'; Expression={$_.Properties[1].Value.Replace("\\", "").ToUpper().Trim() } },
            @{ Name='AccountDomain';      Expression={$_.Properties[5].Value.ToUpper().Trim() } },
            @{ Name='AccountSID';         Expression={$_.Properties[2].Value.ToUpper().Trim() } }
        )
    }

    Process  {
        Return ( $_ | Select-Object $properties )
    }

    End {}
}


#-----------------------------------------------------------------------------------------------------

$events = Get-LockOutEvents -maxEvents $maxEvents -maxDaysBack $maxDaysBack -ComputerName $ComputerName |  Format-LockOutEvents
$events | Out-GridView -Title "Account Lockout" -PassThru | Format-Table * -AutoSize
