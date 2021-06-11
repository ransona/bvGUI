% takes current stimulus and varies it over a range
paramName = [];
paramVals = [];
baseStim = inputdlg('What is the base stimulus number?'); 
baseStim = str2num(baseStim{1});
featToVary = inputdlg('Which features do you want to vary the parameters of?'); 
featToVary = eval(featToVary{1});
resp = questdlg('Replace base stimulus?');

if strcmp(resp,'Yes')
  overwriteBase = true;
else
  overwriteBase = false;
end  

while true
  resp = inputdlg('Please enter name of parameter to vary');
  paramName{end+1} = resp{1};
  resp = inputdlg('Enter desired values (can be in format x,y,z or x:inc:z)');
  paramVals{end+1} = eval(resp{1});
  resp = questdlg('Add another parameter?');
  switch resp
    case 'No'
      break;
    case 'Cancel'
      msgbox('Stimulus generation cancelled');
      return
  end
end 
  
global bvData;
expData = bvData.expData;
baseStimParams = bvData.expData.stims(baseStim);

% remove base stim from set if requested
if overwriteBase
  bvData.expData.stims = bvData.expData.stims(setdiff(1:length(bvData.expData.stims),baseStim));
end

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
    newStim.features(1).vals(paramIndex) = {num2str(paramTable(iStim,iParam))};
  end
  newStimSet(end+1) = newStim;
end

bvData.expData.stims = newStimSet;

% xrange = linspace(-90,0,5);
% yrange = linspace(-30,30,5);
% newStimSet = expData.stims(1);
% currentStim = 0;
% for iX = 1:length(xrange)
%   for iY = 1:length(yrange)
%     currentStim = currentStim + 1;
%     newStimSet(currentStim) = expData.stims(1);
%     indexx = find(strcmp(expData.stims(1).features(1).params, 'x'));
%     indexy = find(strcmp(expData.stims(1).features(1).params, 'y'));
%     newStimSet(currentStim).features(1).vals(indexx) = {num2str(xrange(iX))};
%     newStimSet(currentStim).features(1).vals(indexy) = {num2str(yrange(iY))};
%   end
% end
% 
% expData = [];
% expData.stims = newStimSet;
% uisave({'expData'},'c:\bvGUI\stimsets')   