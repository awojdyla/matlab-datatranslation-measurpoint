classdef AbstractMeasurPoint < handle

    methods (Abstract)

        cIDN = idn(this)
        aTemp_degC = measure_temperature_tc(this, channel_list, channel_type)
        aTemp_degC = measure_temperature_rtd(this, channel_list, channel_type)
        aVolt_V = measure_voltage(this, channel_list)
        aRes_O = measure_resistance(this, channel_list)
        [channels_tc, channels_rtd, channels_vol] = channelType(this)
        c = getFilterType(this)
        setFilterTypeToRaw(this)
        setFilterTypeToAvg(this)
        [d, lError] = getScanData(this)
        [d, lError] = getScanDataOfChannel(this, u8Channel)
        setSensorType(this, channel, type)
        setScanList(this, dChannels)
        setScanPeriod(this, dPeriod)
        initiateScan(this)
        
        l = getIsBusy(this)
        
    end
end

    
