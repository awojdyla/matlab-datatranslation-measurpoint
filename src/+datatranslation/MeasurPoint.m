classdef MeasurPoint < datatranslation.AbstractMeasurPoint
% Wrapper for Data Translation MeasurPoint 
% DT8874-8T-24R-16V,14171149,3.1.0.2
%
% It requires Instrument Control Box, to use NI VISA in order 
% to communicate with SCPI via ethernet
%
%example of use :
%   this = MeasurPoint();         % create the object
%   this.connect();               % connect to the instrument
%   this.idn();                   % ask the instrument identity
%   cAnswer     = this.query('MEAS:VOLT? (@1)') % queries the instrument
%   dTemp_degC  = this.measure_temperature_tc(2);  % measure temperature on ch2

% awojdyla@lbl.gov
% April 2017

%TODO: Add a password protected check bit
%TODO: wrap most function and make prefix them (e.g. SYSTCHAN->SCPI_SYSTCHAN)
%TODO: would be good to refactor SCPI superclass (esp. connect and query)
% Would be good to have : 
% -fetch (time stamped); 

properties
    %FIXME : the IP may change depending on the configuration
    % can be found usign the Eureka discovery tool (needs Windows)
    %http://www.datatranslation.eu/en/ethernet/24-bit-data-acquisition/
    %500v-isolation/data-logger-software,1355.html
    cIP = '192.168.127.100'; % SCPI connection string
    comm   % tcpip || VISA object (see init())
    verbosity = 1; %1: show proper connection; 2: show all i/o's
end

properties (Access = private)
    
     % {logical 1x1} true whend doing a long read. Causes other read
        % commands to not communicate with hardware and return bogus value
    lIsBusy = false
    
    % Cache for getData
    ticGetVariables
    tocMin = 0.2;
    dScanData % {double 1 x m} see getScanData()
    
    % {double 1x1} storage of the number of times getScanData()
    % has thrown an error.  
    dNumOfSequentialGetScanDataErrors = 0
    
    % {double 1x1} storage of the last successfully read index start and
    % index end of the scan buffer
    dIndexStart = 1;
    dIndexEnd = 1;

    
end

