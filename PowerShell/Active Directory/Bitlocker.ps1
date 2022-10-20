Function Get-BitlockerInfo {
    PARAM (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)] $Computer
    )
 
    BEGIN {
        $bitLockerInfo = @()
    }
     
    PROCESS {
        Write-Verbose "Searching $($Computer.DistinguishedName) ..."
        Get-ADObject -LdapFilter "(msFVE-Recoverypassword=*)" -Searchbase $Computer.DistinguishedName -properties msFVE-RecoveryPassword | ForEach-Object {
            $Bitlocker = $_.Name.Split("{")
            $retObj = New-Object -TypeName System.Object
            $retObj | add-Member -memberType NoteProperty -name ComputerDistinguishedName -Value $Computer.DistinguishedName
            $retObj | add-Member -memberType NoteProperty -name BitlockerTime -Value $Bitlocker[0]
            $retObj | add-Member -memberType NoteProperty -name PasswordID -Value $Bitlocker[1].Replace("}", "")
            $retObj | add-Member -memberType NoteProperty -name RecoveryPassword -Value $_."msFVE-RecoveryPassword"
 
            $bitLockerInfo += $retObj
        }
    }
     
    END {
        Return $bitLockerInfo
    }
}
 
# Here is how to use it
Get-AdComputer -LdapFilter "(name=WKS012*)" | Get-BitlockerInfo | Format-List
