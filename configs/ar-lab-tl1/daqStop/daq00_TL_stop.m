function [success,msg] = daq00_TL_stop(expID)
% code to stop acquisition
disp('stopping timeline');
try
  stopTimeline;
  success = true;
  msg = 'very nice';
catch
  success = false;
  msg = 'didn''t work';
end
end

