
metadata = sprintf('%s_S1', datetime(datenum(datetime('now')),'Format','yyyy-MM-dd_HH-mm-ss','convertFrom','datenum'));
osc = OscTcp('158.109.215.49', 4002);
%osc = OscUdp('158.109.215.49',4002,4007);
rig = Rig(osc);
rig.clear();

iStim = 0;
while true
  rig.experiment(metadata);
  
  t0.wall = Wall.Left;
  t0.position = 0;
  t0.extent = 1;
  t0.texture = "cat1";
  rig.tile(t0);

  t1.wall = Wall.Right;
  t1.position = 0;
  t1.extent = 1;
  t1.texture = "Black";
  rig.tile(t1);

  t2.wall = Wall.Left;
  t2.position = 1;
  t2.extent = 1;
  t2.texture = "White";
  rig.tile(t2);

  t3.wall = Wall.Right;
  t3.position = 1;
  t3.extent = 1;
  t3.texture = "Black";
  rig.tile(t3);

  t4.wall = Wall.Left;
  t4.position = 2;
  t4.extent = 1;
  t4.texture = "Black";
  rig.tile(t4);

  rig.interaction('endEntry', "f", {2000.0});
  t5.wall = Wall.Left;
  t5.position = 2;
  t5.extent = 1;
  t5.texture = "White";   
  rig.tile(t5);

  c.length = 3.0;
  c.width = 1.2;
  c.height = 1.0;
  c.x=0.0;
  c.y=0.0;
  c.position=2.5;
  
  rig.corridor(c);
  
  datagram = [];
  while(isempty(datagram))
      datagram = osc.receive();
  end
  disp(datagram);
end

