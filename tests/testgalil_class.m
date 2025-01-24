addpath('../src');


g = galilTCP.GalilTCP2Ch('cTcpipHost', '192.168.10.150', 'u16TcpipPort',uint16(23), 'axes', [2, 3]);




%% Read pos B:
g.getAbs(1)


%% Read pos C:
g.getAbs(2)


%% Read both:
g.getAbs(1:2)



%% Write position

g.moveAbs(1, 1000);

g.moveAbs(2, 1000);

pause(0.5);
g.getAbs(1:2)



%% Turn motors on:
write(com, [uint8('SH C'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')


%% stop program
g.stop();


%% Run program

g.writeParameter('posA1', -2000);
g.writeParameter('posA2', 2000);

g.writeParameter('posB1', -2000);
g.writeParameter('posB2', 2000);

g.writeParameter('waitA', 1000);
g.writeParameter('waitB', 1000);

g.writeParameter('speed', 30000);




g.executeWobble();


%% Set encoder value:
write(com, [uint8('DP,0,0'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')



