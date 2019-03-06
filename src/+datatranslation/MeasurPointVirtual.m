classdef MeasurPointVirtual < datatranslation.AbstractMeasurPoint

    methods
        
        function this = MeasurPointVirtual()
            
        end

        function c = idn(this)
            c = 'MeasurPointVirtual';
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
            channels_vol = 32 : 40;
        end
        
    end
end

    
