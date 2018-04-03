# Пример вызова для формирования файла с перечнем VM и параметрами
# D:\test.ps1 get d:\3.csv 172.17.10.127 root Njhjgsuf904
# Считываем StartAction и StartOrder
# Если StartAction = PowerOn и StartOrder !=null => Всё ок, штатная ситуация
# Если StartAction = PowerOn и StartOrder =null => Всё ок, AnyOrder
# Если StartAction = None => Всё ок, VM не включается автоматом
# Отредактировав файл, запускаем:
# D:\test.ps1 set d:\3.csv 172.17.10.127 root Njhjgsuf904
# Импортируем строки отсортировав по StartOrder 
# Для 0 -  AnyOrder 
# Для остальных проверяем,чтобы начинался с 1 и без пропусков, иначе аларм!!
# Присваиваем соответствующие значения
# Для AnyOrder - выдаем alarm админу - чтобы проверил

[CmdLetBinding()]
    param (
        [parameter( Mandatory = $true )]
        [System.String] $Operation,
		[parameter( Mandatory = $true )]
        [System.String] $FileName,
		[parameter( Mandatory = $true )]
		[System.String] $vi_server,
		[parameter( Mandatory = $true )]
		[System.String] $vi_username,
		[parameter( Mandatory = $true )]
		[System.String] $vi_password
	)

$results = @()

if ($Operation -eq "get") {
	#Очистим файл, если он есть
	New-Item -Path $FileName -ItemType "file" -Force | Out-Null
	foreach ($esxi_server in $vi_server.split("")) {
		Write-Host "Обрабатываем",$esxi_server
		#Подключимся к серверу
		Connect-VIServer -Server $esxi_server -Protocol https -User $vi_username -Password $vi_password | Out-Null
		#Перебор всех VM
		ForEach ($vm in (Get-VM)) {
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
	Disconnect-VIServer $esxi_server -Confirm:$False
	}
}

else  {
	$next_count=0
	$vi_server_old = ""
	#Загрузим данные из файла
	$lines = Import-csv -Delimiter ";" $FileName
	foreach ($line in $lines) {
		$vi_server = $($line.VMHost)
		if ($vi_server -ne $vi_server_old) {
			Write-Host "Обрабатываем VM's на сервере",$vi_server
			if ($vi_server_old -ne "") {
				Disconnect-VIServer $vi_server_old -Confirm:$False
			}
		$next_count=0
		Connect-VIServer -Server $vi_server -Protocol https -User $vi_username -Password $vi_password
		$VMHostStartPolicy = Get-VMHostStartPolicy $vi_server | Select-Object -ExpandProperty Enabled
		if ($VMHostStartPolicy -eq $False) {
			Write-Host "Для продолжения работы нужно включить автостарт на хосте"$vi_server". Включить?"
			$answer = Read-Host "Yes or No"
			while("yes","no" -notcontains $answer){
				$answer = Read-Host "Yes or No"
			}
		}
		if ($answer -eq "Yes" -Or $answer -eq "yes") {
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
			if ($($line.VMHeartBeat) -eq "TRUE") {
				$VMHeartBeat = $true}
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
					$next_count = $next_count + 1
					if ($next_count -eq $VMStartOrder) {
						$vmStartPolicy = Get-VMStartPolicy -VM $vmname
						Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder $VMStartOrder -StartDelay $VMStartDelay -StopDelay $VMStopDelay -WaitForHeartBeat:$VMHeartBeat| Out-Null
					}
					else {
						Write-Host "Указан неправильный StartOrder для VM=",$vmname," должен быть",$next_count
					}
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