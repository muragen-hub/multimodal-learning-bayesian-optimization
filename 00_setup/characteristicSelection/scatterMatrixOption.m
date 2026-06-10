classdef scatterMatrixOption
    %SCATTERMATRIXOPTION 散布図行列を作る時のoption. branching後のRawDataと特徴の名前を突っ込む. 
    properties
        rawData (1,:) RawData
        characteristicName (1,:) string
    end
    
    methods
        function obj = scatterMatrixOption(givenRawData, givenCharacteristicName)
            arguments
                givenRawData (1,:) RawData
                givenCharacteristicName (1,:) string
            end
            %SCATTERMATRIXOPTION このクラスのインスタンスを作成
            obj.rawData = givenRawData;
            obj.characteristicName = givenCharacteristicName;
        end
    end
end

