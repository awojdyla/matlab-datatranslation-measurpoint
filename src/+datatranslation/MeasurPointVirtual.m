classdef MeasurPointVirtual < datatranslation.AbstractMeasurPoint

    methods
        
        function this = MeasurPointVirtual()
            
        end

        function c = idn(this)
            c = 'MeasurPointVirtual';
        end
        
        function l = getIsBusy(this)
            l = false
        end
        
        function d = getScanDataOfChannel(this, u8Channel)
            dAll = this.getScanData();
            d = dAll(u8Channel + 1);
        end
        
        function d = getScanData(this)
            d = zeros(1, 48);
            d(1:8) = randn(size(channel_list)) + 18;
            d(9:32) = randn(size(channel_list)) + 20;
            d(33:48) = randn(size(channel_list)) + 5;
        end
        
        function d = measure_temperature_tc(this, channel_list, channel_type)
            d = randn(size(channel_list)) + 20;
        end
        
        function d = measure_temperature_rtd(this, channel_list, channel_type)
            d = randn(size(channel_list)) + 20;
        end
        
        function d = measure_voltage(this, channel_list)
            d = randn(size(channel_list)) + 5;
        end
        
        function d = measure_resistance(this, channel_list)
            d = randn(size(channel_list)) + 10000;
        end
        
        function [channels_tc, channels_rtd, channels_vol] = channelType(this)
            
            channels_tc = 0 : 7;
            channels_rtd = 8 : 31;
            channels_vol = 32 : 47;
        end
        
    end
end

    
