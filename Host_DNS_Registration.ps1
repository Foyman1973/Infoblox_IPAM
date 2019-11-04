<#        
	.SYNOPSIS
	 ESXi Host DNS Registration Check

	.DESCRIPTION
	A detailed description of the commands in the file.

	.NOTES
	========================================================================
		 Windows PowerShell Source File 
		 
		 NAME:Host_DNS_Registration.ps1 
		 
		 AUTHOR: Jason Foy , DaVita Inc.
		 DATE  : 07-Aug-2019
		 
		 COMMENT: 
		 
	==========================================================================
#>
Clear-Host
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function Set-IBARecord {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$thisView,
		[Parameter(Mandatory = $true)]
		[string]$thisHost,
		[Parameter(Mandatory = $true)]
		[string]$thisIP,
		[Parameter(Mandatory = $true)]
		[pscredential]$uriCreds
	)
	$recordCreated = "**UNK**"
	$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.aRecordGet.value)+$thisHost
	Write-Debug -message "IB A GET:$thisURI"
	$getResult = Invoke-RestMethod -uri $thisURI -method Get -credential $uriCreds
	if(!($getResult)){
		Write-Debug -message "Missing A Record"
		$body = @{
			name     = $thisHost
			ipv4addr = $thisIP
			view     = $thisView
		}|ConvertTo-Json
		Write-Debug -message $body
		$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.aRecordSet.value)
		Write-Debug -message "IB A SET:$thisURI"
		$setResult = Invoke-RestMethod -Uri $thisURI -Method Post -Body $body -Credential $uriCreds -ContentType 'application/json'
		if($setResult){$recordCreated = "**GOOD**"}
		else{$recordCreated = "**ERROR**"}
	}
	else{$recordCreated = "**EXISTS**"}
	Write-Debug -message "IB A DATA:$thisView $thisHost $thisIP $uriCreds.UserName $recordCreated"
	return $recordCreated
}
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function Set-IBPTRRecord {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$thisView,
		[Parameter(Mandatory = $true)]
		[string]$thisHost,
		[Parameter(Mandatory = $true)]
		[string]$thisIP,
		[Parameter(Mandatory = $true)]
		[pscredential]$uriCreds
	)
	$recordCreated = "**UNK**"
	$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.ptrRecordGet.value)+$thisIP
	Write-Debug -message "IB PTR GET:$thisURI"
	$getResult = Invoke-RestMethod -uri $thisURI -method Get -credential $uriCreds
	if(!($getResult.ptrdname -eq $thisHost)){
		Write-Debug -message "Missing PTR"
		$body = @{
			ptrdname = $thisHost
			ipv4addr = $thisIP
			view     = $thisView
		}|ConvertTo-Json
		Write-Debug -message $body
		$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.ptrRecordSet.value)
		Write-Debug -message "IB PTR SET:$thisURI"
		$setResult = Invoke-RestMethod -Uri $thisURI -Method Post -Body $body -Credential $uriCreds -ContentType 'application/json'
		if($setResult){$recordCreated = "**GOOD**"}
		else{$recordCreated = "**ERROR**"}
	}
	else{$recordCreated = "**EXISTS**"}
	Write-Debug -message "IB PTR DATA:$thisView $thisHost $thisIP $uriCreds.UserName $recordCreated"
	return $recordCreated
}
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function Set-IBHOSTRecord {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$thisComment,
		[Parameter(Mandatory = $true)]
		[string]$thisHost,
		[Parameter(Mandatory = $true)]
		[string]$thisIP,
		[Parameter(Mandatory = $true)]
		[string]$thisMAC,
		[Parameter(Mandatory = $true)]
		[pscredential]$uriCreds
	)
	$recordCreated = "**UNK**"
	Write-Debug -Message "checking for network first"
	$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.ipSearch.value)+$thisIP
	Write-Debug -Message "IB IP SEARCH GET:$thisURI"
	$hostNetwork = (Invoke-RestMethod -uri $thisURI -method Get -credential $uriCreds).network
	if($hostNetwork){
		Write-Debug -Message "Found Network:$hostNetwork"
		$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.hostRecordGet.value)+$thisHost
		Write-Debug -message "IB HOST GET:$thisURI"
		$getResult = Invoke-RestMethod -uri $thisURI -method Get -credential $uriCreds
		if(!($getResult.result.name -eq $thisHost)){
			Write-Debug -message "Missing HOST"
			$body = @{
				ipv4addrs         = @(
					@{
						ipv4addr           = $thisIP;
						mac                = $thisMAC;
						configure_for_dhcp = $false
					}
				)
				name              = $thisHost
				comment           = $thisComment
				configure_for_dns = $false
			} | ConvertTo-Json
			Write-Debug -message $body
			$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.hostRecordSet.value)
			Write-Debug -message "IB HOST SET:$thisURI"
			$setResult = Invoke-RestMethod -Uri $thisURI -Method Post -Body $body -Credential $uriCreds -ContentType 'application/json'
			if($setResult){$recordCreated = "**GOOD**"}
			else{$recordCreated = "**ERROR**"}
		}
		else{$recordCreated = "**EXISTS**"}
	}
	else{$recordCreated = "**BADNET**"}
	Write-Debug -message "IB HOST DATA:$thisView $thisHost $thisIP $uriCreds.UserName $recordCreated"
	return $recordCreated
}
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function Exit-Script{
	[CmdletBinding()]
	param([string]$myExitReason)
	Write-Host $myExitReason
	Stop-Transcript
	exit
}
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
function Get-PowerCLI{
	$pCLIpresent=$false
	Get-Module -Name VMware.VimAutomation.Core -ListAvailable | Import-Module -ErrorAction SilentlyContinue
	try{$pCLIpresent=((Get-Module VMware.VimAutomation.Core).Version.Major -ge 10)}
	catch{}
	return $pCLIpresent
}
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
if(!(Get-PowerCLI)){Write-Host "* * * * No PowerCLI Installed or version too old. * * * *" -ForegroundColor Red;Exit-Script}
$Version = "1.2.15"
$ScriptName = $MyInvocation.MyCommand.Name
$scriptPath = Split-Path $MyInvocation.MyCommand.Path
$CompName = (Get-Content env:computername).ToUpper()
$userName = ($env:UserName).ToUpper()
$userDomain = ($env:UserDomain).ToUpper()
$Date = Get-Date -Format g
$StartTime = Get-Date
$dateSerial = Get-Date -Format yyyyMMddhhmmss
$ReportFolder = Join-Path -Path $scriptPath -ChildPath "Reports"
$ReportFile = Join-Path -Path $ReportFolder -ChildPath "$dateSerial-HostDNSregistration.html"
$logsfolder = Join-Path -Path $scriptPath -ChildPath "Logs"
$traceFile = Join-Path -Path $logsfolder -ChildPath "$ScriptName.log"
$configFile = Join-Path -Path $scriptPath -ChildPath "config.xml"
Start-Transcript -Force -LiteralPath $traceFile
$stopwatch = [Diagnostics.Stopwatch]::StartNew()
Write-Host ("="*80) -ForegroundColor DarkGreen
Write-Host ""
Write-Host `t`t"$scriptName v$Version"
Write-Host `t`t"Started $Date"
Write-Host ""
Write-Host ("="*80) -ForegroundColor DarkGreen
Write-Host ""
if(!(Test-Path $ReportFolder)){New-Item -Path $ReportFolder -ItemType Directory|Out-Null}
if(!(Test-Path $logsfolder)){New-Item -Path $logsfolder -ItemType Directory|Out-Null}
if(!(Test-Path $configFile)){Write-Host "! ! ! Missing CONFIG.XML file ! ! !";Exit-Script}
if(test-path $configFile){[xml]$XMLfile = Get-Content $configFile -Encoding UTF8}
else{Exit-Script -myExitReason "Missing Config File"}
$RequiredConfigVersion = "3"
if($XMLFile.Data.Config.Version -lt $RequiredConfigVersion){Write-Host "Config version is too old or malformed Config.xml!";Exit-Script}
$reportTitle = $XMLFile.Data.Config.ReportTitle.value
$DEV_MODE=$false;if($XMLFile.Data.Config.DevMode.value -eq "TRUE"){$DEV_MODE=$true}else{Write-Host "DEV_MODE DISABLED" -ForegroundColor red}
$sendMail = $false;if($XMLFile.Data.Config.SendMail.value -eq "TRUE"){$sendMail=$true;Write-Host "SENDMAIL ENABLED" -ForegroundColor Green}else{Write-Host "SENDMAIL DISABLED" -ForegroundColor red}
$writeReportFile = $false;if($XMLFile.Data.Config.doReporting.value -eq "TRUE"){$writeReportFile=$true;Write-Host "REPORTFILE ENABLED" -ForegroundColor Green}else{Write-Host "REPORTFILE DISABLED" -ForegroundColor red}
if($DEV_MODE){
	$vCenterFile = $XMLFile.Data.Config.vCenterList_TEST.value
	$FROM = $XMLFile.Data.Config.FROM_TEST.value
	$TO = $XMLFile.Data.Config.TO_TEST.value
	$reportTitle = "DEV $reportTitle"
	$DebugPreference = "Continue"
}
else{
	$vCenterFile = $XMLFile.Data.Config.vCenterList.value
	$FROM = $XMLFile.Data.Config.FROM.value
	$TO = $XMLFile.Data.Config.TO.value
	$DebugPreference = "SilentlyContinue"
}
$SMTP = $XMLFile.Data.Config.SMTP.value
$subject = "$reportTitle $(Get-Date -Format yyyy-MMM-dd)"
$dnsView = $XMLFile.Data.Config.view.value
$dnsCreds = New-Object System.Management.Automation.PSCredential($XMLFile.Data.Config.Login.value,(ConvertTo-SecureString($XMLFile.Data.Config.Hash.value)))
if(Test-Path $vCenterFile){$vCenterList = Import-Csv $vCenterFile}
else{Exit-Script -myExitReason "Missing vCenter File"}
Write-Host "Connecting to vCenter instances..." -ForegroundColor Cyan
ForEach($vCenter in $vCenterList){
	Connect-VIServer $vCenter.NAME -Credential (New-Object System.Management.Automation.PSCredential $vCenter.ID, (ConvertTo-SecureString $vCenter.Hash)) -ErrorAction SilentlyContinue
}
$vCenterConnections = ($Global:defaultViServers).Count
Write-Host "Connected to $vCenterConnections vCenter instances" -ForegroundColor Green
if($vCenterConnections -gt 0){
	Write-Host "Getting VMhost Kernel Adapters..." -ForegroundColor Cyan
	$myHosts = Get-Datacenter|Get-VMHost|Where-Object{$_.ConnectionState -match "Connected|Maintenance"}|Get-VMHostNetworkAdapter -VMKernel|Where-Object{$_.DhcpEnabled -eq $false}|Sort-Object VMHost,DeviceName|Select-Object VMhost,DeviceName,IP,Mac,Uid,VMotionEnabled,ManagementTrafficEnabled
	Write-Host "Found $($myHosts.Count) Kernel Adapters to check"
	Write-Host "Disconnecting vCenter instances..." -ForegroundColor Yellow
	Disconnect-VIServer * -Confirm:$false
}
else{Exit-Script -myExitReason "No Connected vCenters, aborting"}
$reportColumns = @("vCenter","VMHost","IP","DeviceName","MAC","A_RecordName","A_RecordResult","PTR_RecordResult","HOST_Result")
$dnsReport = @()
$myHosts|ForEach-Object{
	$row=""|Select-Object $reportColumns
	$deviceName = $_.DeviceName
	$hostName = $_.VMhost
	$deviceIP = $_.IP
	$deviceMAC = $_.Mac
	$vCenterName = (($_.Uid).Split(":")[0].Split("@")[1])
	$deviceMGMT = (($_.ManagementTrafficEnabled).Tostring())
	$deviceVMO = (($_.VMotionEnabled).ToString())
	$deviceComment = "VC:$vCenterName MGMT:$deviceMGMT vMO:$deviceVMO AddedBy:$CompName / $scriptName v$Version"
	if($deviceName -ne "vmk0"){$hostName = "$deviceName-$hostName"}
	$row.VMhost = $_.VMhost
	$row.IP = $deviceIP
	$row.MAC = $deviceMAC
	$row.DeviceName = $deviceName
	$row.A_RecordName = $hostName
	Write-Debug -Message "$($_.VMhost) $deviceIP $deviceName"
	Write-Host "Setting HOST Record:$hostName"
	$thisResult = Set-IBHOSTRecord -thisHost $hostName -thisIP $deviceIP -thisMAC $deviceMAC -thisComment $deviceComment -uriCreds $dnsCreds
	$row.HOST_Result = $thisResult
	Write-Host "Setting A Record:$deviceIP"
	$thisResult = Set-IBARecord -thisView $dnsView -thisHost $hostName -thisIP $deviceIP -uriCreds $dnsCreds
	$row.A_RecordResult = $thisResult
	Write-Host "Setting PTR Record:$deviceIP"
	$thisResult = Set-IBPTRRecord -thisView $dnsView -thisHost $hostName -thisIP $deviceIP -uriCreds $dnsCreds
	$row.PTR_RecordResult = $thisResult
	$dnsReport += $row
	Write-Debug -message $row|Format-Table -AutoSize
}
# Get Networks and free IP counts for VMware
$thisURI = ($XMLFile.Data.Config.WebURI.value)+($XMLFile.Data.Config.Networks.value)
Write-Debug -Message "Networks URI: $thisURI"
$myNetworks = Invoke-RestMethod -Uri $thisURI -Method Get -Credential $dnsCreds
Write-host "writing Networks HTML table"
$siteHTML = $myNetworks|Select-Object Network,@{n="Site";e={$_.extattrs.'Site Prefix'.value}},@{n="VLAN";e={$_.extattrs.VLAN.value}},@{n="Purpose";e={$_.extattrs.Purpose.value}},@{n="FreeIP";e={$uri = $XMLFile.Data.Config.WebURI.value+"ipv4address?network=$($_.Network)&status=UNUSED";(Invoke-RestMethod -Uri $uri -Method Get -Credential $dnsCreds).Count}}|ConvertTo-Html -Fragment
$siteHTML = $siteHTML+"</br><hr></br>"
# Bundle HTML and send report
[string]$reportHTML = $dnsReport|ConvertTo-Html -Head $XMLfile.Data.Config.TableFormats.Blue.value -body "<h4>DNS Record Status</h4>" -PreContent $siteHTML -PostContent "<hr><span style=""background-color:White; font-weight:normal; font-size:10px;color:Orange;align:right""><blockquote>v$Version - $CompName : $userName @ $userDomain - $StartTime</blockquote></span>"
$reportHTML = $reportHTML.Replace("**UNK**","<span style=""font-weight:bold;color:Red"">Unknown</span>")
$reportHTML = $reportHTML.Replace("**GOOD**","<span style=""font-weight:bold;color:Orange"">ADDED</span>")
$reportHTML = $reportHTML.Replace("**ERROR**","<span style=""font-weight:bold;color:Red"">ERROR</span>")
$reportHTML = $reportHTML.Replace("**EXISTS**","<span style=""font-weight:bold;color:Blue"">GOOD</span>")
$reportHTML = $reportHTML.Replace("**BADNET**","<span style=""font-weight:bold;color:Purple"">Missing IB Network</span>")
if($sendMail){
	Write-Host "Emailing Report..."
	Send-MailMessage -Subject $subject -From $FROM -To $TO -Body $reportHTML -BodyAsHtml -SmtpServer $SMTP
}
if($writeReportFile){
	Write-Host "Writing report to disk"
	$reportHTML|Out-File -FilePath $ReportFile -Confirm:$false
}
# ==============================================================================================
# ==============================================================================================
$stopwatch.Stop()
$Elapsed = [math]::Round(($stopwatch.elapsedmilliseconds)/1000,1)
Write-Host ("="*80) -ForegroundColor DarkGreen
Write-Host ("="*80) -ForegroundColor DarkGreen
Write-Host ""
Write-Host "Script Completed in $Elapsed second(s)"
Write-Host ""
Write-Host ("="*80) -ForegroundColor DarkGreen
Exit-Script