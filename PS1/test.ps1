# Пример вызова для формирования файла с перечнем VM и параметрами
# D:\test.ps1 get d:\3.csv 172.17.10.127 root Njhjgsuf904
# После выполнения скрипта будет сформирован (ПЕРЕСОЗДАН) файл d:\3.csv со строками вида:
# VMHost,VMName,VMNotes,VMStartAction,VMStartOrder,VMPrio,VMStartDelay
# 172.17.10.127,linux,linux test machine,AS_ON,1,prio_high,120
# Описание параметров:
# VMHost - ESX  на котором в данный момент хостится VM
# VMName - имя VM
# VMNotes - поле описания VM, содержаще тэг вида <#AS_ON, prio_high#> 
# AS_ON - VM должна автоматически стартовать
# prio_low|prio_med|prio_high - приоритеты автостарта, пока решено не использовать в обработке
# VMStartAction будет сформировано из тэга AS_ON|AS_OFF
# VMStartOrder - порядковый номер автостарта VM
# VMPrio - prio_low|prio_med|prio_high
# VMStartDelay - тайм-аут автостарта, по умолчанию 120
#
# Админ, сформировав файл, должен проставить в требуемом порядке VMStartOrder'ы
# Если админ, забыл проставить для VM VMStartAction = AS_ON, то вторым проходом для данной VM
# ей присвоится last(VMStartAction)+1 и будет присвоен тэг prio_low, 
# т.е. обрабатываем "забывчивость админа" или факт импорта VM в ESX
# Если поля VMStartAction и VMStartOrder пустые, то будет присвоен тэг AS_OFF, prio_low и это будет записано в поле NOTES
#
#Пример вызова для заполнения из файла 
# D:\test.ps1 set d:\3.csv 172.17.10.127 root Njhjgsuf904


#AnyOrder??????????

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

$delim_l = "<#"
$delim_r = "#>"
$results = @()

