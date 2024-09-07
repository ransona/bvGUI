t0.wall = Wall.Left;
t0.position = 0;
t0.extent = 2;
t0.texture = "vert";
rig.tile(t0);

t1.wall = Wall.Right;
t1.position = 0;
t1.extent = 2;
t1.texture = "vert";
rig.tile(t1);

t2.wall = Wall.Top;
t2.position = 0;
t2.extent = 2;
t2.texture = "hor";
rig.tile(t2);

t3.wall = Wall.Bottom;
t3.position = 0;
t3.extent = 2;
t3.texture = "hor";
rig.tile(t3);


t4.wall = Wall.Left;
t4.position = 2;
t4.extent = 2;
t4.texture = "dots";
rig.tile(t4);

t5.wall = Wall.Right;
t5.position = 2;
t5.extent = 2;
t5.texture = "dots";
rig.tile(t5);

t6.wall = Wall.Top;
t6.position = 2;
t6.extent = 2;
t6.texture = "dots";
rig.tile(t6);

t7.wall = Wall.Bottom;
t7.position = 2;
t7.extent = 2;
t7.texture = "dots";
rig.tile(t7);


t8.wall = Wall.Left;
t8.position = 4;
t8.extent = 2;
t8.texture = "hor";
rig.tile(t8);

t9.wall = Wall.Right;
t9.position = 4;
t9.extent = 2;
t9.texture = "hor";
rig.tile(t9);

t10.wall = Wall.Top;
t10.position = 4;
t10.extent = 2;
t10.texture = "vert";
rig.tile(t10);

t11.wall = Wall.Bottom;
t11.position = 4;
t11.extent = 2;
t11.texture = "vert";
rig.tile(t11);


t12.wall = Wall.Left;
t12.position = 6;
t12.extent = 2;
t12.texture = "check";
rig.tile(t12);

t13.wall = Wall.Right;
t13.position = 6;
t13.extent = 2;
t13.texture = "check";
rig.tile(t13);

t14.wall = Wall.Top;
t14.position = 6;
t14.extent = 2;
t14.texture = "check";
rig.tile(t14);

t15.wall = Wall.Bottom;
t15.position = 6;
t15.extent = 2;
t15.texture = "check";
rig.tile(t15);


rig.interaction('endEntry', "f", {10.0});

t16.wall = Wall.Right;
t16.position = 8;
t16.extent = 2;
t16.texture = "Black";
rig.tile(t16);

t17.wall = Wall.Left;
t17.position = 8;
t17.extent = 2;
t17.texture = "Black";
rig.tile(t17);

t18.wall = Wall.Top;
t18.position = 8;
t18.extent = 2;
t18.texture = "Black";
rig.tile(t18);

t19.wall = Wall.Bottom;
t19.position = 8;
t19.extent = 2;
t19.texture = "Black";
rig.tile(t19);




c.length = 9.0;
c.width = 1.2;
c.height = 1.0;
c.x=0.0;
c.y=0.0;
c.position=0.0;
rig.corridor(c);