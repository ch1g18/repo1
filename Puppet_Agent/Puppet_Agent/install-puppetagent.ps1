<#
.synopsis
Install Puppet Agent on Windows Machine
.example
./install-puppetagent.ps1 -PuppetServerFqdn "cmrsupup.cmrschev.com" -Environment "testclone1"
#>
param(
    # Fully quallified Puppet server name
    [Parameter(Mandatory=$true)]
    [string]
    $PuppetServerFqdn,
    # Environment Name
    [Parameter(Mandatory=$true)]
    [string]
    $Environment
)
$PuppetClientMsi = "https://cmrsdevopscommonstorage.blob.core.windows.net/publicbinaries/PuppetMaster/Windows/puppet-agent-1.10.5-x64.msi?st=2020-02-06T09%3A02%3A36Z&se=2025-02-07T09%3A02%3A00Z&sp=r&sv=2018-03-28&sr=b&sig=R57iXReoGjmKjnY434nuaqULmkbN7E1LuH6L%2BVnKoTc%3D"
Invoke-WebRequest -OutFile C:\puppet.msi $PuppetClientMsi

msiexec /qn /norestart /i C:\puppet.msi PUPPET_MASTER_SERVER=$PuppetServerFqdn  PUPPET_AGENT_ENVIRONMENT=$Environment /passive /l*v C:\Agent_Install.log
invoke-expression 'cmd /c start powershell -Command { C:\ProgramData\PuppetLabs\Puppet\bin\puppet agent -t }'