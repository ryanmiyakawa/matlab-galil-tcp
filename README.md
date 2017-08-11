# About

MATLAB class for serial / GPIB communication with a Keithley 6482.  As of v1.0.1, it also supports network communication with a Moxa NPort using the `tcpclient` object.  *This class only implements part of the API that the hardware exposes.* There is an optional user interface that requires the [Matlab Instrument Control](https://github.com/cnanders/matlab-instrument-control) library.  

# Notes for using tcpclient() network communication to Moxa NPort

## Serial settings on Moxa and Keithley must match

On the Keithley, 

1. Click “Menu” -> “Communication” -> “Serial”  
2. Set all serial parameters to desired values.  

In a browser, navigate to the IP of the Moxa.  In the web-based configuration tool:

1. Click “Serial Settings” -> “Port 1” (or other port) navigation item on the left
2. Configure the Moxa to communicate with the Keithley using the parameters that were configured on the Keithley hardware.

## Data Packing

Serial data sent from the Keithley to the NPort accumulates in the NPort’s serial buffer until one of two things happen

1. The buffer fills up to the specified `Packing Length` value.  *Note, however, that when `Packing Length` is set to zero, the NPort immediately packs serial data for network transmission.*
2. The configured delimiter character(s) are received *When this option is enabled, `Packing Length` parameter has no effect.*


After the enabled criteria is satisfied the data is packed for network transmission from the Moxa NPort to the client. 

The simplest solution is to set `Packing Length` to zero and do not bother with delimeters.  In this case, any time the Keithley sends the NPort serial data, that data is immediately packet for network transmission from Moxa NPort to the MATLAB `tcpclient` instance, increasing the `BytesAvailable` property of the `tcpclient`.  

The downside of this approach is that sometimes a single “response” from the Keithley is separated into multiple network packets from Moxa NPort to the MATLAB `tcpclient`, but this is not a big deal.

### Configuring Data Packing to Use Delimiters (Optional)

If you want to configure data packing to use delimiters, here is a recommended setup. 
- Configure the Keithley to use a carriage return terminator. Recall that ASCII is a 8-bit character system (256 characters).  The base10 representation of the carriage return character is 13, which is 0D in hex, or 00001101 in binary.  
- Once the Keithley is configured to use a carriage return terminator, set the NPort “Operation Settings” -> Data Packing -> Delimiter 1 to “0d” (hex) and enable it.  
- Once enabled, Moxa NPort will buffer all serial data sent from the Keithley (possibly over multiple transmissions) until the carriage return is received from the Keithley, after which the data is packed for network transmisison. 

# Requirements

MATLAB Instrument Control Toolbox (GPIB only, serial protocol does not require the additional toolbox)

# Optional

[cnanders/matlab-instrument-control](https://github.com/cnanders/matlab-instrument-control) (to create the UI)