# PS:> notepad $PROFILE

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Function Test-LocalAdmin {
	<#
	.SYNOPSIS
		Checks if the current user is a local admin (and running as admin)
	#>
	If((New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
		Return $true
	} else {
		Return $false
	}
}

Function Prompt {
	<#
	.SYNOPSIS 
		Multicolored prompt with marker for windows started as Admin and marker for providers outside filesystem
		Examples
			C:\Windows\System32>
			[Admin] C:\Windows\System32>
			[Registry] HKLM:\SOFTWARE\Microsoft\Windows>
			[Admin] [Registry] HKLM:\SOFTWARE\Microsoft\Windows>
	#>
	
	# New nice WindowTitle
	if ($PWD.Provider.Name -like "*FileSystem*") {
        $Host.UI.RawUI.WindowTitle = ""
    } else {
        $Host.UI.RawUI.WindowTitle = " (" + $PWD.Provider.Name + ") "
    }
	$Host.UI.RawUI.WindowTitle += $PWD.Path.Replace('Microsoft.PowerShell.Core\FileSystem::', '')
	
	# Running in a Powershell Console
	If ($Host.Name -eq 'ConsoleHost') {
		$UserName = (Get-ChildItem ENV:UserName).Value.ToUpper()

		# Admin ?
		If(Test-LocalAdmin) {
			# Admin-mark in WindowTitle
			$Host.UI.RawUI.WindowTitle = "[$($UserName) (Admin)] " + $Host.UI.RawUI.WindowTitle

			# Admin-mark on prompt
			Write-Host "[" -NoNewline -ForegroundColor DarkGray
			Write-Host $UserName -NoNewline -ForegroundColor Red
			Write-Host "] " -NoNewline -ForegroundColor DarkGray
		} Else {
			# UserID in WindowTitle
			$Host.UI.RawUI.WindowTitle = "[$($UserName)] " + $Host.UI.RawUI.WindowTitle
		}

		# Show providername if you are outside FileSystem
		if ($PWD.Provider.Name -notlike "*FileSystem*") {
			Write-Host "[" -NoNewline -ForegroundColor DarkGray
			Write-Host $PWD.Provider.Name -NoNewline -ForegroundColor Gray
			Write-Host "] " -NoNewline -ForegroundColor DarkGray
		}

		# Split path and write \ in a gray
		$PWD.Path.Split("\") | foreach {
		    Write-Host $_ -NoNewline -ForegroundColor Yellow
		    Write-Host "\" -NoNewline -ForegroundColor Gray
		}

		# Backspace last \ and write >
		Write-Host "`b>" -NoNewline -ForegroundColor Gray
	} else {
		# Running in ISE / PowerGUI
		if ($PWD.Provider.Name -notlike "*FileSystem*") {
			Write-Host "[" -NoNewline
			Write-Host $PWD.Provider.Name -NoNewline
			Write-Host "] " -NoNewline
		}
		
		Write-Host "$($PWD.Path.Replace('Microsoft.PowerShell.Core\FileSystem::', ''))>" -NoNewline
	}
    Return " "
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
