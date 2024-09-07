function [success,msg] = daq01_EYE_start(expID)
% code to start acquisition
% config for contacting SI UDP listener
try
  if ~exist('expID')
    expID = '2016-10-14_09_CFAP049';
  end
  SI_ip = '158.109.215.179';
  SI_receive_port = 1813;
  SI_send_port = 1814;
  disp('starting SI');
  address = java.net.InetAddress.getLocalHost;
  IPaddress = char(address.getHostAddress);
  udpComms = UDPqML(SI_ip,SI_receive_port,SI_send_port);
  msg = 'All good';
  % send command and wait for confirmation
  success = udpComms.send(['GOGO*',expID],'COM',0);
  if success == 1
    % then wait for ready signal from DAQ (i.e. when acquisition
    % running
    %success = udpComms.awaitReady(300);
    %if success == 0
    %  msg = 'siTimed out waiting for response';
    %end
  else
    msg = 'Timed out waiting for response';
  end
  udpComms.delete;
catch ME
  ME.identifier
  success = 0;
  msg = 'Unknown error';
  try
    udpComms.delete;
  catch
  end
end
% allow acqusition to start
pause(2);
end

