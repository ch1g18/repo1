<#
.synopsis
Install the pre-requisite to deploy the application
#>

## Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
Write-Host "Chocolatey installed..." -ForegroundColor Green -BackgroundColor DarkGray

## Install Powershell 5.1
choco install powershell --y
Write-Host "Powershell 5.1 installed..." -ForegroundColor Green -BackgroundColor DarkGray

choco install dotnet4.5.2 --y
Write-Host "Dot Net 4.5.6...installed..." -ForegroundColor Green -BackgroundColor DarkGray


Restart-Computer -Force