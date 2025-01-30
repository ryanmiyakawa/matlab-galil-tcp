classdef GalilTCP2Ch < handle

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
        
        cCONNECTION_TCPCLIENT = 'tcpclient'
        
    end
    
    properties % (Access = private)
     
        % {char 1xm}
        cConnection % cCONNECTION_SERIAL | cCONNECTION_TCPCLIENT
        
        % {tcpip 1x1} tcpip connection 
        comm
        
        axes = [2, 3]
        

        % {double 1x1} - timeout of MATLAB {serial, tcpip, tcpclient} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2
        
        
        
        
        % tcpip config
        % --------------------------------
        % {char 1xm} tcp/ip host
        cTcpipHost = '192.168.10.150'
        
        % {uint16 1x1} tcpip port NPort requires a port of 4001 when in
        % "TCP server" mode
        u16TcpipPort = uint16(23)
        

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
        
        function this = GalilTCP2Ch(varargin) 
            
            this.cConnection = this.cCONNECTION_TCPCLIENT;
            
            for k = 1 : 2: length(varargin)
                this.msg(sprintf('passed in %s', varargin{k}));
                if this.hasProp( varargin{k})
                    this.msg(sprintf('settting %s', varargin{k}));
                    this.(varargin{k}) = varargin{k + 1};
                end
            end
            
            this.init();
            
        end
        
        function init(this)
            
          
            try
                this.msg('init() creating tcpclient instance');
                this.comm = tcpclient(this.cTcpipHost, this.u16TcpipPort);
            catch ME
                this.msg(getReport(ME));
                rethrow(ME)
            end
        end
        
        
        function clearBytesAvailable(this)
            % This doesn't alway work.  I've found that if I overfill the
            % input buffer, call this method, then do a subsequent read,
            % the results come back all with -1.6050e9.  Need to figure
            % this out
            
            this.msg('clearBytesAvailable()');
            pause(0.001);
            
            while this.comm.BytesAvailable > 0
                cMsg = sprintf(...
                    'clearBytesAvailable() clearing %1.0f bytes', ...
                    this.comm.BytesAvailable ...
                );
                this.msg(cMsg);
                read(this.comm, this.comm.BytesAvailable);
            end
        end
        
        
        function d = getAxisAnalog(this, u8Axis)
            if length(this.axes) < (u8Axis + 1)
                d = 0;
            else
                d = this.dVals(u8Axis + 1);
            end
        end


        function stopAxisMove(this)
            cCommand = 'ST';
            this.writeAscii(cCommand);
        end

        function l = getAxisIsInitialized(this, u8Axis)
            l = true;
        end
        function l = initializeAxes(this)
            l = true;
        end

        function zeroEncoders(this)
            this.writeAscii('DP,0,0');
            this.clearBytesAvailable();
        end

        function executeWobble(this)
            this.writeAscii('XQ#wobble');
        end

        function l = getAxisIsReady(this, u8Axis)
            l = true;
        end

        function moveAxisAbsolute(this, dChannel, dLoc)
             this.writeAscii(sprintf('PA%s %d', this.getAxisCommas(dChannel), dLoc));
             this.writeAscii(sprintf('BG %s', this.getAxisLetter(dChannel)));       
        end
        
        function dVal = readParameter(this, cParamName)
            dVal = this.readAscii(sprintf('MG %s', cParamName));
        end
        function writeParameter(this, cParamName, dVal)
            this.writeAscii(sprintf('%s=%d', cParamName, dVal));
        end

        function dPositions = getAxisPosition(this, dChannel)

            % Validate input
            if ~all(ismember(dChannel, [1, 2]))
                error('Invalid channel. Must be 1, 2, or [1, 2].');
            end
            
            dPositions = this.readAscii('TP B C');
            dPositions = dPositions(dChannel);
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
            u8Cmd = [uint8(cCmd) 13];
            write(this.comm, u8Cmd);
            this.clearBytesAvailable();
        end
        
        
        % Read until the terminator is reached and convert to ASCII if
        % necessary (tcpip and tcpclient transmit and receive binary data).
        % @return {char 1xm} the ASCII result
        
        function dVal = readAscii(this, cCommand)
            this.clearBytesAvailable();
            write(this.comm, [uint8(cCommand), uint8(13)]);
            pause(0.01);
            raw = read(this.comm, this.comm.BytesAvailable, 'uint8');
            valAr = str2double(split(strtrim(char(raw))));
            if length(valAr) < 2
                dVal = nan;
                return
            end
            dVal = valAr(1:end-1);
            
        end


        function dLet = getAxisLetter(this, dChannel)
            dLet = char(64 + this.axes(dChannel));
        end
        
        function dLet = getAxisCommas(this, dChannel)
            dLet = '';
            
            for k = 1:this.axes(dChannel)-1
               dLet = [dLet, ',']; 
            end
            
        end
        
        
    end
    
    
    methods (Access = private)
        
    
        
        function l = hasProp(this, c)
            
            l = false;
            if ~isempty(findprop(this, c))
                l = true;
            end
            
        end
        
        function msg(this, cMsg)
            if this.lDebug
                fprintf('TCP Galil %s\n', cMsg);
            end
        end
        
    end
    
end
        
