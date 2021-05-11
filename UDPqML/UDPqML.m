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
        udpObject;
        lastData=[];
        lastPulledData = [];
        debugMode = 1;
        cleanupObj = [];
    end
    
    methods
        function obj=UDPqML(remoteHost,remotePort,localPort)
            % constructor
            % setup UDP stuff
            obj.debugMessage(('Starting UDP object'));
            obj.udpObject = udp(remoteHost,'RemotePort',remotePort,'LocalPort',localPort);
            obj.udpObject.DatagramReceivedFcn = @obj.DatagramReceivedFcn;
            obj.udpObject.InputBufferSize = 2^13;
            obj.udpObject.OutputBufferSize = 2^13;
            
            obj.cleanupObj = onCleanup(@obj.delete);
            
            obj.open;
        end
        
        function debugMessage(obj,debugString)
            if obj.debugMode
                disp(debugString);
            end
        end     
        
        function delete(obj)
            % destructor
            warning('off','all');
            obj.debugMessage(('Deleting UDP object'));
            if strcmp(obj.udpObject.status,'open')
                fclose(obj.udpObject);
            end
            % unbind all port instruments
%             u=instrfindall('RemotePort',obj.udpObject.RemotePort,...
%                            'RemoteHost',obj.udpObject.RemoteHost);
%             delete(u);
            delete('obj.udpObject');
            clear('obj.udpObject');
            warning('on','all');
        end
        
        function nextData = pull(obj)
            if ~isempty(obj.lastData)
                nextData = obj.lastData;
                obj.lastPulledData = obj.lastData;
                obj.lastData = [];
            else
                nextData = [];
            end
        end
        
        function [success, nextData] = waitForData(obj,timeout)
            startTime = tic;
            obj.debugMessage(('Awaiting data'));
            while isempty(obj.lastData)
                drawnow;
                if (toc(startTime))>timeout
                    % timed out
                    obj.debugMessage(('Timed out'));
                    success = 0;
                    nextData = [];
                end
            end
            % new data has arrived
            obj.debugMessage(('Data arrived'));
            nextData = obj.pull;
            success = 1;
        end
        
        function empty(obj)
            obj.queuedCmds = [];
            obj.queuedData = [];
        end
        
        function DatagramReceivedFcn(obj,~,datagram)
            % read data
            dataIn = fread(obj.udpObject);
            % deserialise data into a matlab struct
            dataInDeserialised = hlp_deserialize(dataIn);
            dataInDeserialised.origin = datagram.Data.DatagramAddress;
            obj.lastData = dataInDeserialised;
            obj.debugMessage(('Data received'));
            if dataInDeserialised.confirm == 1
                % send a confirmation back
                obj.debugMessage(('Sending confirmation'));
                obj.send([],'OK',0,dataInDeserialised.confirmID);
            end
        end
        
        function confirmed = awaitConfirm(obj,timeout,confirmID)
            startTime = tic;
            obj.debugMessage(('Awaiting confirmation'));
            while(toc(startTime)<timeout)
                % check if confirmation message has come through
                pulledData = obj.pull;
                if ~isempty(pulledData)
                    if strcmp(pulledData.messageType,'OK')
                        % confirmation received
                        % check the ID is correct
                        if pulledData.confirmID == confirmID
                            % then confirmation is received
                            confirmed = 1;
                            obj.debugMessage(('Confirmation received'));
                            return;
                        else
                            obj.debugMessage(('Confirmation received BUT wrong ID to disregarding - something is going wrong!'));
                        end
                    end
                end
            end
            % if we get here then no suitable confirmation has come through
            confirmed = 0;
        end
        
        function ready = awaitReady(obj,timeout)
            % waits for a server to send a "READY" command whic might be
            % used for example to confirm that a DAQ has starts, i.e. not
            % simply that the UDP command has been received.
            startTime = tic;
            obj.debugMessage(('Awaiting ready confirmation'));
            while(toc(startTime)<timeout)
                % check if confirmation message has come through
                drawnow;
                pulledData = obj.pull;
                if ~isempty(pulledData)
                    if strcmp(pulledData.messageType,'COM')
                        % command received
                        if strcmp(pulledData.messageData,'READY')
                            ready = 1;
                            obj.debugMessage('Confirmation received');
                            return;
                        else
                            disp('WARNING: Command missed while waiting for ready');
                        end
                    end
                end
            end
            % if we get here then no suitable confirmation has come through
            ready = 0;
        end
        
        
        function open(obj)
            % open connection
            obj.debugMessage(('Opening connection'));
            obj.openConnection
        end
        
        function setRemote(obj,remoteHost,remotePort)
            % closes any current connections and connects to a new remote host
            obj.debugMessage(('Setting remote'));
            if strcmp(obj.udpObject.status,'open')
                % close connection
                fclose(obj.udpObject);
            end
            obj.udpObject.remoteHost = remoteHost;
            obj.udpObject.remotePort = remotePort;
            
            % open connection
            obj.openConnection
        end
        
        function setLocalPort(obj,localPort)
            % closes any current connections and connects to a new remote host
            obj.debugMessage(('Setting local port'));
            if strcmp(obj.udpObject.status,'open')
                % close connection
                fclose(obj.udpObject);
            end
            
            obj.udpObject.localPort = localPort;
            
            % open connection
            obj.openConnection
        end
        
        function openConnection(obj)
            % opens connection using current configuration
            try
                % unbind port
                preRemotePort = obj.udpObject.RemotePort;
                preRemoteHost = obj.udpObject.RemoteHost;
                preLocalPort  = obj.udpObject.LocalPort ;
                
                obj.udpObject.RemotePort = 1;
                obj.udpObject.RemoteHost = '';
                obj.udpObject.LocalPort  = 1;
                
                
                u=instrfindall('RemotePort',preRemotePort,...
                               'RemoteHost',preRemoteHost);
                if length(u)>0
                    delete(u);
                    disp('Warning: port was bound when tried to open, so closed');
                end
                
                obj.udpObject.RemotePor = preRemotePort;
                obj.udpObject.RemoteHost = preRemoteHost;
                obj.udpObject.LocalPort = preLocalPort;
                % obj.udpObject.EnablePortSharing = 'on';
                fopen(obj.udpObject);
                
            catch
                disp('Failed to open UDP connection');
            end
        end
        
        function closeConnection(obj)
            % closes connection using current configuration
            obj.debugMessage(('Closing connection'));
            try
                fclose(obj.udpObject);
            catch
                disp('Failed to close UDP connection');
            end
        end

        function success = send(obj,messageData,messageType,confirm,confirmID,remoteHost,remotePort)
            % for sending strings (i.e. not matlab structs)
            obj.debugMessage('Sending UPD');
            if exist('remoteHost','var') && exist('remotePort','var')
                % then close any existing connection and connect to new
                % remote host
                obj.setRemote(remoteHost,remotePort);
            end
            
            % if connection is closed then open connection
            if strcmp(obj.udpObject.status,'closed')
                % open connection
                obj.openConnection
            end
            
            % convert the message from matlab struct to uint8
            messageStruct.messageData = messageData;
            messageStruct.messageType = messageType;
            
            % if the message type is a "COM" (command) parse into the
            % command itself and it's arguments
            if strcmp(messageStruct.messageType,'COM')
                % then parse
                messageData=strsplit(messageData,'*');
                messageStruct.messageData = messageData{1};
                if length(messageData)>2
                    messageStruct.meta = messageData(2:end);
                elseif length(messageData)>1
                    messageStruct.meta        = messageData(2);
                end
            end
            
            if exist('confirm','var')
                messageStruct.confirm = confirm;
                if exist('confirmID','var')
                    % confirmation ID has been passed in
                    messageStruct.confirmID = confirmID;
                    obj.debugMessage((['Confirmation ID: ',num2str(messageStruct.confirmID)]));
                else
                    % generate random confirmation ID
                    messageStruct.confirmID = round(rand*10^6);
                    obj.debugMessage((['Confirmation ID: ',num2str(messageStruct.confirmID)]));
                end
                
            else
                messageStruct.confirm = 0;
            end
            
            messageStructSerial = hlp_serialize(messageStruct);
            
            % send message
            fwrite(obj.udpObject,messageStructSerial,'uint8');
            
            if exist('confirm','var')
                if confirm == 1
                    % wait for confirmation message to come through
                    timeout = 30; % secs
                    success = obj.awaitConfirm(timeout,messageStruct.confirmID);
                else
                    % just send message into ether
                    success = 1;
                end
            else
                success = 1;
            end
            
        end
        
    end
    
end

