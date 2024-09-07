classdef OscTcp < Osc
  properties
    client
    size = 0;
  end
  methods
    
    function obj = OscTcp(varargin)
      if nargin < 2
        error(["Invalid call. Use oscsend(u,path,types,arg1,arg2,...)"]);
      end
      obj.client = tcpclient(varargin{1}, varargin{2}, 'timeout', 1000);
    end
    
    function send(obj, varargin)
      if nargin < 2
        error(["Invalid call. Use oscsend(u,path,types,arg1,arg2,...)"]);
      end
      message = Osc.format(varargin{:});
      len = fliplr(typecast(uint32(length(message)),'uint8'));
      write(obj.client, [len message]);
    end
     
    function message = receive(obj)
      message = [];
      if (obj.size == 0 && obj.client.BytesAvailable > 3)
        datagram = read(obj.client,4);
        obj.size = typecast(uint8(fliplr(datagram)),'uint32');
      end
      if (obj.size > 0 && obj.client.BytesAvailable >= obj.size)
        datagram = read(obj.client,obj.size);
        obj.size = 0;
        message = Osc.parse(datagram);
      end
    end
    
    function delete(obj)
      % free up any resources, although there is no instruction to close
      % tcpclient connection
      delete(obj.client);
    end
  end
end