classdef MEASURpoint < handle
% Wrapper for Data Translation MEASURpoint 
% DT8874-8T-24R-16V,14171149,3.1.0.2
%
% It requires Instrument Control Box, to use NI VISA in order 
% to communicate with SCPI via ethernet
%
%example of use :
%   mp = MEASURpoint();         % create the object
%   mp.connect();               % connect to the instrument
%   mp.idn();                   % ask the instrument identity
%   cAnswer     = mp.query('MEAS:VOLT? (@1)') % queries the instrument
%   dTemp_degC  = mp.measure_temperature_tc(2);  % measure temperature on ch2

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

methods
    
    function mp = MEASURpoint(varargin)
    % MEASURpoint Class constrctor
    %   mp = MEASURpoint() creates an object with default IP (see blow)
    %   mp = MEASURpoint('192.168.127.100')
    %       creates an object with the provided IP
    %
    % See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY
    
    % populate the IP adress
    if nargin==1
        mp.cIP = varargin{1};
    end
    
    % initialise the class
    mp.init();
    end
    
    function init(mp)
    %INIT Initializes the VISA object
    %(this function is called by the constructor of the class)
    %   mp.init()
    %
    % See also MEASURPOINT.STATUS, MEASURPOINT.CONNECT
    
        % SCPI connection string
        cSCPI_IP = sprintf('TCPIP::%s::INSTR',mp.cIP);
        
        % create a VISA object and store it as a property
        % mp.comm = visa('ni', cSCPI_IP);
        mp.comm = tcpip(mp.cIP, 5025);
        % Don't use Nagle's algorithm; send data
        % immediately to the newtork
        mp.comm.TransferDelay = 'off'; 
        
        if mp.verbosity>0
            disp('NI VISA object object initialized')
        end
    end
    
    function cStatus = status(mp)
    %STATUS gets the status of the VISA object
    %(this doesn't tell you if the device is connected)
    %   status = mp.status() returns true if the VISA object is valid
    %
    % See also MEASURPOINT.CONNECT
    
        if ~isempty(mp.comm) 
            %get the status of the VISA object (not the instrument itself!)
            cStatus = mp.comm.Status;
            if nargout == 0 
                fprintf('NI VISA Status : %s\n', cStatus);
            end
        else
            error('MEASURpoint not initialized')
        end
    end
    
    function connect(mp)
    %CONNECT Connects the VISA object to the instrument
    %(required for any query!)
    %   mp.connect()
    %
    % See also MEASURPOINT.ISCONNECTED, MEASURPOINT.DISCONNECT
    
        fopen(mp.comm);
        fprintf('Connected to remote host %s\n', mp.comm.propinfo.RemoteHost.DefaultValue)
    end
    
    function lIsConnected = isConnected(mp)
    %ISCONNECTED Checks whether the communication the device is established
    %   isconnected = mp.isConnected() returns 'true' if the device is
    %   available for queries
    %
    %   See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY
    
        lIsConnected = false;
        if ~isempty(mp.comm)
            lIsConnected = strcmp(mp.comm.Status,'open');
        else
            error('MEASURpoint not initialized')
        end
    end
    
    function disconnect(mp)
    %DISCONNECT Disconnects the device
    %(this function is called by the destructor)
    %   mp.disconnect()
    %
    %   See also MEASURPOINT.CONNECT
    
        if ~isempty(mp.comm)
            fclose(mp.comm);
            fprintf('Disconnected\n')
        end
    end
    
    function cAnswer = query(mp, str_query)
    %QUERY Performs a query of the instrument, to set or get a parameter
    %   cAnswer = query(str_query)
    %
    % example:
    %   cChan = mp.query('SYST:CHAN?')
    %
    %
    % 
    % NOTE: if you are dealing with data, avoid using mp.query, as 
    % mp.query('MEAS:VOLT? (@2)') should return a string with encoded
    % values, but missing elements; use mp.queryData instread
    %
    % BE CAREFUL! Measurement of values can be password protected; 
    % make sure the readings are enabled (mp.enable())
    % use mp.idn() to make sure there is actual communication with the inst
    % use mp.get_error() to troubleshoot message-forming error
    %
    % See also MEASUREPOINT.QUERYDATA, MEASURPOINT.ENABLE, MEASURPOINT.GET_ERROR, 
    %          MEASURPOINT.IDN
    
        cAnswer = '';
       % cQuery = strcat(str_query,';');
         cQuery = str_query;
        if ~isempty(mp.comm)
            
            %print query (for debugging)
            if mp.verbosity>2
                fprintf('SCPI query: "%s"\n',cQuery)
            end
            
            % perform a visa query
            if ~isempty(strfind(cQuery, '?'))
                % Expect an ascii answer in output buffer
                cAnswer = query(mp.comm,cQuery);
            else
                % Do not expect an answer in the output buffer
                fprintf(mp.comm, cQuery);
            end
            
            %{
            fprintf(mp.comm, cQuery);
            cAnswer = fscanf(mp.comm);
            %}
            
            %print answer
            if mp.verbosity>2
                fprintf('SCPI answer: "%s"\n',cAnswer)
            end
            
            %if the answer is empty, but the query was expecting an answer,
            %find out what kind com error happened
            if isempty(cAnswer) && ~isempty(strfind(cQuery, '?'))
                err_msg = query(mp.comm,'SYST:ERR?');
                fprintf('error message : %s',err_msg)
            end
        else
            error('MEASURpoint not initialized')
        end
    end
    
    function bytestring = queryData(mp, str_query, nbytes)
    %QUERYDATA Performs a low-level query of the instrument
    % This is important when handling with data, because otherwise Matlab
    % cast it as a results, sometime trimming it -- making the reading
    % unreliable.
    %   
    %   cAnswer = mp.queryData(str_query,nbytes)
    %   with str_query a SCPI query string, 
    %        nbytes the number of bytes expected (usually 4, +4 per channel)
    %        cAnswer is a bytestring (pairs of hexadecimal values)
    %
    % example:
    %   cChan = mp.queryData('MEAS:TEMP:TC? DEF,(@3)',8)
    %   >> cChan = '23313447C34F800A'
    %   
    % BE CAREFUL! Measurement of values can be password protected; 
    % make sure the readings are enabled (mp.enable())
    %
    % use mp.get_error() to troubleshoot message-forming error
    %
    % See also MEASURPOINT.QUERY, MEASUREPOINT.UNPACK, MEASURPOINT.CONVERTIEEE_754,
    %          MEASUREPOINT.MEASURE_TEMPERATURE, MEASUREPOINT.MEASURE_VOLTAGE
    %          MEASURPOINT.ENABLE, MEASURPOINT.GET_ERROR,MEASURPOINT.IDN, 
    
        cAnswer = '';
        cQuery = strcat(str_query,';');
        if ~isempty(mp.comm)
            
            %print query (for debugging)
            if mp.verbosity>2
                fprintf('SCPI query: "%s"\n',cQuery)
            end
            
            % send the command 
            % (e.g. cQuery='MEAS:TEMP:TC? DEF,(@3)')
            fprintf(mp.comm, cQuery); 
            
            % read the data
            bytes_dec = fread(mp.comm,nbytes); 
            % e.g.  [35;49;52;71;195;79;128;10]'
            
            if ~isempty(bytes_dec)
                % convert to bytes
                bytes = dec2hex(bytes_dec);
                % e.g. bytes ~ ['23';'31';'34';'47';'C3';'4F';'80':'0A']'
                
                % reshape the bytes into a bytstring
                bytestring = reshape(bytes',1,2*size(bytes_dec,1));
                % e.g. bytestring = '23313447C34F800A'
                
                %print answer
                if mp.verbosity>2
                    fprintf('SCPI answer: "%s"\n',cAnswer)
                end
                
                % if the answer is empty, but the query was expecting an answer,
                % find out what kind com error happened
            else
                err_msg = query(mp.comm,'SYST:ERR?');
                fprintf('error message : %s',err_msg)
            end
        else
            error('MEASURpoint not initialized')
        end
    end
    
    function cErr_msg = get_error(mp)
    %GET_ERROR Get the in the error log
    %   cErr_msg = mp.get_error()
    %
    % See also MEASURPOINT.ISCONNECTED, MEASURPOINT.QUERY, MEASURPOINT.ENABLE
    
        cErr_msg = query(mp.comm,'SYST:ERR?');
    end
    
    function lIsEnabled = enable(mp)
        
    %   See also MEASURPOINT.ISENABLED
        fprintf(mp.comm, ':SYST:PASS:CEN admin');
        lIsEnabled = mp.isEnabled;
        
        if mp.verbosity>0
            if mp.isEnabled
                fprintf('device enabled\n')
            else
                fprintf('device not enabled\n')
            end
        end
    end
    
    function lIsEnabled = isEnabled(mp)
    %ISENABLED lets you know whether measurements are password protected
    %   mp.isEnabled
    %
    %   See also MEASURPOINT.ENABLE
    
        sAnswer = query(mp.comm,':SYSTem:PASSword:CENable:STATe?');
        lIsEnabled = logical(strtrim(sAnswer));
    end
    
    function cIDN = idn(mp)
    %IDN Standard SCPI '*IDN?' query, to test proper communication
    %   cIDN = mp.idn() returns the ID string, e.g.
    %   >>'Data Translation,DT8874-8T-24R-16V,14171149,3.1.0.2'
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.SYSTCHAN, MEASURPOINT.CONF
    
        if ~isempty(mp.comm) 
            if mp.isConnected()
                % perform the query
                cIDN = mp.query('*IDN?');
                % trim the result
                cIDN = strtrim(cIDN);
            else
                error('MEASURpoint not connected')
            end
        else
            error('MEASURpoint not initialized')
        end
        
        if mp.verbosity>0
            fprintf('device *IDN: %s\n',cIDN)
        end
    end
    
    function cChan = SYSTCHAN(mp)
    %SYSTCHAN Lists available channels
    %   cChan = mp.SYSTCHAN()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        % Perform the query
        cChan = mp.query('SYST:CHAN?');
        % trim the result
        cChan = strtrim(cChan);
    end
    
    function cConf = CONF(mp)
    % CONF Lists available channels
    %   cChan = mp.CONF()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        % Perform the query
        cConf = mp.query('CONF?');
        % trim the result
        cConf = strtrim(cConf);
        
    end
    
    
    function caSensor_type = getSensorType(mp, channel_list)
    %GETSENSORTYPE Returns the channel sensor type (TC or RTD with type, or voltage)
    %  for one, multiple or all channels
    % 
    %   sensor_type = mp.getChannelType(channel) 
    %       returns the type of the desired channel list (cell strings)
    %
    % e.g. sensor_type = mp.getChannelType(3) returns 'V'
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
        
        cSensor_type = mp.query(cQuery);
        % returns 'V,E,V,J,V,J...'
        caSensor_type = strsplit(strtrim(cSensor_type),',');
        % returns a (cell) array of strings
        
        if numel(caSensor_type)==1
            caSensor_type = caSensor_type{1};
        end
    end
    
    function setSensorType(mp, channel, sensor_type)
    %SETSENSORTYPE Sets the channel type (TC or RTD with type, or voltage)
    % 
    %   mp.setChannelType(channel, type) 
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
            case {'J','K','B','E','N','R','S','T'}
                str_query = sprintf(':CONF:TEMP:TC %s, (@%d)',sensor_type,channel);
            case {'PT100','PT500','PT1000','A_PT100','A_PT500','A_PT1000','PT100_3',...
                  'PT500_3','PT1000_3','A_PT100_3','A_PT500_3','A_PT1000_3'}
              str_query = sprintf(':CONF:TEMP:RTD %s, (@%d)',sensor_type,channel);
            case 'V'
                str_query = sprintf(':CONF:VOLT (@%d)',channel);
        end
        
        % send out the query
        mp.query(str_query);
        % fprintf(this.comm, str_query);
    end
    
    
    function dget = get(mp)
        dget = -1;
    end
    
    function set(mp, value)
        
    end
    
    function aTemp_degC = measure_temperature_tc(mp, channel_list, channel_type)
    %MEASURE_TEMPERATURE Measure the temperature one or multiple channels
    %
    %   dTemp_degC = measure_temperature_tc(channel_list) measures the temperature
    %       on the channel_list, returned as a vector (in degree C)
    %
    %   dTemp_degC = measure_temperature_tc(channel_list, channel_type)
    %       allows you specify the channel_type (e.g. E-type thermocouple)
    %
    %  e.g. : mp.measure_temperature_tc([2,4:6], 'K') returns the temperature
    %  readings from channels 2,4,5 and 6, and set their type as 'K'
    %
    % Note that channels 0-7 are thermocouple and ch 8-47 are RTDs
    %
    % If no channel type is given, channel type will be set as default ('J')
    % If multiple channels are read at once, they must have the same type,
    % otherwise please use mp.measure_multi()
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
            
            nbytes = mp.getNumOfExpectedBytes(nchannels);
            
            % prepare the channel list for the query
            cChannels = sprintf('%d,',channel_list);
            cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
            
            % query string
            sQuery = sprintf('MEAS:TEMP:TC? %s,(@%s)', channel_type, cChannels);
            
            % send the query
            cDataBytestring = mp.queryData(sQuery,nbytes);
            % unpack the result
            [cDataBitstring_cell, ndata, block_length] = mp.unpack(cDataBytestring);
            
            % Convert the data and parse it to each channel
            
            aTemp_degC = zeros(1,length(channel_list));
            for i_chan = 1:length(channel_list) % parse
                try % convert
                    aTemp_degC(i_chan) = mp.convertIEEE_754(cDataBitstring_cell{i_chan});
                catch
                    warning('error while reading temperature on one channel')
                    aTemp_degC(i_chan) = -274;
                end
            end
        else % empty channel list
            aTemp_degC = [];
        end
        
    end
    
    function aTemp_degC = measure_temperature_rtd(mp, channel_list, channel_type)
    %MEASURE_TEMPERATURE_RTD Measure the temperature one or multiple RTD channels
    %
    %   dTemp_degC = measure_temperature_rtd (channel_list) measures the temperature
    %       on the channel_list, returned as a vector (in degree C)
    %
    %   dTemp_degC = measure_temperature_tc(channel_list, channel_type)
    %       allows you specify the channel_type
    %
    %  e.g. : mp.measure_temperature_tc([2,4:6], 'PT1000') returns the temperature
    %  readings from channels 2,4,5 and 6, and set their type as 'PT1000'
    %
    % Note that channels 0-7 are thermocouple and ch 8-47 are RTDs
    %
    % If no channel type is given, channel type will be set as default ('J')
    % If multiple channels are read at once, they must have the same type,
    % otherwise please use mp.measure_multi()
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
        
        nbytes = mp.getNumOfExpectedBytes(nchannels);
        
        % prepare the channel list for the query
        cChannels = sprintf('%d,',channel_list);
        cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
        
        % query string
        sQuery = sprintf('MEAS:TEMP:RTD? %s,(@%s)', channel_type, cChannels);
        
        % send the query
        cDataBytestring = mp.queryData(sQuery,nbytes);
        % unpack the result
        [cDataBitstring_cell, ndata, block_length] = mp.unpack(cDataBytestring);
        
        % Convert the data and parse it to each channel
        
        aTemp_degC = zeros(1,length(channel_list));
        for i_chan = 1:length(channel_list) % parse
            try % convert
                aTemp_degC(i_chan) = mp.convertIEEE_754(cDataBitstring_cell{i_chan});
            catch
                warning('error while reading temperature on one channel')
                aTemp_degC(i_chan) = -274;
            end
        end
        else % empty channel list
            aTemp_degC = [];
        end
    end
    
    function aVolt_V = measure_voltage(mp, channel_list)
    %MEASURE_VOLTAGE Measure the temperature on one or multiple channels
    %
    %   dVolt_V = mp.measure_voltage(channel_list) measure the voltage of
    %   the channels on the channel list, and returns a vector of values in
    %   volts
    %
    %   e.g. mp.measure_voltage(31:47) will return the voltage for channels 
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
        
        nbytes = mp.getNumOfExpectedBytes(nchannels);
        
        % prepare the channel list for the query
        cChannels = sprintf('%d,',channel_list);
        cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
        
        % query string
        sQuery = sprintf('MEAS:VOLT? (@%s)', cChannels);
        
        % send the query
        cBytestring = mp.queryData(sQuery,nbytes);
        
        % unpack the data
        [cDataBitstrings_cell, ~, ~] = mp.unpack(cBytestring);
        
        % Parse and convert the data
        aVolt_V = zeros(1,length(channel_list));
        for i_chan = 1:length(channel_list)
            try
                aVolt_V(i_chan) = mp.convertIEEE_754(cDataBitstrings_cell{i_chan});
            catch
                warning('error while reading temperature on one channel')
                aVolt_V(i_chan) = -1;
            end
        end
    else %empty channel list
        aVolt_V = [];
    end
    end
    
    function aRes_O = measure_resistance(mp, channel_list)
    %MEASURE_RESISTANCE Measure the temperature on one or multiple channels
    %
    %   aRes_O = mp.measure_resistance(channel_list) measure the resistance of
    %   the channels on the channel list, and returns a vector of values in
    %   ohms
    %
    %   e.g. mp.measure_res(8:31) will return the voltage for channels
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
            
            nbytes = mp.getNumOfExpectedBytes(nchannels);
            
            % prepare the channel list for the query
            cChannels = sprintf('%d,',channel_list);
            cChannels = cChannels(1:(length(cChannels)-1));% remove trailing coma
            
            % query string
            sQuery = sprintf('MEAS:RES? (@%s)', cChannels);
            
            % send the query
            cBytestring = mp.queryData(sQuery,nbytes);
            
            % unpack the data
            [cDataBitstrings_cell, ~, ~] = mp.unpack(cBytestring);
            
            % Parse and convert the data
            aRes_O = zeros(1,length(channel_list));
            for i_chan = 1:length(channel_list)
                try
                    aRes_O(i_chan) = mp.convertIEEE_754(cDataBitstrings_cell{i_chan});
                catch
                    warning('error while reading temperature on one channel')
                    aRes_O(i_chan) = -1;
                end
            end
        else
            aRes_O = [];
        end
    end
    
    function [readings, channel_map] = measure_multi(mp, channel_list)
        % Map onto proper channels
        [tc, rtd, volt] =  mp.channelType();
        tc_channels   = intersect(tc,channel_list);
        rtd_channels  = intersect(rtd,channel_list);
        volt_channels = intersect(volt,channel_list);
        
        channel_map = [tc_channels, rtd_channels, volt_channels];
        tc_readings   = mp.measure_temperature_tc(tc_channels);
        rtd_readings  = mp.measure_temperature_rtd(rtd_channels);
        volt_readings = mp.measure_voltage(volt_channels);
        
        readings = [tc_readings, rtd_readings, volt_readings];
    end
    
    function str_temp = MEASTEMP(mp)
    %MEASTEMP Direct hex string output from the instrument on channel 2
    %   for debug purpose
    
    % test function -- should work
        str_temp = mp.query('MEAS:TEMP:TC? DEF,(@2)');
    end
    
    function str_volt = MEASVOLT(mp)
    %MEASVOLT Direct hex string output from the instrument on channel 2
    %   for debug purpose
    
    % test function -- should work
        str_volt = mp.query('MEAS:VOLT? (@2)');
    end
    
    function str_res = MEASRES(mp)
    %MEASRES Direct hex string output from the instrument on channel 2
    
    % untest function -- shouldn't work
        str_res = mp.query('MEAS:RES? (@12)');
    end
    
    function delete(mp)
    %DELETE MEASURpoint class destructor
    %(aside from it closes the TCP/IP connection properly)
    
        mp.disconnect();
    end
    
    function general_status(mp)
    %GENERAL_STATUS Prints the general status of the insrument
    %   mp.general_status()

        str_idn  = mp.query('*IDN?');
        str_conf = mp.query(':CONF?');
        str_stb  = mp.query('*STB?');
        str_cen  = mp.query('SYSTem:PASSword:CENable:STATe?');
        fprintf('%s\n', str_idn)
        fprintf('%s\n', str_conf)
        fprintf('%s\n', str_stb)
        fprintf('%s\n', str_cen)
    end
    
    function [data_cell, ndata, block_length] = unpack(~, str_hex)
    % [data_cell, ndata, block_length] = unpack(mp,str)
        
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
    

    %TODO : refactor, static
    function dec_single = convertIEEE_754(~, str_bits)
    %CONVERTIEEE_754 Converts a measurement query string to a decimal value
    % It does this by apply ing the IEEE_754 single precision float standard
    %   dec_single = MEASUREpoint.convertIEEE_754(str)
    %
    %example:
    %   cTemp = mp.MEASTEMP()
    %   dTemp_degC = mp.convertIEEE_754(cTemp)
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
    
    function [channels_tc, channels_rtd, channels_vol] = channelType(mp)
    %CHANNELTYPE Returns a list of the channels types
    %   [channels_tc, channels_rtd, channels_vol] = mp.channelType()
    %       returns three arrays containing the channels that support
    %       thermocouples, RTD and variable voltage sensor.
    %
    % See also MEASUREPOINT.GETSENSORTYPE, MEASUREPOINT.SETSENSORTYPE
    
        cTC  = strtrim(mp.query(':SYSTem:CHANnel:TC?'));
        cRTD = strtrim(mp.query(':SYSTem:CHANnel:RTD?'));
        cVol = strtrim(mp.query(':SYST:CHAN:VOLT:RANG?'));
        
        channels_tc  = str2num(cTC(3:end-1));
        channels_rtd = str2num(cRTD(3:end-1));
        channels_vol = str2num(cVol(3:end-1));
    end
    
    function monitor_terminal(mp, channel, dt_s)
    %MONITOR LOOP Monitor the temperature on a specific channel
    %
    %   mp.monitor_loop(channel, dt_s) 
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
            temp = mp.measure_temperature_tc(channel);
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
    
    function monitor_graph(mp, channel, dt_s, N_pts)
    %MONITOR_GRAPH plot the temperature readings on a figure
    %
    %    mp.monitor_graph(channel) display continous reading of the
    %       temperature from a specific channel with 0.1s time step over 10s
    %
    %    mp.monitor_graph(channel, dt_s, N_pts) lets you define the time
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
        
        T0 = mp.measure_temperature_tc(channel);
        t_s=(0:(N_pts-1))*dt_s;
        aTemp_C = ones(1,N_pts).*T0;
        
        hFigure = figure('NumberTitle','off','Name','Temperature monitor',...
                         'ToolBar','none');
        idx = 0;
        while hFigure.isvalid
            idx = mod(idx,N_pts)+1;
            aTemp_C(idx) = mp.measure_temperature_tc(channel);
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
        
        function nbytes = getNumOfExpectedBytes(mp, channels)
            
            numDataBytes = channels * 4;
            nbytes = 1 + ... % header byte
                1 + ... % this byte contains the number of bytes in the data length byte group
                ceil(log10(numDataBytes)) + ... % one byte for each data decimal
                numDataBytes + ...
                1; % stop byte (terminator)
        end
        
   end
   
end