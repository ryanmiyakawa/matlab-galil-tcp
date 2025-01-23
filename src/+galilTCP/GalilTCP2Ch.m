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
        

        % {double 1x1} - timeout of MATLAB {serial, tcpip, tcpclient} - amount of time it will
        % wait for a response before aborting.  
        dTimeout = 2
        
        dPLCMax = 10;
        dPLCMin = 0.01;
        
        % {double 1x1} storate for number of calls to getData()
        dCount = 0;
        
        % Store the latest read values into buffer
        dReadBuffer = [0,0]
        uint8ReadTimes = {clock, clock}
        
        
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
         
            
        end
        
        function disconnect(this)
           
        end
        
        function c = identity(this)
            cCommand = '*IDN?';
            this.writeAscii(cCommand);
            c = this.readAscii();
        end

        function stop(this)
            cCommand = 'ST';
            this.writeAscii(cCommand);
        end

        function executeWobble(this)
            this.writeAscii('XQ #wobble');
        end


        function moveAbs(dChannel, dLoc)
            % moveAbs generates a Galil command for absolute motion.
            % 
            % Parameters:
            %   channel (1 or 2) : The channel to move (1 = A, 2 = B)
            %   location         : The absolute position to move to
            %
            % Returns:
            %   command          : A string containing the Galil command
            
            % Validate input
            if length(dChannel) == 2 && length(dLoc)
                % Move both:
                if ~isnumeric(dChannel) || ~isscalar(dChannel)
                    error('Channel must be a numeric scalar.');
                end
                if ~isnumeric(dLoc) || ~isscalar(dLoc)
                    error('Location must be a numeric scalar.');
                end
                cCommand = sprintf('PA %d,%d; BG A B', dLoc(1), dLoc(2)); % Move channel 1 (A)
                this.writeAscii(cCommand);
                return
            end

            % Move single channel:
            if ~ismember(dChannel, [1, 2])
                error('Invalid channel. Must be 1 or 2.');
            end
            
            if ~isnumeric(location) || ~isscalar(location)
                error('Location must be a numeric scalar.');
            end
            
            % Create the PA command with placeholders for unused axes
            if dChannel == 1
                cCommand = sprintf('PA %d,; BG A', dLoc); % Move channel 1 (A)
            elseif channel == 2
                cCommand = sprintf('PA ,%d; BG B', dLoc); % Move channel 2 (B)
            end

            this.writeAscii(cCommand);
        end

        function dPositions = getAbs(dChannel)
            % getAbs queries the current absolute position of one or both channels.
            %
            % Parameters:
            %   dChannel (1, 2, or [1, 2]): The channel(s) to query (1 = A, 2 = B)
            %
            % Returns:
            %   dPositions (numeric): A scalar for a single channel or a 1x2 vector for both
            
            % Validate input
            if ~all(ismember(dChannel, [1, 2]))
                error('Invalid channel. Must be 1, 2, or [1, 2].');
            end
            
            % Initialize the position query command
            if isequal(dChannel, [1, 2])
                cCommand = 'TP A B'; % Query both channels
            elseif dChannel == 1
                cCommand = 'TP A';   % Query channel 1 (A)
            elseif dChannel == 2
                cCommand = 'TP B';   % Query channel 2 (B)
            end
            
            % Send the command to the Galil controller
            response = this.readAscii(cCommand); % Replace with your TCP read method
            
            % Parse the response
            dPositions = str2double(strsplit(response, ',')); % Convert to numeric array
            
            % If a single channel is queried, return a scalar
            if length(dPositions) == 1
                dPositions = dPositions(1);
            end
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
        end
        
        
        % Read until the terminator is reached and convert to ASCII if
        % necessary (tcpip and tcpclient transmit and receive binary data).
        % @return {char 1xm} the ASCII result
        
        function c = readAscii(this)
            u8Result = this.readToTerminator(int8(13));
            % remove carriage return terminator
            u8Result = u8Result(1 : end - 1);
            % convert to ASCII (char)
            c = char(u8Result);
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
                fprintf('Keithley6482 %s\n', cMsg);
            end
        end
        
    end
    
end
        
