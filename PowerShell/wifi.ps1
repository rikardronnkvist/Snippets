Function Extract-WifiInformation {
    $info = @()
    (netsh.exe wlan show profiles) -match '\s{2,}:\s'| ForEach-Object {
        $SSID = ($_ -split':')[1].Trim()

        $cmd = "netsh wlan show profile name=$($SSID) key=clear"
        Invoke-Expression $cmd | Where-Object { $_ -match 'SSID n|Key C' } | Select-Object -Last 1 | ForEach-Object {
            $password = ($_ -split':')[1].Trim().Replace('"', '').Replace($SSID, "<blank>")

            $info += [PSCustomObject]@{
                SSID = $SSID
                Password = $password
            }
        }
    }

    Return $info
}
