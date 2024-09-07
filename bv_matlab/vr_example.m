tfloor.wall = Wall.Bottom;
tfloor.position = 3;
tfloor.extent = 6;
tfloor.texture = "cat1";
rig.tile(tfloor);

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

t2.wall = Wall.Left;
t2.position = 1;
t2.extent = 1;
t2.texture = "Black";
rig.tile(t2);

t3.wall = Wall.Right;
t3.position = 1;
t3.extent = 1;
t3.texture = "White";
rig.tile(t3);

t4.wall = Wall.Left;
t4.position = 2;
t4.extent = 1;
t4.texture = "White";
rig.tile(t4);

t5.wall = Wall.Right;
t5.position = 2;
t5.extent = 1;
t5.texture = "Black";   
rig.tile(t5);




t6.wall = Wall.Left;
t6.position = 3;
t6.extent = 1;
t6.texture = "White";
rig.tile(t6);

t7.wall = Wall.Right;
t7.position = 3;
t7.extent = 1;
t7.texture = "Black";
rig.tile(t7);

t8.wall = Wall.Left;
t8.position = 4;
t8.extent = 1;
t8.texture = "Black";
rig.tile(t8);

t9.wall = Wall.Left;
t9.position = 4;
t9.extent = 1;
t9.texture = "Black";
rig.tile(t9);

t10.wall = Wall.Left;
t10.position = 5;
t10.extent = 1;
t10.texture = "White";
rig.tile(t10);

t11.wall = Wall.Right;
t11.position = 5;
t11.extent = 1;
t11.texture = "Black";   
rig.tile(t11);




t12.wall = Wall.Left;
t12.position = 6;
t12.extent = 1;
t12.texture = "cat1";
rig.tile(t12);

rig.interaction('endEntry', "f", {2000.0});
t13.wall = Wall.Right;
t13.position = 6;
t13.extent = 1;
t13.texture = "cat1";   
rig.tile(t13);

c.length = 6.0;
c.width = 1.2;
c.height = 3;
c.x=0.0;
c.y=0.0;
c.position=1;
rig.corridor(c);