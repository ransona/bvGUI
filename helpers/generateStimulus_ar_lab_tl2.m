targetConfig = 'ar-lab-tl2';
repoRoot = fileparts(fileparts(mfilename('fullpath')));
configRoot = fullfile(repoRoot,'configs',targetConfig);
stimuliDir = fullfile(configRoot,'stimuli');

if ~exist(stimuliDir,'dir')
    mkdir(stimuliDir);
end

% for all stimuli
stimType.params = {'Repeats'};
stimType.vals = {'1'};
save(fullfile(stimuliDir,'stimulus.mat'),'stimType');
