Function Add-AdThumbnailPhoto {
    PARAM (
        [ValidateScript({Test-Path $_ -PathType Leaf})] [string] $PicturePath,
        $UserAccount
    )
     
    If (!(Test-IsModuleLoaded "ActiveDirectory")) {
        Throw "You need to run: Import-Module ActiveDirectory"
    }
    Write-Verbose "Adding $($PicturePath) to $($UserAccount)"
    $pictureBinary = [byte[]](Get-Content $PicturePath -Encoding byte)
     
    If ([System.Text.Encoding]::ASCII.GetString($pictureBinary).Length -ge 100Kb) {
        Throw "Picture to large, max size is 100Kb"
    }
     
     
    Try {
        Set-AdUser $UserAccount -Replace @{ thumbnailPhoto = $pictureBinary }
    }
    Catch {
        Throw $error[0]
    }
}

Add-AdThumbnailPhoto -PicturePath "C:\MyPicture.jpg" -UserAccount "MyUserAccount"


# Set-AdUser "MyUserAccount" -Replace @{ thumbnailPhoto = ([byte[]](Get-Content "C:\MyPicture.jpg" -Encoding byte) }
