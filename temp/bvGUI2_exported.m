classdef bvGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        PauseafterpreloadEditField     matlab.ui.control.EditField
        PauseafterpreloadEditFieldLabel  matlab.ui.control.Label
        LogButton                      matlab.ui.control.Button
        ExperimentlogTextArea          matlab.ui.control.TextArea
        ExperimentlogTextAreaLabel     matlab.ui.control.Label
        ITIEditField                   matlab.ui.control.EditField
        ITIEditFieldLabel              matlab.ui.control.Label
        FeatCopyButton                 matlab.ui.control.Button
        CopyButton                     matlab.ui.control.Button
        VariablesEditField             matlab.ui.control.EditField
        VariablesEditFieldLabel        matlab.ui.control.Label
        TestStimBtn                    matlab.ui.control.Button
        PreBlankText                   matlab.ui.control.EditField
        DelaysecsLabel                 matlab.ui.control.Label
        BuildSetButton                 matlab.ui.control.Button
        AnimalIDEditField              matlab.ui.control.EditField
        AnimalIDEditFieldLabel         matlab.ui.control.Label
        UITable_DAQs                   matlab.ui.control.Table
        FeedbackListBox                matlab.ui.control.ListBox
        RandomiseCheckBox              matlab.ui.control.CheckBox
        RepsEditField                  matlab.ui.control.EditField
        RepsEditFieldLabel             matlab.ui.control.Label
        SequenceRepeatsEditField       matlab.ui.control.EditField
        SequenceRepeatsEditFieldLabel  matlab.ui.control.Label
        ResetButton                    matlab.ui.control.Button
        SettingsPanel                  matlab.ui.container.Panel
        SavesettingsButton             matlab.ui.control.Button
        BVServerEditField              matlab.ui.control.EditField
        BVServerEditFieldLabel         matlab.ui.control.Label
        Rewardv2Button                 matlab.ui.control.Button
        Rewardv1Button                 matlab.ui.control.Button
        Closevalve2Button              matlab.ui.control.Button
        Openvalve2Button               matlab.ui.control.Button
        Closevalve1Button              matlab.ui.control.Button
        Openvalve1Button               matlab.ui.control.Button
        NewFeatureListBoxLabel_2       matlab.ui.control.Label
        NewButton                      matlab.ui.control.Button
        RunButton                      matlab.ui.control.Button
        SaveButton                     matlab.ui.control.Button
        LoadButton                     matlab.ui.control.Button
        ButtonRemoveStim               matlab.ui.control.Button
        ButtonAddStim                  matlab.ui.control.Button
        ButtonRemoveFeature            matlab.ui.control.Button
        ButtonAddFeature               matlab.ui.control.Button
        NewFeatureListBox              matlab.ui.control.ListBox
        NewFeatureListBoxLabel         matlab.ui.control.Label
        UITable                        matlab.ui.control.Table
        FeatureListBox                 matlab.ui.control.ListBox
        FeatureListBoxLabel            matlab.ui.control.Label
        StimulusListBox                matlab.ui.control.ListBox
        StimulusListBoxLabel           matlab.ui.control.Label
    end


    properties (Access = public)
        abortFlag = 0; % Whether you want to abort if stimulus run is ongoing
    end

    methods (Access = private)
        function pauseWithEvents(app, pauseTime)
            % pauseWithEvents pauses for a specified time while processing events
            %
            % Inputs:
            %   pauseTime - Number of seconds to pause
        
            startTime = tic; % Start the timer
            while toc(startTime) < pauseTime
                drawnow; % Process any pending events or callbacks
            end
        end        
      
        function result = send_udp_command(app, server, port, msg)
            % Define the timeout period in seconds (10 minutes)
            timeoutPeriod = 600;
        
            % Create the UDP socket
            udpSocket = udp(server, port);
            fopen(udpSocket);
        
            try
                % Send the provided message
                fwrite(udpSocket, msg);
        
                % Wait for the response
                startTime = tic; % Start timer
                while udpSocket.BytesAvailable == 0
                    elapsedTime = toc(startTime);
                    if elapsedTime > timeoutPeriod
                        result = -1; % Timeout reached, return failure
                        return;
                    end
                    pause(0.1); % Short pause to avoid busy waiting
                end
        
                % Read and process the response
                response = fread(udpSocket, udpSocket.BytesAvailable);
                responseStr = char(response');
                
                % Check the server response and return success or failure
                if strcmp(responseStr, '1')
                    result = 1; % Success
                elseif strcmp(responseStr, '-1')
                    result = -1; % Failure
                else
                    result = -1; % Unexpected response
                end
            catch
                % If an error occurs, return failure
                result = -1;
            end
        
            % Close the UDP socket
            fclose(udpSocket);
            delete(udpSocket);
            clear udpSocket;
            
        end

        function repoRoot = getRepoRoot(app)
            appPath = which(class(app));
            if isempty(appPath)
                repoRoot = pwd;
            else
                repoRoot = fileparts(appPath);
            end
        end

        function config = getRepoConfig(app)
            repoRoot = app.getRepoRoot();
            machineName = app.getMachineName();
            configDir = fullfile(repoRoot,'configs');
            machineConfigRoot = fullfile(configDir,machineName);
            iniPath = fullfile(machineConfigRoot,'bvGUI.ini');
            if ~exist(iniPath,'file')
                error('bvGUI:MissingMachineConfig', 'Missing machine config: %s', iniPath);
            end
            iniData = app.readIniFile(iniPath);

            config = struct();
            config.repoRoot = repoRoot;
            config.configDir = configDir;
            config.machineName = machineName;
            config.machineConfigRoot = machineConfigRoot;
            config.iniPath = iniPath;
            config.featuresDir = fullfile(machineConfigRoot,'features');
            config.stimsetsDir = fullfile(machineConfigRoot,'stimsets');
            config.daqStartDir = fullfile(machineConfigRoot,'daqStart');
            config.daqStopDir = fullfile(machineConfigRoot,'daqStop');
            config.iniData = iniData;
            config.bvServer = app.getIniValue(iniData,'settings','bv_server','127.0.0.1');
            config.localSaveRoot = app.resolveConfigPath(repoRoot, app.getIniValue(iniData,'paths','local_save_root','c:\local_repository'));
            config.remoteSaveRoot = app.resolveConfigPath(repoRoot, app.getIniValue(iniData,'paths','remote_save_root','\\AR-LAB-NAS1\DataServer\Remote_Repository'));
            config.pythonExe = app.resolveConfigPath(repoRoot, app.getIniValue(iniData,'paths','python_exe',''));
            config.hashScript = app.resolveConfigPath(repoRoot, app.getIniValue(iniData,'paths','hash_script',''));
            config.opto2pListener = strtrim(app.getIniValue(iniData,'network','opto_2p_listener',''));
            config.opto2pPort = str2double(strtrim(app.getIniValue(iniData,'network','opto_2p_port','')));
        end

        function machineName = getMachineName(app)
            machineName = getenv('COMPUTERNAME');
            if isempty(machineName)
                machineName = getenv('HOSTNAME');
            end
            if isempty(machineName)
                machineName = 'default';
            end
            machineName = strtrim(machineName);
        end

        function addRepoSupportPaths(app, repoRoot)
            supportPaths = {
                fullfile(repoRoot,'bv_matlab')
                fullfile(repoRoot,'UDPqML')
            };

            for iPath = 1:numel(supportPaths)
                if exist(supportPaths{iPath},'dir')
                    addpath(supportPaths{iPath});
                end
            end
        end

        function iniData = readIniFile(app, iniPath)
            iniData = struct();
            if ~exist(iniPath,'file')
                return;
            end

            iniText = fileread(iniPath);
            iniLines = splitlines(iniText);
            currentSection = 'global';
            iniData.(currentSection) = struct();

            for iLine = 1:length(iniLines)
                lineText = strtrim(iniLines{iLine});
                if isempty(lineText) || startsWith(lineText,';') || startsWith(lineText,'#')
                    continue;
                end

                if startsWith(lineText,'[') && endsWith(lineText,']')
                    currentSection = matlab.lang.makeValidName(lower(strtrim(lineText(2:end-1))));
                    if ~isfield(iniData,currentSection)
                        iniData.(currentSection) = struct();
                    end
                    continue;
                end

                separatorIdx = strfind(lineText,'=');
                if isempty(separatorIdx)
                    continue;
                end

                keyName = strtrim(lineText(1:separatorIdx(1)-1));
                keyValue = strtrim(lineText(separatorIdx(1)+1:end));

                if length(keyValue) >= 2
                    if (startsWith(keyValue,'"') && endsWith(keyValue,'"')) || (startsWith(keyValue,'''') && endsWith(keyValue,''''))
                        keyValue = keyValue(2:end-1);
                    end
                end

                keyName = matlab.lang.makeValidName(lower(keyName));
                iniData.(currentSection).(keyName) = keyValue;
            end
        end

        function value = getIniValue(app, iniData, sectionName, keyName, defaultValue)
            sectionName = matlab.lang.makeValidName(lower(sectionName));
            keyName = matlab.lang.makeValidName(lower(keyName));

            value = defaultValue;
            if isfield(iniData,sectionName) && isfield(iniData.(sectionName),keyName)
                value = iniData.(sectionName).(keyName);
            end
        end

        function iniData = setIniValue(app, iniData, sectionName, keyName, value)
            sectionName = matlab.lang.makeValidName(lower(sectionName));
            keyName = matlab.lang.makeValidName(lower(keyName));
            if ~isfield(iniData,sectionName)
                iniData.(sectionName) = struct();
            end
            iniData.(sectionName).(keyName) = value;
        end

        function writeIniFile(app, iniPath, iniData)
            sectionNames = fieldnames(iniData);
            lines = {};
            for iSection = 1:numel(sectionNames)
                sectionName = sectionNames{iSection};
                if strcmp(sectionName,'global')
                    continue;
                end
                lines{end+1} = ['[', sectionName, ']']; %#ok<AGROW>
                keyNames = fieldnames(iniData.(sectionName));
                for iKey = 1:numel(keyNames)
                    keyName = keyNames{iKey};
                    keyValue = iniData.(sectionName).(keyName);
                    if ~(ischar(keyValue) || isstring(keyValue))
                        keyValue = num2str(keyValue);
                    end
                    lines{end+1} = [keyName, ' = ', char(keyValue)]; %#ok<AGROW>
                end
                lines{end+1} = ''; %#ok<AGROW>
            end
            iniText = strjoin(lines,newline);
            fid = fopen(iniPath,'w');
            if fid == -1
                error('bvGUI:IniWriteFailed','Unable to write ini file: %s', iniPath);
            end
            cleaner = onCleanup(@() fclose(fid));
            fprintf(fid,'%s',iniText);
        end

        function resolvedPath = resolveConfigPath(app, repoRoot, configuredPath)
            resolvedPath = configuredPath;
            if isempty(configuredPath)
                return;
            end

            isDrivePath = ~isempty(regexp(configuredPath,'^[A-Za-z]:[\\/]', 'once'));
            isUncPath = startsWith(configuredPath,'\\');
            isUnixPath = startsWith(configuredPath,'/');

            if ~(isDrivePath || isUncPath || isUnixPath)
                resolvedPath = fullfile(repoRoot, configuredPath);
            end
        end

        function completeStimSeq = buildCompleteStimSeq(app)
            global bvData;

            completeStimSeq = [];
            seqReps = str2num(app.SequenceRepeatsEditField.Value); %#ok<ST2NM>

            for iSeqRep = 1:seqReps
                singleRepSeq = [];
                for iStim = 1:length(bvData.expData.stims)
                    stimReps = bvData.expData.stims(iStim).reps;
                    singleRepSeq = [singleRepSeq,repmat(iStim,[1 stimReps])]; %#ok<AGROW>
                end
                if app.RandomiseCheckBox.Value == true
                    completeStimSeq = [completeStimSeq,singleRepSeq(randperm(length(singleRepSeq)))]; %#ok<AGROW>
                else
                    completeStimSeq = [completeStimSeq,singleRepSeq]; %#ok<AGROW>
                end
            end
        end

        function [prepData, errMsg] = collectOpto2pPrepData(app, expDataEval, completeStimSeq)
            prepData = struct('enabled', false, 'schemaName', '', 'seqNums', []);
            errMsg = '';
            schemaName = '';
            seqNums = [];

            for iTrial = 1:length(completeStimSeq)
                stimIdx = completeStimSeq(iTrial);
                [trialData, errMsg] = app.collectTrialOpto2pData(expDataEval, stimIdx);
                if ~isempty(errMsg)
                    return;
                end
                if ~trialData.enabled
                    continue;
                end

                if isempty(schemaName)
                    schemaName = trialData.schemaName;
                elseif ~strcmp(schemaName,trialData.schemaName)
                    errMsg = ['Conflicting opto_2p schema_name values: ',schemaName,' vs ',trialData.schemaName];
                    return;
                end

                if ~ismember(trialData.seqNum,seqNums)
                    seqNums(end+1) = trialData.seqNum; %#ok<AGROW>
                end
            end

            if isempty(seqNums)
                return;
            end

            prepData.enabled = true;
            prepData.schemaName = schemaName;
            prepData.seqNums = seqNums;
        end

        function [trialData, errMsg] = collectTrialOpto2pData(app, expDataEval, stimIdx)
            trialData = struct('enabled', false, 'schemaName', '', 'seqNum', []);
            errMsg = '';
            schemaName = '';
            seqNum = [];
            enabledOptoCount = 0;

            for iFeature = 1:length(expDataEval(stimIdx).features)
                feature = expDataEval(stimIdx).features(iFeature);
                if ~strcmp(feature.name{1},'opto_2p')
                    continue;
                end

                featureParams = cell2struct(feature.vals',feature.params);
                if isfield(featureParams,'enable') && ~strcmp(strtrim(featureParams.enable),'1')
                    continue;
                end

                enabledOptoCount = enabledOptoCount + 1;
                if enabledOptoCount > 1
                    errMsg = ['Only one enabled opto_2p feature is allowed in stimulus ',num2str(stimIdx)];
                    return;
                end

                if ~isfield(featureParams,'schema_name') || isempty(strtrim(featureParams.schema_name))
                    errMsg = ['Missing schema_name in opto_2p feature for stimulus ',num2str(stimIdx)];
                    return;
                end
                if ~isfield(featureParams,'seq_number') || isempty(strtrim(featureParams.seq_number))
                    errMsg = ['Missing seq_number in opto_2p feature for stimulus ',num2str(stimIdx)];
                    return;
                end

                currentSchemaName = strtrim(featureParams.schema_name);
                currentSeqNum = str2double(featureParams.seq_number);
                if isnan(currentSeqNum) || ~isfinite(currentSeqNum) || currentSeqNum ~= floor(currentSeqNum)
                    errMsg = ['Invalid opto_2p seq_number: ',featureParams.seq_number];
                    return;
                end

                if isempty(schemaName)
                    schemaName = currentSchemaName;
                elseif ~strcmp(schemaName,currentSchemaName)
                    errMsg = ['Conflicting opto_2p schema_name values within stimulus ',num2str(stimIdx)];
                    return;
                end

                if isempty(seqNum)
                    seqNum = currentSeqNum;
                elseif seqNum ~= currentSeqNum
                    errMsg = ['Conflicting opto_2p seq_number values within stimulus ',num2str(stimIdx)];
                    return;
                end
            end

            if isempty(seqNum)
                return;
            end

            trialData.enabled = true;
            trialData.schemaName = schemaName;
            trialData.seqNum = seqNum;
        end

        function [success, errMsg] = runOpto2pPrep(app, config, expID, prepData)
            success = true;
            errMsg = '';

            if ~prepData.enabled
                return;
            end

            if isempty(config.opto2pListener)
                success = false;
                errMsg = ['Opto_2p is not available on machine ',config.machineName,': network.opto_2p_listener is not configured.'];
                return;
            end
            if isnan(config.opto2pPort) || ~isfinite(config.opto2pPort) || config.opto2pPort <= 0
                success = false;
                errMsg = ['Opto_2p is not available on machine ',config.machineName,': network.opto_2p_port is not configured.'];
                return;
            end

            app.debugMessage('Computing masks');

            udpSocket = [];
            timeoutPeriod = 600;
            try
                udpSocket = udp(config.opto2pListener, config.opto2pPort);
                udpSocket.Timeout = timeoutPeriod;
                fopen(udpSocket);
                udpCleaner = onCleanup(@() app.cleanupUdpSocket(udpSocket)); %#ok<NASGU>

                payload = struct( ...
                    'action', 'prep_patterns', ...
                    'schema_name', prepData.schemaName, ...
                    'expID', expID, ...
                    'seq_nums', prepData.seqNums);
                jsonPayload = jsonencode(payload);
                seqNumSummary = strjoin(cellstr(string(prepData.seqNums)),', ');
                app.debugMessage(['Preparing opto_2p masks for seq_nums [',seqNumSummary,'] via ',config.opto2pListener,':',num2str(config.opto2pPort)]);
                fwrite(udpSocket, unicode2native(jsonPayload,'UTF-8'), 'uint8');

                startTime = tic;
                while udpSocket.BytesAvailable == 0
                    if toc(startTime) > timeoutPeriod
                        success = false;
                        errMsg = ['Timed out waiting for opto_2p confirmation for seq_nums [',seqNumSummary,']'];
                        return;
                    end
                    drawnow limitrate;
                    pause(0.1);
                end

                response = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
                responseText = native2unicode(uint8(response)','UTF-8');

                try
                    reply = jsondecode(responseText);
                catch
                    success = false;
                    errMsg = ['Invalid opto_2p JSON reply for seq_nums [',seqNumSummary,']: ',responseText];
                    return;
                end

                if ~isfield(reply,'action') || ~strcmp(reply.action,'prep_patterns')
                    success = false;
                    errMsg = 'Unexpected opto_2p prep action in reply.';
                    return;
                end
                if ~isfield(reply,'schema_name') || ~strcmp(char(string(reply.schema_name)),prepData.schemaName)
                    success = false;
                    errMsg = 'Schema mismatch in opto_2p prep reply.';
                    return;
                end
                if ~isfield(reply,'expID') || ~strcmp(char(string(reply.expID)),expID)
                    success = false;
                    errMsg = 'expID mismatch in opto_2p prep reply.';
                    return;
                end
                if ~isfield(reply,'status')
                    success = false;
                    errMsg = 'Missing status in opto_2p prep reply.';
                    return;
                end

                replyStatus = char(string(reply.status));
                if strcmp(replyStatus,'error')
                    replyError = 'Unknown opto_2p error';
                    if isfield(reply,'error')
                        replyError = char(string(reply.error));
                    end
                    success = false;
                    errMsg = ['Opto_2p prep error: ',replyError];
                    return;
                end
                if ~strcmp(replyStatus,'ready')
                    success = false;
                    errMsg = ['Unexpected opto_2p prep status: ',replyStatus];
                    return;
                end

                preparedSeqNumsSummary = '';
                if isfield(reply,'prepared_seq_nums')
                    preparedSeqNumsSummary = strjoin(cellstr(string(reply.prepared_seq_nums)),', ');
                end

                preparedSequenceNamesSummary = '';
                if isfield(reply,'prepared_sequence_names')
                    preparedSequenceNamesSummary = strjoin(cellstr(string(reply.prepared_sequence_names)),', ');
                end

                patternSummary = '';
                if isfield(reply,'pattern_names')
                    patternNames = cellstr(string(reply.pattern_names));
                    patternSummary = strjoin(patternNames,', ');
                end

                stimulusGroupSummary = '';
                if isfield(reply,'stimulus_groups')
                    stimulusGroups = reply.stimulus_groups;
                    if isstruct(stimulusGroups)
                        if numel(stimulusGroups) == 1
                            stimulusGroups = stimulusGroups(:);
                        end
                        groupParts = cell(1,numel(stimulusGroups));
                        for iGroup = 1:numel(stimulusGroups)
                            groupNum = '';
                            patternName = '';
                            if isfield(stimulusGroups(iGroup),'stimulus_group_num')
                                groupNum = char(string(stimulusGroups(iGroup).stimulus_group_num));
                            end
                            if isfield(stimulusGroups(iGroup),'pattern_name')
                                patternName = char(string(stimulusGroups(iGroup).pattern_name));
                            end
                            groupParts{iGroup} = ['G',groupNum,'=',patternName];
                        end
                        stimulusGroupSummary = strjoin(groupParts,', ');
                    end
                end

                app.debugMessage(['Opto_2p prep ready for schema ',prepData.schemaName,' and seq_nums [',seqNumSummary,']']);
                if ~isempty(preparedSeqNumsSummary)
                    app.debugMessage(['Prepared seq_nums: ',preparedSeqNumsSummary]);
                end
                if ~isempty(preparedSequenceNamesSummary)
                    app.debugMessage(['Prepared sequences: ',preparedSequenceNamesSummary]);
                end
                if ~isempty(patternSummary)
                    app.debugMessage(['Prepared patterns: ',patternSummary]);
                end
                if ~isempty(stimulusGroupSummary)
                    app.debugMessage(['Prepared stimulus groups: ',stimulusGroupSummary]);
                end
            catch err
                success = false;
                errMsg = ['Opto_2p prep failed: ',err.message];
            end
        end

        function [success, errMsg] = triggerOpto2pForTrial(app, config, expID, trialData)
            success = true;
            errMsg = '';

            if ~trialData.enabled
                return;
            end

            if isempty(config.opto2pListener)
                success = false;
                errMsg = ['Opto_2p is not available on machine ',config.machineName,': network.opto_2p_listener is not configured.'];
                return;
            end
            if isnan(config.opto2pPort) || ~isfinite(config.opto2pPort) || config.opto2pPort <= 0
                success = false;
                errMsg = ['Opto_2p is not available on machine ',config.machineName,': network.opto_2p_port is not configured.'];
                return;
            end

            udpSocket = [];
            timeoutPeriod = 600;

            try
                udpSocket = udp(config.opto2pListener, config.opto2pPort);
                udpSocket.Timeout = timeoutPeriod;
                fopen(udpSocket);
                udpCleaner = onCleanup(@() app.cleanupUdpSocket(udpSocket)); %#ok<NASGU>

                payload = struct( ...
                    'action', 'trigger_photo_stim', ...
                    'schema_name', trialData.schemaName, ...
                    'expID', expID, ...
                    'seq_num', trialData.seqNum);
                jsonPayload = jsonencode(payload);
                app.debugMessage(['Triggering opto_2p for seq_num ',num2str(trialData.seqNum),' via ',config.opto2pListener,':',num2str(config.opto2pPort)]);
                fwrite(udpSocket, unicode2native(jsonPayload,'UTF-8'), 'uint8');

                startTime = tic;
                while udpSocket.BytesAvailable == 0
                    if toc(startTime) > timeoutPeriod
                        success = false;
                        errMsg = ['Timed out waiting for opto_2p trigger confirmation for seq_num ',num2str(trialData.seqNum)];
                        return;
                    end
                    drawnow limitrate;
                    pause(0.1);
                end

                response = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
                responseText = native2unicode(uint8(response)','UTF-8');

                try
                    reply = jsondecode(responseText);
                catch
                    success = false;
                    errMsg = ['Invalid opto_2p trigger JSON reply for seq_num ',num2str(trialData.seqNum),': ',responseText];
                    return;
                end

                if ~isfield(reply,'action') || ~strcmp(reply.action,'trigger_photo_stim')
                    success = false;
                    errMsg = ['Unexpected opto_2p trigger action for seq_num ',num2str(trialData.seqNum)];
                    return;
                end
                if ~isfield(reply,'schema_name') || ~strcmp(char(string(reply.schema_name)),trialData.schemaName)
                    success = false;
                    errMsg = ['Schema mismatch in opto_2p trigger reply for seq_num ',num2str(trialData.seqNum)];
                    return;
                end
                if ~isfield(reply,'expID') || ~strcmp(char(string(reply.expID)),expID)
                    success = false;
                    errMsg = ['expID mismatch in opto_2p trigger reply for seq_num ',num2str(trialData.seqNum)];
                    return;
                end
                if ~isfield(reply,'seq_num')
                    success = false;
                    errMsg = ['Missing seq_num in opto_2p trigger reply for seq_num ',num2str(trialData.seqNum)];
                    return;
                end

                replySeqNum = str2double(char(string(reply.seq_num)));
                if isnan(replySeqNum) || replySeqNum ~= trialData.seqNum
                    success = false;
                    errMsg = ['seq_num mismatch in opto_2p trigger reply for seq_num ',num2str(trialData.seqNum)];
                    return;
                end
                if ~isfield(reply,'status')
                    success = false;
                    errMsg = ['Missing status in opto_2p trigger reply for seq_num ',num2str(trialData.seqNum)];
                    return;
                end

                replyStatus = char(string(reply.status));
                if strcmp(replyStatus,'error')
                    replyError = 'Unknown opto_2p trigger error';
                    if isfield(reply,'error')
                        replyError = char(string(reply.error));
                    end
                    success = false;
                    errMsg = ['Opto_2p trigger error for seq_num ',num2str(trialData.seqNum),': ',replyError];
                    return;
                end
                if ~strcmp(replyStatus,'ready')
                    success = false;
                    errMsg = ['Unexpected opto_2p trigger status for seq_num ',num2str(trialData.seqNum),': ',replyStatus];
                    return;
                end

                sequenceName = '';
                if isfield(reply,'sequence_name')
                    sequenceName = char(string(reply.sequence_name));
                end
                stimulusGroupsSummary = '';
                if isfield(reply,'stimulus_groups')
                    stimulusGroupsSummary = strjoin(cellstr(string(reply.stimulus_groups)),', ');
                end

                if isempty(stimulusGroupsSummary)
                    app.debugMessage(['Opto_2p trigger ready for seq_num ',num2str(trialData.seqNum),' (',sequenceName,')']);
                else
                    app.debugMessage(['Opto_2p trigger ready for seq_num ',num2str(trialData.seqNum),' (',sequenceName,'): ',stimulusGroupsSummary]);
                end
            catch err
                success = false;
                errMsg = ['Opto_2p trigger failed: ',err.message];
            end
        end

        function [success, errMsg] = abortOpto2p(app, config)
            success = true;
            errMsg = '';

            if isempty(config.opto2pListener)
                return;
            end
            if isnan(config.opto2pPort) || ~isfinite(config.opto2pPort) || config.opto2pPort <= 0
                return;
            end

            udpSocket = [];
            timeoutPeriod = 600;

            try
                udpSocket = udp(config.opto2pListener, config.opto2pPort);
                udpSocket.Timeout = timeoutPeriod;
                fopen(udpSocket);
                udpCleaner = onCleanup(@() app.cleanupUdpSocket(udpSocket)); %#ok<NASGU>

                payload = struct('action', 'abort_photo_stim');
                jsonPayload = jsonencode(payload);
                app.debugMessage(['Sending abort_photo_stim via ',config.opto2pListener,':',num2str(config.opto2pPort)]);
                fwrite(udpSocket, unicode2native(jsonPayload,'UTF-8'), 'uint8');

                startTime = tic;
                while udpSocket.BytesAvailable == 0
                    if toc(startTime) > timeoutPeriod
                        success = false;
                        errMsg = 'Timed out waiting for abort_photo_stim confirmation.';
                        return;
                    end
                    drawnow limitrate;
                    pause(0.1);
                end

                response = fread(udpSocket, udpSocket.BytesAvailable, 'uint8');
                responseText = native2unicode(uint8(response)','UTF-8');

                try
                    reply = jsondecode(responseText);
                catch
                    success = false;
                    errMsg = ['Invalid abort_photo_stim JSON reply: ',responseText];
                    return;
                end

                if ~isfield(reply,'action') || ~strcmp(reply.action,'abort_photo_stim')
                    success = false;
                    errMsg = 'Unexpected abort_photo_stim action in reply.';
                    return;
                end
                if ~isfield(reply,'status')
                    success = false;
                    errMsg = 'Missing status in abort_photo_stim reply.';
                    return;
                end

                replyStatus = char(string(reply.status));
                if strcmp(replyStatus,'error')
                    replyError = 'Unknown abort_photo_stim error';
                    if isfield(reply,'error')
                        replyError = char(string(reply.error));
                    end
                    success = false;
                    errMsg = ['abort_photo_stim error: ',replyError];
                    return;
                end
                if ~strcmp(replyStatus,'ready')
                    success = false;
                    errMsg = ['Unexpected abort_photo_stim status: ',replyStatus];
                    return;
                end

                app.debugMessage('abort_photo_stim acknowledged.');
            catch err
                success = false;
                errMsg = ['abort_photo_stim failed: ',err.message];
            end
        end

        function restoreRunButton(app)
            app.RunButton.Enable = "on";
            app.RunButton.Text = 'Run';
            app.RunButton.BackgroundColor = 'g';
            app.abortFlag = 0;
        end

        function requestRunAbort(app, messageText)
            app.abortFlag = 1;
            app.RunButton.Text = 'Aborting...';
            app.RunButton.Enable = "off";
            if nargin > 1 && ~isempty(messageText)
                app.debugMessage(messageText);
            end
        end

        function cleanupUdpSocket(app, udpSocket)
            if isempty(udpSocket)
                return;
            end
            try
                fclose(udpSocket);
            catch
            end
            try
                delete(udpSocket);
            catch
            end
        end


        function results = bvUpdateGUI(app)
            % function to make the table in the gui reflect the currently
            % loaded experiment data structure
            global bvData;

            if isfield(bvData.expData,'vars')
                app.VariablesEditField.Value = bvData.expData.vars;
            else
                app.VariablesEditField.Value = '';
            end

            if isfield(bvData.expData,'iti')
                app.ITIEditField.Value = bvData.expData.iti;
            else
                app.ITIEditField.Value = '1';
            end

            if isfield(bvData.expData,'seqreps')
                app.SequenceRepeatsEditField.Value = bvData.expData.seqreps;
            else
                app.SequenceRepeatsEditField.Value = '10';
            end

            % update list of stims
            app.StimulusListBox.Items = {};
            for iStim = 1:length(bvData.expData.stims)
                app.StimulusListBox.Items = [app.StimulusListBox.Items,{num2str(iStim)}];
            end

            if ~isempty(app.StimulusListBox.Tag)
                app.StimulusListBox.Value = app.StimulusListBox.Tag;
                app.RepsEditField.Value = num2str(bvData.expData.stims(str2num(app.StimulusListBox.Tag)).reps);
            end

            % get current selection of stim to update list of features
            currentStim = str2num(app.StimulusListBox.Tag);
            if isempty(currentStim)
                % make feature list empty
                app.FeatureListBox.Items = {};
                % make parameter table empty
                app.UITable.Data = [];
                app.UITable.ColumnName = {'Nothing selected'};
                return;
            end
            % update list of features in current stim
            app.FeatureListBox.Items = {};
            for iFeat = 1:length(bvData.expData.stims(currentStim).features)
                app.FeatureListBox.Items = [app.FeatureListBox.Items,{[num2str(iFeat),'-',bvData.expData.stims(currentStim).features(iFeat).name{1}]}];
            end
            app.FeatureListBox.ItemsData = 1:length(bvData.expData.stims(currentStim).features);

            % get current selection of feature to update list of properties
            currentFeat = str2num(app.FeatureListBox.Tag);
            if isempty(currentFeat)
                % make parameter table empty
                app.UITable.Data = [];
                app.UITable.ColumnName = {'Nothing selected'};
                return;
            end
            app.FeatureListBox.Value = currentFeat;
            paramNames = bvData.expData.stims(currentStim).features(currentFeat).params;
            paramVals = bvData.expData.stims(currentStim).features(currentFeat).vals;
            x = table(paramVals');
            app.UITable.Data = x; %table(paramVals',"RowNames",paramNames);
            app.UITable.RowName = paramNames;
            app.UITable.ColumnName = bvData.expData.stims(currentStim).features(currentFeat).name;

        end

        function results = debugMessage(app,outputMsg)
            currentTime = datestr(datetime('now','TimeZone','local','Format','HH:mm:ss'));
            currentTime = currentTime(end-7:end);
            outputMsg = [currentTime,': ',outputMsg];
            app.FeedbackListBox.Items(end+1)={outputMsg};
            drawnow
            app.FeedbackListBox.Value = outputMsg;
            app.FeedbackListBox.scroll('bottom')
            %       if length(app.FeedbackListBox.Items)>30
            %         app.FeedbackListBox.Items(1:length(app.FeedbackListBox.Items)-30)=[];
            %       end
        end

        function saveForPython(app,expDat,expID,save_path)
            Folder = save_path;
            % Folder = 'G:\.shortcut-targets-by-id\1P7g8LSE5D6vInT7OOXY1EIzJ0M4zvhos\Remote_Repository\TEST\2023-02-27_09_TEST';
            FileList = dir(fullfile(Folder, '**', '*stim.mat'));
            disp(['Found ',num2str(length(FileList)),' stim files']);
            for iFile = 1:length(FileList)
                % load matlab stim file
                load(fullfile(FileList(iFile).folder,FileList(iFile).name));
                disp(['Starting ',expDat.expID,'(',num2str(iFile),'/',num2str(length(FileList)),')...']);
                % determine max number of feats
                max_feat = 0;
                for iStim = 1:length(expDat.stims)
                    if length(expDat.stims(iStim).features)>max_feat
                        max_feat = length(expDat.stims(iStim).features);
                    end
                end
                % determine the total stimulus duration by finding the max start +
                % duration value
                allDurations = zeros([length(expDat.stims),1]);
                for iStim = 1:length(expDat.stims)
                    for iFeat = 1:length(expDat.stims(iStim).features)
                        [~,startIdx] = ismember('onset',expDat.stims(iStim).features(iFeat).params);
                        [~,durationIdx] = ismember('duration',expDat.stims(iStim).features(iFeat).params);
                        if startIdx > 0 && durationIdx > 0
                          if str2num(expDat.stims(iStim).features(iFeat).vals{startIdx})+str2num(expDat.stims(iStim).features(iFeat).vals{durationIdx}) > allDurations(iStim)
                              allDurations(iStim) =  str2num(expDat.stims(iStim).features(iFeat).vals{startIdx})+str2num(expDat.stims(iStim).features(iFeat).vals{durationIdx});
                          end
                        end
                    end
                end
                % make empty variable for param names
                for iFeat = 1:max_feat
                    all_param_names{iFeat} = {};
                end
                % for each feature number discover all unique parameter names
                for iStim = 1:length(expDat.stims)
                    for iFeat = 1:length(expDat.stims(iStim).features)
                        all_param_names{iFeat} = cat(2,all_param_names{iFeat},expDat.stims(iStim).features(iFeat).params,'type');
                    end
                end
                % find unique param names for each feature
                for iFeat = 1:max_feat
                    all_param_names{iFeat} = unique(all_param_names{iFeat});
                end
                % build a table for csv output for each feature
                output_table = [];
                for iStim = 1:length(expDat.stims)
                    for iFeat = 1:max_feat
                        % check stim has enough features to probe iFeat
                        if length(expDat.stims(iStim).features)>=iFeat
                            for iParam = 1:length(all_param_names{iFeat})
                                % find if the param name exists in the stim/feature
                                [Lia,Locb] = ismember(all_param_names{iFeat}{iParam},expDat.stims(iStim).features(iFeat).params);
                                if Lia
                                    output_table{iFeat}(iStim,iParam) = {expDat.stims(iStim).features(iFeat).vals{Locb}};
                                else
                                    if strcmp(all_param_names{iFeat}{iParam},'type')
                                        output_table{iFeat}(iStim,iParam) = {expDat.stims(iStim).features(iFeat).name};
                                    else
                                        output_table{iFeat}(iStim,iParam) = {'NaN'};
                                    end
                                end
                            end
                        else
                            % pad with nans
                            output_table{iFeat}(iStim,1:length(all_param_names{iFeat})) = {'NaN'};
                        end
                    end
                end
                % combine the feature tables into 1 table
                combined_output_table = [];
                for iFeat = 1:max_feat
                    combined_output_table = [combined_output_table,output_table{iFeat}];
                end
                % make a table where each row is a trial
                combined_output_table_all_trials = [];
                for iStim = 1:length(expDat.stimOrder)
                    combined_output_table_all_trials = cat(1,combined_output_table_all_trials,combined_output_table(expDat.stimOrder(iStim),:));
                end
                % rename params to append feat number in headers
                param_header = [];
                for iFeat = 1:max_feat
                    all_feat_headers = [];
                    for iParam = 1:length(all_param_names{iFeat})
                        all_feat_headers{iParam} = ['F',num2str(iFeat),'_',all_param_names{iFeat}{iParam}];
                    end
                    param_header = [param_header,all_feat_headers];
                end
                % add column for stim max length
                param_table = cell2table(cat(2,cellstr(num2str(allDurations)),combined_output_table), 'VariableNames',cat(2,{'duration'},param_header));
                % next 4 lines is to deal with case where there is only 1 stim
                % conditions which causes all_durs to be oriented wrong
                all_durs = allDurations(expDat.stimOrder);
                if size(all_durs,2)>size(all_durs,1)
                    all_durs = all_durs';
                end
                all_trials_table = cell2table(cat(2,cellstr(num2str(expDat.stimOrder')),cellstr(num2str(all_durs)),combined_output_table_all_trials),'VariableNames',cat(2,{'stim'},{'duration'},param_header));
                % save as csv
                save_path = FileList(iFile).folder;
                expID = expDat.expID;
                writematrix(expDat.stimOrder',fullfile(save_path,[expID,'_stim_order.csv']));
                writetable(param_table,fullfile(save_path,[expID,'_stim.csv']));
                writetable(all_trials_table,fullfile(save_path,[expID,'_all_trials.csv']));
                disp(['Finished ',expDat.expID]);
            end
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            global bvData;
            bvData = [];
            bvData.expData.stims = [];
            try
                config = app.getRepoConfig();
            catch err
                repoRoot = app.getRepoRoot();
                machineName = app.getMachineName();
                missingIni = fullfile(repoRoot,'configs',machineName,'bvGUI.ini');
                app.debugMessage(['Repo root: ', repoRoot]);
                app.debugMessage(['Machine config key: ', machineName]);
                app.debugMessage(['Config error: ', err.message]);
                app.debugMessage(['Expected config file: ', missingIni]);
                return;
            end
            app.addRepoSupportPaths(config.repoRoot);
            app.debugMessage(['Repo root: ', config.repoRoot]);
            app.debugMessage(['Machine config key: ', config.machineName]);
            app.debugMessage(['Config file: ', config.iniPath]);
            % load settings
            bvData.settings = struct();
            bvData.settings.bvServer = config.bvServer;
            app.BVServerEditField.Value = bvData.settings.bvServer;
            % populate new feature list box with feature files
            % find feature files
            featFilePath = config.featuresDir;
            featFiles = dir(fullfile(featFilePath,'*.mat'));
            featFiles = {featFiles.name};
            app.NewFeatureListBox.Items = {};
            for iFile = 1:length(featFiles)
                load(fullfile(featFilePath,featFiles{iFile}))
                bvData.featTypes(iFile) = featureType;
                % add feature file names to list box
                [~,featName] = fileparts(featFiles{iFile});
                app.NewFeatureListBox.Items = [app.NewFeatureListBox.Items,{featName}];
                bvData.featNames(iFile) = {featName};
            end
            app.NewFeatureListBox.ItemsData = 1:length(featFiles);

            % populate list of DAQ devices that can be started
            daqList = dir(fullfile(config.daqStartDir,'*.m'));
            daqList = {daqList.name}';
            for iDaq = 1:length(daqList)
                daqList{iDaq} = daqList{iDaq}(1:end-8);
            end
            x=table();
            x.daqs = daqList;
            x.enabled = ones([length(x.daqs),1]);
            app.UITable_DAQs.Data = x;
            app.UITable_DAQs.RowName = [];
            app.UITable_DAQs.ColumnName = {'DAQ','Enabled'};
            bvData.plotAreas = figure('Name','Online analysis','NumberTitle','off','MenuBar', 'None');
            bvData.plotAreas.Position=[app.UIFigure.Position(1)+app.UIFigure.Position(3)+30,app.UIFigure.Position(2),500,app.UIFigure.Position(4)];
            bvData.UIFigure = app.UIFigure;
            bvData.stim_filename = '';
        end

        % Value changed function: FeatureListBox
        function FeatureListBoxValueChanged(app, event)
            value = app.FeatureListBox.Value;
            app.FeatureListBox.Tag = num2str(value);
            app.bvUpdateGUI();
            % app.UITable.
        end

        % Button pushed function: NewButton
        function NewButtonPushed(app, event)
            % create empty experiment structure
            global bvData;
            bvData.expData = [];
            bvData.expData.stims = [];
            app.StimulusListBox.Tag = '';
            app.FeatureListBox.Tag = '';
            app.FeatureListBox.Value = {};
            app.bvUpdateGUI();
        end

        % Button pushed function: ButtonAddStim
        function ButtonAddStimPushed(app, event)
            global bvData;
            bvData.expData.stims(end+1).features = [];
            bvData.expData.stims(end).reps = str2num(app.RepsEditField.Value);
            app.StimulusListBox.Tag = num2str(length(bvData.expData.stims));
            app.FeatureListBox.Tag = '';
            app.bvUpdateGUI;
        end

        % Button pushed function: ButtonAddFeature
        function ButtonAddFeaturePushed(app, event)
            global bvData;
            % determine current selected new feature to add
            currentNewFeat = str2num(app.NewFeatureListBox.Tag);
            currentStim = str2num(app.StimulusListBox.Tag);
            if ~isempty(currentNewFeat) && ~isempty(currentStim)
                newFeatureID = length(bvData.expData.stims(currentStim).features)+1;
                bvData.expData.stims(currentStim).features(newFeatureID).vals = bvData.featTypes(currentNewFeat).vals;
                bvData.expData.stims(currentStim).features(newFeatureID).params = bvData.featTypes(currentNewFeat).params;
                bvData.expData.stims(currentStim).features(newFeatureID).name = bvData.featNames(currentNewFeat);
                app.FeatureListBox.Tag = num2str(newFeatureID);
                app.bvUpdateGUI;
            end
        end

        % Value changed function: StimulusListBox
        function StimulusListBoxValueChanged(app, event)
            value = app.StimulusListBox.Value;
            [~,value] = ismember(value,app.StimulusListBox.Items);
            app.StimulusListBox.Tag = num2str(value);
            app.FeatureListBox.Tag = '';
            app.bvUpdateGUI;
        end

        % Value changed function: NewFeatureListBox
        function NewFeatureListBoxValueChanged(app, event)
            value = app.NewFeatureListBox.Value;
            app.NewFeatureListBox.Tag = num2str(value);
        end

        % Button pushed function: ButtonRemoveStim
        function ButtonRemoveStimPushed(app, event)
            global bvData;
            stimsToPreserve = setdiff(1:length(bvData.expData.stims),str2num(app.StimulusListBox.Tag));
            bvData.expData.stims = bvData.expData.stims(stimsToPreserve);
            app.StimulusListBox.Tag = '';
            app.StimulusListBox.Value = {};
            app.bvUpdateGUI;
        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            global bvData;
            indices = event.Indices;
            newData = event.NewData;
            currentStim = str2num(app.StimulusListBox.Tag);
            currentFeat = str2num(app.FeatureListBox.Tag);
            paramVals = app.UITable.Data.Var1;
            bvData.expData.stims(currentStim).features(currentFeat).vals = paramVals';
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            global bvData;
            config = app.getRepoConfig();
            expData = bvData.expData;
            expData.vars = app.VariablesEditField.Value;
            expData.iti = app.ITIEditField.Value;
            expData.seqreps = app.SequenceRepeatsEditField.Value;
            uisave({'expData'},config.stimsetsDir);
            figure(app.UIFigure);
        end

        % Button pushed function: LoadButton
        function LoadButtonPushed(app, event)
            global bvData;
            config = app.getRepoConfig();
            [file,path] = uigetfile(config.stimsetsDir);
            if isempty(file)
                return
            end
            load(fullfile(path,file));
            figure(app.UIFigure);
            app.UIFigure.Visible = 'on';
            if exist('expData')
                [~,bvData.stim_filename,~] = fileparts(file);
                bvData.expData = expData;
                app.StimulusListBox.Tag = '';
                app.FeatureListBox.Tag = '';
                app.FeatureListBox.Value = {};
                app.bvUpdateGUI;
            end
        end

        % Button pushed function: RunButton
        function RunButtonPushed(app, event)
            % check if we want to run or abort depending on button label
            % value
            switch app.RunButton.Text
                case 'Abort'
                    % then we are already running so set abort flag to true
                    app.abortFlag = 1;
                    app.RunButton.Text = 'Aborting...';
                    app.RunButton.Enable = "off";
                    debugMessage(app,'Aborting...');
                    return;
                case 'Aborting'
                    % don't need to do anything more
                    return;
                case 'Run'
                    % allow run to initiate
                    app.RunButton.Text = 'Abort';
                    app.RunButton.BackgroundColor = 'r';
            end

            global bvData;
            config = app.getRepoConfig();
            remotePath = config.remoteSaveRoot;
            % get a new unique animal ID
            expID = newExpID(app.AnimalIDEditField.Value);
            animalID = expID(15:end);
            bvSavePath = fullfile(config.localSaveRoot,animalID,expID);
            bvSavePath = strrep(bvSavePath,'\','/');
            savePath = remotePath;
            expSavePath = fullfile(savePath,animalID,expID);
            if ~exist(expSavePath,'dir')
                mkdir(expSavePath);
            end
            app.debugMessage('==========================');
            app.debugMessage(['Starting new experiment - ',expID]);
            % request BV computer to make exp dir
            % bv_address = string(bv_config.bvGUIsettings.bvServer);
            bv_address = app.BVServerEditField.Value;
            bv_udp_port = 64645;
            msg = "mkdir" + " " + bvSavePath;
            response = app.send_udp_command(bv_address, bv_udp_port, msg);
            if response == 1
                app.debugMessage('Make data folder command succeeded.');
            elseif response == -1
                app.debugMessage('Make data folder command  failed.');
                app.restoreRunButton();
                return;
            else
                app.debugMessage('Unexpected server response while creating data folder.');
                app.restoreRunButton();
                return;
            end         
            % clear the log box
            % prompt for basic experiment comment
            inp_text = inputdlg('Experiment type?','',1,{bvData.stim_filename});
            app.ExperimentlogTextArea.Value = {datestr(datetime),expID,inp_text{1},''};

            completeStimSeq = app.buildCompleteStimSeq();
            % make sure bonvision server is in idle state 158.109.215.49
            try
              u = OscTcp(bv_address, 4002);
              rig = Rig(u);
              % send dummy stim to initialise the sync square
              % can be removed if Goncalo fixes first trial bug
              % =========
%               try
%                 rmdir('\\AR-LAB-NAS1\DataServer\Remote_Repository\TEST\2025-01-01_01_TEST', 's');
%               catch 
%               end
%               dummy_root = '\\AR-LAB-NAS1\DataServer\Remote_Repository';
%               dummy_data = '\\AR-LAB-NAS1\DataServer\Remote_Repository\TEST\2025-01-01_01_TEST';
%               mkdir(dummy_data)
%               rig.dataset(dummy_root);
%               rig.experiment('2025-01-01_01_TEST')
%               g = [];
%               g.contrast = 1;
%               g.duration = 0.1;
%               g.y = -100;
%               % add grating to rig
%               rig.gratings(g);
%               rig.start();
%               datagram = [];
%               while(isempty(datagram))
%                 datagram = u.receive();
%                 drawnow limitrate;
%               end
              % ======

              % ensure rig is cleared
              rig = Rig(u);
              rig.clear();
              rig.experiment('');
              app.pauseWithEvents(1);
            catch
              % bonvision server probably not in use
              app.debugMessage('Problem clearing Bonvision')
              app.restoreRunButton();
              debugMessage(app,['Experiment complete with error - ',expID]);
              app.debugMessage('Check Bonvision server is running')
              return;
            end

            % convert all variable stim params to their values defined in the gui
            allVars = app.VariablesEditField.Value;
            allVars = strsplit(allVars,';');
            varStruc = [];
            for iVar = 1:length(allVars)
                allVars{iVar} = strrep(allVars{iVar},' ','');
                if ~isempty(allVars{iVar})
                    eval(['varStruc.',allVars{iVar}]);
                end
            end

            expDataEval = bvData.expData.stims;
            for iStim = 1:length(expDataEval)
                for iFeature = 1:length(expDataEval(iStim).features)
                    featureParamsCell = expDataEval(iStim).features(iFeature).params;
                    featureParams = cell2struct(expDataEval(iStim).features(iFeature).vals',expDataEval(iStim).features(iFeature).params);
                    for iParam = 1:length(featureParamsCell)
                        if isfield(varStruc,featureParams.(featureParamsCell{iParam}))
                            variableVal = varStruc.(featureParams.(featureParamsCell{iParam}));
                            if ~isstring(variableVal)
                                variableVal = num2str(variableVal);
                            end
                            expDataEval(iStim).features(iFeature).vals{iParam} = variableVal;
                        end
                    end
                end
            end

            [opto2pPrep, opto2pErr] = app.collectOpto2pPrepData(expDataEval, completeStimSeq);
            if ~isempty(opto2pErr)
                app.debugMessage(['Opto_2p prep error: ', opto2pErr]);
                app.restoreRunButton();
                return;
            end

            if opto2pPrep.enabled
                [success, opto2pErr] = app.runOpto2pPrep(config, expID, opto2pPrep);
                if ~success
                    app.debugMessage(opto2pErr);
                    app.restoreRunButton();
                    return;
                end
            end
            % initiate any DAQ devices which have been selected
            daqList = dir(fullfile(config.daqStartDir,'*.m'));
            daqList = {daqList.name}';
            % do checking to make sure all start and stop daqs match up
            % ... to implement

            % pull data from table of whether DAQ devices are enabled
            daqEnabled = app.UITable_DAQs.Data.enabled;

            startDir = cd;
            cd(config.daqStartDir);
            app.debugMessage('Attempting to start all DAQs');
            for iDaq = 1:length(daqList)
                if daqEnabled(iDaq)
                    app.debugMessage(['Running ',daqList{iDaq}]);
                    [success,resp_msg] = eval([daqList{iDaq}(1:end-2),'(expID)']);
                    if ~success
                        err_msg = ['Error starting ',daqList{iDaq}];
                        app.debugMessage('Error... attempting to stop all DAQs');
                        % attempt to stop all of the daqs in reverse
                        daqList = dir(fullfile(config.daqStopDir,'*.m'));
                        daqList = {daqList.name}';
                        cd(config.daqStopDir);
                        for iDaqStop = iDaq-1:-1:1
                            if daqEnabled(iDaqStop)
                                app.debugMessage(['Stopping ',daqList{iDaqStop}]);
                                [success,resp_msg] = eval(daqList{iDaqStop}(1:end-2));
                                if ~success
                                    app.debugMessage(['Error stopping ',daqList{iDaqStop}]);
                                    err_msg = [err_msg,'; ', ['Error stopping ',daqList{iDaqStop}]];
                                else
                                    % app.debugMessage('OK');
                                end
                            end
                        end
                        cd(startDir);
                        % restore GUI elements so ready to start again
                        app.restoreRunButton();
                        debugMessage(app,'Experiment complete (with errors!)');
                        inp_text = inputdlg('Final comments?');
                        if strcmp(app.ExperimentlogTextArea.Value{end},'')
                            app.ExperimentlogTextArea.Value{end} = inp_text{1};
                        else
                            app.ExperimentlogTextArea.Value{end+1} = inp_text{1};
                        end
                        app.ExperimentlogTextArea.Value{end+1} = datestr(datetime);
                        % save log file
                        formatSpec= '%s\r\n';
                        value = app.ExperimentlogTextArea.Value;  % Value entered in textArea
                        % log to experiment log file
                        f = fopen(fullfile(expSavePath,'exp_log.txt'),'w');
                        for i =1:length(value)
                            fprintf(f,formatSpec,value{i});
                        end
                        % append error msg to log
                        fprintf(f,formatSpec,err_msg);
                        fclose(f);

                        % log to animal log file IF final comment was not x
                        if ~strcmp(inp_text,'x')
                            f2 = fopen(fullfile(savePath,animalID,'animal_log.txt'),'a');
                            for i =1:length(value)
                                fprintf(f2,formatSpec,value{i});
                            end
                            % append error msg to log
                            fprintf(f2,formatSpec,err_msg);
                            fprintf(f2,formatSpec,'======================');
                            fprintf(f2,formatSpec,'======================');
                            fprintf(f2,formatSpec,'======================');
                            fclose(f2);
                        end

                        return;
                    else
                        % app.debugMessage('OK');
                    end
                end
            end

            % make list of ITIs
            itiText = app.ITIEditField.Value;
            if length(eval(itiText))==1
                % fixed iti
                itiSeq = ones(1,length(completeStimSeq))*eval(itiText);
            else
                % random iti in range
                itiMax = max(eval(itiText));
                itiMin = min(eval(itiText));
                itiSeq = linspace(itiMin,itiMax,length(completeStimSeq));
                itiSeq = itiSeq(randperm(length(itiSeq)));
            end

            preBlankTime = str2num(app.PreBlankText.Value);
            startTime = tic;
            if preBlankTime > 0
                app.debugMessage(['Showing blank for ',num2str(preBlankTime),' secs']);
            end
            while (toc(startTime)<preBlankTime) && app.abortFlag == 0
                % wait
                drawnow limitrate;
            end

            % Pause for 3 secs to allow a check that Bonvision timing pulses are
            % correct (i.e. starting at zero)
            pauseTime = 3;
            startTime = tic;
            while (toc(startTime)<pauseTime) && app.abortFlag == 0
                % wait
                drawnow limitrate;
            end

            if ~isempty(completeStimSeq)
                % establish udp connection
                %global u;
                metadata = expID;
                u = OscTcp(bv_address, 4002);

                % fopen(u);
                rig = Rig(u);
                rig.dataset(strrep(config.localSaveRoot,'\','/'));
                debugMessage(app,'New experiment trigger sent to bonsai');
                % Pause for 10 secs to check what trial ID means in frames file
                % this can probably be removed later:
                pauseTime = 2;
                startTime = tic;
                while (toc(startTime)<pauseTime) && app.abortFlag == 0
                    % wait
                    drawnow limitrate;
                end
%                 % preload all video/image files
%                 all_resources = [];
%                 for iStim = 1:length(expDataEval)
%                     for iFeat = 1:length(expDataEval(iStim).features)
%                         % check if feature is a movie and if so add it as a resource
%                         if strcmp(expDataEval(iStim).features(iFeat).name{1},'movie')
%                             all_resources{end+1} = expDataEval(iStim).features(iFeat).vals{1};
%                         end
%                     end
%                 end
%                 all_resources = unique(all_resources);
%                 for iRes = 1:length(all_resources)
%                     rig.resource(all_resources{iRes});
%                 end
%                 rig.preload();

                % start loop of going through each trial
                % rig.experiment(metadata);
                for iTrial = 1:length(completeStimSeq)
                    drawnow
                    iStim = completeStimSeq(iTrial);
                    [trialOpto2pData, trialOpto2pErr] = app.collectTrialOpto2pData(expDataEval, iStim);
                    if ~isempty(trialOpto2pErr)
                        app.requestRunAbort(['Opto_2p trigger error: ', trialOpto2pErr]);
                        break;
                    end

                    if trialOpto2pData.enabled
                        [success, trialOpto2pErr] = app.triggerOpto2pForTrial(config, expID, trialOpto2pData);
                        if ~success
                            app.requestRunAbort(trialOpto2pErr);
                            break;
                        end
                    end

                    rig.clear();
                    rig.experiment(metadata);
                    debugMessage(app,['Starting trial ',num2str(iTrial),' of ',num2str(length(completeStimSeq))]);
                    go_nogo_trial.enable = false;
                    vr.enable = false;
                    vr.command = '';
%                     % add synch square high
%                     g = [];
%                     g.angle = 0;
%                     g.width = 10;
%                     g.height = 10;
%                     g.size = 10;
%                     g.x = 0;
%                     g.y = -30;
%                     g.contrast = 1;
%                     g.opacity = 1;
%                     g.phase = 0;
%                     g.freq = 0.01;
%                     g.speed = 0;
%                     g.dcycle = 1;
%                     g.onset = 0;
%                     g.duration = 0.5;
%                     % add grating to rig
%                     rig.gratings(g);   
%                     % add synch square low
%                     g = [];
%                     g.angle = 0;
%                     g.width = 10;
%                     g.height = 10;
%                     g.size = 10;
%                     g.x = 0;
%                     g.y = -30;
%                     g.contrast = 1;
%                     g.opacity = 1;
%                     g.phase = 0;
%                     g.freq = 0.01;
%                     g.speed = 0;
%                     g.dcycle = 0;
%                     g.onset = 0.5;
%                     g.duration = 0.5;
%                     % add grating to rig
%                     rig.gratings(g);   
                    
                    % generate commands to send stim to BV server
                    for iFeature = 1:length(expDataEval(completeStimSeq(iTrial)).features)
                        featureParamsCell = expDataEval(completeStimSeq(iTrial)).features(iFeature).params;
                        featureParams = cell2struct(expDataEval(completeStimSeq(iTrial)).features(iFeature).vals',expDataEval(completeStimSeq(iTrial)).features(iFeature).params);
                        % determine feature type and build stimulus
                        switch bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).name{1}
                            case 'grating'
                                g = [];
                                g.angle = str2num(featureParams.angle);
                                g.width = str2num(featureParams.width);
                                g.height = str2num(featureParams.height);
                                g.size = str2num(featureParams.width);
                                g.x = str2num(featureParams.x);
                                g.y = str2num(featureParams.y);
                                g.contrast = str2num(featureParams.contrast);
                                g.opacity = str2num(featureParams.opacity);
                                g.phase = str2num(featureParams.phase);
                                g.freq = str2num(featureParams.freq);
                                g.speed = str2num(featureParams.speed);
                                g.dcycle = str2num(featureParams.dcycle);
                                g.onset = str2num(featureParams.onset);
                                g.duration = str2num(featureParams.duration);
                                % add grating to rig
                                rig.gratings(g);
                            case 'go_nogo'
                                go_nogo_trial.enable = true;
                                go_nogo_trial.suppress_duration = str2num(featureParams.suppress_duration);
                                go_nogo_trial.response_start = str2num(featureParams.response_start);
                                go_nogo_trial.response_duration = str2num(featureParams.response_duration);
                                go_nogo_trial.lick_threshold = str2num(featureParams.lick_threshold);
                                go_nogo_trial.go = str2num(featureParams.go)==1;     
                            case 'vr'
                                vr.enable = true;
                                vr.command = featureParams.vr_command;
                                vr.name = featureParams.vr_name;
                            case 'movie'
                                v = [];
                                v.name  = featureParams.name;
                                % convert name to last folder of filename
                                spstr = strsplit(v.name,'\');
                                v.name = spstr{end};
                                v.angle = str2num(featureParams.angle);
                                v.width = str2num(featureParams.width);
                                v.height = str2num(featureParams.height);
                                v.x = str2num(featureParams.x);
                                v.y = str2num(featureParams.y);
                                v.loop = str2num(featureParams.loop);
                                v.speed = str2num(featureParams.speed);
                                v.onset = str2num(featureParams.onset);
                                v.duration = str2num(featureParams.duration);
                                % add movie to rig
                                rig.video(v);
                            case 'opto'
                                % arm the arduino laser controller
                                if strcmp(featureParams.enable,'1')
                                % suppress,start response window,response window duration,lick threshold
                                % load stimulation config to arduino
                                % rig.go(0, 0, 100, 0); % go trial
                                % Arduino UDP server settings
                                arduino_ip = '158.109.210.169';  % Replace with your Arduino's IP address
                                arduino_port = 8888;  % Replace with your Arduino's port number
                                
                                % Create a UDP object
                                u_opto = udp(arduino_ip, arduino_port);
                                % Set a timeout for the socket operations (e.g., 5 seconds)
                                u_opto.Timeout = 5;
                                
                                % Open the connection
                                fopen(u_opto);
                                
                                try
                                    % Message format: D,Fs,L,DC                                
                                    msg_str = featureParams.opto_command;
                                    message = uint8(msg_str);  % Encoding the message to bytes
                                
                                    % Send message
                                    fprintf('Sending message to Arduino UDP server: %s\n', msg_str);
                                    fwrite(u_opto, message, 'uint8');
                                
                                    % Attempt to receive a response within the timeout period
                                    try
                                        data = fread(u_opto, u_opto.BytesAvailable, 'uint8');
                                        fprintf('Received: %s\n', char(data)');
                                    catch
                                        % Handle the timeout case
                                        fprintf('Timed out waiting for a response\n');
                                    end
                                catch
                                    fprintf('An error occurred\n');
                                end
                                
                                % Clean up
                                fprintf('Closing socket\n');
                                fclose(u_opto);
                                delete(u_opto);
                                clear u_opto
                                end
                        end

                    end
                    % once all features are added
                    % preload resources
                    % preload all video/image files
                    all_resources = [];
                    for iFeat = 1:length(expDataEval(iStim).features)
                      % check if feature is a movie and if so add it as a resource
                      if strcmp(expDataEval(iStim).features(iFeat).name{1},'movie')
                        all_resources{end+1} = expDataEval(iStim).features(iFeat).vals{1};
                        debugMessage(app,['Added resource: ',expDataEval(iStim).features(iFeat).vals{1}]);
                      end
                    end
            
                    all_resources = unique(all_resources);
                    for iRes = 1:length(all_resources)
                      rig.resource(all_resources{iRes});
                    end
                    
                    if ~isempty(all_resources)
                        debugMessage(app,'Preloading trail resources');
                        drawnow
                        tic
                        rig.preload();
                        load_time = toc;
                        debugMessage(app,['Preload command returned ',num2str(load_time),' secs']);
                        debugMessage(app,['Pausing ', app.PauseafterpreloadEditField.Value, ' secs more to ensure preload complete']);
                        drawnow
                        pauseTime = str2double(app.PauseafterpreloadEditField.Value);
                        app.pauseWithEvents(pauseTime);
                    else
                        rig.preload();
                        app.pauseWithEvents(0.5);
                    end

                    % start trial
                    % check if it has a go/nogo feature
                    if go_nogo_trial.enable
                        if go_nogo_trial.go
                            % go trial
                            debugMessage(app,'go/nogo GO trial start requested');
                            rig.pulseValve()
                            rig.success()
                            % start trial (replaces rig.start())
                            rig.go(go_nogo_trial.suppress_duration, ...
                                   go_nogo_trial.response_start, ...
                                   go_nogo_trial.response_duration, ...
                                   go_nogo_trial.lick_threshold)
                        else
                            % nogo trial
                            debugMessage(app,'go/nogo NOGO trial start requested');
                            rig.success()
                            % start trial (replaces rig.start())
                            rig.nogo(go_nogo_trial.suppress_duration, ...
                                   go_nogo_trial.response_start, ...
                                   go_nogo_trial.response_duration, ...
                                   go_nogo_trial.lick_threshold)
                        end
                    elseif vr.enable
                        % vr trial
                        debugMessage(app,'VR trial start requested');
                        eval(featureParams.vr_command);
                        debugMessage(app,['Starting VR: ',vr.name]);
                    else
                        % passive trial
                        debugMessage(app,'Passive trial start requested');
                        rig.start();
                    end
                                                    

                    %debugMessage(app,['before go']);
                    
                    % rig.go(1, 0, 0, 0);
                    %rig.go(100, 100, 100, 0);
                    %rig.go(1000, 500, 1000, 0);
                    %debugMessage(app,['after go']);
                    % start a trial using the go command to initialise optogenetic stimulation
                    % this should generate a trial start trigger
                    %rig.go(0, 0, 0, 0);
                    % wait for end of trial
                    %oscrecv(u
                    datagram = [];
                    while(isempty(datagram))
                        datagram = u.receive();
                        drawnow limitrate;
                    end
                    % Initialize an empty string
                    concatenatedString = '';
                    % Loop through each cell in the outer array
                    for i = 1:length(datagram)
                        % Access the string in the inner cell and concatenate
                        concatenatedString = [concatenatedString, datagram{i},' '];
                    end
                    debugMessage(app,concatenatedString);
                    %pause(0.5);
                    % check if abort has been pressed
                    if app.abortFlag
                        break;
                    end
                    % wait for inter trial period
                    pauseTime = itiSeq(iTrial);
                    startTime = tic;
                    while (toc(startTime)<pauseTime) && app.abortFlag == 0
                        % wait
                        drawnow limitrate;
                    end
                end
                
                % Stop bonvision ouputting timing pulses
                rig.clear();
                rig.experiment('');
               
                
                % 10 second post experiment delay
                app.debugMessage('Post-experiment 10 second pause...');
                pauseTime = 10;
                startTime = tic;
                while (toc(startTime)<pauseTime)
                    % wait
                    drawnow limitrate;
                end
                
                % request BV computer to copy data to server
                bv_udp_server = bv_address;
                bv_udp_port = 64645;
                remote_path_python = strcat(remotePath,'\',animalID,'\',expID);
                remote_path_python = strrep(remote_path_python,'\','/');          
                msg = "sync" + " " + bvSavePath + " "  + remote_path_python;
                
                response = app.send_udp_command(bv_udp_server, bv_udp_port, msg);
                if response == 1
                    app.debugMessage('sync Command succeeded.');
                elseif response == -1
                    app.debugMessage('sync Command failed.');
                    return;
                else
                    app.debugMessage(['Unexpected server response: ', responseStr]);
                    return;
                end

                %u.delete;

                % save experiment data
                expDat.expID = expID;
                expDat.stimOrder = completeStimSeq(1:iTrial);
                expDat.stims = expDataEval;
                expDat.itiSeq = itiSeq(1:iTrial);
                save(fullfile(expSavePath,[expID,'_stim.mat']),'expDat');
                % save in format for python
                saveForPython(app,expDat,expID,expSavePath);
                %
            end

            % Stop all DAQs
            app.debugMessage('Attempting to stop all DAQs');
            % attempt to stop all of the daqs in reverse
            daqList = dir(fullfile(config.daqStopDir,'*.m'));
            daqList = {daqList.name}';
            cd(config.daqStopDir);
            for iDaqStop = length(daqList):-1:1
                err_msg = '';
                if daqEnabled(iDaqStop)
                    app.debugMessage(['Stopping ',daqList{iDaqStop}]);
                    [success,resp_msg] = eval(daqList{iDaqStop}(1:end-2));
                    if ~success
                        app.debugMessage(['Error stopping ',daqList{iDaqStop}]);
                        err_msg = [err_msg,'; ', ['Error stopping ',daqList{iDaqStop}]];
                    else
                        % app.debugMessage('OK');
                    end
                end
            end

            cd(startDir);

            [success, abortPhotoStimErr] = app.abortOpto2p(config);
            if ~success
                app.debugMessage(abortPhotoStimErr);
            end

            debugMessage(app,['Experiment complete - ',expID]);
            inp_text = inputdlg('Final comments?');
            if strcmp(app.ExperimentlogTextArea.Value{end},'')
                app.ExperimentlogTextArea.Value{end} = inp_text{1};
            else
                app.ExperimentlogTextArea.Value{end+1} = inp_text{1};
            end
            app.ExperimentlogTextArea.Value{end+1} = datestr(datetime);
            % save log file
            formatSpec= '%s\r\n';
            value = app.ExperimentlogTextArea.Value;  % Value entered in textArea
            % log to experiment log file
            f = fopen(fullfile(expSavePath,'exp_log.txt'),'w');
            for i =1:length(value)
                fprintf(f,formatSpec,value{i});
            end
            % append error msg to log
            fprintf(f,formatSpec,err_msg);
            fclose(f);

            % log to animal log file IF final comment was not x
            if ~strcmp(inp_text,'x')
                f2 = fopen(fullfile(savePath,animalID,'animal_log.txt'),'a');
                for i =1:length(value)
                    fprintf(f2,formatSpec,value{i});
                end
                % append error msg to log
                fprintf(f2,formatSpec,err_msg);
                fprintf(f2,formatSpec,'======================');
                fprintf(f2,formatSpec,'======================');
                fprintf(f2,formatSpec,'======================');
                fclose(f2);
            end

            % hash all data created on server
            debugMessage(app,['Hashing ',expID]);
            drawnow
            if isempty(config.pythonExe) || isempty(config.hashScript)
                debugMessage(app,'Hashing skipped: python_exe or hash_script is not configured.');
            else
                command = ['"', config.pythonExe, '" "', config.hashScript, '" "', expSavePath, '" "nas" "False"'];
                return_code = dos(command);
                if return_code == 0
                    debugMessage(app,'Hashing complete!');
                    %dos(['explorer.exe ' expSavePath])
                else
                    debugMessage(app,'Hashing Error! Ensure the configured python_exe and hash_script are correct.');
                end
            end

            % put run button back to default state
            app.RunButton.Enable = "on";
            app.RunButton.Text = 'Run';
            app.RunButton.BackgroundColor = 'g';
            app.abortFlag = 0;
        end

        % Button pushed function: SavesettingsButton
        function SavesettingsButtonPushed(app, event)
            global bvData;
            config = app.getRepoConfig();
            bvData.settings.bvServer = app.BVServerEditField.Value;
            iniData = config.iniData;
            iniData = app.setIniValue(iniData,'settings','bv_server',app.BVServerEditField.Value);
            app.writeIniFile(config.iniPath, iniData);
        end

        % Value changing function: RepsEditField
        function RepsEditFieldValueChanging(app, event)
            global bvData;
            changingValue = event.Value;
            % check there is a selected stimulus
            if ~isempty(app.StimulusListBox.Tag)
                % validate value (check it is a number)
                if ~isnan(str2double(changingValue))
                    bvData.expData.stims(str2num(app.StimulusListBox.Tag)).reps = str2num(changingValue);
                end
            end
        end

        % Button pushed function: ButtonRemoveFeature
        function ButtonRemoveFeaturePushed(app, event)
            global bvData;
            currentStim = str2num(app.StimulusListBox.Tag);
            currentFeature = str2num(app.FeatureListBox.Tag);
            featsToPreserve = setdiff(1:length(bvData.expData.stims(currentStim).features),currentFeature);
            bvData.expData.stims(currentStim).features = bvData.expData.stims(currentStim).features(featsToPreserve);
            app.FeatureListBox.Tag = '';
            app.FeatureListBox.Value = {};
            app.bvUpdateGUI;
        end

        % Button pushed function: ResetButton
        function ResetButtonPushed(app, event)
            % put run button back to default state
            app.RunButton.Enable = "on";
            app.RunButton.Text = 'Run';
            app.RunButton.BackgroundColor = 'g';
            app.abortFlag = 0;

            app.TestStimBtn.Text = 'Test';
            app.TestStimBtn.BackgroundColor = 'g';
        end

        % Button pushed function: Rewardv1Button
        function Rewardv1ButtonPushed(app, event)
            %subplot(app.UIAxes,)
            %             app.FeedbackPanel.AutoResizeChildren = 'off';
            %             ax = subplot(1,2,1,'Parent',app.FeedbackPanel);
        end

        % Button pushed function: BuildSetButton
        function BuildSetButtonPushed(app, event)
            % takes current stimulus and varies it over a range
            global bvData;
            paramName = [];
            paramVals = [];
            baseStim = inputdlg('What is the base stimulus number?');
            baseStim = str2num(baseStim{1});
            if isempty(baseStim);return;end
            if or(baseStim > length(bvData.expData.stims),baseStim < 1)
                msgbox(['Base stimulus doesn''t exist - there are only ',num2str(length(bvData.expData.stims)),' stimuli']);
                return;
            end
            featToVary = inputdlg('Which features do you want to vary the parameters of?');
            featToVary = eval(featToVary{1});
            if isempty(featToVary);return;end
            if or(max(featToVary)>length(bvData.expData.stims(baseStim).features),min(featToVary)<1)
                msgbox(['At least one feature of stimulus doesn''t exist - there are only ',num2str(length(bvData.expData.stims(baseStim).features)),' features']);
                return;
            end
            resp = questdlg('Replace base stimulus?');

            if strcmp(resp,'Yes')
                overwriteBase = true;
            else
                overwriteBase = false;
            end

            while true
                resp1 = inputdlg('Please enter name of parameter to vary');
                resp2 = inputdlg('Enter desired values (can be in format x,y,z or x:inc:z)');
                if or(isempty(resp1{1}),isempty(resp2{1}))
                    uiwait(msgbox('Param name / vals invalid','Success','modal'));
                end
                try
                    paramVals{end+1} = eval(resp2{1});
                catch
                    uiwait(msgbox('Param values syntax invalid','Success','modal'));
                end
                paramName{end+1} = resp1{1};
                resp = questdlg('Add another parameter?');
                switch resp
                    case 'No'
                        break;
                    case 'Cancel'
                        msgbox('Stimulus generation cancelled');
                        return;
                end
            end

            expData = bvData.expData;
            baseStimParams = bvData.expData.stims(baseStim);

            % build param table
            paramTable = [];
            for iParam = 1:length(paramName)
                if isempty(paramTable)
                    paramTable = paramVals{iParam}';
                else
                    tempTable = [];
                    numValsInParam = length(paramVals{iParam});
                    for iRow = 1:size(paramTable)
                        % reproduce each row with all vals of the new param
                        tempBlock = [repmat(paramTable(iRow,:),[numValsInParam,1]),paramVals{iParam}'];
                        tempTable = [tempTable;tempBlock];
                    end
                    paramTable = tempTable;
                end

            end

            newStimSet = bvData.expData.stims;

            for iStim = 1:size(paramTable,1)
              newStim = baseStimParams;
              for iParam = 1:size(paramTable,2)
                for iFeature = 1:length(featToVary)
                  currentFeature = featToVary(iFeature);
                  paramIndex = find(strcmp(newStim.features(currentFeature).params, paramName{iParam}));
                  if isempty(paramIndex)
                    msgbox(['A parameter wasn''t found (',paramName{iParam},')']);
                    return;
                  end
                  newStim.features(currentFeature).vals(paramIndex) = {num2str(paramTable(iStim,iParam))};
                end
              end
              newStimSet(end+1) = newStim;
            end

            % remove base stim from set if requested
            if overwriteBase
                newStimSet = newStimSet(setdiff(1:length(newStimSet),baseStim));
            end

            bvData.expData.stims = newStimSet;
            app.bvUpdateGUI;
        end

        % Button pushed function: TestStimBtn
        function TestStimBtnButtonPushed(app, event)
            % check if we want to run or abort depending on button label
            % value
            switch app.TestStimBtn.Text
                case 'Running'
                    % don't need to do anything more
                    % return;
                case 'Test'
                    % allow run to initiate
                    app.TestStimBtn.Text = 'Running';
                    app.TestStimBtn.BackgroundColor = 'r';
            end

            global bvData;
            config = app.getRepoConfig();
            remotePath = config.remoteSaveRoot;
            % get a new unique animal ID
            expID = newExpID('STIMTEST');
            animalID = expID(15:end);
            savePath = remotePath;

            app.debugMessage('==========================');

            % make sure bonvision server is in idle state
            % request BV computer to make exp dir
            bv_address = app.BVServerEditField.Value;
            try
                u = OscTcp(bv_address, 4002);
                rig = Rig(u);
                rig.clear();
                rig.experiment('');
            catch
                % bonvision server probably not in use
                app.debugMessage('Problem clearing Bonvision');
                app.TestStimBtn.Text = 'Test';
                app.TestStimBtn.BackgroundColor = 'g';
                return;
            end

            completeStimSeq = str2num(app.StimulusListBox.Value);

            if ~isempty(completeStimSeq)
                % establish udp connection
                %global u;
                metadata = expID;
                u = OscTcp(bv_address, 4002);

                % fopen(u);
                rig = Rig(u);
                rig.dataset(savePath);

                debugMessage(app,['Testing stimulus ', num2str(completeStimSeq)]);

                % pull stim variables out of the gui text box
                allVars = app.VariablesEditField.Value;
                % put each var into a struct
                allVars = strsplit(allVars,';');
                varStruc = [];
                for iVar = 1:length(allVars)
                    if ~isempty(allVars{iVar})
                        eval(['varStruc.',allVars{iVar}]);
                    end
                end

                % convert all variable stim params to their values defined in the gui:
                expDataEval = bvData.expData.stims;
                for iStim = 1:length(expDataEval)
                    for iFeature = 1:length(expDataEval(iStim).features)
                        featureParamsCell = expDataEval(iStim).features(iFeature).params;
                        featureParams = cell2struct(expDataEval(iStim).features(iFeature).vals',expDataEval(iStim).features(iFeature).params);
                        % cycle through feature params checking if they have been set
                        % using a variable
                        for iParam = 1:length(featureParamsCell)
                            if isfield(varStruc,featureParams.(featureParamsCell{iParam}))
                                % then it is a variable
                                variableVal = varStruc.(featureParams.(featureParamsCell{iParam}));
                                % convert to string if needed
                                if ~isstring(variableVal)
                                    variableVal = num2str(variableVal);
                                end
                                expDataEval(iStim).features(iFeature).vals{iParam} = variableVal;
                            end
                        end
                    end
                end

                % preload all video/image files
                all_resources = [];
                for iStim = 1:length(expDataEval)
                    for iFeat = 1:length(expDataEval(iStim).features)
                        % check if feature is a movie and if so add it as a resource
                        if strcmp(expDataEval(iStim).features(iFeat).name{1},'movie')
                            all_resources{end+1} = expDataEval(iStim).features(iFeat).vals{1};
                        end
                    end
                end
                all_resources = unique(all_resources);
                for iRes = 1:length(all_resources)
                    rig.resource(all_resources{iRes});
                end
                rig.preload();

                % start loop of going through each trial (only 1 here)
                for iTrial = 1:length(completeStimSeq)
                    drawnow
                    rig.experiment(metadata);
                    % generate commands to send stim to BV server
                    for iFeature = 1:length(bvData.expData.stims(completeStimSeq(iTrial)).features)
                        featureParamsCell = bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).params;
                        featureParams = cell2struct(bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).vals',bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).params);
                        % cycle through feature params checking if they have been set
                        % using a variable
                        for iParam = 1:length(featureParamsCell)
                            if isfield(varStruc,featureParams.(featureParamsCell{iParam}))
                                % then it is a variable
                                variableVal = varStruc.(featureParams.(featureParamsCell{iParam}));
                                % convert to string if needed
                                if ~isstring(variableVal)
                                    variableVal = num2str(variableVal);
                                end
                                featureParams.(featureParamsCell{iParam}) = variableVal;
                            end
                        end
                        % determine feature type and build stimulus
                        switch bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).name{1}
                            case 'grating'
                                g = [];
                                g.angle = str2num(featureParams.angle);
                                g.width = str2num(featureParams.width);
                                g.height = str2num(featureParams.height);
                                g.size = str2num(featureParams.width);
                                g.x = str2num(featureParams.x);
                                g.y = str2num(featureParams.y);
                                g.contrast = str2num(featureParams.contrast);
                                g.opacity = str2num(featureParams.opacity);
                                g.phase = str2num(featureParams.phase);
                                g.freq = str2num(featureParams.freq);
                                g.speed = str2num(featureParams.speed);
                                g.dcycle = str2num(featureParams.dcycle);
                                g.onset = str2num(featureParams.onset);
                                g.duration = str2num(featureParams.duration);
                                % add grating to rig
                                rig.gratings(g);
                            case 'movie'
                                v = [];
                                v.name  = featureParams.name;
                                % convert name to last folder of filename
                                spstr = strsplit(v.name,'\');
                                v.name = spstr{end};
                                v.angle = str2num(featureParams.angle);
                                v.width = str2num(featureParams.width);
                                v.height = str2num(featureParams.height);
                                v.x = str2num(featureParams.x);
                                v.y = str2num(featureParams.y);
                                v.loop = str2num(featureParams.loop);
                                v.speed = str2num(featureParams.speed);
                                v.onset = str2num(featureParams.onset);
                                v.duration = str2num(featureParams.duration);
                                % add movie to rig
                                rig.video(v);
                        end
                    end
                    % once all features are added
                    % start trial
                    rig.start();
                    % wait for end of trial
                    datagram = [];
                    while(isempty(datagram))
                        datagram = u.receive();
                        drawnow limitrate;
                    end
                end

                % Stop bonvision ouputting timing pulses
                rig.clear();
                rig.experiment('');
                %u.delete;
            end

            % put run button back to default state
            app.TestStimBtn.Text = 'Test';
            app.TestStimBtn.BackgroundColor = 'g';
            debugMessage(app,'Stimulus complete');
        end

        % Button pushed function: CopyButton
        function CopyButtonPushed(app, event)
            global bvData;
            currentStim = str2num(app.StimulusListBox.Tag);
            bvData.expData.stims(end+1).features = bvData.expData.stims(currentStim).features;
            bvData.expData.stims(end).reps = bvData.expData.stims(currentStim).reps;
            app.StimulusListBox.Tag = num2str(length(bvData.expData.stims));
            app.FeatureListBox.Tag = '';
            app.bvUpdateGUI;
        end

        % Button pushed function: FeatCopyButton
        function FeatCopyButtonPushed(app, event)
            global bvData;
            currentStim = str2num(app.StimulusListBox.Tag);
            currentFeature = str2num(app.FeatureListBox.Tag);
            bvData.expData.stims(currentStim).features(currentFeature+1)=bvData.expData.stims(currentStim).features(currentFeature);
            app.FeatureListBox.Tag = '';
            app.FeatureListBox.Value = {};
            app.bvUpdateGUI;
        end

        % Value changed function: VariablesEditField
        function VariablesEditFieldValueChanged(app, event)
            value = app.VariablesEditField.Value;
        end

        % Value changing function: VariablesEditField
        function VariablesEditFieldValueChanging(app, event)
            global bvData;
            changingValue = event.Value;
            bvData.expData.vars = changingValue;
        end

        % Button pushed function: LogButton
        function LogButtonPushed(app, event)
            % get a new unique animal ID
            config = app.getRepoConfig();
            animalID = app.AnimalIDEditField.Value;
            savePath = config.remoteSaveRoot;
            dos(['notepad.exe "',fullfile(savePath,animalID,'animal_log.txt'),'"'])
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 773 668];
            app.UIFigure.Name = 'MATLAB App';

            % Create StimulusListBoxLabel
            app.StimulusListBoxLabel = uilabel(app.UIFigure);
            app.StimulusListBoxLabel.HorizontalAlignment = 'right';
            app.StimulusListBoxLabel.Position = [81 605 52 22];
            app.StimulusListBoxLabel.Text = 'Stimulus';

            % Create StimulusListBox
            app.StimulusListBox = uilistbox(app.UIFigure);
            app.StimulusListBox.Items = {};
            app.StimulusListBox.ValueChangedFcn = createCallbackFcn(app, @StimulusListBoxValueChanged, true);
            app.StimulusListBox.Position = [148 555 100 74];
            app.StimulusListBox.Value = {};

            % Create FeatureListBoxLabel
            app.FeatureListBoxLabel = uilabel(app.UIFigure);
            app.FeatureListBoxLabel.HorizontalAlignment = 'right';
            app.FeatureListBoxLabel.Position = [86 478 47 22];
            app.FeatureListBoxLabel.Text = 'Feature';

            % Create FeatureListBox
            app.FeatureListBox = uilistbox(app.UIFigure);
            app.FeatureListBox.Items = {};
            app.FeatureListBox.ValueChangedFcn = createCallbackFcn(app, @FeatureListBoxValueChanged, true);
            app.FeatureListBox.Position = [148 428 100 74];
            app.FeatureListBox.Value = {};

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {''};
            app.UITable.RowName = {'Row 1'; 'Row2'};
            app.UITable.ColumnEditable = true;
            app.UITable.CellEditCallback = createCallbackFcn(app, @UITableCellEdit, true);
            app.UITable.Position = [269 403 220 196];

            % Create NewFeatureListBoxLabel
            app.NewFeatureListBoxLabel = uilabel(app.UIFigure);
            app.NewFeatureListBoxLabel.HorizontalAlignment = 'right';
            app.NewFeatureListBoxLabel.Position = [59 398 74 22];
            app.NewFeatureListBoxLabel.Text = 'New Feature';

            % Create NewFeatureListBox
            app.NewFeatureListBox = uilistbox(app.UIFigure);
            app.NewFeatureListBox.Items = {};
            app.NewFeatureListBox.ValueChangedFcn = createCallbackFcn(app, @NewFeatureListBoxValueChanged, true);
            app.NewFeatureListBox.Position = [148 348 100 74];
            app.NewFeatureListBox.Value = {};

            % Create ButtonAddFeature
            app.ButtonAddFeature = uibutton(app.UIFigure, 'push');
            app.ButtonAddFeature.ButtonPushedFcn = createCallbackFcn(app, @ButtonAddFeaturePushed, true);
            app.ButtonAddFeature.Position = [121 452 20 20];
            app.ButtonAddFeature.Text = '+';

            % Create ButtonRemoveFeature
            app.ButtonRemoveFeature = uibutton(app.UIFigure, 'push');
            app.ButtonRemoveFeature.ButtonPushedFcn = createCallbackFcn(app, @ButtonRemoveFeaturePushed, true);
            app.ButtonRemoveFeature.Position = [121 432 20 20];
            app.ButtonRemoveFeature.Text = '-';

            % Create ButtonAddStim
            app.ButtonAddStim = uibutton(app.UIFigure, 'push');
            app.ButtonAddStim.ButtonPushedFcn = createCallbackFcn(app, @ButtonAddStimPushed, true);
            app.ButtonAddStim.Position = [121 579 20 20];
            app.ButtonAddStim.Text = '+';

            % Create ButtonRemoveStim
            app.ButtonRemoveStim = uibutton(app.UIFigure, 'push');
            app.ButtonRemoveStim.ButtonPushedFcn = createCallbackFcn(app, @ButtonRemoveStimPushed, true);
            app.ButtonRemoveStim.Position = [121 559 20 20];
            app.ButtonRemoveStim.Text = '-';

            % Create LoadButton
            app.LoadButton = uibutton(app.UIFigure, 'push');
            app.LoadButton.ButtonPushedFcn = createCallbackFcn(app, @LoadButtonPushed, true);
            app.LoadButton.Position = [75 637 100 22];
            app.LoadButton.Text = 'Load';

            % Create SaveButton
            app.SaveButton = uibutton(app.UIFigure, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Position = [186 637 100 22];
            app.SaveButton.Text = 'Save';

            % Create RunButton
            app.RunButton = uibutton(app.UIFigure, 'push');
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.RunButton.BackgroundColor = [0 1 0];
            app.RunButton.Position = [408 637 100 22];
            app.RunButton.Text = 'Run';

            % Create NewButton
            app.NewButton = uibutton(app.UIFigure, 'push');
            app.NewButton.ButtonPushedFcn = createCallbackFcn(app, @NewButtonPushed, true);
            app.NewButton.Position = [297 637 100 22];
            app.NewButton.Text = 'New';

            % Create NewFeatureListBoxLabel_2
            app.NewFeatureListBoxLabel_2 = uilabel(app.UIFigure);
            app.NewFeatureListBoxLabel_2.HorizontalAlignment = 'right';
            app.NewFeatureListBoxLabel_2.Position = [269 602 111 22];
            app.NewFeatureListBoxLabel_2.Text = 'Feature parameters';

            % Create Openvalve1Button
            app.Openvalve1Button = uibutton(app.UIFigure, 'push');
            app.Openvalve1Button.Position = [71 286 100 22];
            app.Openvalve1Button.Text = 'Open valve 1';

            % Create Closevalve1Button
            app.Closevalve1Button = uibutton(app.UIFigure, 'push');
            app.Closevalve1Button.Position = [71 256 100 22];
            app.Closevalve1Button.Text = 'Close valve 1';

            % Create Openvalve2Button
            app.Openvalve2Button = uibutton(app.UIFigure, 'push');
            app.Openvalve2Button.Position = [181 286 100 22];
            app.Openvalve2Button.Text = 'Open valve 2';

            % Create Closevalve2Button
            app.Closevalve2Button = uibutton(app.UIFigure, 'push');
            app.Closevalve2Button.Position = [181 256 100 22];
            app.Closevalve2Button.Text = 'Close valve 2';

            % Create Rewardv1Button
            app.Rewardv1Button = uibutton(app.UIFigure, 'push');
            app.Rewardv1Button.ButtonPushedFcn = createCallbackFcn(app, @Rewardv1ButtonPushed, true);
            app.Rewardv1Button.Position = [301 286 100 22];
            app.Rewardv1Button.Text = 'Reward v1';

            % Create Rewardv2Button
            app.Rewardv2Button = uibutton(app.UIFigure, 'push');
            app.Rewardv2Button.Position = [301 256 100 22];
            app.Rewardv2Button.Text = 'Reward v2';

            % Create SettingsPanel
            app.SettingsPanel = uipanel(app.UIFigure);
            app.SettingsPanel.Title = 'Settings';
            app.SettingsPanel.Position = [71 31 260 221];

            % Create BVServerEditFieldLabel
            app.BVServerEditFieldLabel = uilabel(app.SettingsPanel);
            app.BVServerEditFieldLabel.HorizontalAlignment = 'right';
            app.BVServerEditFieldLabel.Position = [16 164 60 22];
            app.BVServerEditFieldLabel.Text = 'BV Server';

            % Create BVServerEditField
            app.BVServerEditField = uieditfield(app.SettingsPanel, 'text');
            app.BVServerEditField.HorizontalAlignment = 'center';
            app.BVServerEditField.Position = [91 164 100 22];
            app.BVServerEditField.Value = '127.0.0.1';

            % Create SavesettingsButton
            app.SavesettingsButton = uibutton(app.SettingsPanel, 'push');
            app.SavesettingsButton.ButtonPushedFcn = createCallbackFcn(app, @SavesettingsButtonPushed, true);
            app.SavesettingsButton.Position = [61 11 100 22];
            app.SavesettingsButton.Text = 'Save settings';

            % Create ResetButton
            app.ResetButton = uibutton(app.UIFigure, 'push');
            app.ResetButton.ButtonPushedFcn = createCallbackFcn(app, @ResetButtonPushed, true);
            app.ResetButton.Position = [518 637 100 22];
            app.ResetButton.Text = 'Reset';

            % Create SequenceRepeatsEditFieldLabel
            app.SequenceRepeatsEditFieldLabel = uilabel(app.UIFigure);
            app.SequenceRepeatsEditFieldLabel.HorizontalAlignment = 'right';
            app.SequenceRepeatsEditFieldLabel.Position = [533 490 60 28];
            app.SequenceRepeatsEditFieldLabel.Text = {'Sequence'; 'Repeats'};

            % Create SequenceRepeatsEditField
            app.SequenceRepeatsEditField = uieditfield(app.UIFigure, 'text');
            app.SequenceRepeatsEditField.HorizontalAlignment = 'center';
            app.SequenceRepeatsEditField.Position = [607 494 101 22];
            app.SequenceRepeatsEditField.Value = '10';

            % Create RepsEditFieldLabel
            app.RepsEditFieldLabel = uilabel(app.UIFigure);
            app.RepsEditFieldLabel.HorizontalAlignment = 'right';
            app.RepsEditFieldLabel.Position = [80 583 34 22];
            app.RepsEditFieldLabel.Text = 'Reps';

            % Create RepsEditField
            app.RepsEditField = uieditfield(app.UIFigure, 'text');
            app.RepsEditField.ValueChangingFcn = createCallbackFcn(app, @RepsEditFieldValueChanging, true);
            app.RepsEditField.HorizontalAlignment = 'center';
            app.RepsEditField.Position = [80 560 37 22];
            app.RepsEditField.Value = '1';

            % Create RandomiseCheckBox
            app.RandomiseCheckBox = uicheckbox(app.UIFigure);
            app.RandomiseCheckBox.Text = 'Randomise';
            app.RandomiseCheckBox.Position = [637 598 83 22];
            app.RandomiseCheckBox.Value = true;

            % Create FeedbackListBox
            app.FeedbackListBox = uilistbox(app.UIFigure);
            app.FeedbackListBox.Items = {};
            app.FeedbackListBox.Position = [343 34 418 216];
            app.FeedbackListBox.Value = {};

            % Create UITable_DAQs
            app.UITable_DAQs = uitable(app.UIFigure);
            app.UITable_DAQs.ColumnName = {''};
            app.UITable_DAQs.RowName = {'Row 1'; 'Row2'};
            app.UITable_DAQs.ColumnEditable = true;
            app.UITable_DAQs.Position = [88 74 227 109];

            % Create AnimalIDEditFieldLabel
            app.AnimalIDEditFieldLabel = uilabel(app.UIFigure);
            app.AnimalIDEditFieldLabel.HorizontalAlignment = 'right';
            app.AnimalIDEditFieldLabel.Position = [535 562 58 22];
            app.AnimalIDEditFieldLabel.Text = 'Animal ID';

            % Create AnimalIDEditField
            app.AnimalIDEditField = uieditfield(app.UIFigure, 'text');
            app.AnimalIDEditField.HorizontalAlignment = 'center';
            app.AnimalIDEditField.Position = [608 562 100 22];
            app.AnimalIDEditField.Value = 'TEST';

            % Create BuildSetButton
            app.BuildSetButton = uibutton(app.UIFigure, 'push');
            app.BuildSetButton.ButtonPushedFcn = createCallbackFcn(app, @BuildSetButtonPushed, true);
            app.BuildSetButton.Position = [151 316 100 22];
            app.BuildSetButton.Text = 'Build set';

            % Create DelaysecsLabel
            app.DelaysecsLabel = uilabel(app.UIFigure);
            app.DelaysecsLabel.HorizontalAlignment = 'right';
            app.DelaysecsLabel.Position = [494 601 72 22];
            app.DelaysecsLabel.Text = {'Delay (secs)'; ''};

            % Create PreBlankText
            app.PreBlankText = uieditfield(app.UIFigure, 'text');
            app.PreBlankText.Position = [581 601 40 22];
            app.PreBlankText.Value = '0';

            % Create TestStimBtn
            app.TestStimBtn = uibutton(app.UIFigure, 'push');
            app.TestStimBtn.ButtonPushedFcn = createCallbackFcn(app, @TestStimBtnButtonPushed, true);
            app.TestStimBtn.BackgroundColor = [0 1 0];
            app.TestStimBtn.Position = [168 518 59 21];
            app.TestStimBtn.Text = 'Test';

            % Create VariablesEditFieldLabel
            app.VariablesEditFieldLabel = uilabel(app.UIFigure);
            app.VariablesEditFieldLabel.HorizontalAlignment = 'right';
            app.VariablesEditFieldLabel.Position = [270 350 55 22];
            app.VariablesEditFieldLabel.Text = 'Variables';

            % Create VariablesEditField
            app.VariablesEditField = uieditfield(app.UIFigure, 'text');
            app.VariablesEditField.ValueChangedFcn = createCallbackFcn(app, @VariablesEditFieldValueChanged, true);
            app.VariablesEditField.ValueChangingFcn = createCallbackFcn(app, @VariablesEditFieldValueChanging, true);
            app.VariablesEditField.Position = [340 348 149 25];

            % Create CopyButton
            app.CopyButton = uibutton(app.UIFigure, 'push');
            app.CopyButton.ButtonPushedFcn = createCallbackFcn(app, @CopyButtonPushed, true);
            app.CopyButton.Position = [80 517 60 22];
            app.CopyButton.Text = 'Copy';

            % Create FeatCopyButton
            app.FeatCopyButton = uibutton(app.UIFigure, 'push');
            app.FeatCopyButton.ButtonPushedFcn = createCallbackFcn(app, @FeatCopyButtonPushed, true);
            app.FeatCopyButton.Position = [54 428 60 22];
            app.FeatCopyButton.Text = 'Copy';

            % Create ITIEditFieldLabel
            app.ITIEditFieldLabel = uilabel(app.UIFigure);
            app.ITIEditFieldLabel.HorizontalAlignment = 'right';
            app.ITIEditFieldLabel.Position = [568 529 25 22];
            app.ITIEditFieldLabel.Text = 'ITI';

            % Create ITIEditField
            app.ITIEditField = uieditfield(app.UIFigure, 'text');
            app.ITIEditField.HorizontalAlignment = 'center';
            app.ITIEditField.Position = [608 529 100 22];
            app.ITIEditField.Value = '2';

            % Create ExperimentlogTextAreaLabel
            app.ExperimentlogTextAreaLabel = uilabel(app.UIFigure);
            app.ExperimentlogTextAreaLabel.HorizontalAlignment = 'right';
            app.ExperimentlogTextAreaLabel.Position = [508 428 86 22];
            app.ExperimentlogTextAreaLabel.Text = 'Experiment log';

            % Create ExperimentlogTextArea
            app.ExperimentlogTextArea = uitextarea(app.UIFigure);
            app.ExperimentlogTextArea.Position = [518 270 243 159];

            % Create LogButton
            app.LogButton = uibutton(app.UIFigure, 'push');
            app.LogButton.ButtonPushedFcn = createCallbackFcn(app, @LogButtonPushed, true);
            app.LogButton.Position = [715 562 46 22];
            app.LogButton.Text = 'Log';

            % Create PauseafterpreloadEditFieldLabel
            app.PauseafterpreloadEditFieldLabel = uilabel(app.UIFigure);
            app.PauseafterpreloadEditFieldLabel.HorizontalAlignment = 'right';
            app.PauseafterpreloadEditFieldLabel.WordWrap = 'on';
            app.PauseafterpreloadEditFieldLabel.Position = [518 455 74 30];
            app.PauseafterpreloadEditFieldLabel.Text = 'Pause after preload';

            % Create PauseafterpreloadEditField
            app.PauseafterpreloadEditField = uieditfield(app.UIFigure, 'text');
            app.PauseafterpreloadEditField.HorizontalAlignment = 'center';
            app.PauseafterpreloadEditField.Position = [607 455 101 23];
            app.PauseafterpreloadEditField.Value = '5';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = bvGUI

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
