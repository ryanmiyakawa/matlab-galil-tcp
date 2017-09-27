classdef Keithley6482 < keithley.AbstractKeithley6482

    % Troubleshooting
    %
    % If this class issues timeout warnings, it is a communication error.
    % Check the the following are working properly:
    % - NPort (serial to ethernet)
    % - Routers
    % - Keithley
    %
    % For read speed, the BaudRate is generally not the limiting factor.
    % There is overhead on the instrument between the measure command and
    % the fscanf
    
    properties (Constant)
        
        cCONNECTION_SERIAL = 'serial'
        cCONNECTION_TCPCLIENT = 'tcpclient'
        
    end
    
    properties % (Access = private)
     
        % {char 1xm}
        cConnection % cCONNECTION_SERIAL | cCONNECTION_TCPCLIENT
        
        % {tcpip 1x1} tcpip connection 
        % MATLAB talks to nPort 5150A Serial Device Server over tcpip.
        % The nPort then talks to the MMC-103 using RS-485 BUS
        comm
        
        % {char 1xm} port of MATLAB {serial}
        cPort = 'COM2'
        
        % {char 1xm} terimator of MATLAB {serial}. Must match hardware
        % To set on hardware: menu --> communication --> rs-232 --> terminator
        % Short is better for communication; each character is ~ 10 bits.
        cTerminator = 'CR'  % 'CR/LF'
        
        % {uint16 1x1} - baud rate of MATLAB {serial}.  Must match hardware
        % to set on hardware: menu --> communication --> rs-232 -> baud
        u16BaudRate = uint16(57600);
        
        % {double 1x1} - timeout of MATLAB {serial, tcpip, tcpclient} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2
        
        dPLCMax = 10;
        dPLCMin = 0.01;
        
        % {double 1x1} storate for number of calls to getData()
        dCount = 0;
        
        
        % {logical 1x1} use manually created binary data packets with tcpip 
        % uses fwrite instead of fprintf
        lManualPacket = false
        % {logical 1x1} use manual polling and reading of binary data with 
        % tcpip (uses fread in a while loop instead of fscanf)
        lManualPollAndRead = false
        
        
        
        % tcpip config
        % --------------------------------
        % {char 1xm} tcp/ip host
        cTcpipHost = '192.168.0.3'
        
        % {uint16 1x1} tcpip port NPort requires a port of 4001 when in
        % "TCP server" mode
        u16TcpipPort = uint16(4001)
        

        % The tcpclient implmentation must manually build the data packets
        % and manually poll for the termination byte because fprintf and
        % fscanf are not supported by tcpclient instances. 
        %
        % fwrite() and fread() write and read binary data and
        % fread does not do any polling.  This is good because
        % it lets us directly  create the data packets that are sent and
        % directly unpack the data packets that are received. 
        %
        % Writing:
        % During write commands, the binary version of the ASCII command
        % must be followed by a carriage return (13).
        % Optionally, it can be followed 10 13 (space + line feed +
        % carriage return).  Multiple write commands can be sent at
        % once
        %
        % Reading
        % The number of commands sent since the last read dictates
        % the number of responses that will be included in the next read.
        % Every response has a 10 (line feed) after it.  The last reaponse 
        % additionally has a carriage return (13) after it. I.E., the last
        % response has a 10 and a 13 after it. When a 13 is read, the data
        % read operation containing the result of every command since the
        % previous read is done.
        
        
        % {logical 1x1}
        lDebug = false
    end
    methods 
        
        function this = Keithley6482(varargin) 
            
            this.cConnection = this.cCONNECTION_TCPCLIENT;
            
            for k = 1 : 2: length(varargin)
                this.msg(sprintf('passed in %s', varargin{k}));
                if this.hasProp( varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}));
                    this.(varargin{k}) = varargin{k + 1};
                end
            end
            
        end
        
        function init(this)
            
            switch this.cConnection
                case this.cCONNECTION_SERIAL
                    try
                        this.msg('init() creating serial instance');
                        this.comm = serial(this.cPort);
                        this.comm.BaudRate = this.u16BaudRate;
                        this.comm.Terminator = this.cTerminator;
                        % this.comm.InputBufferSize = this.u16InputBufferSize;
                        % this.comm.OutputBufferSize = this.u16OutputBufferSize;
                    catch ME
                        rethrow(ME)
                    end
                case this.cCONNECTION_TCPCLIENT
                    try
                       this.msg('init() creating tcpclient instance');
                       this.comm = tcpclient(this.cTcpipHost, this.u16TcpipPort);
                    catch ME
                        rethrow(ME)
                    end
            end
            
            

        end
        
        
        function clearBytesAvailable(this)
            
            % This doesn't alway work.  I've found that if I overfill the
            % input buffer, call this method, then do a subsequent read,
            % the results come back all with -1.6050e9.  Need to figure
            % this out
            
            this.msg('clearBytesAvailable()');
            
            while this.comm.BytesAvailable > 0
                cMsg = sprintf(...
                    'clearBytesAvailable() clearing %1.0f bytes', ...
                    this.comm.BytesAvailable ...
                );
                this.msg(cMsg);
                fread(this.comm, this.comm.BytesAvailable);
            end
        end
        
        
        function connect(this)
            
            switch this.cConnection
                case this.cCONNECTION_TCPCLIENT
                    % Do nothing
                otherwise
                    % tcpip and serial both need to be open with fopen 
                    try
                        fopen(this.comm); 
                    catch ME
                        rethrow(ME)
                    end
            end
            
            
        end
        
        function disconnect(this)
            this.msg('disconnect()');
            
            switch this.cConnection
                case this.cCONNECTION_TCPCLIENT
                    % Do nothing
                otherwise
                    try
                        fclose(this.comm);
                    catch ME
                        rethrow(ME);
                    end
            end
        end
        
        function c = identity(this)
            cCommand = '*IDN?';
            this.writeAscii(cCommand);
            c = this.readAscii();
        end
        
