classdef MultiVectorModifiedDataBeforeFormat
    %MODIFIEDDATABEFOREFORMAT 前処理を負えたことを示す型 中身はRawDataとほぼ同じ
    
    properties (SetAccess = immutable)
        rawData RawData
        multiVectorData (1,:) cell
    end
    
    methods
        function MultiVectorModifiedDataBeforeFormat = MultiVectorModifiedDataBeforeFormat(rawData, multiVectorData)
            %MODIFIEDDATABEFOREFORMAT このクラスのインスタンスを作成
            MultiVectorModifiedDataBeforeFormat.rawData = rawData;
            MultiVectorModifiedDataBeforeFormat.multiVectorData = multiVectorData; 
        end
    end
end
