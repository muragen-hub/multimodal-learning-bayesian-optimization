classdef PreProcessorAfterFormat
    %PREPROCESSORAFTERFORMAT format後のdataWidth分のデータそれぞれに対して何かしらの処理を行う処理機

    properties (Access = private)
        preProcessorCore
    end

    methods
        function obj = PreProcessorAfterFormat(funcs)
            %PREPROCESSORAFTERFORMAT このクラスのインスタンスを作成
            arguments
                funcs (1,:) cell
            end
            obj.preProcessorCore = funcs;
        end

        function modifiedFormatData = process(obj,formattedData)
            arguments
                obj PreProcessorAfterFormat
                formattedData FormattedData
            end
            processingData = formattedData;
            for i = 1:length(obj.preProcessorCore)
                processingData = obj.preProcessorCore{i}(processingData);
            end
            modifiedFormatData = processingData;
        end
    end
end

