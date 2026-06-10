classdef DataFormatterOptionWave
    % DATAFORMATTEROPTIONWAVE RawDataWaveのデータを深層学習用に整える際の設定
    properties (SetAccess = immutable)
        stride {mustBePositive, mustBeInteger}
        dataWidth {mustBePositive, mustBeInteger}
        interval {mustBeNonnegative, mustBeInteger} % ★ intervalBetweenData を interval に短縮
        lengthLimitInEachCondition int16
        
        % ★ RawDataWaveは単一チャネルを前提とするため、channelsは不要だが、互換性のために残すか、削除を選択
        channels {mustBePositive, mustBeInteger} 
        
        % 特徴量フラグ
        useFeature (1,1) logical % ★ useWaveformは常にtrueと仮定し、Featureの利用のみを制御
    end
    methods (Access = public)
        function option = DataFormatterOptionWave(stride, dataWidth, interval, nameAndVar)
            arguments
                stride {mustBePositive, mustBeInteger}
                dataWidth {mustBePositive, mustBeInteger}
                interval {mustBeNonnegative, mustBeInteger}
                % 名前と値の引数
                nameAndVar.lengthLimitInEachCondition {mustBePositive} = intmax("int16");
                nameAndVar.channels {mustBePositive, mustBeInteger} = 1; % Waveは通常1チャネル
                nameAndVar.useFeature (1,1) logical = true;
            end
            
            % --- プロパティに設定 ---
            option.stride = stride;
            option.dataWidth = dataWidth;
            option.interval = interval;
            option.lengthLimitInEachCondition = nameAndVar.lengthLimitInEachCondition;
            
            % ★ channels と useFeature は互換性のために残す
            option.channels = nameAndVar.channels;
            option.useFeature = nameAndVar.useFeature;
            
            % RawDataWaveは常に波形データを利用するため、useWaveformのチェックは不要とします
            % if ~option.useWaveform && ~option.useFeature
            %     error('DataFormatterOption: useWaveform または useFeature の少なくとも一方を true に設定してください。');
            % end
        end
    end
end