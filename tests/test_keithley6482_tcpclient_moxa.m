[cDirThis, cName, cExt] = fileparts(mfilename('fullpath'));
cDirSrc = fullfile(cDirThis, '..', 'src');

addpath(genpath(cDirSrc));


cTcpipHost = '192.168.20.28';
u16TcpipPort = uint16(4002);
   
try
    api = keithley.Keithley6482(...
        'cTcpipHost', cTcpipHost, ...
        'u16TcpipPort', u16TcpipPort, ...
        'lDebug', true ...
    );
    
catch mE
    getReport(mE)
    return;
end
  
api.connect()
api.identity()
api.disconnect()


%{
api.getSingleMeasurement()

u8AverageCount1 = api.getAverageCount(1)
api.setAverageCount(1, 3)
u8AverageCount1 = api.getAverageCount(1)

cAutoRange1B = api.getAutoRangeState(1)
cAutoRange2B = api.getAutoRangeState(2)

api.setAutoRangeState(1, 'off')

cAutoRange1A = api.getAutoRangeState(1)
cAutoRange2A = api.getAutoRangeState(2)
%}