Install notes:

If you want to persistently emulate a d drive so that bv_resouces etc are in a consistant place you can do so with these command:
Create:
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices" /v D: /t REG_SZ /d "\??\C:\Data\Ddrive" /f
Remove if needed:
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices" /v D: /f
