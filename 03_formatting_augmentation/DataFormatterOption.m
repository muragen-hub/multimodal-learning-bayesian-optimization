classdef DataFormatterOption
    % DATAFORMATTEROPTION データを深層学習用に整える際の設定
    properties (SetAccess = immutable)
        stride {mustBePositive, mustBeInteger}
        dataWidth {mustBePositive, mustBeInteger}
        intervalBetweenData {mustBeNonnegative, mustBeInteger}
        lengthLimitInEachCondition int16
        
        % ✅ 追加したプロパティ
        channels {mustBePositive, mustBeInteger}
        featureChannels {mustBePositive, mustBeInteger}
        useWaveform (1,1) logical
        useFeature (1,1) logical
    end

    methods (Access = public)
        function option = DataFormatterOption(stride, dataWidth, intervalBetweenData, nameAndVar)
            arguments
                stride {mustBePositive, mustBeInteger}
                dataWidth {mustBePositive, mustBeInteger}
                intervalBetweenData {mustBeNonnegative, mustBeInteger}
                % 名前と値の引数として新しいオプションも受け取る
                nameAndVar.lengthLimitInEachCondition {mustBePositive} = intmax("int16");
                nameAndVar.channels {mustBePositive, mustBeInteger} = 1;
                nameAndVar.featureChannels {mustBePositive, mustBeInteger} = 4;
                nameAndVar.useWaveform (1,1) logical = true;
                nameAndVar.useFeature (1,1) logical = true;
            end
            
            % --- プロパティに設定 ---
            option.stride = stride;
            option.dataWidth = dataWidth;
            option.intervalBetweenData = intervalBetweenData;
            option.lengthLimitInEachCondition = nameAndVar.lengthLimitInEachCondition;
            
            % ✅ 新しいプロパティも nameAndVar から設定
            option.channels = nameAndVar.channels;
            option.featureChannels = nameAndVar.featureChannels;
            option.useWaveform = nameAndVar.useWaveform;
            option.useFeature = nameAndVar.useFeature;

            if ~option.useWaveform && ~option.useFeature
                error('DataFormatterOption: useWaveform または useFeature の少なくとも一方を true に設定してください。');
            end
        end
    end
end