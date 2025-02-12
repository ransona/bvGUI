function [success,msg] = daq00_TL_start(expID)
% code to start acquisition
disp('starting timeline');
try
  startTimeline(expID);
  success = true;
  msg = 'very nice';
catch
  success = false;
end
end

