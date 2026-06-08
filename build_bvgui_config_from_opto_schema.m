function expData = build_bvgui_config_from_opto_schema(schemaPath, outputPath, schemaName)
%BUILD_BVGUI_CONFIG_FROM_OPTO_SCHEMA Build a bvGUI opto_2p config from an opto schema.
%
%   expData = build_bvgui_config_from_opto_schema(schemaPath)
%   expData = build_bvgui_config_from_opto_schema(schemaPath, outputPath)
%   expData = build_bvgui_config_from_opto_schema(schemaPath, outputPath, schemaName)
%
% Creates one bvGUI stimulus per sequence in the schema. Each stimulus has a
% single enabled opto_2p feature and one repeat. Sequence numbers are zero-
% based to match the opto_2p UDP protocol.
%
% If outputPath is omitted or empty, the script writes a .mat file next to
% schemaPath named <schemaName>_bvgui.mat.

    if nargin < 1 || isempty(schemaPath)
        defaultSchemaDir = '\\AR-LAB-NAS1\DataServer\opto_schemas';
        [fileName, filePath] = uigetfile({'schema.yaml;schema.yml;*.yaml;*.yml', 'Opto schema YAML (*.yaml, *.yml)'}, 'Select opto schema', defaultSchemaDir);
        if isequal(fileName, 0)
            expData = [];
            return;
        end
        schemaPath = fullfile(filePath, fileName);
    end
    if nargin < 2
        outputPath = '';
    end
    if nargin < 3
        schemaName = '';
    end

    schemaPath = char(schemaPath);
    assert(exist(schemaPath, 'file') == 2, 'Schema file does not exist: %s', schemaPath);

    if isempty(schemaName)
        schemaDir = fileparts(schemaPath);
        [~, schemaName] = fileparts(schemaDir);
    end
    schemaName = char(schemaName);
    assert(~isempty(strtrim(schemaName)), 'schemaName could not be inferred. Pass it explicitly.');

    sequenceNames = local_sequence_names_from_schema(schemaPath);
    assert(~isempty(sequenceNames), 'Schema does not contain any sequences: %s', schemaPath);

    expData = struct();
    expData.stims = struct('features', {}, 'reps', {});
    expData.vars = '';
    expData.iti = '1';
    expData.seqreps = '1';

    for iSequence = 1:numel(sequenceNames)
        feature = struct();
        feature.name = {'opto_2p'};
        feature.params = {'schema_name', 'seq_num'};
        feature.vals = {schemaName, num2str(iSequence - 1)};

        expData.stims(iSequence).features = feature; %#ok<AGROW>
        expData.stims(iSequence).reps = 1; %#ok<AGROW>
    end

    if isempty(outputPath)
        schemaDir = fileparts(schemaPath);
        outputPath = fullfile(schemaDir, [schemaName '_bvgui.mat']);
    end
    outputPath = char(outputPath);
    save(outputPath, 'expData');
    fprintf('Saved bvGUI config with %d opto_2p stimulus/stimuli to %s\n', numel(sequenceNames), outputPath);
end


function sequenceNames = local_sequence_names_from_schema(schemaPath)
    text = fileread(schemaPath);
    lines = regexp(text, '\r\n|\n|\r', 'split');
    sequenceNames = {};
    inSequences = false;
    sequenceIndent = [];

    for iLine = 1:numel(lines)
        line = lines{iLine};
        stripped = strtrim(line);
        if isempty(stripped) || startsWith(stripped, '#')
            continue;
        end

        topLevelMatch = regexp(line, '^([A-Za-z0-9_]+)\s*:', 'tokens', 'once');
        if ~isempty(topLevelMatch)
            inSequences = strcmp(topLevelMatch{1}, 'sequences');
            sequenceIndent = [];
            continue;
        end

        if ~inSequences
            continue;
        end

        if isempty(sequenceIndent)
            indentMatch = regexp(line, '^(\s+)([^:\s][^:]*)\s*:', 'tokens', 'once');
            if isempty(indentMatch)
                continue;
            end
            sequenceIndent = numel(indentMatch{1});
            sequenceName = strtrim(indentMatch{2});
        else
            expr = sprintf('^(\\s{%d})([^:\\s][^:]*)\\s*:', sequenceIndent);
            indentMatch = regexp(line, expr, 'tokens', 'once');
            if isempty(indentMatch)
                continue;
            end
            sequenceName = strtrim(indentMatch{2});
        end

        if ~isempty(sequenceName) && ~strcmp(sequenceName, '{}')
            sequenceNames{end + 1} = sequenceName; %#ok<AGROW>
        end
    end
end
