addpath('../src');


g = galilTCP.GalilTCP2Ch('cTcpipHost', '192.168.10.150', 'u16TcpipPort',uint16(23), 'axes', [2, 3]);



com = g.comm;

%% Read pos B:
raw = read(com, com.BytesAvailable, 'uint8')
write(com, [uint8('TPB'), uint8(13)]);
pause(0.1)
raw = read(com, com.BytesAvailable, 'uint8');
valAr = str2double(split(strtrim(char(raw))));
val = valAr(1)



%% Read pos C:
raw = read(com, com.BytesAvailable, 'uint8')
write(com, [uint8('TPC'), uint8(13)]);
pause(0.1)
raw = read(com, com.BytesAvailable, 'uint8')
valAr = str2double(split(strtrim(char(raw))));
val = valAr(1)


%% Read both:
raw = read(com, com.BytesAvailable, 'uint8')

write(com, [uint8('TP B C'), uint8(13)]);
pause(0.1)
raw = read(com, com.BytesAvailable, 'uint8')
valAr = str2double(split(strtrim(char(raw))));
val = valAr(1:2)


%% Write position

% write to motor B
write(com, [uint8('PA, 500'), uint8(13)]);
write(com, [uint8('BG B'), uint8(13)]);


% write to motor C
write(com, [uint8('PA,, 0'), uint8(13)]);
write(com, [uint8('BG C'), uint8(13)]);



%% Turn motors on:
write(com, [uint8('SH C'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')


%% stop program
write(com, [uint8('ST'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')


%% Run program
write(com, [uint8('posA1=0'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')

write(com, [uint8('posA2=8000'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')

write(com, [uint8('posB1=0'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')

write(com, [uint8('posB2=8000'), uint8(13)]);

write(com, [uint8('waitA=1000'), uint8(13)]);
write(com, [uint8('waitB=1000'), uint8(13)]);

write(com, [uint8('speed=30000'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')


write(com, [uint8('XQ#wobble'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')



%% Set encoder value:
write(com, [uint8('DP,0,0'), uint8(13)]);
raw = read(com, com.BytesAvailable, 'uint8')



