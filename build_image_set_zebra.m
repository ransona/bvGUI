function build_image_set_zebra()
    config = localReadConfig();
    % folder of video folders
    video_folder = config.zebra_video_root;
    
    % load the default stimulus
    load(fullfile(config.stimsets_dir,'Templates','image_set.mat'));
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

function config = localReadConfig()
    repo_root = fileparts(mfilename('fullpath'));
    config_dir = fullfile(repo_root,'configs');
    machine_name = localGetMachineName();
    machine_config_root = fullfile(config_dir,machine_name);
    ini_path = fullfile(machine_config_root,'bvGUI.ini');
    if ~exist(ini_path,'file')
        machine_config_root = fullfile(config_dir,'default');
        ini_path = fullfile(machine_config_root,'bvGUI.ini');
    end
    ini_data = localParseIni(ini_path);

    config.stimsets_dir = fullfile(machine_config_root,'stimsets');
    config.zebra_video_root = localResolvePath(repo_root, localGetIniValue(ini_data,'media','zebra_video_root','C:\bonsai_resources\all_movie_clips_bv_sets'));
end

function machine_name = localGetMachineName()
    machine_name = getenv('COMPUTERNAME');
    if isempty(machine_name)
        machine_name = getenv('HOSTNAME');
    end
    if isempty(machine_name)
        machine_name = 'default';
    end
    machine_name = matlab.lang.makeValidName(machine_name);
end

function ini_data = localParseIni(ini_path)
    ini_data = struct();
    if ~exist(ini_path,'file')
        return;
    end

    ini_lines = splitlines(fileread(ini_path));
    current_section = 'global';
    ini_data.(current_section) = struct();

    for iLine = 1:length(ini_lines)
        line_text = strtrim(ini_lines{iLine});
        if isempty(line_text) || startsWith(line_text,';') || startsWith(line_text,'#')
            continue;
        end

        if startsWith(line_text,'[') && endsWith(line_text,']')
            current_section = matlab.lang.makeValidName(lower(strtrim(line_text(2:end-1))));
            if ~isfield(ini_data,current_section)
                ini_data.(current_section) = struct();
            end
            continue;
        end

        separator_idx = strfind(line_text,'=');
        if isempty(separator_idx)
            continue;
        end

        key_name = matlab.lang.makeValidName(lower(strtrim(line_text(1:separator_idx(1)-1))));
        key_value = strtrim(line_text(separator_idx(1)+1:end));
        ini_data.(current_section).(key_name) = key_value;
    end
end

function value = localGetIniValue(ini_data, section_name, key_name, default_value)
    section_name = matlab.lang.makeValidName(lower(section_name));
    key_name = matlab.lang.makeValidName(lower(key_name));
    value = default_value;

    if isfield(ini_data,section_name) && isfield(ini_data.(section_name),key_name)
        value = ini_data.(section_name).(key_name);
    end
end

function resolved_path = localResolvePath(repo_root, configured_path)
    resolved_path = configured_path;
    is_drive_path = ~isempty(regexp(configured_path,'^[A-Za-z]:[\\/]', 'once'));
    is_unc_path = startsWith(configured_path,'\\');
    is_unix_path = startsWith(configured_path,'/');

    if ~(is_drive_path || is_unc_path || is_unix_path)
        resolved_path = fullfile(repo_root, configured_path);
    end
end
