classdef Rig
  properties
    osc
  end
  methods
    function obj = Rig(client)
      obj.osc = client;
    end

    function dataset(obj, path)
      obj.osc.send("/dataset",",s", path);
    end

    function experiment(obj, expid)
      obj.osc.send('/experiment',',s', expid);
    end

    function resource(obj, path)
      obj.osc.send('/resource', ',s', path);
    end
        
    function preload(obj)
      obj.osc.send('/preload', ',i', 0);
    end
        
    function clear(obj)
      obj.osc.send('/clear', ',i', 0);
    end

    function replay(obj, expid, trial)
      obj.osc.send('/replay', ',si', expid, trial)
    end

    function background(obj, color)
      obj.osc.send('/background', ',s', color)
    end

    function gratings(obj, g)
      angle = get(g, 'angle', 0.0);
      width = get(g, 'width', 20.0);
      height = get(g, 'height', 20.0);
      x = get(g, 'x', 0.0);
      y = get(g, 'y', 0.0);
        
      contrast = get(g, 'contrast', 1.0);
      opacity = get(g, 'opacity', 1.0);
      phase = get(g, 'phase', 0.0);
      freq = get(g, 'freq', 0.1);
      speed = get(g, 'speed', 0.0);
      dcycle = get(g, 'dcycle', nan);

      onset = get(g,'onset', 0.0);
      duration = get(g, 'duration', 1.0);
      obj.osc.send('/gratings', ',[fffff][ffffff][ff]', ...
                   angle, width, height, x, y, ...
                   contrast, opacity, phase, freq, speed, dcycle, ...
                   onset, duration);
    end

    function video(obj, v)
      name = v.name;
      angle = get(v, 'angle', 0.0);
      width = get(v, 'width', 20.0);
      height = get(v, 'height', 20.0);
      x = get(v, 'x', 0.0);
      y = get(v, 'y', 0.0);
        
      loop = get(v, 'loop', 1.0);
      speed = get(v, 'speed', 30.0);
        
      onset = get(v, 'onset', 0.0);
      duration = get(v, 'duration', 2.0);
        
      obj.osc.send('/video', ',[fffff][ffs][ff]', ...
                   angle, width, height, x, y, ...
                   loop, speed, name, ...
                   onset, duration);
    end

    function pulseValve(obj)
      obj.osc.send('/pulseValve', ',i', 0);
    end

    function start(obj)
      obj.osc.send('/start', ',i', 0);
    end

    function success(obj)
      obj.osc.send('/success', ',i', 0);
    end
    
    function failure(obj)
      obj.osc.send('/failure', ',i', 0);
    end
    
    function go(obj, suppress, start, duration, threshold)
      obj.osc.send('/go', ',fffi', suppress, start, duration, threshold);
    end
    
    function nogo(obj, suppress, start, duration, threshold)
      obj.osc.send('/nogo', ',fffi', suppress, start, duration, threshold);
    end

    function interaction(obj, name, type, arguments)
      obj.osc.send(sprintf('/interaction/%s', name), sprintf(',%s', type), arguments{:});
    end

    function tile(obj, t)
      wall = t.wall;
      position = get(t, 'position', 0.0);
      extent = get(t, 'extent', 1.0);
      texture = get(t, 'texture', 'Transparent');
      obj.osc.send('/tile', ',iffs', ...
                   wall, position, extent, texture);
    end
    
    function corridor(obj, c)
      length = c.length;
      width = get(c, 'width', 1.0);
      height = get(c, 'height', 1.0);
      x = get(c, 'x', 0.0);
      y = get(c, 'y', 0.0);
      position = get(c, 'position', 0.0);
      obj.osc.send('/corridor', ',ffffff', ...
                   length, width, height, x, y, position);
    end
  end
end

function b = get(a, name, default)
    if isfield(a, name)
        b = getfield(a, name);
    else
        b = default;
    end
end