
% for gratings:
% featureType.params = {'x','y','width','height','angle','contrast','opacity','phase','freq','speed','dcycle','onset','duration'};
% featureType.vals =   {'0','0','30','30','0','1','1','0','0.05','0','0.5','0','3'};
% save('C:\bvGUI\features\grating.mat','featureType');

% % for go/nogo grating
% featureType.params = {'suppress_duration','response_start','response_duration','lick_threshold','go'};
% featureType.vals =   {'1000','500','1000','2','0'};
% save('C:\bvGUI\features\go_nogo.mat','featureType');

% for vr
featureType.params = {'vr_command','vr_name'};
featureType.vals =   {'',''};
save('C:\bvGUI\features\vr.mat','featureType');