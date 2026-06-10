classdef ModifiedDataBeforeFormatWave
    % MODIFIEDDATABEFOREFORMATWAVE: 
    % 前処理を終えたことを示すラッパー型。中身は RawDataWave オブジェクト。
    
    properties (SetAccess = immutable)
        % 処理済みの RawDataWave オブジェクトを格納
        modifiedRawDataWave RawDataWave
    end
    
    methods (Access = public)
        function obj = ModifiedDataBeforeFormatWave(processedDataWave)
            % MODIFIEDDATABEFOREFORMATWAVE このクラスのインスタンスを作成
            
            arguments
                processedDataWave RawDataWave
            end
            
            % 渡された処理済み RawDataWave をプロパティに格納
            obj.modifiedRawDataWave = processedDataWave;
        end
        
        % 互換性のため、プロパティ名を既存の ModifiedDataBeforeFormat に合わせる場合は
        % 以下のように修正することも可能です
        % function obj = ModifiedDataBeforeFormatWave(rawDataWave)
        %     obj.rawDataWave = rawDataWave;
        % end
    end
end