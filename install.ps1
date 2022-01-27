# Ignore errors from `Stop-Process`
$PSDefaultParameterValues['Stop-Process:ErrorAction'] = [System.Management.Automation.ActionPreference]::SilentlyContinue
function Get-File
{
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [System.Uri]
        $Uri,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [System.IO.FileInfo]
        $TargetFile,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Int32]
        $BufferSize = 1,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('KB, MB')]
        [String]
        $BufferUnit = 'MB',
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('KB, MB')]
        [Int32]
        $Timeout = 10000
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $useBitTransfer = $null -ne (Get-Module -Name BitsTransfer -ListAvailable) -and ($PSVersionTable.PSVersion.Major -le 5)

    if ($useBitTransfer)
    {
        Write-Information -MessageData 'Using a fallback BitTransfer method since you are running Windows PowerShell'
        Start-BitsTransfer -Source $Uri -Destination "$($TargetFile.FullName)"
    }
    else
    {
        $request = [System.Net.HttpWebRequest]::Create($Uri)
        $request.set_Timeout($Timeout) #15 second timeout
        $response = $request.GetResponse()
        $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1024)
        $responseStream = $response.GetResponseStream()
        $targetStream = New-Object -TypeName ([System.IO.FileStream]) -ArgumentList "$($TargetFile.FullName)", Create
        switch ($BufferUnit)
        {
            'KB' { $BufferSize = $BufferSize * 1024 }
            'MB' { $BufferSize = $BufferSize * 1024 * 1024 }
            Default { $BufferSize = 1024 * 1024 }
        }
        Write-Verbose -Message "Buffer size: $BufferSize B ($($BufferSize/("1$BufferUnit")) $BufferUnit)"
        $buffer = New-Object byte[] $BufferSize
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes = $count
        $downloadedFileName = $Uri -split '/' | Select-Object -Last 1
        while ($count -gt 0)
        {
            $targetStream.Write($buffer, 0, $count)
            $count = $responseStream.Read($buffer, 0, $buffer.length)
            $downloadedBytes = $downloadedBytes + $count
            Write-Progress -Activity "Telechargement du fichier '$downloadedFileName'" -Status "Finish ! ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100)
        }

        Write-Progress -Activity "Le telechargement du fichier est terminé (ton pc est toujours en vie tkt) '$downloadedFileName'"

        $targetStream.Flush()
        $targetStream.Close()
        $targetStream.Dispose()
        $responseStream.Dispose()
    }
}

Write-Host @'
*****************
@D_BOT message: 
Version 3.2.1
Reprise et recreation du projet Open Source de 'Mpond' Pour un meilleur code et des meilleurs fonctionnaliter
Usage de ce logiciel strictement privee ! Suppression instantane en cas de leak :)
*****************
'@ -ForegroundColor Darkgreen

Write-Host @'
*****************
Authors: @Doublox
Contributeurs: @Nuzair46, @KUTlime (Pour le systeme de telechargement du Spotify et de la desinstallation si ce dernier vien de Microsoft )
*****************
'@ -ForegroundColor DarkRed

$spotifyDirectory = Join-Path -Path $env:APPDATA -ChildPath 'Spotify'
$spotifyExecutable = Join-Path -Path $spotifyDirectory -ChildPath 'Spotify.exe'
$spotifyApps = Join-Path -Path $spotifyDirectory -ChildPath 'Apps'

Write-Host "(OBLIGATOIRE) Je te Stop spotify avant de commencer...`n"
Stop-Process -Name Spotify
Stop-Process -Name SpotifyWebHelper

$dbx = Read-Host "Pour une meilleur opti , il faudrais que je te stop fiveM, veux tu stopper fiveM (Y/N)?`n" 
 
If ($dbx -eq 'y') 
{ 
   Write-Host "Carré ! Je te Stop fiveM avant de commencer...`n"
   Stop-Process -Name FiveM
}
else
{
       Write-Host "Carré ! Je te re Stop Spotify avant de commencer...`n"
       Stop-Process -Name Spotify
       Stop-Process -Name SpotifyWebHelper
}

if ($PSVersionTable.PSVersion.Major -ge 7)
{
  Import-Module Appx -UseWindowsPowerShell
}

if (Get-AppxPackage -Name SpotifyAB.SpotifyMusic)
{
  Write-Host "La version Microsoft Store de Spotify a ete detectee et n'est pas prise en charge..`n"

  $ch = Read-Host -Prompt 'Je peux te le desinstaller ? (Y/N)'
  if ($ch -eq 'y')
  {
    Write-Host "Desinstallation de Spotify en cours...`n"
    Get-AppxPackage -Name SpotifyAB.SpotifyMusic | Remove-AppxPackage
  }
  else
  {
    Read-Host "Fin du programme...`nPress n'importe quel touche pour quitter..."
    exit
  }
}

