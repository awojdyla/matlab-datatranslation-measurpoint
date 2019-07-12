%% Test script for MEASURpoint.m class
% do not execute as a whole!

%% Add src (function in this dir, navigate to this dir to run)

[cDirThis, ~, ~] = fileparts(mfilename('fullpath'));
cDirSrc = fullfile(cDirThis, '..', 'src');
addpath(genpath(cDirSrc));


%% Initiate the instrument class

cIP = '192.168.20.27';
mp = datatranslation.MeasurPoint(cIP);


%% Connect the instrument through TCP/IP
mp.connect();

%% Ask the instument its id using SCPI standard queries
mp.idn();

%% Enable readout on protected channels
mp.enable();
mp.abortScan();


%% Set up the scan 

channels = 0 : 7;
for n = channels
   mp.setSensorType(n, 'J');
end

channels = 8 : 15;
for n = channels
    mp.setSensorType(n, 'PT1000');
end

 channels = 16 : 19;
for n = channels
    mp.setSensorType(n, 'PT100');
end

channels = 20 : 23;
for n = channels
   mp.setSensorType(n, 'PT1000');
end

channels = 24 : 31;
for n = channels
    mp.setSensorType(n, 'PT100');
end

channels = 32 : 47;
for n = channels
    mp.setSensorType(n, 'V');
end

mp.setScanList(0:47);
mp.setScanPeriod(0.1);
mp.initiateScan();
% mp.abortScan();
mp.clearBytesAvailable();
            
%% Show the scan list
mp.getScanList()
mp.getScanRate()


%% Show indicies of circular buffer scan
[dIndexStart, dIndexEnd] = mp. getIndiciesOfScanBuffer()

%% Read all values from the scan buffer
results = mp.getScanData()


%% Read all values more recent than provided index
close all;
mp.clearBytesAvailable();
results = mp.getScanDataSet(0, 18);
figure
plot(results(:, 49), results(:, 20:25), '.-')

%% Read as many values as supported by network packet continuously

[dIndexStart, dIndexEnd] = mp. getIndiciesOfScanBuffer()
for n = 1 : 5
    [results, dIndexStart] = mp.getScanDataAheadOfIndex(dIndexStart);
    plot(results(:, 49), results(:, 20:25), '.-')
    pause(0.5);
end


%% Disconnect
mp.disconnect();


