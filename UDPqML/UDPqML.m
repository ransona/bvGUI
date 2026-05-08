classdef UDPqML < handle
    % class for receiving udp events
    % events are NOT queued
    % events are Matlab structures
    % events have timestamps of arrival time
    % events have a 'type' field which indicates type of message:
    % types:
    % 'DAT' - data such as stim properties.
    % 'OK'  - a confirmation of data received.
    % 'COM' - a command.

    properties
        %% UDP stuff
        udpObject = [];
        remoteHost = '';
        remotePort = [];
        localPort = [];
        isOpen = false;
        lastData = [];
        lastPulledData = [];
        debugMode = 1;
    end

    methods
        function obj = UDPqML(remoteHost, remotePort, localPort)
            % constructor
            obj.debugMessage('Starting UDP object');
            obj.remoteHost = remoteHost;
            obj.remotePort = remotePort;
            obj.localPort = localPort;
            obj.open();
        end

        function debugMessage(obj, debugString)
            if obj.debugMode
                disp(debugString);
            end
        end

        function delete(obj)
            % destructor
            warning('off', 'all');
            obj.debugMessage('Deleting UDP object');
            obj.closeConnection();
            warning('on', 'all');
        end

        function nextData = pull(obj)
            obj.pollIncoming();
            if ~isempty(obj.lastData)
                nextData = obj.lastData;
                obj.lastPulledData = obj.lastData;
                obj.lastData = [];
            else
                nextData = [];
            end
        end

        function [success, nextData] = waitForData(obj, timeout)
            startTime = tic;
            obj.debugMessage('Awaiting data');
            while isempty(obj.lastData)
                obj.pollIncoming();
                drawnow;
                if toc(startTime) > timeout
                    obj.debugMessage('Timed out');
                    success = 0;
                    nextData = [];
                    return;
                end
            end

            obj.debugMessage('Data arrived');
            nextData = obj.pull();
            success = 1;
        end

        function empty(obj)
            obj.lastData = [];
            obj.lastPulledData = [];
        end

        function confirmed = awaitConfirm(obj, timeout, confirmID)
            startTime = tic;
            obj.debugMessage('Awaiting confirmation');
            while toc(startTime) < timeout
                obj.pollIncoming();
                pulledData = obj.pull();
                if ~isempty(pulledData) && isfield(pulledData, 'messageType') && strcmp(pulledData.messageType, 'OK')
                    if pulledData.confirmID == confirmID
                        confirmed = 1;
                        obj.debugMessage('Confirmation received');
                        return;
                    else
                        obj.debugMessage('Confirmation received BUT wrong ID to disregarding - something is going wrong!');
                    end
                end
                drawnow;
                pause(0.01);
            end

            confirmed = 0;
        end

        function ready = awaitReady(obj, timeout)
            % waits for a server to send a "READY" command which might be
            % used for example to confirm that a DAQ has started.
            startTime = tic;
            obj.debugMessage('Awaiting ready confirmation');
            while toc(startTime) < timeout
                obj.pollIncoming();
                drawnow;
                pulledData = obj.pull();
                if ~isempty(pulledData) && isfield(pulledData, 'messageType') && strcmp(pulledData.messageType, 'COM')
                    if strcmp(pulledData.messageData, 'READY')
                        ready = 1;
                        obj.debugMessage('Confirmation received');
                        return;
                    else
                        disp('WARNING: Command missed while waiting for ready');
                    end
                end
                pause(0.01);
            end

            ready = 0;
        end

        function open(obj)
            obj.debugMessage('Opening connection');
            obj.openConnection();
        end

        function setRemote(obj, remoteHost, remotePort)
            obj.debugMessage('Setting remote');
            obj.remoteHost = remoteHost;
            obj.remotePort = remotePort;
            if obj.isOpen
                obj.closeConnection();
                obj.openConnection();
            end
        end

        function setLocalPort(obj, localPort)
            obj.debugMessage('Setting local port');
            obj.localPort = localPort;
            if obj.isOpen
                obj.closeConnection();
                obj.openConnection();
            end
        end

        function openConnection(obj)
            % opens connection using current configuration
            try
                obj.closeConnection();
                obj.udpObject = udpport("datagram", "IPV4", "LocalPort", obj.localPort);
                obj.udpObject.Timeout = 30;
                obj.isOpen = true;
            catch
                obj.isOpen = false;
                disp('Failed to open UDP connection');
            end
        end

        function closeConnection(obj)
            % closes connection using current configuration
            obj.debugMessage('Closing connection');
            if isempty(obj.udpObject)
                obj.isOpen = false;
                return;
            end

            try
                configureCallback(obj.udpObject, "off");
            catch
            end

            try
                clear obj.udpObject;
            catch
            end

            obj.udpObject = [];
            obj.isOpen = false;
        end

        function success = send(obj, messageData, messageType, confirm, confirmID, remoteHost, remotePort)
            % for sending strings (i.e. not matlab structs)
            obj.debugMessage('Sending UDP');
            if exist('remoteHost', 'var') && exist('remotePort', 'var')
                obj.setRemote(remoteHost, remotePort);
            end

            if ~obj.isOpen || isempty(obj.udpObject)
                obj.openConnection();
            end

            % convert the message from matlab struct to uint8
            messageStruct.messageData = messageData;
            messageStruct.messageType = messageType;

            % if the message type is a "COM" (command) parse into the
            % command itself and its arguments
            if strcmp(messageStruct.messageType, 'COM')
                messageData = strsplit(messageData, '*');
                messageStruct.messageData = messageData{1};
                if length(messageData) > 2
                    messageStruct.meta = messageData(2:end);
                elseif length(messageData) > 1
                    messageStruct.meta = messageData(2);
                end
            end

            if exist('confirm', 'var')
                messageStruct.confirm = confirm;
                if exist('confirmID', 'var')
                    messageStruct.confirmID = confirmID;
                    obj.debugMessage(['Confirmation ID: ', num2str(messageStruct.confirmID)]);
                else
                    messageStruct.confirmID = round(rand * 10^6);
                    obj.debugMessage(['Confirmation ID: ', num2str(messageStruct.confirmID)]);
                end
            else
                messageStruct.confirm = 0;
            end

            messageStructSerial = hlp_serialize(messageStruct);
            write(obj.udpObject, uint8(messageStructSerial), "uint8", obj.remoteHost, obj.remotePort);

            if exist('confirm', 'var') && confirm == 1
                timeout = 30; % secs
                success = obj.awaitConfirm(timeout, messageStruct.confirmID);
            else
                success = 1;
            end
        end

        function pollIncoming(obj)
            if ~obj.isOpen || isempty(obj.udpObject)
                return;
            end

            while obj.udpObject.NumBytesAvailable > 0
                dataIn = read(obj.udpObject, obj.udpObject.NumBytesAvailable, 'uint8');
                if isempty(dataIn)
                    return;
                end

                dataInDeserialised = hlp_deserialize(uint8(dataIn));
                if isstruct(dataInDeserialised)
                    dataInDeserialised.origin = '';
                end
                obj.lastData = dataInDeserialised;
                obj.debugMessage('Data received');

                if isstruct(dataInDeserialised) && isfield(dataInDeserialised, 'confirm') && dataInDeserialised.confirm == 1
                    obj.debugMessage('Sending confirmation');
                    if isfield(dataInDeserialised, 'confirmID')
                        obj.send([], 'OK', 0, dataInDeserialised.confirmID);
                    else
                        obj.send([], 'OK', 0);
                    end
                end
            end
        end
    end
end
