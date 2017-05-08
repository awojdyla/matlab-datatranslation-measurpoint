# matlab-datatranslation-measurpoint
======

## About
It requires NI VISA (to make sure it is installed on you computer, type "ver" in the Matlab command line)

This class is meant to use with (but independant) from the [Matlab Instrument Control](https://github.com/cnanders/matlab-instrument-control)
(A general class SCPI is coming up)

THIS SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND

## Usage
`mp = MEASURpoint();         % create the object
mp.connect();               % connect to the instrument
mp.idn();                   % ask the instrument identity
cAnswer     = mp.query('MEAS:VOLT? (@1)') % queries the instrument
dTemp_degC  = mp.measure_temperature(2);  % measure temperature on ch2`

## A few hurdles
A few issues that were encountered 
Some function are password protected (See page 36 of the manual), notably readout functions
When asking for the temperature, one must use DEF or K
Conversion to single precision is quite challenging

## test condition 
The device was connected to a router

## Troubleshooting 
The IP is hard to get; one must use the eureka discovery tool (python and NI ViISA on mac do not work very well)
type the IP in your web browser(e.g. 192.168.127.100)
To determine the IP of the device on your network you can use the Eureka Tool Discover provided with the [MEASURpoin software](http://www.datatranslation.de/en/measure/measurpoint-24-bit/measurpoint-usb/data-logger-software,1355.html?merk=e35d01fd463cc351bcc67baf54fa1869) (work with Windows)
it can have some issues with Java version 

## References
[SCPI Programmer’s Manual for LXI Measurement Instruments](http://www.omgl.com.cn/upfile/File/2011/DT/SCPI_Programmer%27s_Manual_for_MEASURpoint_Ethernet(LXI)_Instruments.pdf)

## useful tools 





