[cDirThis, cName, cExt] = fileparts(mfilename('fullpath'));

% Add keithley package
addpath(genpath(fullfile(cDirThis, '..')));


inst = keithley.Keithley6482Virtual();
inst.init()
inst.connect()
inst.identity()


inst.setAverageCount(1, 45)
inst.getAverageCount(1)

inst.setAverageState(1, 'ON')
inst.getAverageState(1)

inst.setIntegrationPeriodPLC(1)
inst.getIntegrationPeriod
