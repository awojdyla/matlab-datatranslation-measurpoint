classdef MeasurPointVirtual < datatranslation.AbstractMeasurPoint

    properties (Access = private)
        
        dateTimeStart
        dHz = 10
        
        cFilterType = 'AVG'
        dScanPeriod = 1;
    end
    
    
    methods
        
        function this = MeasurPointVirtual()
            
            this.dateTimeStart = datetime('now');
            
        end

        function c = idn(this)
            c = 'MeasurPointVirtual';
        end
        
        function l = getIsBusy(this)
            l = false;
        end
        
        %{
        function d = getScanDataOfChannel(this, u8Channel)
            dAll = this.getScanData();
            d = dAll(u8Channel + 1);
        end
        %}
        
        function [dIndexStart, dIndexEnd] = getIndiciesOfScanBuffer(this)
            
            dIndexStart = 0;
            dSeconds = seconds(datetime('now') - this.dateTimeStart);
            dIndexEnd = floor(10 * dSeconds);
        end
        
        function [dResults, dIndexEnd] = getScanDataAheadOfIndex(this, dIndex)
            
            
            [dIndexStart, dIndexEnd] = this.getIndiciesOfScanBuffer();

            % Error checking
            if dIndex < dIndexStart
                dIndex = dIndexStart;
            end

            if dIndexEnd == 0
                dResults = zeros(1, 49);
                dResults(49) = posixtime(datetime('now'));
                return;
            end

            if dIndex > dIndexEnd
                dIndex = dIndexEnd - 1;
            end

            dNum = dIndexEnd - dIndex;
            if dNum > 20 % max supported by network packet 
                dNum = 20; 
            end
            
            dIndexEnd = dIndex + dNum;
            dResults = this.getScanDataSet(dIndex, dNum);
                        
        end
        
        function d = getScanDataSet(this, dIndex, dNum)
            
            d = zeros(dNum, 49);
            d(:, 1:8) = randn(dNum,8) + 18;
            d(:, 9:32) = randn(dNum, 24) + 20;
            d(:, 33:48) = randn(dNum, 16) + 5;
            
            dStep = 0.1; % sec
            
            dDateTimeOfIndex = this.dateTimeStart + seconds(dIndex / 10);
            
            t = dDateTimeOfIndex + seconds(0 : dStep : (dNum - 1)* dStep);
            d(:, 49) = posixtime(t);
        end
       
        
        function [d, lError] = getScanData(this)
            d = zeros(1, 48);
            d(1:8) = randn(1,8) + 18;
            d(9:32) = randn(1, 24) + 20;
            d(33:48) = randn(1, 16) + 5;
            lError = false
        end
        
        function [d, lError] = getScanDataOfChannel(this, channel)
            [dAll, lError] = this.getScanData();
            d = dAll(channel);
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
        
        function c = getFilterType(this)
            c = this.cFilterType;
        end

        function setFilterTypeToRaw(this)
            this.cFilterType = 'RAW';
        end

        function setFilterTypeToAvg(this)
            this.cFilterType = 'AVG';
        end
        
        function setSensorType(this, channel, type)
            % fixme
        end
        
        function setScanList(this, dChannels)
            % fixme
        end
        
        function setScanPeriod(this, dPeriod)
            % fixme
            this.dScanPeriod = dPeriod;
        end
        
        function d = getScanPeriod(this)
            d = this.dScanPeriod;
        end
                
        function initiateScan(this)
            % fixme
        end
        
    end
end

    
