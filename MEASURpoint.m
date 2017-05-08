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
%   dTemp_degC  = mp.measure_temperature(2);  % measure temperature on ch2

% awojdyla@lbl.gov
% April 2017

%TODO: Add a password protected check bit
%TODO: wrap most function and make prefix them (e.g. SYSTCHAN->SCPI_SYSTCHAN)
%TODO: would be good to refactor SCPI superclass (esp. connect and query)
% Would be good to have : 
% -fetch (time stamped); 
% -multi-channel queries
% -setting the configuration

properties
    %FIXME : the IP may change depending on the configuration
    % can be found usign the Eureka discovery tool (needs Windows)
    %http://www.datatranslation.eu/en/ethernet/24-bit-data-acquisition/
    %500v-isolation/data-logger-software,1355.html
    cIP = 'TCPIP::192.168.127.100::INSTR'; % SCPI connection string
    niMP    % Matlab VISA object
end

methods
    
    function mp = MEASURpoint(varargin)
    % MEASURpoint Class constrctor
    %   mp = MEASURpoint() creates an object with default IP (see blow)
    %   mp = MEASURpoint('TCPIP::192.168.127.100::INSTR')
    %       creates an object with the provided IP
    %
    % See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY
    
    if nargin==1
        mp.cIP = varargin{1};
    end
    
    mp.init();
    end
    
    function init(mp)
    %INIT Initializes the VISA object
    %(this function is called by the constructor of the class)
    %   mp.init()
    %
    % See also MEASURPOINT.STATUS, MEASURPOINT.CONNECT
    
        % create a VISA object and store it as a property
        mp.niMP = visa('ni', mp.cIP);
        disp('NI VISA object object initialized')
    end
    
    function cStatus = status(mp)
    %STATUS gets the status of the VISA object
    %(this doesn't tell you if the device is connected)
    %   status = mp.status() returns true if the VISA object is valid
    %
    % See also MEASURPOINT.CONNECT
    
        if ~isempty(mp.niMP) 
            %get the status of the VISA object (not the instrument itself!)
            cStatus = mp.niMP.Status;
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
    
        fopen(mp.niMP);
        fprintf('NI VISA connected\n')
    end
    
    function lIsConnected = isConnected(mp)
    %ISCONNECTED Checks whether the communication the device is established
    %   isconnected = mp.isConnected() returns 'true' if the device is
    %   available for queries
    %
    %   See also MEASURPOINT.CONNECT, MEASURPOINT.QUERY
    
        lIsConnected = false;
        if ~isempty(mp.niMP)
            lIsConnected = strcmp(mp.niMP.Status,'open');
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
    
        if ~isempty(mp.niMP)
            fclose(mp.niMP);
            fprintf('NI VISA disconnected\n')
        end
    end
    
    function cAnswer = query(mp, str_query)
    %QUERY Performs a query of the instrument, to set or get a parameter
    %   cAnswer = query(str_query)
    %
    % example:
    %   cChan = mp.query('SYST:CHAN?')
    %
    % use mp.idn() to make sure there is actual communication with the ins
    %
    % BE CAREFUL! Measurement of values can be password protected; 
    % make sure the readings are enabled (mp.enable())
    %
    %   mp.query('MEAS:VOLT? (@2)')  should return a string with meas val
    %
    % use mp.get_error() to to troubleshoot message-forming error
    %
    % See also MEASURPOINT.ENABLE, MEASURPOINT.GET_ERROR, MEASURPOINT.IDN, 
    % MEASURPOINT.CONVERTIEEE_754
    
        cAnswer = '';
        cQuery = strcat(str_query,';');
        if ~isempty(mp.niMP)
            %print query (for debugging)
            fprintf('SCPI query: "%s"\n',cQuery)
            %perform query
            cAnswer = query(mp.niMP,cQuery);
            %print answer
            fprintf('SCPI answer: "%s"\n',cAnswer)
            %if the answer is empty, but the query was expecting an answer,
            %find out what kind com error happened
            if isempty(cAnswer) && contains(cQuery,'?')
                err_msg = query(mp.niMP,'SYST:ERR?');
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
    
        cErr_msg = query(mp.niMP,'SYST:ERR?');
    end
    
    function enable(mp)
        
        %   See also MEASURPOINT.ISENABLED
        query(mp.niMP,':SYST:PASS:CEN admin')
    end
    
    function cIsEnabled = isEnabled(mp)
    %ISENABLED lets you know whether measurements are password protected
    %   mp.isEnabled
    %
    %   See also MEASURPOINT.ENABLE
    
        lIsEnabled = query(mp.niMP,':SYSTem:PASSword:CENable:STATe?');
    end
    
    function cIDN = idn(mp)
    %IDN Standard SCPI '*IDN?' query, to test proper communication
    %   cIDN = mp.idn()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.SYSTCHAN, MEASURPOINT.CONF
    
        if ~isempty(mp.niMP) 
            if mp.isConnected()
                cIDN = mp.query('*IDN?');
            else
                error('MEASURpoint not connected')
            end
        else
            error('MEASURpoint not initialized')
        end
    end
    
    function cChan = SYSTCHAN(mp)
    %SYSTCHAN Lists available channels
    %   cChan = mp.SYSTCHAN()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        cChan = mp.query('SYST:CHAN?');
    end
    
    function cConf = CONF(mp)
    % CONF Lists available channels
    %   cChan = mp.CONF()
    %
    % See also MEASURPOINT.QUERY, MEASURPOINT.CONF, MEASURPOINT.IDN
    
        cConf = mp.query('CONF?');
    end
    
    function dget = get(mp)
        dget = -1;
    end
    
    function set(mp, value)
        
    end
    
    function dTemp_degC = measure_temperature(mp, channel)
    %MEASURE_TEMPERATURE Measure the temperature on a specific channel
    %   dTemp_degC = measure_temperature(2) measures the temperature
    %       on channel 2, assuming default sensor
    %
    %   See also MEASURPOINT.MEASURE_VOLTAGE, MEASURPOINT.QUERY
    
    str = sprintf('MEAS:TEMP:TC? DEF,(@%d)', channel);
        cTemp = mp.query(str);
        dTemp_degC = mp.convertIEEE_754(cTemp);
        %%FIXM catch error
    end
    
    function aTemp_degC = measure_multichannel(mp)
       %unicode2native
        
    end
    
    function msg = parse_multichannel(str_multi)
    end
    
    function dVolt_V = measure_voltage(mp, channel)
    %MEASURE_VOLTAGEE Measure the temperature on a specific channel
    %   dVolt_V = mp.measure_voltage(channel)
    %
    %   See also MEASURE_TEMPERATURE
        
        str = sprintf('MEAS:VOLT? (@%d)', channel);
        cVolt = mp.query(str);
        dVolt_V = mp.convertIEEE_754(cVolt);
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
    % for debug purpose -- should not work
    
    % untest function -- shouldn't work
        str_res = mp.query('MEAS:RES? (@2)');
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
    
    %TODO : refactor, static
    function dec_single = convertIEEE_754(~, str)
    %CONVERTIEEE_754 Converts a measurement query string to a decimal value
    % It does this by apply ing the IEEE_754 single precision float standard
    %   dec_single = MEASUREpoint.convertIEEE_754(str)
    %
    %example:
    %   cTemp = mp.MEASTEMP()
    %   dTemp_degC = mp.convertIEEE_754(cTemp)
    %
    %   (for the recordds, 41bd99b6 => 24.7° C
    
        % unpacking
        xout = dec2hex(uint8(str));
        hd = xout(1,:);     % header (eq. to #)
        dec1 = xout(2,:);   % number of values (assume 1)
        dec2 = xout(3,:);   % number of values (assume 1)
        hex1 = xout(4,:);   % data
        hex2 = xout(5,:);   % data
        hex3 = xout(6,:);   % data
        hex4 = xout(7,:);   % data
        %cr = xout(8,:);     % line termination
        val_hex = strcat(hex1,hex2,hex3,hex4);

        % no direct hex2bin conversion
        % if no sign add it

        %IEEE_754 convention
        % see https://www.h-schmidt.net/FloatConverter/IEEE754.html
        
        %add invisble leading bit (underflow)
        val_b = strcat('0',dec2bin(hex2dec(val_hex)));
        %compute the signum
        signum = sign(-(str2num(val_b(1))-0.5));
        %compute the exponent
        exponent = 2^(bin2dec(val_b(3:9))-1);
        %compute the mantissa (binary floating point)
        bits = str2num(val_b(10:end)')';
        weights = 2.^(-(1:length(bits)));
        mantissa = 1+sum(bits.*weights);
        
        dec_single = signum*mantissa*2^exponent;
    end
end

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
   end
   
end