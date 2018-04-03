[CmdLetBinding()]
    param (
        [parameter( Mandatory = $true )]
        [System.String] $Operation,
		[parameter( Mandatory = $false )]
        [System.String] $FileName
	)

if ($Operation -eq "get") {	
	Connect-VIServer -Server spbvtc03 -Protocol https -User 'amust\adm-dkovalenko' -Password 'Kdsroot1'
	$esxhosts = Get-VMHost | select Name
	foreach ($vmhost in $esxhosts){
		#write-host $vmhost.Name
		Get-VMHost $vmhost.Name | Get-VM | Get-VMStartPolicy | Select-Object {$vmhost.Name},VM,StartAction,StartDelay,StartOrder,StopAction,StopDelay | Export-Csv d:/111.csv -NoTypeInformation -Append -Force
	}
	Disconnect-VIServer spbvtc03	
}
else {
	write-host " set"
#$lines = import-csv $FileName -header vm, StartAction, StartDelay, StartOrder
#foreach ($line in $lines) {
# $vm = $($line.vm)
# $StartAction = $($line.StartAction)
# $StartDelay = $($line.StartDelay)
# $StartOrder = $($line.StartOrder)
# if ($StartOrder -ne "") { Write-host $vm $StartOrder}
#}



#Connect-VIServer -Server 172.17.10.127 -Protocol https -User 'root' -Password 'Njhjgsuf904'
#Connect-VIServer -Server spbvtc03 -Protocol https -User 'amust\adm-dkovalenko' -Password 'Kdsroot1'
#Get-VM linux |Get-VMStartPolicy | Set-VMStartPolicy -StartAction PowerOn -StartOrder 2 -StartDelay 300 -StopAction Suspend -StopDelay 120


#-NoTypeInformation
#Get-VM | Get-VMStartPolicy | Export-Csv -NoTypeInformation -Path d:/VMAnnotations.csv

#Get-VMHost spbesx05.amust.local | Get-VM | Get-VMStartPolicy | Select-Object "spbesx05.amust.local",* | Export-Csv d:/111.csv -NoTypeInformation
}