%         function setFunctionToAmps(this)
%             this.writeAscii(':FUNCtion "CURRent"');
%         end
        
        % Set the speed (integration time) of the ADC.  
        % @param {double 1x1} dPLC - the integration time as the number of power 
        %   line cycles.  Min = 0.01 Max = 10.  1 PLC = 1/60s = 16.67 ms @
        %   60Hz or 1/50s = 20 ms @ 50 Hz.
        function setIntegrationPeriodPLC(this, dPLC)
            % [:SENSe[1]]:CURRent[:DC]:NPLCycles <n>
            
            if (dPLC > this.dPLCMax)
                cMsg = sprintf(...
                    'ERROR: supplied PLC = %1.2f > max allowed = %1.2f', ...
                    dPLC, ...
                    this.dPLCMax ...
                );
                this.log(cMsg);
                return;
            end
            
            if (dPLC < this.dPLCMin)
                cMsg = sprintf(...
                    'ERROR: supplied PLC = %1.2f <  min allowed = %1.2f', ...
                    dPLC, ...
                    this.dPLCMin ...
                );
                this.log(cMsg);
                return;
            end
            
            cCommand = sprintf(':current:nplcycles %1.3f', dPLC);
            this.writeAscii(cCommand);
            
        end
        
        function setIntegrationPeriod(this, dSeconds)
            % [:SENSe[1]]:CURRent[:DC]:APERture <n>
            % <n> =166.6666666667e-6 to 200e-3 Integration period in seconds
            dPLC = dSeconds * 60;
            this.setIntegrationPeriodPLC(dPLC);
        end
        
        
        function d = getIntegrationPeriod(this)
            dPLC = this.getIntegrationPeriodPLC();
            d = dPLC * 1/60;
        end
        
        function d = getIntegrationPeriodPLC(this)
            cCommand = ':current:nplcycles?';
            this.writeAscii(cCommand);
            c = this.readAscii();
            d = str2double(c);
        end
        
        % --------
        % UPDATE
        %
        % I didn't realize that the ADC, Average Filter, and Median Filter
        % Settings are global to both channels.  The Api below still works,
        % but know that if you set channel 2, it is the same as setting 1,
        % which is really setting both channels
        
        % Enable or disable the digital averaging filter 
        % @param {char 1xm} cVal - the state: "ON" of "OFF"
        function setAverageState(this, u8Ch, cVal) 
            % [:SENSe[1]]:CURRent[:DC]:AVERage[:STATe] <b>
            % ON
            % OFF
            cCommand = sprintf(':sense%u:average %s', u8Ch, cVal);
            this.writeAscii(cCommand);
        end
        
        % @return {char 1xm} "ON" or "OFF"
        function c = getAverageState(this, u8Ch)
            cCommand = sprintf(':sense%u:average?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            % c = this.stateText(c);
        end
        
        
        
        function setAverageAdvancedState(this, u8Ch, cVal)
            cCommand = sprintf(':sense%u:average:advanced %s', u8Ch, cVal);
            this.writeAscii(cCommand);
        end
        
        function c = getAverageAdvancedState(this, u8Ch)
            cCommand = sprintf(':sense%u:average:advanced?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            c = this.stateText(c);
        end
        
        
         % Set the averaging filter mode of a channel
        % @param {char 1xm} cVal - the mode: "REPEAT" or "MOVING"
        function setAverageMode(this, u8Ch, cVal)
            % [:SENSe[1]]:CURRent[:DC]:AVERage:TCONtrol <name>
            % REPeat
            % MOVing
            cCommand = sprintf(':sense%u:average:tcontrol %s', u8Ch, cVal);
            this.writeAscii(cCommand);
        end
        
        function c = getAverageMode(this, u8Ch)
            cCommand = sprintf(':sense%u:average:tcontrol?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
        end
        
        % Set the averaging filter count of a channel
        % @param {uint8) u8Val - the count (1 to 100)
        function setAverageCount(this, u8Ch, u8Val) 
            % [:SENSe[1]]:CURRent[:DC]:AVERage:COUNt <n>
            cCommand = sprintf(':sense%u:average:count %u', u8Ch, u8Val);
            this.writeAscii(cCommand);

        end
        
        function u8 = getAverageCount(this, u8Ch)
            cCommand = sprintf(':sense%u:average:count?', u8Ch);
            this.writeAscii(cCommand);
            u8 = str2double(this.readAscii());
        end
        
        % Set the median filter state of a channel
        % @param {char 1xm} cVal - the state: "ON" of "OFF"
        function setMedianState(this, u8Ch, cVal)
            % [:SENSe[1]]:CURRent[:DC]:MEDian[:STATe] <b>
            cCommand = sprintf(':sense%u:median %s', u8Ch, cVal);
            this.writeAscii(cCommand);
        end
        
        
        function c = getMedianState(this, u8Ch)
            cCommand = sprintf(':sense%u:median?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            c = this.stateText(c);
        end
        
        % Set the median filter rank of a channel
        % @param {uint8) cVal - the rank: 0 (disabled), 1, 2, 3, 4, 5. [3, 5,
        % 7, 9, 11 samples, respectively]
        function setMedianRank(this, u8Ch, u8Val)
            % [:SENSe[1]]:CURRent[:DC]:MEDian:RANK <NRf>
            cCommand = sprintf(':sense%u:median:rank %u', u8Ch, u8Val);
            this.writeAscii(cCommand);
        end
        
        function u8 = getMedianRank(this, u8Ch)
            cCommand = sprintf(':sense%u:median:rank?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            u8 = str2double(c);
        end
        

        % Set the range
        % @param {double 1x1} dAmps - the expected current.
        % The Model 6517A will then go to the most sensitive range that
        % will accommodate that expected reading.
        function setRange(this, u8Ch, dAmps)
           % [:SENSe[1]]:CURRent[:DC]:RANGe[:UPPer] <n> 
           cCommand = sprintf(':sense%u:current:range %1.3e', u8Ch, dAmps);
           this.writeAscii(cCommand);

        end
            
        function d = getRange(this, u8Ch)
            cCommand = sprintf( ':sense%u:current:range?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            d = str2double(c);
        end
        
        % Set the auto range state of a channel
        % @param {char 1xm} cVal - the state: "ON" of "OFF" 
        function setAutoRangeState(this, u8Ch, cVal)
            cCommand = sprintf(':sense%u:current:range:auto %s', u8Ch, cVal);
            this.writeAscii(cCommand);
        end
        
        function c = getAutoRangeState(this, u8Ch)
            cCommand = sprintf(':sense%u:current:range:auto?', u8Ch);
            this.writeAscii(cCommand);
            c = this.readAscii();
            c = this.stateText(c);
        end
            
        
        % Set the auto range lower limit of a channel
        % @param {double 1x1} dVal - the range: 2e-9, 20e-9, 200e-9, etc.
        function setAutoRangeLowerLimit(this, dVal)
        end
        
        
        % Set the auto range upper limit of a channel
        % @param {double 1x1} dVal - the range: 2e-9, 20e-9, 200e-9, etc.
        function setAutoRangeUpperLimit(this, dVal)  
        end
        
        function delete(this)
            this.msg('delete()');
            this.disconnect();
            delete(this.comm);
        end
                
        % @return {double 1x2} - ch1 and ch2 current
        function d = getSingleMeasurement(this)
           cCommand = ':measure?';
           this.writeAscii(cCommand);
           c = this.readAscii(); % {char 1xm} '+6.925672E-07,+3.245491E-10'
           ce = strsplit(c, ','); % {cell 1x2} {'+6.925672E-07', '+3.245491E-10'}
           d = str2double(ce); % {double 1x2} [6.925672e-07 3.245491e-10]
        end
        
        
        function d = read(this, u8Ch)
            % this.dCount = this.dCount + 1;
            % tic
           cCommand = sprintf(':FORM:ELEM CURR%u', u8Ch);
           this.writeAscii(cCommand);
           cCommand = ':read?';
           this.writeAscii(cCommand);
           c = this.readAscii(); % {char 1xm} '+6.925672E-07
           % time = toc;
           % fprintf('Read %1.0f time = %1.1f ms\n', this.dCount, time * 1000);
           d = str2double(c);
        end
        
        
        % Writes an ASCII command to the communication object (serial,
        % tcpip, or tcpclient
        % Create the binary command packet as follows:
        % Convert the char command into a list of uint8 (decimal), 
        % concat with the first terminator: 10 (base10) === 'line feed')
        % concat with the second terminator: 13 (base10)=== 'carriage return') 
        % write the command to the tcpip port (the nPort 5150A)
        % using binary (each uint8 is converted to stream of 8 bits, I think)
        function writeAscii(this, cCmd)
            
            % this.msg(sprintf('write %s', cCmd))
            switch this.cConnection
                case this.cCONNECTION_TCPCLIENT
                    u8Cmd = [uint8(cCmd) 13];
                    write(this.comm, u8Cmd);
                case  this.cCONNECTION_TCPIP
                    if this.lManualPacket
                        u8Cmd = [uint8(cCmd) 13];
                        fwrite(this.comm, u8Cmd);
                    else
                        % default format for fprintf is %s\n and 
                        % fprintf replaces instances of \n by the terminator
                        % then fprintf converts each ASCII character to its
                        % 8-bit representation to create the data packet
                        fprintf(this.comm, cCmd);
                    end
                case this.cCONNECTION_SERIAL
                    fprintf(this.comm, cCmd);
            end
                    
        end
        
        
        % Read until the terminator is reached and convert to ASCII if
        % necessary (tcpip and tcpclient transmit and receive binary data).
        % @return {char 1xm} the ASCII result
        
        function c = readAscii(this)
            
            switch this.cConnection
                case this.cCONNECTION_TCPCLIENT
                    u8Result = this.readToTerminator(int8(13));
                    % remove carriage return terminator
                    u8Result = u8Result(1 : end - 1);
                    % convert to ASCII (char)
                    c = char(u8Result);
                case this.cCONNECTION_SERIAL
                    c = fscanf(this.comm);
            end
        end
        
        
        % Sets the offset to the current reading
        function setChannel1OffsetValueToCurrentReading(this)
           cCommand = ':CALC3:NULL:ACQ';
           this.writeAscii(cCommand);
        end
        
        
        % @param {double 1x1} dVal - the desired offset
        function setChannel1OffsetValue(this, dVal)
            cCommand = sprintf(':CALC3:NULL:OFFS %1.3e', dVal);
            this.writeAscii(cCommand);
        end
        
        % @param {char 1xm} cVal - the state: "ON" of "OFF"
        function setChannel1OffsetState(this, cVal)
            cCommand = sprintf(':CALC3:NULL:STAT %s', cVal);
            this.writeAscii(cCommand);
        end
        
        function d = getChannel1OffsetValue(this)
            cCommand = ':CALC3:NULL:OFFS?';
            this.writeAscii(cCommand);
            c = this.readAscii();
            d = str2double(c);
        end
        
        % @return {char 1xm} "ON" or "OFF"
        function c = getChannel1OffsetState(this)
            cCommand = ':CALC3:NULL:STAT?';
            this.writeAscii(cCommand);
            c = this.readAscii();
            c = this.stateText(c);
        end
        
        % When CALC3 is enabled, the returned value will include the offset
        function d = getChannel1CalcResult(this)
           % See Appendix B of the manual to learn about data flow.  Need 
           % to send the INIT command to place new data in the sample
           % buffer which subsequently feeds the result to the CALC system so a new CALC
           % value is waiting.  Note that the READ command is identical to 
           % INIT + FETCH
           cCommand = 'INIT';
           this.writeAscii(cCommand);
           cCommand = ':CALC3:DATA?';
           this.writeAscii(cCommand);
           c = this.readAscii();
           d = str2double(c);
        end
        
        
        
        % Sets the offset to the current reading
        function setChannel2OffsetValueToCurrentReading(this)
           cCommand = ':CALC4:NULL:ACQ';
           this.writeAscii(cCommand);
        end
        
        
        % @param {double 1x1} dVal - the desired offset
        function setChannel2OffsetValue(this, dVal)
            cCommand = sprintf(':CALC4:NULL:OFFS %1.3e', dVal);
            this.writeAscii(cCommand);
        end
        
        % @param {char 1xm} cVal - the state: "ON" of "OFF"
        function setChannel2OffsetState(this, cVal)
            cCommand = sprintf(':CALC4:NULL:STAT %s', cVal);
            this.writeAscii(cCommand);
        end
        
        function d = getChannel2OffsetValue(this)
            cCommand = ':CALC4:NULL:OFFS?';
            this.writeAscii(cCommand);
            c = this.readAscii();
            d = str2double(c);
        end
        
        % @return {char 1xm} "ON" or "OFF"
        function c = getChannel2OffsetState(this)
            cCommand = ':CALC4:NULL:STAT?';
            this.writeAscii(cCommand);
            c = this.readAscii();
            c = this.stateText(c);
        end
        
        % When CALC3 is enabled, the returned value will include the offset
        function d = getChannel2CalcResult(this)
           % See Appendix B of the manual to learn about data flow.  Need 
           % to send the INIT command to place new data in the sample
           % buffer which subsequently feeds the result to the CALC system so a new CALC
           % value is waiting.  Note that the READ command is identical to 
           % INIT + FETCH
           cCommand = 'INIT';
           this.writeAscii(cCommand);
           cCommand = ':CALC4:DATA?';
           this.writeAscii(cCommand);
           c = this.readAscii();
           d = str2double(c);
        end
        
        
        
        
    end
    
    
    methods (Access = private)
        
        % The SPCI state? commands return a {char 1xm} representation of 1
        % or 0 followed by the terminator.  The 6517A terminator is CR/LF,
        % which is equivalent to \r\n in matlab. This method converts the
        % {char 1xm} response, for example '1\r\n' or '0\r\n' (except the char
        % doesn't actually equal this, you have to wrap sprintf around it
        % for \r\n to convert.) to 'on' or 'off', respectively
        % @param {char 1xm} - response from SPCI
        % @return {char 1xm} - 'on' or 'off'
           
        function c = stateText(this, cIn)
            
            switch this.cTerminator
                case 'CR'
                    if strcmp(cIn, sprintf('1\r'))
                        c = 'on';
                    else
                        c = 'off';
                    end
                case 'CR/LF'
                    if strcmp(cIn, sprintf('1\r\n'))
                        c = 'on';
                    else
                        c = 'off';
                    end
            end
                    
        end
        
        % We want to do writes with fwrite() and reads with fread() because
        % it allows us to construct the binary data packet.  fprintf() and
        % fscanf() do some weird shit with replacing \n by the terminator
        % and stuff that can lead to problems.  With fwrite() and fread(),
        % you have full control over what is sent and received.
        %
        % fread(), if not supplied with a number of bytes, will attempt to
        % read tcpip.InputBufferSize bytes.  In general, Never call fread()
        % without specifying the number of bytes because it will read for
        % tcpip.Timeout seconds
        %
        % The MMC-103 documentation does not say how many bytes are
        % returned by each command so we do not know a-priori how many
        % bytes to wait for in the input buffer.  If we did we could have a
        % while loop similar to while (this.comm.BytesAvailable <
        % bytesRequired) that polls BytesAvailable and then only issues the
        % fread(this.comm, bytesRequired) once those bytes are availabe.
        %
        % The alternate approach, below is more of a manual
        % implementatation of what fscanf() does, but for binary data.   As
        % bytes become available, read them in and check to see if the
        % terminator character has been found.  Once the terminator is
        % reached, the read is complete.
        % @return {uint8 1xm} 
        
        function u8 = readToTerminator(this, u8Terminator)
            
            lTerminatorReached = false;
            u8Result = [];
            idTic = tic;
            while(~lTerminatorReached && ...
                   toc(idTic) < this.comm.Timeout )
                if (this.comm.BytesAvailable > 0)
                    
                    cMsg = sprintf(...
                        'readToTerminator reading %u bytesAvailable', ...
                        this.comm.BytesAvailable ...
                    );
                    this.msg(cMsg);
                    % Append available bytes to previously read bytes
                    
                    % {uint8 1xm} 
                    u8Val = read(this.comm, this.comm.BytesAvailable);
                    % {uint8 1x?}
                    u8Result = [u8Result u8Val];
                    % search new data for terminator
                    u8Index = find(u8Val == u8Terminator);
                    if ~isempty(u8Index)
                        lTerminatorReached = true;
                    end
                end
            end
            
            u8 = u8Result;
            
        end
        
        function l = hasProp(this, c)
            
            l = false;
            if ~isempty(findprop(this, c))
                l = true;
            end
            
        end
        
        function msg(this, cMsg)
            if this.lDebug
                fprintf('Keithley6482 %s\n', cMsg);
            end
        end
        
    end
    
end
        
