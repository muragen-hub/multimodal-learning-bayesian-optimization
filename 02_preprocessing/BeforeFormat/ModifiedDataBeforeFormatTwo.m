classdef ModifiedDataBeforeFormatTwo
    %MODIFIEDDATABEFOREFORMAT 前処理を負えたことを示す型 中身はRawDataとほぼ同じ
    
    properties (SetAccess = immutable)
        rawDataTwo RawDataTwo
    end
    
    methods
        function modifiedDataBeforeFormat = ModifiedDataBeforeFormatTwo(rawDataTwo)
            %MODIFIEDDATABEFOREFORMAT このクラスのインスタンスを作成
            modifiedDataBeforeFormat.rawDataTwo = rawDataTwo;
        end
    end
end

