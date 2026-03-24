targetConfig = 'ar-lab-tl2';
repoRoot = fileparts(fileparts(mfilename('fullpath')));
configRoot = fullfile(repoRoot,'configs',targetConfig);
featuresDir = fullfile(configRoot,'features');

if ~exist(featuresDir,'dir')
    error('Feature output directory does not exist: %s', featuresDir);
end

% Example definitions:
% featureType.params = {'x','y','width','height','angle','contrast','opacity','phase','freq','speed','dcycle','onset','duration'};
% featureType.vals =   {'0','0','30','30','0','1','1','0','0.05','0','0.5','0','3'};
% save(fullfile(featuresDir,'grating.mat'),'featureType');
%
% featureType.params = {'suppress_duration','response_start','response_duration','lick_threshold','go'};
% featureType.vals =   {'1000','500','1000','2','0'};
% save(fullfile(featuresDir,'go_nogo.mat'),'featureType');

% for vr
featureType.params = {'vr_command','vr_name'};
featureType.vals = {'',''};
save(fullfile(featuresDir,'vr.mat'),'featureType');
