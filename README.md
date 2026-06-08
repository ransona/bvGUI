Install notes:

If you want to persistently emulate a d drive so that bv_resouces etc are in a consistant place you can do so with these command:
Create:
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices" /v D: /t REG_SZ /d "\??\C:\Data\Ddrive" /f
Remove if needed:
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices" /v D: /f

Opto schema helper:

Use `build_bvgui_config_from_opto_schema.m` to create a bvGUI stimulation `.mat` file from a 2P_OPTO_TOOLS opto schema. The helper creates one `opto_2p` stimulus per schema sequence, each with one repeat. Sequence numbers are zero-based to match the opto_2p UDP protocol.

Example:

```matlab
schemaPath = '\\ar-lab-nas1\DataServer\opto_schemas\TEST\DEFAULT\schema.yaml';
outputPath = 'C:\Code\repos\bvGUI\configs\ar-lab-tl2\stimsets\photo_stim_default.mat';
build_bvgui_config_from_opto_schema(schemaPath, outputPath);
```

The helper infers `schema_name` from the parent folder of `schema.yaml`. Pass a third argument to override it:

```matlab
build_bvgui_config_from_opto_schema(schemaPath, outputPath, 'DEFAULT');
```
