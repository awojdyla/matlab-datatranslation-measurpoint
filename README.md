# matlab-datatranslation-measurpoint
This software allows you to read the measurements a **DataTranslation MEASURpoint** with SCPI-over-Ethernet **using Matlab**.
This device can be used to read temperature, voltage and resistance over many channels.

## About

This class is self-contained, though it is meant to be used within the [Matlab Instrument Control](https://github.com/cnanders/matlab-instrument-control) framework, designed to provide flexible and powerful instrument control capabalities to Matlab.

This class was built especially for a DataTranslation **MEASURpoint**, but should work with a **TEMPpoint** and **VOLTpoint** without too much difficulty. This class can also be used as template for proper communication with other SCPI-over-ethernet instruments.

THIS SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

## Installation & Requirements
This software runs on **MacOS X** and **Windows** versions of Matlab.

To install this package, dowload it and unpack it, or clone it on you computer by going to the terminal (or git bash) and type: 
```
git clone https://github.com/awojdyla/matlab-datatranslation-measurpoint.git
```

To use it, you will need :

  * **Matlab** (version >2013a)
  * Matlab [Instrument Control Toolbox](https://www.mathworks.com/products/instrument.html)
  
To make sure the later is installed on you computer, type `ver` in the Matlab command line.

Make sure the `MEASURpoint.m` class is in you current directory, or at least that it is in you path, *e.g.* : 

```matlab
addpath(genpath(./MATLAB/matlab-datatranslation-measurpoint))
```

Make sure you can instantiate a class by typing the following in the Matlab command line:

```matlab
mp = MEASURpoint()
```



## Usage
The use of this software is fairly straightforward. The corresponding object has to be instantiated using `mp = MEASURpoint('192.168.127.100')` (to determine the IP of your device, see sections below), then connected to the remote device using `MEASURpoint.connect()`. If the device has been turned off, it is required to enable it using `MEASURpoint.enable()`. From there, you can try to measure the temperature on a specific channel (say 3) using `MEASURpoint.measure_temperature_tc(3)`, and you should get an answer back.

All at once: 

```matlab
cIP = '192.168.127.100'  	% IP of the device
mp = MEASURpoint(cIP);      % create an instance of the object
mp.connect();               % connect to the instrument
mp.enable()					% (after power-cycling, functions are password-protected)
mp.idn();                   % ask the instrument identity
channel = 3					% channel we want to talk with
dTemp_degC  = mp.measure_temperature_tc(channel);  % measure temperature on ch3
```

To get started, you can have a look at `test_measurpoint.m`, which has many examples on how to use this class. If you are not familiar with the cell iteration, you should know that you can execute a limited number of lines by hitting `ctrl+enter` or `cmd+enter`

![demo_tutorial][test_tutorial]

The most useful commands will be:

  * `mp.measure_temperature_tc` to measure the temperature on a single or multiple thermocouple channel.
  * `mp.measure_temperature_rtd` to measure the temperature on a single or multiple TRD channel.
  * `mp.measure_voltage` to measure the voltage a single or multiple  channel (of any type)
  * `mp.measure_multi` to measure temperature or voltage on mixed channels, with proper mapping.
  
The functions are fully documented, and you can get the help for a function by typing:

```matlab
help mp.measure_temperature_tc
```

There's also auto-generated documentation ('javadoc'-style) that you can get by typing:

```matlab
doc MEASURpoint
```
## Demo
You can use the monitor (`mp.monitor_graph`) to read the temperature over a determined time-interval

```matlab
channel = 3; 		% channel
dt_s = 0.3 			% refresh rate
N_pts = 100			% number of points
mp.monitor_graph(dt_s,N_pts)
```
![demo_scan][temp_read_graph]

## Test condition 
Macbook pro (2014), running Matlab 2017a, connected through ethernet via a thunderbolt adapter.
The device (\*IDN>'Data Translation,DT8874-8T-24R-16V,14171149,3.1.0.2') was connected the computer through a router. 
The router assigned an IP address (192.168.127.100) which may depend on your configuration.

There was only one J-type thermocouple available, and temperature reading worked just fine. **RTD sensors have not been tested**, and **outputs from voltage channel have not been tested**

## Caveats
When the temperature is read *and the sensor type is specified*, the **configuration of the sensor type is changed** at the same time. 
This is especially true for multiple channel read -- where it is not a good idea to have different type of sensors.
If many sensor types are used, it is best to read channel-by-channel

## A few hurdles
*This part is more for programmer who wants to know what's under the hood*
A few hurdles that were encountered while wrapping SCPI queries to the device.

  * Some SCPI function are password protected (See page 36 of the manual), notably the `MEAS:` read functions. The solution is to enable them with a `:SYST:PASS:CEN admin` SCPI query. The password protection is reset everytime the device is powered off.
  *  Queries of the temperature *requires* the type of sensor you're using (even if set with `:CONF:TEMP:TC:`); you can always use `DEF` (which is the default sensor type, *i.e.* 'J'): 
    *  `MEAS:TEMP:TC? (@3)` will not work, but 
    *  `MEAS:TEMP:TC? DEF,(@3)` will.
  *  when collecting data, do not use Matlab's `query`, which returns a string which variable size (and sometimes trimmed), but rather use:
    *  `fprintf(visa_instance,cQuery)`, followed by
    * `fread(visa_instance,n_bytes)` to get the data as bytes.
  *  Data types in Matlab is always confusing: `fread` returns bytes as decimal; they have to be converted to hexadecimal pairs and then bitstrings in order to be read properly.
  *  Matlab does not have a function to translate 32-bit strings into IEEE 754 single-precision. `MEASURpoint.convert_IEE754` does just that (see also [matlab-ieee](https://github.com/cnanders/matlab-ieee))!
  
I am endebted to [Chris Anderson](https://github.com/cnanders) for his tremendous help!

## Finding instrument IP address
To determine the IP of the device on your network you can use the Eureka Tool Discover provided with the [MEASURpoint software](http://www.datatranslation.de/en/measure/measurpoint-24-bit/measurpoint-usb/data-logger-software,1355.html?merk=e35d01fd463cc351bcc67baf54fa1869) (works with Windows only.)

![Eureka Tool Discovery][eureka]

To make sure the device is properly connected, type the IP in your web browser (e.g. 192.168.127.100), and it should should connect to the browser-based interface. It should be nearly instantaneous (otherwise something is wrong.) I've ade some issues with Java version while using the web browser -- there are many security warnings, but at least it should connect to the main interface.

If you have a Mac talking to the device through a router, make sure you are using DHCP. The adress of the device can be assigned at random, and the best thing to do is to figure out what are the attached device.
![IP configuration on a Mac][ip_configuration]

You can also use PyVisa to test the connection:
make sure you have [NI-Visa Runtime engine](http://www.ni.com/nisearch/app/main/p/bot/no/ap/tech/lang/en/pg/1/sn/catnav:du,n8:3.25.123.1640,ssnav:ndr/) and  [PyVisa](https://pyvisa.readthedocs.io/en/stable/) installed (if not, type `pip install pyvisa` in the terminal), then in python (changing the IP if needed):

```python
import pyvisa
rm   = pyvisa.ResourceManager()
inst = rm.open_resource('TCPIP::192.168.127.100::INSTR')
print(inst.query("*IDN?"))
```

## Troubleshooting 


## References
[SCPI Programmer’s Manual for LXI Measurement Instruments](http://www.omgl.com.cn/upfile/File/2011/DT/SCPI_Programmer%27s_Manual_for_MEASURpoint_Ethernet(LXI)_Instruments.pdf)


[ip_configuration]: https://github.com/awojdyla/matlab-datatranslation-measurpoint/blob/master/assets/ip_configuration.png
"IP configuration for a Mac"
[eureka]: https://github.com/awojdyla/matlab-datatranslation-measurpoint/blob/master/assets/eureka.png
"Eureka tool discovery"
[test_tutorial]: https://github.com/awojdyla/matlab-datatranslation-measurpoint/blob/master/assets/test_tutorial.gif
"A few easy steps"
[temp_read_graph]: https://github.com/awojdyla/matlab-datatranslation-measurpoint/blob/master/assets/temperature.gif
"Temperature read graph"


