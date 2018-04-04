<#
.SYNOPSIS
Предназначен для манипулирвоания очередью автострата VM на esxi или VCenter

.DESCRIPTION
Предназначен для манипулирвоания очередью автострата VM на esxi или VCenter от имени указанного пользователя.

.PARAMETER Server 
Имя или IP адрес целевого хоста (esxi или VCenter).

.PARAMETER FileName
Имя файла для в котором располагается список VM с параметрами автостарта

.INPUT
System.String, System.String

.OUTPUT
Get - формируется файл
Set - параметры заливаются в указанный хост

.EXAMPLE
PS c:\> Import-Module 'D:\WORK\CSA\virtualization\VMAutostartOrder.psm1'
PS c:\> Get-VMAutostartOrder -Server 172.17.10.121,172.17.10.127 d:\3.csv
PS c:\> Set-VMAutostartOrder d:\3.csv
#>

function Get-VMAutostartOrder {
	param (
		[parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string[]]$Server,
		
		[parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$FileName
	)
	Begin {
		#Очистим файл, если он есть
		New-Item -Path $FileName -ItemType "file" -Force | Out-Null
	}
	Process {
		ForEach ($vi_server in $Server) {
			Write-Host "Обрабатываем",$vi_server
			#Подключимся к серверу
			Connect-VIServer -Server $vi_server -Protocol https | Out-Null
			#Перебор всех VM
			$results = @() 
			ForEach ($vm in (Get-VM)) {
				Write-Host "Экспортируем инфо по хосту"$vm.Name
				$state_lines = Get-VMStartPolicy $vm
				$vm_StartAction = Get-VMStartPolicy $vm | Select-Object -ExpandProperty StartAction
				$vm_VMHeartBeat = Get-VMStartPolicy $vm | Select-Object -ExpandProperty WaitForHeartBeat
				$details = @{   
					VC				= $vi_server
					VMHost 		 	= $vm.vmhost
					VMName	      	= $vm.Name
					VMStartAction	= $vm_StartAction
					VMStartDelay  	= $($state_lines).StartDelay
					VMStartOrder  	= $($state_lines).StartOrder
					VMStopDelay		= $($state_lines).StopDelay
					VMHeartBeat		= $vm_VMHeartBeat
				}
				$results += New-Object PSObject -Property $details
			}
			#Выгрузим получившиеся данные в csv
			$results | Select-Object VC, VMHost, VMName, VMStartAction, VMStartOrder, VMStartDelay, VMStopDelay, VMHeartBeat |sort VC, VMHost, VMStartAction, VMStartOrder |export-csv -Delimiter ";" -Append -Path $FileName -NoTypeInformation 
			Disconnect-VIServer $vi_server -Confirm:$False
		}
	}
}

function Set-VMAutostartOrder {
	param (
		[parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$FileName
	)
	
	$next_count=0
	$vi_server_old = ""
	#Загрузим данные из файла
	$lines = Import-csv -Delimiter ";" $FileName |sort VC, VMHost, VMStartAction, VMStartOrder
	foreach ($line in $lines) {
		$vi_server = $($line.VMHost)
		$answer = ""
		if ($vi_server -ne $vi_server_old) {
			Write-Host "Обрабатываем VM's на сервере",$vi_server
			if ($vi_server_old -ne "") {
				Disconnect-VIServer $vi_server_old -Confirm:$False
			}
			$next_count=0
			Connect-VIServer -Server $vi_server -Protocol https | Out-Null
			$VMHostStartPolicy = Get-VMHostStartPolicy $vi_server | Select-Object -ExpandProperty Enabled
			if ($VMHostStartPolicy -eq $False) {
				Write-Host "Для продолжения работы нужно включить автостарт на хосте"$vi_server". Включить?"
				$answer = Read-Host "Yes or No"
				while("Yes","No" -notcontains $answer){
					$answer = Read-Host "Yes or No"
				}
			}
			if ($answer.ToLower() -eq "yes") {
				Get-VMHost $vi_server | Get-VMHostStartPolicy | Set-VMHostStartPolicy -Enabled:$true | Out-Null
				Write-Host "Автостарт на хосте"$vi_server" теперь Включен"
			}
			$vi_server_old = $vi_server
		}
		# Если пользователь отказался включить Автостарт, пропускаем этот хост
		$VMHostStartPolicy = Get-VMHostStartPolicy $vi_server | Select-Object -ExpandProperty Enabled
		if ($VMHostStartPolicy -eq $True) {
			$vmname = $($line.VMName)
			$VMStartAction = $($line.VMStartAction)
			$VMStartOrder = $($line.VMStartOrder)
			$VMStartDelay = $($line.VMStartDelay)
			$VMStopDelay = $($line.VMStopDelay)
			Write-Host "Обрабатываем хост"$vmname
			if ($($line.VMHeartBeat) -eq "TRUE") {
				$VMHeartBeat = $true
			}
			else {$VMHeartBeat = $false}
			#Если VMStartAction=PowerOn
			if ($VMStartAction.trim() -eq "PowerOn"){
				if ($VMStartOrder.trim() -eq ""){
				#Ситуация с AnyOrder
					$vmStartPolicy = Get-VMStartPolicy -VM $vmname 
					Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -UnspecifiedStartOrder -StartDelay $VMStartDelay -StopDelay $VMStopDelay -WaitForHeartBeat:$VMHeartBeat| Out-Null
					Write-Host "Обратите внимание на VM=",$vmname,"(вы задали PowerOn with AnyOrder)"
				}
				else {
				#Ситуация с заданным Order
					$vmStartPolicy = Get-VMStartPolicy -VM $vmname
					Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder $VMStartOrder -StartDelay $VMStartDelay -StopDelay $VMStopDelay -WaitForHeartBeat:$VMHeartBeat| Out-Null
				}
			}		
			else {
				#VMStartAction=None
				if ($VMStartOrder.trim() -ne "") {
					#Если ошибочно оставлен StartOrder выдать аларм
					Write-Host "Обратите внимание на VM=",$vmname,"(вы забыли убрать StartOrder)"
				}
				else {
					$vmStartPolicy = Get-VMStartPolicy -VM $vmname
					Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction None | Out-Null					
				}
			}		
		}
	}
	Disconnect-VIServer $vi_server -Confirm:$False
}

export-modulemember -function Get-VMAutostartOrder
export-modulemember -function Set-VMAutostartOrder