# About

MATLAB class for serial communication with a Keithley 6482.  

- v1.0.0 supports `MATLAB.serial`
- As of v1.0.1, supports network communication with a Moxa NPort using the `MATLAB.tcpclient` object.  

*This class only implements part of the API that the hardware exposes.* There is an optional user interface that requires the [Matlab Instrument Control](https://github.com/cnanders/matlab-instrument-control) library.  

# Notes for using tcpclient() network communication to Moxa NPort

See [https://github.com/cnanders/matlab-moxa-nport-notes](https://github.com/cnanders/matlab-moxa-nport-notes)

# Requirements

MATLAB Instrument Control Toolbox (GPIB only, serial protocol does not require the additional toolbox)

# Optional

[cnanders/matlab-instrument-control](https://github.com/cnanders/matlab-instrument-control) (to create the UI)