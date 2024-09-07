metadata = sprintf('%s_S1', datetime(datenum(datetime('now')),'Format','yyyy-MM-dd_HH-mm-ss','convertFrom','datenum'));
osc = OscTcp('158.109.215.49', 4002);
%osc = OscUdp('158.109.215.49',4002,4007);
rig = Rig(osc);

rig.resource("Videos/Blink");
rig.preload();

rig.experiment(metadata);
g1.width = 30;
g1.height = 30;
g1.x = -15;
g1.y = -5;
g1.angle = 0;
g1.freq = 0.1;
g1.duration = 2.0;
g1.speed = 0;
rig.gratings(g1); % grating 1


g2.width = 15;
g2.height = 15;
g2.x = 15;
g2.y = -5;
g2.angle = 45;
g2.freq = 0.1;
g2.duration = 2.0;
g2.speed = 1;
rig.gratings(g2); % grating 2

v.name = "Blink";
v.y = 20;
v.speed = 2.0;
v.onset = 1.0;
v.duration = 2.0;
rig.video(v); % video 1
rig.start();

datagram = [];
while(isempty(datagram))
    datagram = osc.receive();
end
disp(datagram);

rig.clear();

rig.experiment(metadata)
rig.pulseValve()
rig.success()
gg.width = 120;
gg.height = 120;
gg.angle = 30;
gg.freq = 0.1;
gg.duration = 2.0;
rig.gratings(gg); % go gratings
rig.go(1000, 500, 1000, 2); % go trial
% Wait for end trial
datagram = [];
while(isempty(datagram))
    datagram = osc.receive();
end
disp(datagram);

rig.experiment(metadata)
ng.width = 120;
ng.height = 120;
ng.angle = 0;
ng.freq = 0.1;
ng.duration = 2.0;
rig.gratings(ng); % nogo gratings
rig.nogo(500, 500, 1000, 1); % no-go trial
% Wait for end trial
datagram = [];
while(isempty(datagram))
    datagram = osc.receive();
end
disp(datagram);

rig.experiment(metadata)
rig.interaction('rewardLick', "ii", {2, 1}); % lickthreshold, max activations
rig.interaction('endLick', "if", {3, 3000.0}); % lickthreshold, delay
t0.wall = Wall.Left;
t0.position = 0;
t0.extent = 1;
t0.texture = "White";
rig.tile(t0);

t1.wall = Wall.Right;
t1.position = 0;
t1.extent = 1;
t1.texture = "Black";
rig.tile(t1);

rig.interaction('teleportLick', "fii", {0.0, 3, 3});
t2.wall = Wall.Left;
t2.position = 1;
t2.extent = 1;
t2.texture = "Black";
rig.tile(t2);

rig.interaction('rewardEntry', "fi", {1000.0, 2});
t3.wall = Wall.Right;
t3.position = 1;
t3.extent = 1;
t3.texture = "White";
rig.tile(t3);

rig.interaction('endEntry', "f", {2000.0});
t4.wall = Wall.Left;
t4.position = 2;
t4.extent = 1;
t4.texture = "White";   
rig.tile(t4);

rig.interaction('teleportEntry', "fi", {0.0, 2});
t5.wall = Wall.Right;
t5.position = 2;
t5.extent = 1;
t5.texture = "Black";
rig.tile(t5);

rig.interaction('gainEntry', "fi", {0.1, 1});
t6.wall = Wall.Top;
t6.position = 1;
t6.extent = 1;
t6.texture = "Black";
rig.tile(t6);

c.length = 3.0;
c.width = 1.2;
c.height = 1.0;
c.x=0.0;
c.y=0.0;
c.position=0.0;
rig.corridor(c);
% Wait for end trial
datagram = [];
while(isempty(datagram))
    datagram = osc.receive();
end
disp(datagram);

rig.experiment(metadata)
rig.replay(metadata, 3)
% Wait for end trial
datagram = [];
while(isempty(datagram))
    datagram = osc.receive();
end
disp(datagram);

osc.delete();