Push-Location -LiteralPath $env:TEMP
try
{
  # Unique directory name based on time
  New-Item -Type Directory -Name "BlockTheSpot-$(Get-Date -UFormat '%Y-%m-%d_%H-%M-%S')" |
  Convert-Path |
  Set-Location
}
catch
{
  Write-Output $_
  Read-Host 'Press la touche que tu veux pour quitter...'
  exit
}

Write-Host "Telechargement du dernier patch (chrome_elf.zip)...`n"
$elfPath = Join-Path -Path $PWD -ChildPath 'chrome_elf.zip'
try
{
  $uri = 'https://github.com/mrpond/BlockTheSpot/releases/latest/download/chrome_elf.zip'
  Get-File -Uri $uri -TargetFile "$elfPath"
}
catch
{
  Write-Output $_
  Start-Sleep
}

Expand-Archive -Force -LiteralPath "$elfPath" -DestinationPath $PWD
Remove-Item -LiteralPath "$elfPath" -Force

$spotifyInstalled = Test-Path -LiteralPath $spotifyExecutable
$update = $false
if ($spotifyInstalled)
{
  $ch = Read-Host -Prompt '(Facultatif) - Mettre a jour Spotify a la derniere version. (Peut etre ce dernier est deja mis a jour). (Y/N)`n'
  if ($ch -eq 'y')
  {
    $update = $true
  }
  else
  {
    Write-Host 'Essaye pas de mettre a jour Spotify hein soit pas con.`n'
  }
}
else
{
  Write-Host 'L"Installation de Spotify a pas ete detectee.'
}
if (-not $spotifyInstalled -or $update)
{
  Write-Host 'Telechargement de la derniere version du exe complet de Spotify, veuillez patienter....'
  $spotifySetupFilePath = Join-Path -Path $PWD -ChildPath 'SpotifyFullSetup.exe'
  try
  {
    $uri = 'https://download.scdn.co/SpotifyFullSetup.exe'
    Get-File -Uri $uri -TargetFile "$spotifySetupFilePath"
  }
  catch
  {
    Write-Output $_
    Read-Host 'Press la touche que tu veux pour quitter...'
    exit
  }
  New-Item -Path $spotifyDirectory -ItemType:Directory -Force | Write-Verbose

  [System.Security.Principal.WindowsPrincipal] $principal = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $isUserAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
  Write-Host 'Installation en cours...'
  if ($isUserAdmin)
  {
    Write-Host
    Write-Host 'Creation d"une tache planifiee...'
    $apppath = 'powershell.exe'
    $taskname = 'Spotify install'
    $action = New-ScheduledTaskAction -Execute $apppath -Argument "-NoLogo -NoProfile -Command & `'$spotifySetupFilePath`'"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -WakeToRun
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $taskname -Settings $settings -Force | Write-Verbose
    Write-Host 'La tache d"installation a ete planifiee. Lancement de la tache...'
    Start-ScheduledTask -TaskName $taskname
    Start-Sleep -Seconds 2
    Write-Host 'Desenregistrement de la tache...'
    Unregister-ScheduledTask -TaskName $taskname -Confirm:$false
    Start-Sleep -Seconds 2
  }
  else
  {
    Start-Process -FilePath "$spotifySetupFilePath"
  }

  while ($null -eq (Get-Process -Name Spotify -ErrorAction SilentlyContinue))
  {
    # Waiting until installation complete
    Start-Sleep -Milliseconds 100
  }

  # Create a Shortcut to Spotify in %APPDATA%\Microsoft\Windows\Start Menu\Programs and Desktop 
  # (allows the program to be launched from search and desktop)
  $wshShell = New-Object -comObject WScript.Shell
  $desktopShortcut = $wshShell.CreateShortcut("$Home\Desktop\Spotify.lnk")
  $startMenuShortcut = $wshShell.CreateShortcut("$Home\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Spotify.lnk")
  $desktopShortcut.TargetPath = "$Home\AppData\Roaming\Spotify\Spotify.exe"
  $startMenuShortcut.TargetPath = "$Home\AppData\Roaming\Spotify\Spotify.exe"
  $desktopShortcut.Save()
  $startMenuShortcut.Save()

  Write-Host 'Je te Stop Spotify...encore'

  Stop-Process -Name Spotify
  Stop-Process -Name SpotifyWebHelper
  Stop-Process -Name SpotifyFullSetup
}
$elfDllBackFilePath = Join-Path -Path $spotifyDirectory -ChildPath 'chrome_elf_bak.dll'
$elfBackFilePath = Join-Path -Path $spotifyDirectory -ChildPath 'chrome_elf.dll'
if ((Test-Path $elfDllBackFilePath) -eq $false)
{
  Move-Item -LiteralPath "$elfBackFilePath" -Destination "$elfDllBackFilePath" | Write-Verbose
}

