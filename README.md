# matlab-datatranslation-measurpoint
This software allows you to control a Data Translation MEASURpoint with SCPI over Ethernet using Matlab, and read voltage and temperatures on various channels. 

## About
It requires the Matlab [Instrument Control Toolbox](https://www.mathworks.com/products/instrument.html)
NI VISA (to make sure it is installed on you computer, type "ver" in the Matlab command line)

Though this class is self contained, it is meant to be used with the [Matlab Instrument Control](https://github.com/cnanders/matlab-instrument-control) -- check out this very cool project.

This class was built especially for a Data Translation MEASURpoint, but should work with a TEMPpoint and VOLTpoint without too much difficulty. This class can also be used as template for other SCPI instruments -- 

THIS SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND

## Usage
```matlab
mp = MEASURpoint();         % create the object
mp.connect();               % connect to the instrument
mp.idn();                   % ask the instrument identity
cAnswer     = mp.query('MEAS:VOLT? (@1)')    % queries the instrument
dTemp_degC  = mp.measure_temperature_tc(3);  % measure temperature on ch3
```

## Demo
![demo_scan][temp_read_graph]


## test condition 
Macbook pro (2014), running Matlab 2017a, connected through ethernet via a thunderbolt adapter.
The device (\*IDN>'Data Translation,DT8874-8T-24R-16V,14171149,3.1.0.2') was connected the computer through a router. 
The router assigned an address

## Caveats
When the temperature is read and the sensor type is specified, the configuration of the sensor type is changed at the same time. 
This is especially true for multiple channel read -- where it is not a good idea to have different type of sensors.
If many sensor types are used, it is best to read channel-by-channel

## A few hurdles
A few issues that were encountered 
Some function are password protected (See page 36 of the manual), notably readout functions
When asking for the temperature, one must use DEF or K
Conversion to single precision is quite challenging

## Troubleshooting 
Type the IP in your web browser(e.g. 192.168.127.100)
I've ade some issues with Java version while using the web browser -- there are many security warnings

To determine the IP of the device on your network you can use the Eureka Tool Discover provided with the [MEASURpoin software](http://www.datatranslation.de/en/measure/measurpoint-24-bit/measurpoint-usb/data-logger-software,1355.html?merk=e35d01fd463cc351bcc67baf54fa1869) (works with Windows only)

You can also use PyVisa to test the connection 

## References
[SCPI Programmer’s Manual for LXI Measurement Instruments](http://www.omgl.com.cn/upfile/File/2011/DT/SCPI_Programmer%27s_Manual_for_MEASURpoint_Ethernet(LXI)_Instruments.pdf)

## useful tools 




[temp_read_graph]: https://github.com/awojdyla/matlab-datatranslation-measurpoint/blob/master/assets/temperature.gif
"Temperature read graph"


