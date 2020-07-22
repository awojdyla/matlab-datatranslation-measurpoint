
[cDirThis, ~, ~] = fileparts(mfilename('fullpath'));
cDirSrc = fullfile(cDirThis, '..', 'src');
addpath(genpath(cDirSrc));
    
    
%% Initiate the instrument class

mp = datatranslation.MeasurPointVirtual();

%% Ask the instument its id using SCPI standard queries
mp.idn();
 
%% Get all channel types (These cannot be set)
[tc, rtd, volt] = mp.channelType();
fprintf('TC   sensor channels = %s\n',num2str(tc,'%02.0f '))
fprintf('RTD  sensor channels = %s\n',num2str(rtd,'%02.0f '))
fprintf('Volt sensor channels = %s\n',num2str(volt,'%02.0f '))
fprintf('\n')

%% Measure temperature on a specific channel (TC)
channel = 3;
temp_C = mp.measure_temperature_tc(channel);
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on a specific channel (TC), with sensor type
channel = 3;
sensorType = 'J';
temp_C = mp.measure_temperature_tc(channel, sensorType);
fprintf('temperature = %2.3f degree C\n',temp_C)

%% Measure temperature on multiple channels (TC), with sensor type
channel_list = 0:3;
temp_C = mp.measure_temperature_tc(channel_list);
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

%% Read as many values as supported by network packet continuously

[dIndexStart, dIndexEnd] = mp.getIndiciesOfScanBuffer()
for n = 1 : 5
    [results, dIndexStart] = mp.getScanDataAheadOfIndex(dIndexStart);
    plot(...
        datetime(results(:,49), 'ConvertFrom', 'posixtime'), ...
        results(:, 20:25), ...
        '.-')
    pause(1);
end