Write-Host 'Patching Spotify...'-ForegroundColor Darkgreen
$patchFiles = (Join-Path -Path $PWD -ChildPath 'chrome_elf.dll'), (Join-Path -Path $PWD -ChildPath 'config.ini')

Copy-Item -LiteralPath $patchFiles -Destination "$spotifyDirectory"

$ch = Read-Host -Prompt '(Facultatif) - Voulez vous Supprimer l"emplacement de la publicite et le bouton de mise a niveau ? (Y/N)`n'
if ($ch -eq 'y')
{
  $xpuiBundlePath = Join-Path -Path $spotifyApps -ChildPath 'xpui.spa'
  $xpuiUnpackedPath = Join-Path -Path (Join-Path -Path $spotifyApps -ChildPath 'xpui') -ChildPath 'xpui.js'
  $fromZip = $false

  # Try to read xpui.js from xpui.spa for normal Spotify installations, or
  # directly from Apps/xpui/xpui.js in case Spicetify is installed.
  if (Test-Path $xpuiBundlePath)
  {
    Add-Type -Assembly 'System.IO.Compression.FileSystem'
    Copy-Item -Path $xpuiBundlePath -Destination "$xpuiBundlePath.bak"

    $zip = [System.IO.Compression.ZipFile]::Open($xpuiBundlePath, 'update')
    $entry = $zip.GetEntry('xpui.js')

    # Extract xpui.js from zip to memory
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $xpuiContents = $reader.ReadToEnd()
    $reader.Close()

    $fromZip = $true
  }
  elseif (Test-Path $xpuiUnpackedPath)
  {
    Copy-Item -LiteralPath $xpuiUnpackedPath -Destination "$xpuiUnpackedPath.bak"
    $xpuiContents = Get-Content -LiteralPath $xpuiUnpackedPath -Raw

    Write-Host 'Spicetify detecter - Il se peut que vous deviez reinstaller le BTS apres avoir executer "spicetify apply".';
  }
  else
  {
    Write-Host 'Impossible de trouver xpui.js.'
  }

  if ($xpuiContents)
  {
    # Replace ".ads.leaderboard.isEnabled" + separator - '}' or ')'
    # With ".ads.leaderboard.isEnabled&&false" + separator
    $xpuiContents = $xpuiContents -replace '(\.ads\.leaderboard\.isEnabled)(}|\))', '$1&&false$2'

    # Delete ".createElement(XX,{onClick:X,className:XX.X.UpgradeButton}),X()"
    $xpuiContents = $xpuiContents -replace '\.createElement\([^.,{]+,{onClick:[^.,]+,className:[^.]+\.[^.]+\.UpgradeButton}\),[^.(]+\(\)', ''

    if ($fromZip)
    {
      # Rewrite it to the zip
      $writer = New-Object System.IO.StreamWriter($entry.Open())
      $writer.BaseStream.SetLength(0)
      $writer.Write($xpuiContents)
      $writer.Close()

      $zip.Dispose()
    }
    else
    {
      Set-Content -LiteralPath $xpuiUnpackedPath -Value $xpuiContents
    }
  }
}
else
{
  Write-Host "Impossible de supprimer l'espace publicitaire et le bouton de mise a niveau..`n" -ForegroundColor Darkred
}

$tempDirectory = $PWD
Pop-Location

Remove-Item -LiteralPath $tempDirectory -Recurse

Write-Host 'Patching terminer, demarrage de Spotify...'

Start-Process -WorkingDirectory $spotifyDirectory -FilePath $spotifyExecutable
Write-Host 'Termine.'

Write-Host @'
*****************
@D_BOT message:
Version 3.2.1
Reprise et recreation du projet Open Source de 'Mpond' Pour un meilleur code et des meilleurs fonctionnaliter
Usage de ce logiciel strictement privee ! Suppression instantaner en cas de leak :)
*****************
'@ -ForegroundColor Darkgreen

exit
