function data = harpread(filename)
    fid = fopen(filename,'r');                          % open the binary file
    cleanupObj = onCleanup(@() fclose(fid))             % ensure file handle gets closed
    data = fread(fid,'*uint8');                         % read data as raw binary
    stride = data(2) + 2;                               % size of each message
    count = length(data) / int32(stride);               % number of messages in file
    payloadsize = stride - 12;                          % size of each message payload
    payloadtype = bitand(data(5), bitcmp(uint8(0x10))); % the type of payload data
    elementsize = bitand(payloadtype, uint8(0x3));      % the size in bytes of each element
    payloadshape = [count, payloadsize / elementsize];  % the dimensions of the data matrix
    messages = reshape(data, stride, count);            % structure all message data
    seconds = typecast(reshape(messages(6:9, :),[],1), 'uint32');  % the seconds part of the timestamp
    ticks = typecast(reshape(messages(10:11, :),[],1), 'uint16');  % the 32-microsecond ticks part of each timestamp
    seconds = double(ticks) * 32e-6 + double(seconds);  % the message timestamp

    payload = messages(12:12 + payloadsize - 1, :);     % extract the payload data
    switch payloadtype                                  % get the payload data type
    case 1
        dtype = 'uint8';
    case 2
        dtype = 'uint16';
    case 4
        dtype = 'uint32';
    case 8
        dtype = 'uint64';
    case 129
        dtype = 'int8';
    case 130
        dtype = 'int16';
    case 132
        dtype = 'int32';
    case 136
        dtype = 'int64';
    case 68
        dtype = 'float32';
    end

    payload = typecast(payload(:), dtype);              % convert payload data type
    payload = reshape(payload, elementsize, count)';    % reshape into final data matrix
    data = [seconds double(payload)];                   % convert data to double and return
end 
