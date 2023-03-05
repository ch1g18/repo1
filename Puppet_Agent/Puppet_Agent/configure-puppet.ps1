<#
.synopsis
Configure Puppet agent on Windows machine
.description
configure account and services for puppet
.example ./configure-puppet.ps1 -puppetuser "marvel\u_cmrsd151pup" -puppetPassword "test1234" -clientName "marvel" -role "test,test2"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]
    $puppetuser,
    [Parameter(Mandatory=$true)]
    [string]
    $puppetPassword,
    [Parameter(Mandatory=$true)]
    [string]
    $clientName,
    [Parameter(Mandatory=$true)]
    [string]
    $role
)

function LogonAsService([string]$accountToAdd) {

    if ( [string]::IsNullOrEmpty($accountToAdd) ) {
        Write-Host "no account specified"
        exit
    }

    $sidstr = $null
    try {
        $ntprincipal = new-object System.Security.Principal.NTAccount "$accountToAdd"
        $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
        $sidstr = $sid.Value.ToString()
    }
    catch {
        $sidstr = $null
    }

    Write-Host "Account: $($accountToAdd)" -ForegroundColor DarkCyan

    if ( [string]::IsNullOrEmpty($sidstr) ) {
        Write-Host "Account not found!" -ForegroundColor Red
        exit -1
    }

    Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

    $tmp = [System.IO.Path]::GetTempFileName()

    Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 

    $currentSetting = ""

    foreach ($s in $c) {
        if ( $s -like "SeServiceLogonRight*") {
            $x = $s.split("=", [System.StringSplitOptions]::RemoveEmptyEntries)
            $currentSetting = $x[1].Trim()
        }
    }

    if ( $currentSetting -notlike "*$($sidstr)*" ) {
        Write-Host "Modify Setting ""Logon as a Service""" -ForegroundColor DarkCyan
	
        if ( [string]::IsNullOrEmpty($currentSetting) ) {
            $currentSetting = "*$($sidstr)"
        }
        else {
            $currentSetting = "*$($sidstr),$($currentSetting)"
        }
	
        Write-Host "$currentSetting"
	
        $outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeServiceLogonRight = $($currentSetting)
"@

        $tmp2 = [System.IO.Path]::GetTempFileName()
	
	
        Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
        $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

        #notepad.exe $tmp2
        Push-Location (Split-Path $tmp2)
	
        try {
            secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
            #write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
        }
        finally {	
            Pop-Location
        }
    }
    else {
        Write-Host "NO ACTIONS REQUIRED! Account already in ""Logon as a Service""" -ForegroundColor DarkCyan
    }

    Write-Host "Done." -ForegroundColor DarkCyan
}

function UpdateService([string[]]$Services){
    Write-host "Manage Windows Service..."
    
    # Variables (do not change below this)
    foreach ($s in $Services) {
        #get value from string
        $serviceName = ($s -split ",")[0]
        $expectedStartMode = ($s -split ",")[1]
        $expectedLogin = ($s -split ",")[3]
        $expectedLoginPwd = ($s -split ",")[4]
        if (($s -split ",")[2] -eq "Running") {
            $expectedStatus = $true
        }
        else {
            $expectedStatus = $false
        }
    
        Write-Host "Managing Windows Service: $serviceName"

    ## Set-Service -Name "MSSQLSERVER" -StartupType Automatic -Status Running


        # Get current service details
        $servcie = gwmi win32_service -filter "name='$serviceName'"

        if ($servcie) {
            # check for StartMode, Status and Login
            if ($servcie.StartMode -ne $expectedStartMode `
                    -or $servcie.Started -ne $expectedStatus `
                    -or $servcie.StartName -ne $expectedLogin) {
                Write-Host "Change is required for '$serviceName'" -ForegroundColor Yellow
                Write-Host "$serviceName, StartMode, Current: '$($servcie.StartMode)', Expected: '$expectedStartMode'"
                Write-Host "$serviceName, Status, Current: '$($servcie.Started)', Expected: '$expectedStatus'"
                Write-Host "$serviceName, StartName, Current: '$($servcie.StartName)', Expected: '$expectedLogin'"

                # update the service
                Stop-Service -Name $serviceName
                sc.exe config "$serviceName" start=$expectedStartMode obj= $expectedLogin password= $expectedLoginPwd
                Write-Host "$serviceName was changed successfully" -ForegroundColor Yellow
                if ($expectedStatus) {
                    Start-Service -Name $serviceName
                    Write-Host "$serviceName started successfully" -ForegroundColor Yellow
                }
                else {
                    Write-Host "$serviceName was stopped" -ForegroundColor Yellow
                }
        
            }
            else {
                Write-Host "No change required for '$serviceName'" -ForegroundColor Green
            }
        }
        else {
            Write-Host "Service '$serviceName' not found" -ForegroundColor Red
        }
    }
}


#1 Add Puppet user as local admin
$test = (Get-LocalGroupMember -Group "Administrators" | Where-Object {$_.Name -eq $puppetUser})
if(!$test){
    Add-LocalGroupMember -Group "Administrators" -Member $puppetUser
}
Write-Host "User added to Local-Admin" -ForegroundColor Yellow

#2 Add puppet user to logon as service policy
LogonAsService -accountToAdd $puppetUser
Write-Host "User added to Logon as service policy" -ForegroundColor Yellow

#3 - Create Puppet Facter file
$facterFile = "C:\ProgramData\PuppetLabs\facter\facts.d\roles.txt"
$roles = @(
    "clientname=$clientName"
    "roles="
)
[IO.File]::WriteAllLines($facterFile, $roles)
Write-Host "Puppet facter file updated" -ForegroundColor Yellow

#4 Run puppet console
$puppetexecute = {
cd "C:\Program Files\Puppet Labs\Puppet\bin"
puppet agent -t
}
Invoke-Command -scriptblock $puppetexecute
Write-Host "Puppet execution complete" -ForegroundColor Yellow

#5 Update servcie account
$pupServices = @(
    "puppet"
    "pxp-agent"
    "mcollective"
)
foreach($svc in $pupServices){
    $pm = "$($svc),delayed-auto,Running,$($puppetUser),$($puppetPassword)"
    Write-host $pm -ForegroundColor Green
    UpdateService -Services $pm
}
Write-Host "Puppet servcie accout updated" -ForegroundColor Yellow

Start-Sleep -Seconds 60
#3 - Create Puppet Facter file
$facterFile = "C:\ProgramData\PuppetLabs\facter\facts.d\roles.txt"
$roles = @(
    "clientname=$clientName"
    "roles=$role"
)
[IO.File]::WriteAllLines($facterFile, $roles)
Write-Host "Puppet facter file updated" -ForegroundColor Yellow