if ($Operation -eq "get") {
	#Очистим файл, если он есть
	New-Item -Path $FileName -ItemType "file" -Force
	#Подключимся к серверу
	Connect-VIServer -Server $vi_server -Protocol https -User $vi_username -Password $vi_password
	#Перебор всех VM
	ForEach ($vm in (Get-VM)) {
		$vm_prio = ''
		$vm_note = ''
		$state_lines = Get-VMStartPolicy $vm
		$vm_StartAction = ''
		$vm_StartAction_bytag = 'AS_OFF'
		#Если в процессе работы произойдет ошибка - всеравно запишем хост, но с пометкой ALARM
		try {
			#Извлечем реальное поле NOTES,-ErrorAction Ignore потому что у какой-то VM может быть не заполнено поле Notes
			$vm_notes = Get-VM $vm | Select-Object -ExpandProperty Notes -ErrorAction Ignore
			$vm_StartAction = Get-VMStartPolicy $vm | Select-Object -ExpandProperty StartAction
			#Если найдем в строке левый разделитель тэгов, извлечем данные об автостарте и приоритете
			if ($vm_notes.length -ge 0) {
				if ($vm_notes.indexof($delim_l) -ge 0) {
					#Write-Host $vm_notes,"========"
					#Полезное описание VM
					$vm_note = $vm_notes.substring(0,$vm_notes.indexof($delim_l)-1)
					#Если StartAction - PowerOn, а StartOrder -----, то получается Policy - AnyOrder?????????
					$vm_StartAction_bytag = $vm_notes.substring($vm_notes.indexof($delim_l)+2,$vm_notes.indexof(",")-$vm_notes.indexof($delim_l)-2)
					#Приоритет автостарта
					$vm_prio = $vm_notes.substring($vm_notes.indexof(",")+2, $vm_notes.Length-$vm_notes.indexof(",")-4)
				}
				else {
					#Нет тэгов автостарта
					$vm_note = $vm_notes
				}
			}
		}
		Catch [system.exception] {
			Write-Host "Какая-то проблема с извлечением Notes у хоста ", $vm.Name
			$vm_note = 'ALARM!!!'
		}	
		Finally {
			$details = @{            
				VMHost 		 		= $vm.vmhost
				VMName	      		= $vm.Name
				VMNotes		  		= $vm_note
				VMStartAction		= $vm_StartAction
				VMStartAction_bytag = $vm_StartAction_bytag
				VMPrio		  		= $vm_prio
				VMStartDelay  		= $($state_lines).StartDelay
				VMStartOrder  		= $($state_lines).StartOrder
			}
			$results += New-Object PSObject -Property $details  
			$vm_note = ""
			$vm_StartAction_bytag = ""
		}
	}
	#Выгрузим получившиеся данные в csv
	$results | Select-Object VMHost, VMName, VMNotes, VMStartAction, VMStartAction_bytag, VMStartOrder, VMPrio, VMStartDelay|export-csv -Path $FileName -NoTypeInformation
	#Отключимся от сервера
	Disconnect-VIServer $vi_server -Confirm:$False
}
else  {
	Connect-VIServer -Server $vi_server -Protocol https -User $vi_username -Password $vi_password 
	#Загрузим данные из файла
	$lines = Import-csv $FileName #-header VMHost, VMName, VMNotes, StartAction, StartOrder,VMPrio, StartDelay
	$next_count=0
	foreach ($line in $lines) {
		$AS_note = ''
		$vm = $($line.VMHost)
#Предусмотреть connect к разным VMHost
		$vmname = $($line.VMName)
		$vmnotes = $($line.VMNotes)
		$VMStartAction_bytag = $($line.VMStartAction_bytag)
		$VMStartOrder = $($line.VMStartOrder)
		$VMStartPrio = $($line.VMPrio)
		$VMStartDelay = $($line.VMStartDelay)
		if ($VMStartOrder.trim() -ne ""){
		#Если порядок автостарта не нулевой - заполнить NOTES и включить в автостарт
			if ($VMStartPrio -eq '') {$VMStartPrio="prio_low"}
			$NewVMNotes = $vmnotes + "`n"+ $delim_l + "AS_ON, " + $VMStartPrio + $delim_r
			Set-vm $vmname -Notes $NewVMNotes -Confirm:$False
			$vmStartPolicy = Get-VMStartPolicy -VM $vmname 
			Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder $VMStartOrder
			$next_count = $next_count + 1
		}
		else {
			#Для пустого VMStartOrder - выключим
			$NewVMNotes = $vmnotes + "`n"+ $delim_l + "AS_OFF, prio_low" + $delim_r
			Set-vm $vmname -Notes $NewVMNotes -Confirm:$False
			$vmStartPolicy = Get-VMStartPolicy -VM $vmname
			Set-VMStartPolicy -StartPolicy $vmStartPolicy -StartAction None 
		}
	}
	$lines = Import-csv $FileName #-header VMHost, VMName, VMNotes, StartAction, StartOrder,VMPrio, StartDelay
	# Перебираем заново весь список, если VM была импортирована то AS_ON, но VMStartOrder не установлен, добавим последним в список автостарта
	foreach ($line in $lines) {
		$vm = $($line.VMHost)
		$vmname = $($line.VMName)
		$vmnotes = $($line.VMNotes)
		$VMStartAction = $($line.VMStartAction)
		$VMStartOrder = $($line.VMStartOrder)
		$VMStartPrio = $($line.VMPrio)
		$VMStartDelay = $($line.VMStartDelay)
		if ($VMStartAction -eq "AS_ON" -And $VMStartPrio -eq "") {
			#Заполним правильно NOTES
			$NewVMNotes = $vmnotes + "`n"+ $delim_l + "AS_ON, prio_low" + $delim_r
			Set-vm $vmname -Notes $NewVMNotes -Confirm:$False
			#Для нулевого VMStartOrder надо выключить автострат
			$vmStartPolicy = Get-VMStartPolicy -VM $vmname
			$next_count = $next_count+1
			Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartOrder $next_count
		}
	}
	Disconnect-VIServer $vi_server -Confirm:$False
}




















