classdef ModifiedDataBeforeFormat
    %MODIFIEDDATABEFOREFORMAT 前処理を負えたことを示す型 中身はRawDataとほぼ同じ
    
    properties (SetAccess = immutable)
        rawData RawData
    end
    
    methods
        function modifiedDataBeforeFormat = ModifiedDataBeforeFormat(rawData)
            %MODIFIEDDATABEFOREFORMAT このクラスのインスタンスを作成
            modifiedDataBeforeFormat.rawData = rawData;
        end
    end
end

