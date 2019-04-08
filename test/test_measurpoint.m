

d = randn(size(channel_list)) + 5;
%% Initiate the instrument class


cIP = '192.168.0.3';
mp = datatranslation.MeasurPoint(cIP);

%% Connect the instrument through TCP/IP
mp.connect();

%% Ask the instument its id using SCPI standard queries
mp.idn();

%% Enable readout on protected channels
mp.enable();

%% read one channel
channel = 3;
temp_C = mp.measure_temperature_tc(channel);
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Regular query
a = mp.queryData('MEAS:TEMP:TC? DEF,(@3)',8);

%% Get all channel types (These cannot be set)
[tc, rtd, volt] = mp.channelType();
fprintf('TC   sensor channels = %s\n',num2str(tc,'%02.0f '))
fprintf('RTD  sensor channels = %s\n',num2str(rtd,'%02.0f '))
fprintf('Volt sensor channels = %s\n',num2str(volt,'%02.0f '))
fprintf('\n')

%% Get sensor types
channel = 3;
sensorType = mp.getSensorType(channel);
fprintf('Channel %d has a ''%s''-type sensor\n',channel,sensorType)
%% Get multiple sensor types
[~, rtd, ~] = mp.channelType(); % get all RTDs
sensor_types = mp.getSensorType(rtd);
fprintf('%s ',sensor_types{:})
fprintf('\n')

%% Set sensor type
channel = 3;
new_type = 'J';
mp.setSensorType(channel,new_type);
fprintf('Channel %d has a ''%s''-type sensor\n',channel,mp.getSensorType(channel))

%% Measure temperature on a specific channel (TC)
channel = 3;
temp_C = mp.measure_temperature_tc(channel);
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on a specific channel (TC), with sensor type
channel = 3;
sensorType = 'J';
tic
temp_C = mp.measure_temperature_tc(channel, sensorType);
toc
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on multiple channels (TC), with sensor type
channel_list = 0:3;
tic
temp_C = mp.measure_temperature_tc(channel_list);
toc
fprintf('temperatures = ')
fprintf('%2.3fC - ',temp_C)
fprintf('\n')

%% Measure temperature on a specific channel (RTD)
channel = 9;
temp_C = mp.measure_temperature_rtd(channel);
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on a specific channel (RTD), with sensor type
channel = 9;
temp_C = mp.measure_temperature_rtd(channel,'PT100');
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on a multiple channel (RTD), with sensor type
channel_list = 9:12;
temp_C = mp.measure_temperature_rtd(channel_list,'PT100');
fprintf('temperatures = ')
fprintf('%2.3fC - ',temp_C)
fprintf('\n')

%% Measure voltage on one channel
channel = 42;
volt = mp.measure_voltage(channel);
fprintf('voltage = %2.3f V\n', volt)

%% Measure voltage on multiple channel
channel_list = [10,40:42];
volt = mp.measure_voltage(channel_list);
fprintf('voltages = ')
fprintf('%2.1eV  -  ', volt)
fprintf('\n')

%% Measure on mixed channels
channel_list = floor(rand(1,10)*48);
[readings, channel_map] = mp.measure_multi(channel_list);
fprintf('channel : ')
fprintf('%06.0f ',channel_map)
fprintf('\nreading : ')
fprintf('%06.0f ',readings)
fprintf('\n')

%% Unpack and convert data (single measurement)
bytestring1 = '23313441B513420A';
bitstring1  = mp.unpack(bytestring1);
value = mp.convertIEEE_754(bitstring1{1});
fprintf('IEEE 754 single precision conversion - value = %2.3f, expected: 22.634\n',value)
% 22.6344

%% Unpack and convert data (multiple measurement)
bytestring2 = '2332313241B5134241bd99b6425A73620a';
bitstring2  = mp.unpack(bytestring2);
%mp.convertIEEE_754('425A7362')
value1 = mp.convertIEEE_754(bitstring2{1});
value2 = mp.convertIEEE_754(bitstring2{2});
value3 = mp.convertIEEE_754(bitstring2{3});
fprintf('multiple IEEE 754 single precision conversion\n')
fprintf('values =  %2.3f; %2.3f; %2.3f\n', value1, value2, value3)
fprintf('expected: 22.634; 23.700; 54.612\n')

%% Get error message
mp.get_error()

%% 
if false % so that the script can be "Run" all at once
%% Continous reading on one channel, displayed in the command window
channel = 3;
dt_s = 0.3;
mp.monitor_terminal(channel, dt_s);

%% Continous reading on one channel, displayed as a graph
channel =3;
dt_s = 0.1;
N_pts = 100;
mp.monitor_graph(channel, dt_s, N_pts);


end

