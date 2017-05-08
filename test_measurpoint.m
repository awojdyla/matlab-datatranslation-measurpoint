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
query(ni,'MEAS:VOLT? (@2)','%s','%x')
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
%%


%query(ni,'SYST:ERR?')

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

%% Initiate the instrument class
mp = MEASURpoint();

%% Connect the instrument through TCP/IP
mp.connect();

%% Ask the instument its id using SCPI standard queries
mp.idn;

%% Ask the instrument its port configuration
mp.CONF;

%% Ask the instrument which channels are configured
mp.SYSTCHAN;

%% Ask the instrument to measure something it can read
out = mp.MEASVOLT;
size(out)
%% Ask the instrument to measure something it cannot read
mp.MEASRES;

%%
out = mp.MEASTEMP;
size(out)
%%
temp = mp.measure_temperature(2);
fprintf('temperature = %2.1f\n',temp)

%%
volt = mp.measure_voltage(2);
fprintf('temperature = %2.1f\n', volt)
%%
%% parsing the answer
xout = dec2hex(uint8(out));
hd = xout(1,:);
dec1 = xout(2,:);
dec2 = xout(3,:);
hex1 = xout(4,:);
hex2 = xout(5,:);
hex3 = xout(6,:);
hex4 = xout(7,:);
cr = xout(8,:);

val_hex = strcat(hex1,hex2,hex3,hex4);
% no direct hex2bin conversion
% if no sign add it
val_b = strcat('0',dec2bin(hex2dec(val_hex)));
%%
signum = sign(-(str2num(val_b(1))-0.5));
exponent = 2^(bin2dec(val_b(3:9))-1);
bits = str2num(val_b(10:end)')';
weights = 2.^(-(1:length(bits)));
mantissa = 1+sum(bits.*weights);

exponent;
signum*mantissa*2^exponent
%%
%c7ad9c00 = ?88888°
%41bd99b6 = 27.7° C

