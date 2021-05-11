global bvData;
expData = bvData.expData;
xrange = linspace(-90,90,10);
yrange = linspace(-30,30,5);
newStimSet = expData.stims(1);
currentStim = 0;
for iX = 1:length(xrange)
  for iY = 1:length(yrange)
    currentStim = currentStim + 1;
    newStimSet(currentStim) = expData.stims(1);
    indexx = find(strcmp(expData.stims(1).features(2).params, 'x'));
    indexy = find(strcmp(expData.stims(1).features(2).params, 'y'));
    newStimSet(currentStim).features(2).vals(indexx) = {num2str(xrange(iX))};
    newStimSet(currentStim).features(2).vals(indexy) = {num2str(yrange(iY))};
  end
end

expData = [];
expData.stims = newStimSet;
uisave({'expData'},'c:\bvGUI\stimsets')   