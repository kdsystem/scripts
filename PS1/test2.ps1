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
# Для Anyorder - выдаем alarm админу - чтобы проверил

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
	
	foreach ($esxi_server in $vi_server.split("")) {
		Write-Host $esxi_server
	}
}

else  {
	$next_count=0
}