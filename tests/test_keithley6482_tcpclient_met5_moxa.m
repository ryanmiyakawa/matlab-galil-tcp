[cDirThis, cName, cExt] = fileparts(mfilename('fullpath'));
cDirSrc = fullfile(cDirThis,  '..', 'src');
% Add keithley package
addpath(genpath(cDirSrc));

cTcpipHost = '192.168.20.28';
u16TcpipPort = uint16(4002);

device = keithley.Keithley6482(...
    'cTcpipHost', cTcpipHost, ...
    'u16TcpipPort', u16TcpipPort ...
);
device.init()
device.connect()

device.identity()
device.disconnect();

%{
device.getSingleMeasurement()

u8AverageCount1 = device.getAverageCount(1)
device.setAverageCount(1, 3)
u8AverageCount1 = device.getAverageCount(1)

cAutoRange1B = device.getAutoRangeState(1)
cAutoRange2B = device.getAutoRangeState(2)

device.setAutoRangeState(1, 'off')

cAutoRange1A = device.getAutoRangeState(1)
cAutoRange2A = device.getAutoRangeState(2)
%}