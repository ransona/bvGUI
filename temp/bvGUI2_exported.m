classdef bvGUI2_exported < matlab.apps.AppBase

  % Properties that correspond to app components
  properties (Access = public)
    UIFigure                       matlab.ui.Figure
    PreBlankText                   matlab.ui.control.EditField
    DelaysecsLabel                 matlab.ui.control.Label
    BuildSetButton                 matlab.ui.control.Button
    FeedbackPanel                  matlab.ui.container.Panel
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
    
    function results = bvUpdateGUI(app)
      % function to make the table in the gui reflect the currently
      % loaded experiment data structure
      global bvData;
      
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
  end
  

  % Callbacks that handle component events
  methods (Access = private)

    % Code that executes after component creation
    function startupFcn(app)
      global bvData;
      bvData = [];
      bvData.expData.stims = [];
      % load settings
      load('c:\bvGUI\bvGUISettings.mat');
      bvData.settings = bvGUIsettings;
      app.BVServerEditField.Value = bvData.settings.bvServer;
      % populate new feature list box with feature files
      % find feature files
      featFilePath = 'c:\bvGUI\features\';
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
      daqList = dir('c:\bvGUI\daqStart\*.m');
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
      
      % make plot panel available to timeline
      app.FeedbackPanel.AutoResizeChildren = 'off';
      bvData.plotAreas =  app.FeedbackPanel;
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
      expData = bvData.expData;
      uisave({'expData'},'c:\bvGUI\stimsets');
      figure(app.UIFigure);
    end

    % Button pushed function: LoadButton
    function LoadButtonPushed(app, event)
      global bvData;
      uiopen('c:\bvGUI\stimsets');
      figure(app.UIFigure);
      app.UIFigure.Visible = 'on';
      bvData.expData = expData;
      app.StimulusListBox.Tag = '';
      app.FeatureListBox.Tag = '';
      app.FeatureListBox.Value = {};
      app.bvUpdateGUI;
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
      % get a new unique animal ID
      expID = newExpID(app.AnimalIDEditField.Value);
      animalID = expID(15:end);
      savePath = fullfile(remotePath);%'c:\local_repository\'; %

      app.debugMessage('==========================');
      app.debugMessage(['Starting new experiment - ',expID]);
      
      % initiate any DAQ devices which have been selected
      daqList = dir('c:\bvGUI\daqStart\*.m');
      daqList = {daqList.name}';
      % do checking to make sure all start and stop daqs match up
      % ... to implement
      
      % pull data from table of whether DAQ devices are enabled
      daqEnabled = app.UITable_DAQs.Data.enabled;
      
      startDir = cd;
      cd('c:\bvGUI\daqStart');
      app.debugMessage('Attempting to start all DAQs');
      for iDaq = 1:length(daqList)
        if daqEnabled(iDaq)
          app.debugMessage(['Running ',daqList{iDaq}]);
          [success,resp_msg] = eval([daqList{iDaq}(1:end-2),'(expID)']);
          if ~success
            app.debugMessage('Error... attempting to stop all DAQs');
            % attempt to stop all of the daqs in reverse
            daqList = dir('c:\bvGUI\daqStop\*.m');
            daqList = {daqList.name}';
            cd('c:\bvGUI\daqStop');
            for iDaqStop = iDaq-1:-1:1
              if daqEnabled(iDaqStop)
                app.debugMessage(['Stopping ',daqList{iDaqStop}]);
                [success,resp_msg] = eval(daqList{iDaqStop}(1:end-2));
                if ~success
                  app.debugMessage(['Error stopping ',daqList{iDaqStop}]);
                else
                  % app.debugMessage('OK');
                end
              end
            end
            cd(startDir);
            % restore GUI elements so ready to start again
            % put run button back to default state
            app.RunButton.Enable = "on";
            app.RunButton.Text = 'Run';
            app.RunButton.BackgroundColor = 'g';
            app.abortFlag = 0;
            debugMessage(app,'Experiment complete (with errors!)');
            return;
          else
            % app.debugMessage('OK');
          end
        end
      end
      
      
      % preload any resources needed
      % the list of these resources should be generated from the
      % parameter settings in the gui
      %rig.resource("Videos/Blink");
      %rig.preload();
      % start any DAQ servers here with UDP commands
      % ...
      % make stim order with correct ratio of repeats for each stim
      % type & randomisation / pseudorandom / pooled pseudorandom as
      % requested by user
      completeStimSeq = [];
      
      seqReps = str2num(app.SequenceRepeatsEditField.Value);
      for iSeqRep = 1:seqReps
        singleRepSeq = [];
        for iStim = 1:length(bvData.expData.stims)
          stimReps = bvData.expData.stims(iStim).reps;
          singleRepSeq = [singleRepSeq,repmat(iStim,[1 stimReps])];
        end
        if app.RandomiseCheckBox.Value == true
          completeStimSeq = [completeStimSeq,singleRepSeq(randperm(length(singleRepSeq)))];
        else
          completeStimSeq = [completeStimSeq,singleRepSeq];
        end
      end
      
      preBlankTime = str2num(app.PreBlankText.Value);
      startTime = tic;
      if preBlankTime > 0
        app.debugMessage(['Showing blank for ',num2str(preBlankTime),' secs']);
      end
      while toc(startTime)<preBlankTime
        % wait
        drawnow limitrate;
      end
      
      if ~isempty(completeStimSeq)
        % establish udp connection
        global u;
        % u = udp(bvData.settings.bvServer, 4002,'LocalPort',4007);
        %u = udp(bvData.settings.bvServer, 4002,'LocalPort',4007);
        
        % remember to correct meta name here
        
        metadata = expID;
        u = OscTcp('158.109.215.49', 4002);
        
        % fopen(u);
        rig = Rig(u);
        rig.dataset(savePath);
        rig.experiment(metadata);

        % start loop of going through each trial
        for iTrial = 1:length(completeStimSeq)
          drawnow
          % meta data to label trial should be added here using
          % something like:
          % rig.experiment(metadata);
          rig.dataset(savePath);
          rig.experiment(metadata);
          debugMessage(app,['Starting trial ',num2str(iTrial),' of ',num2str(length(completeStimSeq))]);
          % generate commands to send stim to BV server
          for iFeature = 1:length(bvData.expData.stims(completeStimSeq(iTrial)).features)
            featureParams = cell2struct(bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).vals',bvData.expData.stims(completeStimSeq(iTrial)).features(iFeature).params);
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
              case 'video'
            end
          end
          % once all features are added
          % start trial
          rig.start();
          % wait for end of trial
          %oscrecv(u
          datagram = [];
          while(isempty(datagram))
            datagram = u.receive();
            drawnow limitrate;
          end
          disp(datagram);
          pause(0.5);
          % check if abort has been pressed
          if app.abortFlag
            break;
          end
        end
        
      end
      
      % Stop all DAQs
      app.debugMessage('Attempting to stop all DAQs');
      % attempt to stop all of the daqs in reverse
      daqList = dir('c:\bvGUI\daqStop\*.m');
      daqList = {daqList.name}';
      cd('c:\bvGUI\daqStop');
      for iDaqStop = length(daqList):-1:1
        if daqEnabled(iDaqStop)
          app.debugMessage(['Stopping ',daqList{iDaqStop}]);
          [success,resp_msg] = eval(daqList{iDaqStop}(1:end-2));
          if ~success
            app.debugMessage(['Error stopping ',daqList{iDaqStop}]);
          else
            % app.debugMessage('OK');
          end
        end
      end
      cd(startDir);
      
      % put run button back to default state
      app.RunButton.Enable = "on";
      app.RunButton.Text = 'Run';
      app.RunButton.BackgroundColor = 'g';
      app.abortFlag = 0;
      debugMessage(app,['Experiment complete - ',expID]);
    end

    % Button pushed function: SavesettingsButton
    function SavesettingsButtonPushed(app, event)
      global bvData;
      bvGUIsettings = bvData.settings;
      save('c:\bvGUI\bvGUISettings.mat','bvGUIsettings');
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
          paramIndex = find(strcmp(newStim.features(1).params, paramName{iParam}));
          if isempty(paramIndex)
            msgbox(['A parameter wasn''t found (',paramName{iParam},')']);
            return;
          end
          newStim.features(1).vals(paramIndex) = {num2str(paramTable(iStim,iParam))};
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
  end

  % Component initialization
  methods (Access = private)

    % Create UIFigure and components
    function createComponents(app)

      % Create UIFigure and hide until all components are created
      app.UIFigure = uifigure('Visible', 'off');
      app.UIFigure.Position = [100 100 1238 668];
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
      app.FeatureListBoxLabel.Position = [86 525 47 22];
      app.FeatureListBoxLabel.Text = 'Feature';

      % Create FeatureListBox
      app.FeatureListBox = uilistbox(app.UIFigure);
      app.FeatureListBox.Items = {};
      app.FeatureListBox.ValueChangedFcn = createCallbackFcn(app, @FeatureListBoxValueChanged, true);
      app.FeatureListBox.Position = [148 475 100 74];
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
      app.NewFeatureListBoxLabel.Position = [59 445 74 22];
      app.NewFeatureListBoxLabel.Text = 'New Feature';

      % Create NewFeatureListBox
      app.NewFeatureListBox = uilistbox(app.UIFigure);
      app.NewFeatureListBox.Items = {};
      app.NewFeatureListBox.ValueChangedFcn = createCallbackFcn(app, @NewFeatureListBoxValueChanged, true);
      app.NewFeatureListBox.Position = [148 395 100 74];
      app.NewFeatureListBox.Value = {};

      % Create ButtonAddFeature
      app.ButtonAddFeature = uibutton(app.UIFigure, 'push');
      app.ButtonAddFeature.ButtonPushedFcn = createCallbackFcn(app, @ButtonAddFeaturePushed, true);
      app.ButtonAddFeature.Position = [121 499 20 20];
      app.ButtonAddFeature.Text = '+';

      % Create ButtonRemoveFeature
      app.ButtonRemoveFeature = uibutton(app.UIFigure, 'push');
      app.ButtonRemoveFeature.ButtonPushedFcn = createCallbackFcn(app, @ButtonRemoveFeaturePushed, true);
      app.ButtonRemoveFeature.Position = [121 479 20 20];
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
      app.Openvalve1Button.Position = [71 317 100 22];
      app.Openvalve1Button.Text = 'Open valve 1';

      % Create Closevalve1Button
      app.Closevalve1Button = uibutton(app.UIFigure, 'push');
      app.Closevalve1Button.Position = [71 287 100 22];
      app.Closevalve1Button.Text = 'Close valve 1';

      % Create Openvalve2Button
      app.Openvalve2Button = uibutton(app.UIFigure, 'push');
      app.Openvalve2Button.Position = [181 317 100 22];
      app.Openvalve2Button.Text = 'Open valve 2';

      % Create Closevalve2Button
      app.Closevalve2Button = uibutton(app.UIFigure, 'push');
      app.Closevalve2Button.Position = [181 287 100 22];
      app.Closevalve2Button.Text = 'Close valve 2';

      % Create Rewardv1Button
      app.Rewardv1Button = uibutton(app.UIFigure, 'push');
      app.Rewardv1Button.ButtonPushedFcn = createCallbackFcn(app, @Rewardv1ButtonPushed, true);
      app.Rewardv1Button.Position = [301 317 100 22];
      app.Rewardv1Button.Text = 'Reward v1';

      % Create Rewardv2Button
      app.Rewardv2Button = uibutton(app.UIFigure, 'push');
      app.Rewardv2Button.Position = [301 287 100 22];
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
      app.SequenceRepeatsEditFieldLabel.Position = [623 631 60 28];
      app.SequenceRepeatsEditFieldLabel.Text = {'Sequence'; 'Repeats'};

      % Create SequenceRepeatsEditField
      app.SequenceRepeatsEditField = uieditfield(app.UIFigure, 'text');
      app.SequenceRepeatsEditField.HorizontalAlignment = 'center';
      app.SequenceRepeatsEditField.Position = [697 636 37 22];
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
      app.AnimalIDEditFieldLabel.Position = [534 562 58 22];
      app.AnimalIDEditFieldLabel.Text = 'Animal ID';

      % Create AnimalIDEditField
      app.AnimalIDEditField = uieditfield(app.UIFigure, 'text');
      app.AnimalIDEditField.Position = [607 562 100 22];
      app.AnimalIDEditField.Value = 'TEST';

      % Create FeedbackPanel
      app.FeedbackPanel = uipanel(app.UIFigure);
      app.FeedbackPanel.Title = 'Feedback';
      app.FeedbackPanel.Position = [781 31 439 627];

      % Create BuildSetButton
      app.BuildSetButton = uibutton(app.UIFigure, 'push');
      app.BuildSetButton.ButtonPushedFcn = createCallbackFcn(app, @BuildSetButtonPushed, true);
      app.BuildSetButton.Position = [151 360 100 22];
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

      % Show the figure after all components are created
      app.UIFigure.Visible = 'on';
    end
  end

  % App creation and deletion
  methods (Access = public)

    % Construct app
    function app = bvGUI2_exported

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