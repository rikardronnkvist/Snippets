Function Get-RandomPassword {
    PARAM (
        $pwdMask = "####-####-####-####-####",
        $pwdCharacters = "abcdefghjkmnopqrstuvwxy23456789ABCDEFGHJKLMNPQRTUVWXYZ"
    )
 
    $newPassword = ""
    (0 .. (($pwdMask.Length)-1) ) | ForEach-Object  {
        If ( $pwdMask.Chars($_) -eq "#" ) {
            $rndChar = Get-Random -Minimum 0 -Maximum $pwdCharacters.Length
            $newPassword += $pwdCharacters.Chars($rndChar)
        } else {
            $newPassword += $pwdMask.Chars($_)
        }
    }
 
    Return $newPassword
}
 
 
Function Set-LocalAdminPassword {
    PARAM (
        [string] $computerName,
        [string] $newPassword
    )
 
    $adminAccountName = (Get-WmiObject Win32_UserAccount -Filter "LocalAccount = True AND SID LIKE 'S-1-5-21-%-500'" -ComputerName $computerName | Select-Object -First 1 ).Name
    TRY {
        Write-Verbose "Reset password for $($computerName)$($adminAccountName) to $($newPassword)"
        $adminAccount = [adsi]"WinNT://$($computerName)/$($adminAccountName),user"
        $adminAccount.setPassword($newPassword)
        Return $true
    }
    CATCH {
        Return $false
    }
}


# Set-LocalAdminPassword -computerName "SOMEPC" -newPassword (Get-RandomPassword)
