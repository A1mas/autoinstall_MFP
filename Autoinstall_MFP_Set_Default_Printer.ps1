  
    $logfile = 'C:\Temp\mfu_setdef_log.txt'
    if ([System.IO.File]::Exists($logfile)) { Remove-Item $logfile -Force -Confirm:$false }

    (Get-Date).ToString() + " " + "- ������ ������ �������" | out-file $logfile -Append -Encoding utf8
    
    Start-Sleep -s 300
    
    $file = 'C:\Temp\mfu_parsed.csv'
    $newfilename = 'C:\Temp\mfu_setdef.csv'


    if ( Test-Path -Path $file) 
     { $lastupdate = ((Get-ItemProperty -Path $file | SELECT *).LastWriteTime).Date #ToString("dd/MM/yyyy")
       if ((Get-Date).Date -eq $lastupdate) {
         $mfu = Import-Csv $file -Delimiter ";"
         $mfuSN = $mfu.serial

         # ��������� �������� ��-���������
         $PRINTERTMP = (Get-CimInstance -ClassName CIM_Printer | WHERE {$_.Name -eq $mfuSN})
         if ($PRINTERTMP -ne $null) {
            $PRINTERTMP | Invoke-CimMethod -MethodName SetDefaultPrinter | Out-Null

            $wshell = New-Object -ComObject Wscript.Shell
            $Output = $wshell.Popup("��������� ��� SN $mfuSN ���������!",0,"�����������",0+64)

            if ([System.IO.File]::Exists($newfilename)) { Remove-Item $newfilename -Force -Confirm:$false }
            Rename-Item -path $file -NewName $newfilename
            (Get-Date).ToString() + " " + "- the default printer setup is done" | out-file $logfile -Append -Encoding utf8

         } else { (Get-Date).ToString() + " " + "- the default printer setup ERROR!" | out-file $logfile -Append -Encoding utf8 }

       } else { (Get-Date).ToString() + " " + "- ���� ����� �� ��������� � �������" | out-file $logfile -Append -Encoding utf8; exit }
    } else { (Get-Date).ToString() + " " + "- ���� mfu_parsed.csv �� ������" | out-file $logfile -Append -Encoding utf8; exit }