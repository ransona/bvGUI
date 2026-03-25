function build_image_set_zebra()
    % folder of video folders
    video_folder = 'C:\bonsai_resources\all_movie_clips_bv_sets';
    stimsets_dir = localGetStimsetsDir();
    
    % load the default stimulus
    load(fullfile(stimsets_dir,'Templates','image_set.mat'));
    default_stim = expData.stims;
    
    % variables
    expData.vars = 'width=90; height=50.6; x=-90; y=0; loop=0; speed=30; onset=0; duration=30;';
    expData.iti = '0';
    expData.seqreps = '1';
    
    % set stim properties to use variables
    default_stim.features.vals(3) = {'width'};
    default_stim.features.vals(4) = {'height'};
    default_stim.features.vals(5) = {'x'};
    default_stim.features.vals(6) = {'y'};
    default_stim.features.vals(7) = {'loop'};
    default_stim.features.vals(8) = {'speed'};
    default_stim.features.vals(9) = {'onset'};
    default_stim.features.vals(10) = {'duration'};
    
    % Get list of subfolders in video_folder
    folder_info = dir(video_folder); % get folder info
    subfolders = folder_info([folder_info.isdir]); % only keep directories
    
    % Remove '.' and '..' directories
    subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));
    
    % Cycle through each subfolder (each will be one video stimulus)
    for i = 1:length(subfolders)
        folder_name = subfolders(i).name;
        folder_path = fullfile(video_folder, folder_name);
        
        % Display the folder path for verification
        disp(['Processing folder: ', folder_path]);
        % point to video diectory
        default_stim.features.vals(1) = {folder_path};
        expData.stims(i) = default_stim;
    end
    
    % Prompt user to save expData to a .mat file
    [file_name, file_path] = uiputfile('*.mat', 'Save expData as');
    if ischar(file_name)
        save(fullfile(file_path, file_name), 'expData');
        disp(['expData saved to ', fullfile(file_path, file_name)]);
    else
        disp('Save operation canceled.');
    end
    
end

function stimsets_dir = localGetStimsetsDir()
    repo_root = fileparts(mfilename('fullpath'));
    config_dir = fullfile(repo_root,'configs');
    machine_name = localGetMachineName();
    machine_config_root = fullfile(config_dir,machine_name);
    if ~exist(machine_config_root,'dir')
        error('Missing machine config directory: %s', machine_config_root);
    end
    stimsets_dir = fullfile(machine_config_root,'stimsets');
end

function machine_name = localGetMachineName()
    machine_name = getenv('COMPUTERNAME');
    if isempty(machine_name)
        machine_name = getenv('HOSTNAME');
    end
    if isempty(machine_name)
        machine_name = 'default';
    end
    machine_name = strtrim(machine_name);
end
