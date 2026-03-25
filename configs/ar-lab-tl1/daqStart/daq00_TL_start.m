function [success,msg] = daq00_TL_start(expID)
% code to start acquisition
disp('starting timeline');
global delay_time
delay_time = tic;
disp(['Timeline GUI starter function: ' num2str(toc(delay_time))])
try
  startTimeline(expID);
  success = true;
  msg = 'very nice';
catch
  success = false;
end
end

