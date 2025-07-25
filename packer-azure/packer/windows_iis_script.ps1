#
# Install and configure IIS

Install-WindowsFeature Web-Server
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value '<html><body><h1>Hello from Windows Server</h1></body></html>'

# Sysprep

while ((Get-Service RdAgent).Status -ne 'Running') {
  Start-Sleep -s 5
}

while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') {
  Start-Sleep -s 5
}

& $env:SystemRoot\\System32\\Sysprep\\Sysprep.exe /oobe /generalize /quiet /quit

while($true) {
  $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState;
  if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') {
    Write-Output $imageState.ImageState; Start-Sleep -s 10
  } else {
    break
  }
}

