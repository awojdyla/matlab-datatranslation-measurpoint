ni = visa('ni', 'TCPIP::192.168.127.100::INSTR');

%%
fopen(ni);

%%
fclose(ni)

%% WORKS
query(ni,'*IDN?')

%% WORKS
query(ni,'SYSTem:BOArd?')

%% WORKS
query(ni,'SYST:CHAN?')

%% WORKS - error status
query(ni,':SYST:ERR?')

%% Remove password
query(ni,':SYST:PASS:CEN admin')

%%
query(ni,':SYSTem:PASSword:CENable:STATe?')

%% works 
clc
query(ni,'MEAS:VOLT? (@2)','%s\n','%s')
%a = query(ni,'MEAS:VOLT? (@2)','%x')
%b = sprintf('%x',a);
%size(b)
%%
        fprintf(ni, 'MEAS:VOLT? (@2)');
        idn = fgets(ni,8);
        size(idn)


%% Does not work, but shouldn't
query(ni,':MEASure:RES?')
query(ni,'SYST:ERR?')

%% Works
query(ni,'MEAS:TEMP:TC? DEF,(@2)')
% def is for default type of sensor
query(ni,'SYST:ERR?')
%% Works
query(ni,'MEAS:TEMP:TC? K,(@2)')
% def is for K type of sensor

%% Works
out = query(ni,'MEAS:TEMP:TC? K,(@2)');
% def is for K type of sensor
query(ni,'SYST:ERR?')


%% WORKS - configure TC
query(ni,':CONF:TEMP:TC K, (@2)')
query(ni,':CONF?')

%%
query(ni,':CONF?')

%%
query(ni,'SYST:ERR?')

%%
query(ni,'*STB?')

%%
query(ni,'*STB?')

%% WORKS
query(ni,'STAT:QUES?')
% 0 is normal behavoir


%% WORKS
query(ni,'CONF?')
%returns the configuration of specified analog input channels on the
%instrument

%% WORKS
query(ni,'CONF:SCA:LIST?')
%returns the list that are enabled for scanning on the instrument
% ...apparently zero

%% WORKS
query(ni,'CONF:SCA:RATE?')
% scan rate

%% CANNOT
query(ni,'MEAS:RES?')

%% WORKS
query(ni,'OUTPUT?')
% Returns the current state of all 8 output lines of the digital output
% port as a wighed sum of all lines that are on

%% WORKS
query(ni,'STAT:OPER:COND?')

%% DOES NOT WORK
query(ni,':STAT:OPER:ENAB')

%% DOES NOT WORK
query(ni,'STAT:CHAN:VOLT:RANG?')

%% DOES NOT WORK
query(ni,'MEAS:VOLT?')

%% DOES NOT WORK
query(ni,'MEAS:VOLT? (@4:6)')

%% ideal way to read data
fprintf(ni, 'MEAS:VOLT? (@4)');
bytes_dec = fread(ni,8);