methods
    
    function this = MeasurPoint(varargin)
        % MeasurPoint Class constrctor
        %   this = MeasurPoint() creates an object with default IP (see blow)
        %   this = MeasurPoint('192.168.127.100')
        %       creates an object with the provided IP
        %
        % See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY

        % populate the IP adress
        if nargin==1
            this.cIP = varargin{1};
        end

        % initialise the class
        this.init();
    end
    
    function clearCache(this)
            this.ticGetVariables = [];
    end
        
    function l = getIsBusy(this)
        l = this.lIsBusy;
    end
    
    function init(this)
    %INIT Initializes the VISA object
    %(this function is called by the constructor of the class)
    %   this.init()
    %
    % See also MEASURPOINT.STATUS, MEASURPOINT.CONNECT
    
        % SCPI connection string
        cSCPI_IP = sprintf('TCPIP::%s::INSTR',this.cIP);
        
        % create a VISA object and store it as a property
        % this.comm = visa('ni', cSCPI_IP);
        this.comm = tcpip(this.cIP, 5025);
        % Don't use Nagle's algorithm; send data
        % immediately to the newtork
        this.comm.TransferDelay = 'off'; 
        this.comm.Timeout = 2;
        this.comm.InputBufferSize = 2^20; % bytes ~ 1MB
        
        if this.verbosity>0
            disp('NI VISA object object initialized')
        end
    end
    
    % Reads all available bytes from the input buffer
    function clearBytesAvailable(this)
       
        this.lIsBusy = true;
        while this.comm.BytesAvailable > 0
            cMsg = sprintf(...
                'clearBytesAvailable() clearing %1.0f bytes\n', ...
                this.comm.BytesAvailable ...
            );
            fprintf(cMsg);
            bytes = fread(this.comm, this.comm.BytesAvailable);
        end
        this.lIsBusy = false;
    end
    
    function cStatus = status(this)
    %STATUS gets the status of the VISA object
    %(this doesn't tell you if the device is connected)
    %   status = this.status() returns true if the VISA object is valid
    %
    % See also MEASURPOINT.CONNECT
    
        if ~isempty(this.comm) 
            %get the status of the VISA object (not the instrument itself!)
            cStatus = this.comm.Status;
            if nargout == 0 
                fprintf('NI VISA Status : %s\n', cStatus);
            end
        else
            error('MeasurPoint not initialized')
        end
    end
    
    function connect(this)
    %CONNECT Connects the VISA object to the instrument
    %(required for any query!)
    %   this.connect()
    %
    % See also MEASURPOINT.ISCONNECTED, MEASURPOINT.DISCONNECT
    
        fopen(this.comm);
        fprintf('Connected to remote host %s\n', this.comm.propinfo.RemoteHost.DefaultValue)
    end
    
    % Returns RAW or AVG
    function c = getFilterType(this)
        c = this.query(':CONF:FILT?');
    end
    
    % No filter. Providdes fast response times. Manfucturer recommends the
    % only timne it is desireable to run is if you are using fast things
    % sampled > 1 Hz.
    function setFilterTypeToRaw(this)
        this.query(':CONF:FILT RAW');
    end
    
    % this low-pass filter take the previous 16 samples, adds themn
    % together, and divides by 16. 
    function setFilterTypeToAvg(this)
        this.query(':CONF:FILT AVG');
    end
    
    function lIsConnected = isConnected(this)
    %ISCONNECTED Checks whether the communication the device is established
    %   isconnected = this.isConnected() returns 'true' if the device is
    %   available for queries
    %
    %   See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY
    
        lIsConnected = false;
        if ~isempty(this.comm)
            lIsConnected = strcmp(this.comm.Status,'open');
        else
            error('MeasurPoint not initialized')
        end
    end
    
    function disconnect(this)
    %DISCONNECT Disconnects the device
    %(this function is called by the destructor)
    %   this.disconnect()
    %
    %   See also MEASURPOINT.CONNECT
    
        if ~isempty(this.comm)
            fclose(this.comm);
            fprintf('Disconnected\n')
        end
    end
    
    function cAnswer = query(this, str_query)
    %QUERY Performs a query of the instrument, to set or get a parameter
    %   cAnswer = query(str_query)
    %
    % example:
    %   cChan = this.query('SYST:CHAN?')
    %
    %
    % 
    % NOTE: if you are dealing with data, avoid using this.query, as 
    % this.query('MEAS:VOLT? (@2)') should return a string with encoded
    % values, but missing elements; use this.queryData instread
    %
    % BE CAREFUL! Measurement of values can be password protected; 
    % make sure the readings are enabled (this.enable())
    % use this.idn() to make sure there is actual communication with the inst
    % use this.get_error() to troubleshoot message-forming error
    %
    % See also MEASUREPOINT.QUERYDATA, MEASURPOINT.ENABLE, MEASURPOINT.GET_ERROR, 
    %          MEASURPOINT.IDN
    
        cAnswer = '';
       % cQuery = strcat(str_query,';');
         cQuery = str_query;
        if ~isempty(this.comm)
            
            %print query (for debugging)
            if this.verbosity > 1
                fprintf('query() "%s"\n',cQuery)
            end
            
            % perform a visa query
            if ~isempty(strfind(cQuery, '?'))
                % Expect an ascii answer in output buffer
                cAnswer = query(this.comm,cQuery);
            else
                % Do not expect an answer in the output buffer
                fprintf(this.comm, cQuery);
            end
                        
            %if the answer is empty, but the query was expecting an answer,
            %find out what kind com error happened
            if isempty(cAnswer) && ~isempty(strfind(cQuery, '?'))
                err_msg = query(this.comm,'SYST:ERR?');
                fprintf('error message : %s',err_msg)
            end
        else
            error('MeasurPoint not initialized')
        end
    end
    
    function bytestring = queryData(this, str_query, nbytes)
    %QUERYDATA Performs a low-level query of the instrument
    % This is important when handling with data, because otherwise Matlab
    % cast it as a results, sometime trimming it -- making the reading
    % unreliable.
    %   
    %   cAnswer = this.queryData(str_query,nbytes)
    %   with str_query a SCPI query string, 
    %        nbytes the number of bytes expected (usually 4, +4 per channel)
    %        cAnswer is a bytestring (pairs of hexadecimal values)
    %
    % example:
    %   cChan = this.queryData('MEAS:TEMP:TC? DEF,(@3)',8)
    %   >> cChan = '23313447C34F800A'
    %   
    % BE CAREFUL! Measurement of values can be password protected; 
    % make sure the readings are enabled (this.enable())
    %
    % use this.get_error() to troubleshoot message-forming error
    %
    % See also MEASURPOINT.QUERY, MEASUREPOINT.UNPACK, MEASURPOINT.CONVERTIEEE_754,
    %          MEASUREPOINT.MEASURE_TEMPERATURE, MEASUREPOINT.MEASURE_VOLTAGE
    %          MEASURPOINT.ENABLE, MEASURPOINT.GET_ERROR,MEASURPOINT.IDN, 
    
        cAnswer = '';
        cQuery = strcat(str_query,';');
        if ~isempty(this.comm)
            
            %print query (for debugging)
            if this.verbosity > 1
                fprintf('queryData() query = "%s" bytes expected = %1.0f \n',cQuery, nbytes)
            end
            
            % send the command 
            % (e.g. cQuery='MEAS:TEMP:TC? DEF,(@3)')
            
            dTimeStart = tic;
            fprintf(this.comm, cQuery); 
            dTimeWrite = toc(dTimeStart);
            
            % read the data (fread waits for nbytes to accumulate in the
            % output buffer)
            
            bytes_dec = fread(this.comm,nbytes);
            char(bytes_dec);
            dTimeRead = toc(dTimeStart);
            
            if this.verbosity > 1
                cMsg = [...
                    'quertyData(): ', ...
                    sprintf('time of write: %1.1f ms; ', dTimeWrite * 1000), ...
                    sprintf('time of write + read: %1.1f ms \n', dTimeRead * 1000) ...
                ];
                fprintf(cMsg);
            end
                
            % e.g.  [35;49;52;71;195;79;128;10]'
            
            if ~isempty(bytes_dec)
                % convert to bytes
                bytes = dec2hex(bytes_dec);
                % e.g. bytes ~ ['23';'31';'34';'47';'C3';'4F';'80':'0A']'
                
                % reshape the bytes into a bytstring
                bytestring = reshape(bytes',1,2*size(bytes_dec,1));
                % e.g. bytestring = '23313447C34F800A'
                                
                % if the answer is empty, but the query was expecting an answer,
                % find out what kind com error happened
            else
                err_msg = query(this.comm,'SYST:ERR?');
                fprintf('error message : %s',err_msg)
            end
        else
            error('MeasurPoint not initialized')
        end
        
    end
    
    function cErr_msg = get_error(this)
    %GET_ERROR Get the in the error log
    %   cErr_msg = this.get_error()
    %
    % See also MEASURPOINT.ISCONNECTED, MEASURPOINT.QUERY, MEASURPOINT.ENABLE
    
        cErr_msg = query(this.comm,'SYST:ERR?');
    end
    
    function lIsEnabled = enable(this)
        
    %   See also MEASURPOINT.ISENABLED
        fprintf(this.comm, ':SYST:PASS:CEN admin');
        lIsEnabled = this.isEnabled;
        
        if this.verbosity>0
            if this.isEnabled
                fprintf('device enabled\n')
            else
                fprintf('device not enabled\n')
            end
        end
    end
    
    function lIsEnabled = isEnabled(this)
    %ISENABLED lets you know whether measurements are password protected
    %   this.isEnabled
    %
    %   See also MEASURPOINT.ENABLE
    
        sAnswer = query(this.comm,':SYSTem:PASSword:CENable:STATe?');
        lIsEnabled = logical(strtrim(sAnswer));
    end
    
    function cIDN = idn(this)
    %IDN Standard SCPI '*IDN?' query, to test proper communication
    %   cIDN = this.idn() returns the ID string, e.g.
    %   >>'Data Translation,DT8874-8T-24R-16V,14171149,3.1.0.2'
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.SYSTCHAN, MEASURPOINT.CONF
    
        if ~isempty(this.comm) 
            if this.isConnected()
                % perform the query
                cIDN = this.query('*IDN?');
                % trim the result
                cIDN = strtrim(cIDN);
            else
                error('MeasurPoint not connected')
            end
        else
            error('MeasurPoint not initialized')
        end
        
        if this.verbosity>0
            fprintf('device *IDN: %s\n',cIDN)
        end
    end
    
    function cChan = SYSTCHAN(this)
    %SYSTCHAN Lists available channels
    %   cChan = this.SYSTCHAN()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        % Perform the query
        cChan = this.query('SYST:CHAN?');
        % trim the result
        cChan = strtrim(cChan);
    end
    
    function cConf = CONF(this)
    % CONF Lists available channels
    %   cChan = this.CONF()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        % Perform the query
        cConf = this.query('CONF?');
        % trim the result
        cConf = strtrim(cConf);
        
    end
    
    % Enables a list of channels to scan on the instrument.
    % {u8 1xm} channels - a list of channels to have the hardware scan
    % and store in internal buffer for fast retrieval
    function setScanList(this, u8Channels)
        
        cList = sprintf('%u,', u8Channels);
        cList = cList(1:end - 1); % remove final comma
        cQuery = sprintf(':CONF:SCA:LIS (@%s)', cList);
        this.query(cQuery);
    end
    
    function setScanListAll(this)
        this.setScanList(0:47);
    end
    
    % Returns the size of the circular buffer, in bytes, that is used to store scan data.
    function c = getSizeOfScanBuffer(this)
        c = this.query('CONF:SCA:BUF?');
    end
    
    
    %  Returns the indices of the chronologically oldest and most recent
    %  scan records in the circular buffer on the instrument.
    function [dIndexStart, dIndexEnd] = getIndiciesOfScanBuffer(this)
        
        try
            c = this.query('STAT:SCA?');
            ceVals = strsplit(c, ',');
            if length(ceVals) == 1
                % there was an error, send out the last good values
                dIndexStart = this.dIndexStart;
                dIndexEnd = this.dIndexEnd;
            else
                dIndexStart = str2num(ceVals{1});
                dIndexEnd = str2num(ceVals{2});
                
                % Update last good values
                this.dIndexStart = dIndexStart;
                this.dIndexEnd = dIndexEnd;
                
            end
        catch mE
           dIndexStart = this.dIndexStart;
           dIndexEnd = this.dIndexEnd;
        end
        
    end
    
    
    %{
    % NOT POSSIBLE ON HARDWARE
    % Sets the size of the circular buffer in bytes.  Need 4 bytes per
    % channel, per scan.
    % E.g. if the buffer should only be large enough for one scan, 
    % and the scan list is set to channels 0 : 47, the size of the 
    % circular buffer should be 4 * 48;
    function setSizeOfScanBuffer(this, u32Bytes)
        cCmd = sprintf('CONF:SCA:BUF %d', u32Bytes)
        this.query(cCmd);
    end
    %}
    
    % Configures the trigger source that starts the analog input operation
    % on the instrument once the INITiate command is executed.
    % Sets it to the default which is IMMEDIATE, meaning that as soon as
    % INIT is sent, the scan begins
    function setScanTriggerSourceToDefault(this)
        cCmd = 'CONF:TRIG:SOUR IMM';
        this.query(cCmd);
    end
    
    % Returns the currently configured trigger source that starts the
    % analog input operation on the instrument once the INITiate command is
    % executed.
    function c = getScanTriggerSource(this)
        c = this.query('CONF:TRIG:SOUR?');
    end
    
    % Configures either the time period of each scan, in the number of seconds per scan
    function setScanPeriod(this, dSeconds)
       cCmd = sprintf('CONF:SCA:RAT %1.1f', dSeconds);
       this.query(cCmd);
    end
    
    % Initiates a continuous scan operation on a instrument using the
    % configured channels, scan list, scan rate, and trigger source.
    function initiateScan(this)
        this.query(':INIT');
    end
    
    % Stops a continuous scan operation on the instrument, if it is in progress.
    function abortScan(this)
        this.query('ABOR');
    end
    
    
    % Returns the scan period in seconds
    function c = getScanRate(this)
        c = this.query('CONF:SCA:RAT?');
    end
    
    % Returns the minimum scan period in seconds (0.1)
    function c = getScanRateMinimum(this)
        c = this.query('SYST:SCA:RAT:MIN?');
    end
    
    % Returns the maximum scan period in seconds (unknown)
    function c = getScanRateMaximum(this)
        c = this.query('SYST:SCA:RAT:MAX?');
    end
    
    % Returns the list of channels that are enabled for scanning on the instrument.
    function c = getScanList(this)
        cQuery = 'CONF:SCA:LIS?';
        c = this.query(cQuery);
    end
    
    
    function c = getOperationStatus(this)
        c = this.query('STAT:OPER?');
    end
    
    function caSensor_type = getSensorType(this, channel_list)
    %GETSENSORTYPE Returns the channel sensor type (TC or RTD with type, or voltage)
    %  for one, multiple or all channels
    % 
    %   sensor_type = this.getChannelType(channel) 
    %       returns the type of the desired channel list (cell strings)
    %
    % e.g. sensor_type = this.getChannelType(3) returns 'V'
    %
    % See also MEASUREPOINT.SETSENSORTYPE, MEASUREPOINT.CHANNELTYPE
    %          MEASUREPOINT.MEASURE_TEMPERATURE, MEASUREPOINT.MEASURE_VOLTAGE
    
    if nargin==2
                % reformatting the channel list, in case needed
        if size(channel_list,1)>size(channel_list,2)
            channel_list = channel_list';
        end
        % prepare the channel list for the query
        cChannels = sprintf('%d,',channel_list);
        cChannels = cChannels(1:end-1);
        
        cQuery = sprintf(':CONF? (@%s)',cChannels);
        
    else
        cQuery = ':CONF?';
    end
        
        cSensor_type = this.query(cQuery);
        % returns 'V,E,V,J,V,J...'
        caSensor_type = strsplit(strtrim(cSensor_type),',');
        % returns a (cell) array of strings
        
        if numel(caSensor_type)==1
            caSensor_type = caSensor_type{1};
        end
    end
    
    
    % Configures specified analog input channels on the instrument for resistance measurements.
    % Configures specified analog input channels on the instrument for RTD temperature measurements.
    % Configures specified analog input channels on the instrument for thermocouple temperature measurements using the specified thermocouple type.
    % Configures specified analog input channels on the instrument for voltage measurements.
    % In a mix-and-match configuration, it is easy to accidentally mismatch
    % the software and hardware configuration for a channel. Therefore, it
    % is recommended that you pay particular attention when configuring
    % channels, since the resultant errors may be not large enough to
    % notice initially, but may be significantly larger than the accuracy
    % specification for the instrument.
    function setSensorType(this, channel, sensor_type)
    %SETSENSORTYPE Sets the channel type (TC or RTD with type, or voltage)
    % 
    %   this.setChannelType(channel, type) 
    %       changes the destired channel to the desired type
    %
    %   Supported types for TC   channels (O:7) are {'J','K','B','E','N','R','S','T'}
    %   Supported types for RTD channels (8:31) are {'PT100','PT500','PT1000',,
    %       'A_PT100','A_PT500','A_PT1000','PT100_3''PT500_3','PT1000_3','A_PT100_3',
    %       'A_PT500_3','A_PT1000_3'}
    %
    % See also MEASUREPOINT.GETSENSORTYPE, MEASUREPOINT.CHANNELTYPE
    %          MEASUREPOINT.MEASURE_TEMPERATURE, MEASUREPOINT.MEASURE_VOLTAGE
    
        switch sensor_type 
            case {...
                'J',...
                'K',...
                'B',...
                'E',...
                'N',...
                'R',...
                'S',...
                'T' ...
            }
                str_query = sprintf(':CONF:TEMP:TC %s, (@%d)',sensor_type,channel);
            case {...
                'PT100',...
                'PT500',...
                'PT1000',...
                'A_PT100',...
                'A_PT500',...
                'A_PT1000',...
                'PT100_3',...
                'PT500_3',...
                'PT1000_3',...
                'A_PT100_3',...
                'A_PT500_3',...
                'A_PT1000_3' ...
              }
              str_query = sprintf(':CONF:TEMP:RTD %s, (@%d)',sensor_type,channel);
            case 'V'
                str_query = sprintf(':CONF:VOLT (@%d)',channel);
        end
        
        % send out the query
        this.query(str_query);
        % fprintf(this.comm, str_query);
    end
    
    
    function dget = get(this)
        dget = -1;
    end
    
    function set(this, value)
        
    end
    
    function aTemp_degC = measure_temperature_tc(this, channel_list, channel_type)
    %MEASURE_TEMPERATURE Measure the temperature one or multiple channels
    %
    %   dTemp_degC = measure_temperature_tc(channel_list) measures the temperature
    %       on the channel_list, returned as a vector (in degree C)
    %
    %   dTemp_degC = measure_temperature_tc(channel_list, channel_type)
    %       allows you specify the channel_type (e.g. E-type thermocouple)
    %
    %  e.g. : this.measure_temperature_tc([2,4:6], 'K') returns the temperature
    %  readings from channels 2,4,5 and 6, and set their type as 'K'
    %
    % Note that channels 0-7 are thermocouple and ch 8-47 are RTDs
    %
    % If no channel type is given, channel type will be set as default ('J')
    % If multiple channels are read at once, they must have the same type,
    % otherwise please use this.measure_multi()
    % 
    %   See also MEASURPOINT.MEASURE_VOLTAGE, MEASURPOINT.MEASURE_MULTI,
    %       	 MEASURPOINT.CHANNELTYPE, MEASURPOINT.GETSENSORTYPE
    
        % if channel type is not given, use default
        
        if nargin<3
            channel_type = 'DEF';
        end

        if ~isempty(channel_list)
            % reformatting the channel list, in case needed
            if size(channel_list,1)>size(channel_list,2)
                channel_list = channel_list';
            end
            
            % number of channels to be read
            nchannels = numel(channel_list);
            % number of bytes to read from the buffer
            
            nbytes = this.getNumOfExpectedBytes(nchannels);
            
            % prepare the channel list for the query
            cChannels = sprintf('%d,',channel_list);
            cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
            
            % query string
            sQuery = sprintf('MEAS:TEMP:TC? %s,(@%s)', channel_type, cChannels);
            
            % send the query
            cDataBytestring = this.queryData(sQuery,nbytes);
            % unpack the result
            [cDataBitstring_cell, ndata, block_length] = this.unpack(cDataBytestring);
            
            % Convert the data and parse it to each channel
            
            aTemp_degC = zeros(1,length(channel_list));
            for i_chan = 1:length(channel_list) % parse
                try % convert
                    aTemp_degC(i_chan) = this.convertIEEE_754(cDataBitstring_cell{i_chan});
                catch
                    warning('error while reading temperature on one channel')
                    aTemp_degC(i_chan) = -274;
                end
            end
        else % empty channel list
            aTemp_degC = [];
        end
        
    end
    
    % {u8Channel} zero-indexed channel of the instrument
    function [d, lError] = getScanDataOfChannel(this, u8Channel)
        [dAll, lError] = this.getScanData();
        d = dAll(u8Channel + 1);
        
    end
    
    
    % Returns {double n x 48} scan records from the circular
    % buffer where n is the lower of the number chronologically newer
    % than the provided index or the maximum number of records supported
    % by the size of the network packet, which is 20 records when each
    % record contains 48 channel.  It also returns the end index
    % @param {double 1x1} dIndex - [0 - large number]
    
    function [result, dIndexEnd] = getScanDataAheadOfIndex(this, dIndex)
        
        this.lIsBusy = true;
        % Ask the hardware for the most recent index of the circular buffer
        % that was filled and do a FETCH to get data from it
        [dIndexStart, dIndexEnd] = this.getIndiciesOfScanBuffer();
        
        % Error checking
        if dIndex < dIndexStart
            dIndex = dIndexStart;
        end
        
        if dIndexEnd == 0
            result = zeros(1, 48);
            return;
        end
        
        if dIndex > dIndexEnd
            dIndex = dIndexEnd - 1;
        end
        
        dNum = dIndexEnd - dIndex;
        if dNum > 20 % max supported by network packet 
            dNum = 20; 
        end
              
        result = this.getScanDataSet(dIndex, dNum);
        dIndexEnd = dIndex + dNum;
        this.lIsBusy = false;
        
    end
    
    % Returns {double n x 49} scan records from the circular
    % buffer between indicies dIndex and dIndex + dNumRecords
    % The amount of data that is return is limited by the packet size of the network. 
    % The absolute limitation on TCP packet size is 64K (65535 bytes),
    % but in practicality this is far larger than the size of any
    % packet you will see, because the lower layers (e.g. ethernet)
    % have lower packet sizes which is about 20 records when the records
    % contain 48 channels each
    % @param {double 1x1} dIndex - [0 - large number]
    % @param {double 1x1} dNumRecords - number of records to retrieve
    
    function [result] = getScanDataSet(this, dIndex, dNumRecords)
        
        % NOTE
        this.lIsBusy = true;
        
        % Error checking based on populated indicies of the buffer
        
        [dIndexStart, dIndexEnd] = this.getIndiciesOfScanBuffer();
        if dIndex < dIndexStart
            dIndex = dIndexStart;
        end
        
        if dIndexEnd - dIndexStart < dNumRecords
            dNumRecords = dIndexEnd - dIndexStart;
        end
        
        if dNumRecords == 0
            result = zeros(1, 49);
            return
        end
        
        cCmd = sprintf('FETCH? %d, %d', dIndex, dNumRecords);
        fprintf(this.comm, cCmd); 
                
        
        % BYTE 1 - {ASCII} #
        % BYTE 2 - {ASCII} is a character 1-9, which is the number
        % of bytes that the data length block occupies
        % BYTE 3 up to 11 - {ASCII} characters 1-9 in sequence that
        % show the number of bytes that follow, examples (after conversion
        % to ASCII) are 4 (when reading one channel), 8 (when reading two channels), 192
        % when reading 48 channels.
        % BYTE 4 up to byte 12 is the start of the 4-byte data chunks 
        % For the FETCH query, it returns SCAN_RECORD which consists of:
        % unsigned long tmStamp;
        % unsigned long tmMillisec;
        % unsigned long scanNumber;
        % unsigned long numValues;
        % float values[];
        
        % For each scan record, get back
        % 4 bytes for tmStamp
        % 4 bytes for tmMillisec
        % 4 bytes for scanNumber
        % 4 bytes for numValues
        % 4 bytes for each channel that was specified in the channel list. (192 bytes if 48 channels)
        % -------
        % = 208 bytes
        
        dNumBytesData = 208 * dNumRecords;
        dNumBytesHeader = ...
            1 + ... % header byte for # char
            1 + ... % this byte contains the number of bytes in the data length byte group
            max(ceil(log10(dNumBytesData)), 4); % one byte for each data decimal, with a minimum of 4
        dNumBytesTerminator = 1; % stop byte for terminator ; char
        
        dNumBytes = dNumBytesHeader + dNumBytesData + dNumBytesTerminator;
       
        [bytes_dec, count, error] = fread(this.comm, dNumBytes);
        
        if ~isempty(error)
            fprintf('+datatranslation.MeasurPoint.getScanDataSet ERROR\n');
            fprintf('%s\n', error);
            fprintf('Returning zeros');
            result = zeros(1, 49);
            return;
        end
                
              
        % Convert bytes_dec into a hex char array
        
        bytes = dec2hex(bytes_dec);
        % e.g. bytes ~ ['23';'31';'34';'47';'C3';'4F';'80':'0A']'

        % reshape the bytes into a bytstring
        bytestring = reshape(bytes',1,2*size(bytes_dec,1));
        % e.g. bytestring = '23313447C34F800A'
        
        % Skip the number of bytes in the header, two ascii characters per
        % byte
        cursor = dNumBytesHeader * 2 + 1;
        
        result = zeros(dNumRecords, 49);
        
        for m = 1 : dNumRecords
            
            % tmStamp (long)
            % The time stamp of the scan record, defined as the number of
            % seconds that have elapsed since Coordinated Universal Time (UTC)
            wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
            cursor = cursor + 2 * 4;
            tmStamp = hex2dec(wordLong);

            % tmMillisec (long)
            % The millisecond after tmStamp at which the sample was acquired.
            wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
            cursor = cursor + 2 * 4;
            tmMillisec = hex2dec(wordLong);

            % scanNumber (long)
            % The index of the scan record in the circular buffer.
            wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
            cursor = cursor + 2 * 4;
            scanNumber = hex2dec(wordLong);

            %numValues (long)
            % The number of single-precision values that follow in the record.
            wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
            cursor = cursor + 2 * 4;
            numValues = hex2dec(wordLong);

            % Channels 0 - 47 result (float)
            
            for n = 1 : 48
                wordIEEE32 = bytestring(cursor : cursor + 2 * 4 - 1);
                result(m, n) = this.convertIEEE32Word(wordIEEE32);
                cursor = cursor + 2 * 4;
            end
            
            result(m, 49) = tmStamp + tmMillisec / 1000;
           
        end
        
        this.lIsBusy = false;
                
    end
    
    % Returns {double 1x48} fresh value of every channel from the circular
    % buffer on the instrument.  The circular buffer is updated internally
    % at 10Hz and reading it is fast.  It is recommended to use always
    % use this method to read data.  
    % setScanList
    % setScanRate
    % setSizeOfScanBuffer
    % setScanTriggeSourceToDefault
    % setSensorType
    % initiateScan
    % abortScan
    function [result, lError] = getScanData(this)
        
        % reset {logical} error
        lError = false;
        
        % Check if should return cached value
        if ~isempty(this.ticGetVariables)
            if (toc(this.ticGetVariables) < this.tocMin)
                % Use cache
                result = this.dScanData;
                % fprintf('datatranslation.MeasurPoint.getScanData() using cache\n');
                return;
            end
        end
            
        this.lIsBusy = true;
        
        % Ask the hardware for the most recent index of the circular buffer
        % that was filled and do a FETCH to get data from it
        [dIndexStart, dIndexEnd] = this.getIndiciesOfScanBuffer();
        cCmd = sprintf('FETCH? %d, 1', dIndexEnd);
        fprintf(this.comm, cCmd); 
        dBytes = this.getNumOfExpectedBytesInScanRecord();
       
        [bytes_dec, count, errorMsg] = fread(this.comm, dBytes);
        
        
        if ~isempty(errorMsg)
            cMsg = [...
                    '+datatranslation/MeasurPoint.getScanData()', ...
                    'read error. ', ...
                    'Returning last good data and lError = true.\n'
                ];
                fprintf(cMsg);
            lError = true;
            result = this.dScanData;
            return;
        end
        
        %{
        if ~isempty(errorMsg)
            
            % Try again
            this.dNumOfSequentialGetScanDataErrors = this.dNumOfSequentialGetScanDataErrors + 1;
        
            if this.dNumOfSequentialGetScanDataErrors > 5
                cMsg = [...
                    '+datatranslation/MeasurPoint.getScanData()', ...
                    '> 5 sequential errors. ', ...
                    'Returning last good data.\n'
                ];
                fprintf(cMsg);
                result = this.dScanData;
                return;
                
            end
            % Timeout / Error
            
            % Clear bytes available so the next time we don't get
            % a messed up answer
            
            cMsg = [...
                '+datatranslation/MeasurPoint.getScanData() ', ...
                sprintf('ERROR #%d calling recursively', this.dNumOfSequentialGetScanDataErrors), ...
                '\n' ...
            ];
            fprintf(cMsg);
            
            this.clearBytesAvailable();
            this.lIsBusy = false;
            
            
            result = this.getScanData(); % call recursively
            return;
        end
        %}
        
        
        
        % BYTE 1 - {ASCII} #
        % BYTE 2 - {ASCII} is a character 1-9, which is the number
        % of bytes that the data length block occupies
        % BYTE 3 up to 11 - {ASCII} characters 1-9 in sequence that
        % show the number of bytes that follow, examples (after conversion
        % to ASCII) are 4 (when reading one channel), 8 (when reading two channels), 192
        % when reading 48 channels.
        % BYTE 4 up to byte 12 is the start of the 4-byte data chunks 
        % For the FETCH query, it returns SCAN_RECORD which consists of:
        % unsigned long tmStamp;
        % unsigned long tmMillisec;
        % unsigned long scanNumber;
        % unsigned long numValues;
        % float values[];
        
        % LAST BYTE {ASII} ; char
        
        
        % Convert bytes_dec into a hex char array
        
        bytes = dec2hex(bytes_dec);
        % e.g. bytes ~ ['23';'31';'34';'47';'C3';'4F';'80':'0A']'

        % reshape the bytes into a bytstring
        bytestring = reshape(bytes',1,2*size(bytes_dec,1));
        % e.g. bytestring = '23313447C34F800A'
        
        % Skip the first six bytes of data (12 hex characters)
        % Skip byte 1 x23
        % Skip byte 2, which has ASCII value "4" x34 // number of bytes in
        % the data length block
        % Skip byte 3, 4, 5, 6 which has ASCII value "0208" or 
        % hex value x30323038 "0" "2" "0" "8" // this says there are 208
        % bytes in the data block:
        % 4 bytes for tmStamp
        % 4 bytes for tmMillisec
        % 4 bytes for scanNumber
        % 4 bytes for numValues
        % 4 bytes for each channel that was specified in the channel list. (192 bytes if 48 channels)
        % -------
        % = 208 bytes
        % So for each scan record, get back 208 bytes
       
        cursor = 6 * 2 + 1;
        
        % tmStamp (long)
        % The time stamp of the scan record, defined as the number of
        % seconds that have elapsed since Coordinated Universal Time (UTC)
        wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
        cursor = cursor + 2 * 4;
        tmStamp = hex2dec(wordLong);
        
        % tmMillisec (long)
        % The millisecond after tmStamp at which the sample was acquired.
        wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
        cursor = cursor + 2 * 4;
        tmMillisec = hex2dec(wordLong);
        
        % scanNumber (long)
        % The index of the scan record in the circular buffer.
        wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
        cursor = cursor + 2 * 4;
        scanNumber = hex2dec(wordLong);
        
        %numValues (long)
        % The number of single-precision values that follow in the record.
        wordLong = bytestring(cursor : cursor + 2 * 4 - 1);
        cursor = cursor + 2 * 4;
        numValues = hex2dec(wordLong);
        
        % Channels 0 - 47 result (float)
        result = zeros(1, 48);
        for n = 1 : 48
            wordIEEE32 = bytestring(cursor : cursor + 2 * 4 - 1);
            result(n) = this.convertIEEE32Word(wordIEEE32);
            cursor = cursor + 2 * 4;
        end
           
        % Reset tic and update cache
        this.ticGetVariables = tic();
        this.dScanData = result;
        this.lIsBusy = false;
        this.dNumOfSequentialGetScanDataErrors = 0;
        
    end
    
    
    function aTemp_degC = measure_temperature_rtd(this, channel_list, channel_type)
    %MEASURE_TEMPERATURE_RTD Measure the temperature one or multiple RTD channels
    %
    %   dTemp_degC = measure_temperature_rtd (channel_list) measures the temperature
    %       on the channel_list, returned as a vector (in degree C)
    %
    %   dTemp_degC = measure_temperature_tc(channel_list, channel_type)
    %       allows you specify the channel_type
    %
    %  e.g. : this.measure_temperature_tc([2,4:6], 'PT1000') returns the temperature
    %  readings from channels 2,4,5 and 6, and set their type as 'PT1000'
    %
    % Note that channels 0-7 are thermocouple and ch 8-47 are RTDs
    %
    % If no channel type is given, channel type will be set as default ('J')
    % If multiple channels are read at once, they must have the same type,
    % otherwise please use this.measure_multi()
    % 
    %   See also MEASURPOINT.MEASURE_VOLTAGE, MEASURPOINT.MEASURE_MULTI,
    %       	 MEASURPOINT.CHANNELTYPE, MEASURPOINT.GETSENSORTYPE
    
        % if channel type is not given, use default
        if nargin<3
            channel_type = 'DEF';
        end

        if ~isempty(channel_list)
        % reformatting the channel list, in case needed
        if size(channel_list,1)>size(channel_list,2)
            channel_list = channel_list';
        end

        % number of channels to be read
        nchannels = numel(channel_list);
        % number of bytes to read from the buffer
        
        nbytes = this.getNumOfExpectedBytes(nchannels);
        
        % prepare the channel list for the query
        cChannels = sprintf('%d,',channel_list);
        cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
        
        % query string
        sQuery = sprintf('MEAS:TEMP:RTD? %s,(@%s)', channel_type, cChannels);
        
        % send the query
        cDataBytestring = this.queryData(sQuery,nbytes);
        % unpack the result
        [cDataBitstring_cell, ndata, block_length] = this.unpack(cDataBytestring);
        
        % Convert the data and parse it to each channeln
        
        aTemp_degC = zeros(1,length(channel_list));
        for i_chan = 1:length(channel_list) % parse
            try % convert
                aTemp_degC(i_chan) = this.convertIEEE_754(cDataBitstring_cell{i_chan});
            catch
                warning('error while reading temperature on one channel')
                aTemp_degC(i_chan) = -274;
            end
        end
        else % empty channel list
            aTemp_degC = [];
        end
    end
    
    function aVolt_V = measure_voltage(this, channel_list)
    %MEASURE_VOLTAGE Measure the temperature on one or multiple channels
    %
    %   dVolt_V = this.measure_voltage(channel_list) measure the voltage of
    %   the channels on the channel list, and returns a vector of values in
    %   volts
    %
    %   e.g. this.measure_voltage(31:47) will return the voltage for channels 
    %   31 to 47
    %   
    %   Note that chan 31:47 support variable voltage range
    %
    %   See also MEASURPOINT.MEASURE_TEMPERATURE, MEASURPOINT.MEASURE_MULTI
    %       	 MEASURPOINT.CHANNELTYPE, MEASURPOINT.GETSENSORTYPE
    
    if ~isempty(channel_list)
        % reformatting the channel list if needed
        if size(channel_list,1)>size(channel_list,2)
            channel_list = channel_list';
        end
        
        % number of channels to be read
        nchannels = numel(channel_list);
        % number of bytes to read from the buffer
        
        nbytes = this.getNumOfExpectedBytes(nchannels);
        
        % prepare the channel list for the query
        cChannels = sprintf('%d,',channel_list);
        cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
        
        % query string
        sQuery = sprintf('MEAS:VOLT? (@%s)', cChannels);
        
        % send the query and wait for answer
        cBytestring = this.queryData(sQuery,nbytes);
        
        % unpack the data
        [cDataBitstrings_cell, ~, ~] = this.unpack(cBytestring);
        
        % Parse and convert the data
        aVolt_V = zeros(1,length(channel_list));
        for i_chan = 1:length(channel_list)
            try
                aVolt_V(i_chan) = this.convertIEEE_754(cDataBitstrings_cell{i_chan});
            catch
                warning('error while reading temperature on one channel')
                aVolt_V(i_chan) = -1;
            end
        end
    else %empty channel list
        aVolt_V = [];
    end
    end
    
    function aRes_O = measure_resistance(this, channel_list)
    %MEASURE_RESISTANCE Measure the temperature on one or multiple channels
    %
    %   aRes_O = this.measure_resistance(channel_list) measure the resistance of
    %   the channels on the channel list, and returns a vector of values in
    %   ohms
    %
    %   e.g. this.measure_res(8:31) will return the voltage for channels
    %   31 to 47
    %
    %   Note that this only works for RTD channels (typically ch 8 to 31)
    %
    %   See also MEASURPOINT.MEASURE_TEMPERATURE, MEASURPOINT.MEASURE_MULTI
    %       	 MEASURPOINT.CHANNELTYPE, MEASURPOINT.GETSENSORTYPE
        
        if ~isempty(channel_list)
            % reformatting the channel list if needed
            if size(channel_list,1)>size(channel_list,2)
                channel_list = channel_list';
            end
            
            % number of channels to be read
            nchannels = numel(channel_list);
            % number of bytes to read from the buffer
            
            nbytes = this.getNumOfExpectedBytes(nchannels);
            
            % prepare the channel list for the query
            cChannels = sprintf('%d,',channel_list);
            cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
            
            % query string
            sQuery = sprintf('MEAS:RES? (@%s)', cChannels);
            
            % send the query
            cBytestring = this.queryData(sQuery,nbytes);
            
            % unpack the data
            [cDataBitstrings_cell, ~, ~] = this.unpack(cBytestring);
            
            % Parse and convert the data
            aRes_O = zeros(1,length(channel_list));
            for i_chan = 1:length(channel_list)
                try
                    aRes_O(i_chan) = this.convertIEEE_754(cDataBitstrings_cell{i_chan});
                catch
                    warning('error while reading temperature on one channel')
                    aRes_O(i_chan) = -1;
                end
            end
        else
            aRes_O = [];
        end
    end
    
    function [readings, channel_map] = measure_multi(this, channel_list)
        % Map onto proper channels
        [tc, rtd, volt] =  this.channelType();
        tc_channels   = intersect(tc,channel_list);
        rtd_channels  = intersect(rtd,channel_list);
        volt_channels = intersect(volt,channel_list);
        
        channel_map = [tc_channels, rtd_channels, volt_channels];
        tc_readings   = this.measure_temperature_tc(tc_channels);
        rtd_readings  = this.measure_temperature_rtd(rtd_channels);
        volt_readings = this.measure_voltage(volt_channels);
        
        readings = [tc_readings, rtd_readings, volt_readings];
    end
    
    function str_temp = MEASTEMP(this)
    %MEASTEMP Direct hex string output from the instrument on channel 2
    %   for debug purpose
    
    % test function -- should work
        str_temp = this.query('MEAS:TEMP:TC? DEF,(@2)');
    end
    
    function str_volt = MEASVOLT(this)
    %MEASVOLT Direct hex string output from the instrument on channel 2
    %   for debug purpose
    
    % test function -- should work
        str_volt = this.query('MEAS:VOLT? (@2)');
    end
    
    function str_res = MEASRES(this)
    %MEASRES Direct hex string output from the instrument on channel 2
    
    % untest function -- shouldn't work
        str_res = this.query('MEAS:RES? (@12)');
    end
    
    function delete(this)
    %DELETE MeasurPoint class destructor
    %(aside from it closes the TCP/IP connection properly)
    
        this.disconnect();
    end
    
    function general_status(this)
    %GENERAL_STATUS Prints the general status of the insrument
    %   this.general_status()

        str_idn  = this.query('*IDN?');
        str_conf = this.query(':CONF?');
        str_stb  = this.query('*STB?');
        str_cen  = this.query('SYSTem:PASSword:CENable:STATe?');
        fprintf('%s\n', str_idn)
        fprintf('%s\n', str_conf)
        fprintf('%s\n', str_stb)
        fprintf('%s\n', str_cen)
    end
    
    function [data_cell, ndata, block_length] = unpack(~, str_hex)
    % [data_cell, ndata, block_length] = unpack(this,str)
        
        % str_hex = sprintf('%x',str_in);
        % number of bytes per chunk of data (fixed)
        nbyte       = 4;
        
        % header of the message (should be a #)
        c_header	= char(hex2dec(str_hex(1:2)));
        
        % number of decimal in the block length
        c_ndec      = char(hex2dec(str_hex(3:4))); %decimal number of the block length
        ndec        = str2double(c_ndec);
        % block length (nbyte x nb channels)
        c_block_length_dec1 = char(hex2dec(str_hex(5:6)));
        c_block_length_dec2 = char(hex2dec(str_hex(7:8)));
        
        % if the number of decimal is larger than 1, do this
        if ndec == 1
            block_length = str2double(c_block_length_dec1);
        else
            block_length = str2double(strcat(c_block_length_dec1,c_block_length_dec2));
        end
        
        % data begins here
        ndata = block_length/nbyte;
        data_cell = cell(1,ndata);
        cursor = 5+2*ndec;
        for i_data=1:(ndata)
            try
            data_cell{i_data} = dec2bin(hex2dec(str_hex(cursor:cursor+2*nbyte-1)));
            catch
                warning('data block #%d is empty',i_data)
            end
            cursor = cursor+2*nbyte;
        end
    end
    
    function bitstring = bytestr2bitstr(bytestring)
    %BYTESTR2BITSTR Convert a bytestring into a bitstring
    
        bitstring =  dec2bin(hex2dec(bytestring));
    end
    
    % @param {char 1x8} 8-char hex string in IEEE.754 32-bit format
    function d = convertIEEE32Word(this, cWord)
        d = this.convertIEEE_754(dec2bin(hex2dec(cWord)));
    end

    %TODO : refactor, static
    function dec_single = convertIEEE_754(~, str_bits)
    %CONVERTIEEE_754 Converts a measurement query string to a decimal value
    % It does this by apply ing the IEEE_754 single precision float standard
    %   dec_single = MEASUREpoint.convertIEEE_754(str)
    %
    %example:
    %   cTemp = this.MEASTEMP()
    %   dTemp_degC = this.convertIEEE_754(cTemp)
    %
    %   (for the recordds, 41bd99b6 => 24.7° C
    

        %IEEE_754 convention
        % see https://www.h-schmidt.net/FloatConverter/IEEE754.html
        
        % padding with zeros
        val_b = str_bits;
        while length(val_b)<32
            %add invisble leading bit (underflow)
            val_b = strcat('0',val_b);
        end
        
        % compute the signum
        signum = sign(-(str2num(val_b(1))-0.5));
        % compute the exponent
        exponent = (bin2dec(val_b(3:9))+1)-(1-str2double(val_b(2)))*128;
        % compute the mantissa (binary floating point)
        bits = str2num(val_b(10:end)')';
        
        weights = 2.^(-(1:length(bits)));
        mantissa = 1+sum(bits.*weights);
        
        % decimal representations
        dec_single = signum*mantissa*2^exponent;
    end
    
    function [channels_tc, channels_rtd, channels_vol] = channelType(this)
    %CHANNELTYPE Returns a list of the channels types
    %   [channels_tc, channels_rtd, channels_vol] = this.channelType()
    %       returns three arrays containing the channels that support
    %       thermocouples, RTD and variable voltage sensor.
    %
    % See also MEASUREPOINT.GETSENSORTYPE, MEASUREPOINT.SETSENSORTYPE
    
        cTC  = strtrim(this.query(':SYSTem:CHANnel:TC?'));
        cRTD = strtrim(this.query(':SYSTem:CHANnel:RTD?'));
        cVol = strtrim(this.query(':SYST:CHAN:VOLT:RANG?'));
        
        channels_tc  = str2num(cTC(3:end-1));
        channels_rtd = str2num(cRTD(3:end-1));
        channels_vol = str2num(cVol(3:end-1));
    end
    
    function monitor_terminal(this, channel, dt_s)
    %MONITOR LOOP Monitor the temperature on a specific channel
    %
    %   this.monitor_loop(channel, dt_s) 
    %       diplays the temperature on a specific channel with reading
    %       interval dt_s (in seconds)
    %
    %
    %
    % HIT CRTL+C to stop
    %
    % See also MEASUREPOINT.MONITOR_GRAPH, MEASURPOINT.MEASURE_TEMPERATURE
    
    if ~exist('dt_s')
        dt_s = 1;
    end
    
        fprintf('Hit Ctrl+C to stop\n')
        a = '';
        warning off
        while true
            temp = this.measure_temperature_tc(channel);
            if ~strcmp(a,'')
                del = '';
                for i=1:length(a)
                    del = strcat(del,'\b');
                end
                fprintf(del)
            end
            
            a = sprintf('temperature = %2.3f deg C',temp);
            fprintf('%s',a)
            pause(dt_s)
        end
    end
    
    function monitor_graph(this, channel, dt_s, N_pts)
    %MONITOR_GRAPH plot the temperature readings on a figure
    %
    %    this.monitor_graph(channel) display continous reading of the
    %       temperature from a specific channel with 0.1s time step over 10s
    %
    %    this.monitor_graph(channel, dt_s, N_pts) lets you define the time
    %    step and the total number of points.
    %
    %    
    % See also MEASUREPOINT.MONITOR_TERMINAL
    
        if ~exist('dt_s')
            dt_s = 0.1;
        end
        if ~exist('N_pts')
            N_pts = 100;
        end
        
        T0 = this.measure_temperature_tc(channel);
        t_s=(0:(N_pts-1))*dt_s;
        aTemp_C = ones(1,N_pts).*T0;
        
        hFigure = figure('NumberTitle','off','Name','Temperature monitor',...
                         'ToolBar','none');
        idx = 0;
        while hFigure.isvalid
            idx = mod(idx,N_pts)+1;
            aTemp_C(idx) = this.measure_temperature_tc(channel);
            plot(t_s,aTemp_C,'k',t_s(idx),aTemp_C(idx),'xk')
            xlabel('time [sec]');
            ylabel('temperature [degC]')
            title(sprintf('Channel %d',channel));
            pause(dt_s)
        end
    end
    
end %methods


   %remove some inherited handle methods from autocompletion
   methods(Hidden)
        function lh = addlistener(varargin)
            lh = addlistener@handle(varargin{:});
        end
        function notify(varargin)
            notify@handle(varargin{:});
        end
        function Hmatch = findobj(varargin)
            Hmatch = findobj@handle(varargin{:});
        end
        function p = findprop(varargin)
            p = findprop@handle(varargin{:});
        end
        function TF = eq(varargin)
            TF = eq@handle(varargin{:});
        end
        function TF = ne(varargin)
            TF = ne@handle(varargin{:});
        end
        function TF = lt(varargin)
            TF = lt@handle(varargin{:});
        end
        function TF = le(varargin)
            TF = le@handle(varargin{:});
        end
        function TF = gt(varargin)
            TF = gt@handle(varargin{:});
        end
        function TF = ge(varargin)
            TF = ge@handle(varargin{:});
        end
        
        
        function nbytes = getNumOfExpectedBytesInScanRecord(this)
            
            nbytes = 215;
            return
            
            %{
            struct {
                unsigned long tmStamp;
                unsigned long tmMillisec;
                unsigned long scanNumber;
                unsigned long numValues;
                float values[];
            } SCAN_RECORD;
            %}

            % Example reaponse for 2 channels
            % 1-byte % x23 character
            % 1-byte % 
            
            numDataBytes = 4 + 4 + 4 + 4 + 48 * 4; % base10
            
            % num of base10 numbers to represent numDataBytes (this number
            % is in the response in base10, need one byte for each base10
            % number
            
            nbytes = 1 + ... % header byte for # char
                1 + ... % this byte contains the number of bytes in the data length byte group
                max(ceil(log10(10233)), 4) + ... % one byte for each data decimal, with a minimum of 4
                numDataBytes + ...
                1; % stop byte for terminator ; char
        end
        
        function nbytes = getNumOfExpectedBytes(this, channels)
            
            numDataBytes = channels * 4;
            nbytes = 1 + ... % header byte for # char
                1 + ... % this byte contains the number of bytes in the data length byte group
                ceil(log10(numDataBytes)) + ... % one byte for each data decimal
                numDataBytes + ...
                1; % stop byte for terminator ; char
        end
        
   end
   
end