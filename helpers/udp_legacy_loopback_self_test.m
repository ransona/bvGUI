function result = udp_legacy_loopback_self_test(varargin)
%UDP_LEGACY_LOOPBACK_SELF_TEST Verify local UDP send/receive using udp(...).
%
% This test exercises the legacy Instrument Control Toolbox UDP interface
% used by older bvGUI code paths. It is intended to answer one narrow
% question: does MATLAB's old udp(...) API still work locally on this host.
%
% Example:
%   result = udp_legacy_loopback_self_test()
%
% Optional name/value inputs:
%   "ReceiverPort" - UDP port for the local receiver (default 40133)
%   "SenderPort"   - UDP port for the local sender   (default 40134)
%   "Timeout"      - Timeout in seconds per receive phase (default 2.0)
%   "Verbose"      - Whether to print progress (default true)
%
% Returned struct fields:
%   ok
%   receiver_port
%   sender_port
%   one_way_ok
%   reply_ok
%   received_message
%   reply_message
%   error

    parser = inputParser();
    addParameter(parser, 'ReceiverPort', 40133, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'SenderPort', 40134, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'Timeout', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'Verbose', true, @(x) islogical(x) || isnumeric(x));
    parse(parser, varargin{:});

    receiverPort = double(parser.Results.ReceiverPort);
    senderPort = double(parser.Results.SenderPort);
    timeoutSeconds = double(parser.Results.Timeout);
    verbose = logical(parser.Results.Verbose);

    result = struct( ...
        'ok', false, ...
        'receiver_port', receiverPort, ...
        'sender_port', senderPort, ...
        'one_way_ok', false, ...
        'reply_ok', false, ...
        'received_message', "", ...
        'reply_message', "", ...
        'error', "");

    probeMessage = 'bvgui_udp_legacy_probe';
    replyMessage = 'bvgui_udp_legacy_reply';

    receiver = [];
    sender = [];

    try
        if verbose
            fprintf('Creating legacy UDP receiver on 127.0.0.1:%d\n', receiverPort);
        end
        receiver = udp('127.0.0.1', 'RemotePort', senderPort, 'LocalPort', receiverPort);
        receiver.Timeout = timeoutSeconds;
        receiver.InputBufferSize = 65535;
        receiver.OutputBufferSize = 65535;

        if verbose
            fprintf('Creating legacy UDP sender on 127.0.0.1:%d\n', senderPort);
        end
        sender = udp('127.0.0.1', 'RemotePort', receiverPort, 'LocalPort', senderPort);
        sender.Timeout = timeoutSeconds;
        sender.InputBufferSize = 65535;
        sender.OutputBufferSize = 65535;

        fopen(receiver);
        receiverCleaner = onCleanup(@() close_udp(receiver)); %#ok<NASGU>
        fopen(sender);
        senderCleaner = onCleanup(@() close_udp(sender)); %#ok<NASGU>

        if verbose
            fprintf('Sending probe message through legacy UDP sender\n');
        end
        fwrite(sender, uint8(probeMessage), 'uint8');

        receivedProbe = wait_for_legacy_message(receiver, timeoutSeconds);
        result.received_message = string(receivedProbe);
        result.one_way_ok = strcmp(receivedProbe, probeMessage);
        if ~result.one_way_ok
            error('Legacy UDP receive mismatch. Expected "%s", got "%s".', probeMessage, receivedProbe);
        end

        if verbose
            fprintf('Receiver got probe; sending reply back through legacy UDP receiver\n');
        end
        fwrite(receiver, uint8(replyMessage), 'uint8');

        receivedReply = wait_for_legacy_message(sender, timeoutSeconds);
        result.reply_message = string(receivedReply);
        result.reply_ok = strcmp(receivedReply, replyMessage);
        if ~result.reply_ok
            error('Legacy UDP reply mismatch. Expected "%s", got "%s".', replyMessage, receivedReply);
        end

        result.ok = true;
        if verbose
            fprintf('Legacy UDP loopback self-test passed.\n');
        end
    catch err
        result.error = string(err.message);
        if verbose
            fprintf(2, 'Legacy UDP loopback self-test failed: %s\n', err.message);
        end
    end

    close_udp(sender);
    close_udp(receiver);
end

function message = wait_for_legacy_message(udpObj, timeoutSeconds)
    startTime = tic;
    while udpObj.BytesAvailable == 0
        if toc(startTime) > timeoutSeconds
            error('Timed out waiting for legacy UDP datagram.');
        end
        pause(0.01);
    end

    data = fread(udpObj, udpObj.BytesAvailable, 'uint8');
    message = char(data(:)');
end

function close_udp(udpObj)
    if isempty(udpObj)
        return;
    end

    try
        if strcmp(udpObj.Status, 'open')
            fclose(udpObj);
        end
    catch
    end

    try
        delete(udpObj);
    catch
    end
end
