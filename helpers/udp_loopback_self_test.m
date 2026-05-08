function result = udp_loopback_self_test(varargin)
%UDP_LOOPBACK_SELF_TEST Verify local UDP send/receive using udpport.
%
% This is a standalone local comms test for MATLAB hosts where legacy
% Instrument Control Toolbox UDP objects may be deprecated, blocked, or
% otherwise behaving unexpectedly. It avoids the old udp(...) API and uses
% udpport("datagram","IPV4") instead.
%
% Example:
%   result = udp_loopback_self_test()
%
% Optional name/value inputs:
%   "Port"       - Receiver UDP port to use locally (default 40123)
%   "Timeout"    - Timeout in seconds for each receive phase (default 2.0)
%   "Verbose"    - Whether to print progress to the command window
%                  (default true)
%
% Returned struct fields:
%   ok                 - True only if the full round trip succeeded
%   listen_port        - Receiver port used for the test
%   sender_port        - Sender local port used for the test
%   one_way_ok         - Receiver got the probe message intact
%   reply_ok           - Sender got the reply message intact
%   received_message   - Payload observed by the receiver
%   reply_message      - Payload observed by the sender
%   error              - Error text on failure, empty on success

    parser = inputParser();
    addParameter(parser, 'Port', 40123, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'Timeout', 2.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'Verbose', true, @(x) islogical(x) || isnumeric(x));
    parse(parser, varargin{:});

    listenPort = double(parser.Results.Port);
    timeoutSeconds = double(parser.Results.Timeout);
    verbose = logical(parser.Results.Verbose);

    result = struct( ...
        'ok', false, ...
        'listen_port', listenPort, ...
        'sender_port', NaN, ...
        'one_way_ok', false, ...
        'reply_ok', false, ...
        'received_message', "", ...
        'reply_message', "", ...
        'error', "");

    probeMessage = "bvgui_udp_probe";
    replyMessage = "bvgui_udp_reply";

    receiver = [];
    sender = [];

    try
        if verbose
            fprintf('Creating UDP receiver on 127.0.0.1:%d\n', listenPort);
        end
        receiver = udpport("datagram", "IPV4", "LocalPort", listenPort);
        receiver.Timeout = timeoutSeconds;
        receiver.EnablePortSharing = false;

        if verbose
            fprintf('Creating UDP sender on 127.0.0.1 with an ephemeral local port\n');
        end
        sender = udpport("datagram", "IPV4");
        sender.Timeout = timeoutSeconds;
        result.sender_port = sender.LocalPort;

        if verbose
            fprintf('Sending probe message to receiver\n');
        end
        write(sender, uint8(probeMessage), "uint8", "127.0.0.1", listenPort);

        receivedProbe = wait_for_message(receiver, timeoutSeconds);
        result.received_message = receivedProbe;
        result.one_way_ok = strcmp(receivedProbe, probeMessage);

        if ~result.one_way_ok
            error('UDP loopback receive mismatch. Expected "%s", got "%s".', probeMessage, receivedProbe);
        end

        if verbose
            fprintf('Receiver got probe; sending reply back to sender port %d\n', sender.LocalPort);
        end
        write(receiver, uint8(replyMessage), "uint8", "127.0.0.1", sender.LocalPort);

        receivedReply = wait_for_message(sender, timeoutSeconds);
        result.reply_message = receivedReply;
        result.reply_ok = strcmp(receivedReply, replyMessage);

        if ~result.reply_ok
            error('UDP loopback reply mismatch. Expected "%s", got "%s".', replyMessage, receivedReply);
        end

        result.ok = true;
        result.error = "";

        if verbose
            fprintf('UDP loopback self-test passed.\n');
        end
    catch err
        result.error = string(err.message);
        if verbose
            fprintf(2, 'UDP loopback self-test failed: %s\n', err.message);
        end
    end

    cleanup_port(sender);
    cleanup_port(receiver);
end

function message = wait_for_message(portObj, timeoutSeconds)
    startTime = tic;
    while portObj.NumDatagramsAvailable == 0
        if toc(startTime) > timeoutSeconds
            error('Timed out waiting for UDP datagram.');
        end
        pause(0.01);
    end

    data = read(portObj, 1, "uint8");
    message = string(char(uint8(data(:)')));
end

function cleanup_port(portObj)
    if isempty(portObj)
        return;
    end

    try
        clear portObj;
    catch
    end
end
