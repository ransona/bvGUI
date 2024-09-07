classdef Osc < handle
  methods (Abstract)
    send(obj, varargin)
    message = receive(obj)
  end
  methods (Static)
    function s = oscstr(str)
      str = char(str);
      s = uint8(str);
      l = length(str) + 1;
      pad = mod(4 - mod(l,4),4);
      s(l + pad) = 0;
    end

    function message = parse(oscMessage)
      str = sprintf('%s',oscMessage);
      strList = strsplit(str,",");
      tmp = strsplit(strList{1},'\0');
      i = 1;
      message{i} = tmp{1};
      
      if length(strList) > 1
        types = strsplit(strList{2},'\0');
        offset = length(types{1}) + 2 + length(strList{1}) + 1;
        for count = 1:length(types{1})
          code = types{1}(count);
          if code == 'i'
            value = typecast(uint8(fliplr(oscMessage(offset:offset+3))), 'uint32');
            offset = offset + 4;
          elseif code == 'f'
            value = typecast(uint8(fliplr(oscMessage(offset:offset+3))), 'single');
            offset = offset + 4;
          elseif code == 's'
            strTmp = strsplit(extractAfter(str, offset),'\0');
            % the offset still needs to be tested
            offset = offset + length(strTmp) + 2;
            strTmp = strtrim(strTmp);
            value = strTmp{1};
          else
            error("Unsupported type tag.");
          end
          i = i+1;
          message{i} = value;
        end
      end
    end
    
    function oscMessage = format(varargin)
      if nargin < 2
        error(["Invalid call. Use oscFormatMessage(path,types,arg1,arg2,...)"]);
      end
      path = Osc.oscstr(varargin{1});
      types = char(varargin{2});
      data = [];
      offset = 3;
      for i = 2:length(types)
        code = types(i);
        if code == 'i'
          value = fliplr(typecast(uint32(varargin{offset}),'uint8'));
        elseif code == 'f'
          value = fliplr(typecast(single(varargin{offset}),'uint8'));
        elseif code == 's'
          value = Osc.oscstr(varargin{offset});
        elseif code == '['
          continue
        elseif code == ']'
          continue
        else
          error("Unsupported type tag.");
        end
        offset = offset + 1;
        data = [data value];
      end
      types = Osc.oscstr(types);
      oscMessage = [path types data];
    end
  end
end