##############################################################################
## 					            KPMG ONE AMERICAS			                ##
##		    Install/Configure Azure Devops Agent and all Dependencies       ##
##############################################################################

param ($pat, $org, $poolname='default')

$INSTALL_PATH = 'devops_agent'
$AGENTURL = 'https://vstsagentpackage.azureedge.net/agent/2.181.0/vsts-agent-win-x64-2.181.0.zip'
$OUTPUTAGENT = Split-Path $AGENTURL -Leaf
$DOTNETURL = 'https://go.microsoft.com/fwlink/?linkid=2088631'
$SERVERURL = 'https://dev.azure.com/'+$org
$AGENT = $env:computername

function check_dotnet {
    Write-Output "Checking installation prerequisites.."
    $CHECKVERSION = gci 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\' | sort pschildname -des | select -fi 1 -exp pschildname
    if ($CHECKVERSION -ne 'v4.0') {
        Write-Output "* Getting .NET Framework.."
        Invoke-WebRequest $DOTNETURL -OutFile "dotnet48-x86-x64-all.exe"
        Write-Output "* Installing .NET Framework in silent mode"
        .\dotnet48-x86-x64-all.exe /x64 /q /norestart
    }else{
        Write-Output ".NET Version founded:"+$CHECKVERSION
    }
}

function check_download_agent {
    $DownloadAgent = Test-Path $OUTPUTAGENT
    if (!($DownloadAgent)){
        Write-Output "* Downloading Azure Devops Agent.."
        Invoke-WebRequest $AGENTURL -OutFile "$OUTPUTAGENT"
    }
}

function check_old_service {
    $Service = Get-Service "vstsagent.$org.Default.$AGENT" -ErrorAction SilentlyContinue
    if ( $Service.Status -eq 'Running' -or $Service.Status -eq "Stopped" ) {
        Write-Output "* Stopping and remove old service.."
        sc.exe stop vstsagent.$org.Default.$AGENT
        sleep(4)
        sc.exe delete vstsagent.$org.Default.$AGENT
        sleep(2)
    }
}

function check_old_files {
    $OldFiles = Test-Path $INSTALL_PATH
    if ($OldFiles -eq 'True'){
        Write-Output "* Cleaning up all old files.."
        rm $INSTALL_PATH -r -fo
        Write-Output "* Creating new installation folder.."
        mkdir $INSTALL_PATH
    }
}

check_dotnet
check_download_agent
check_old_service
check_old_files

Write-output "* Unzipping installation file.."
Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory($OUTPUTAGENT, "$INSTALL_PATH")

Write-output "* Configuring Azure DevOps Agent.."
cd $INSTALL_PATH
.\config.cmd --unattended --url "$SERVERURL" --auth pat --token "$pat" --pool $poolname --agent $AGENT --replace --work _work --acceptTeeEula --runAsService --runAsAutoLogon
