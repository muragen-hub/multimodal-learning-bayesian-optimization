classdef PreProcessorBeforeFormat
    % PREPROCESSORBEFOREFORMAT strideいくつで,
    % intervalいくつ300点区切りと言ったformatを行う前に行う前処理を担当するクラス
    % 登録する関数は, 第一引数がRawData型, 第二引数がRawAllDataBeforeFormatで返り値はRawData型にすること.
    % 関数は登録した順番に呼び出されるので, 例えば, 最後に標準化を行いたい場合には配列の最後に標準化を入れる.
    % インスタンス作成の例
    %  funcs = {@correct @Standardize} ボイド率系の補正を行った後での補正を行う意味.
    %  preProcessorBeforeFormat = PreProcessorBeforeFormat(funcs);
    % もし仮に, AllDateの方を変更後のデータで更新したものを
    % 外側から処理を規定してインスタンス生成.

    properties (Access = private)
        preProcessorCore
    end

    methods (Access = public)
        function obj = PreProcessorBeforeFormat(funcs)
            arguments
                funcs (1,:) cell
            end
            obj.preProcessorCore = funcs;
        end

        function modifiedData = process(obj,rawData, rawAllDataBeforeFormat)
            arguments
                obj PreProcessorBeforeFormat
                rawData RawData
                rawAllDataBeforeFormat RawAllDataBeforeFormat
            end
            processingData = rawData;
            for i = 1:length(obj.preProcessorCore)
                processingData = obj.preProcessorCore{i}(processingData, rawAllDataBeforeFormat);
            end
            modifiedData = ModifiedDataBeforeFormat(processingData);
        end

        function modifiedRawData = processRemainRawData(obj,rawData, rawAllDataBeforeFormat)
        % PROCESSREMAINRAWDATA 
        % もし, rawDataの方を一回, 前処理したものでもう一度作り直して, preprocessorの中で使いたいと思った場合には,
        % こちらの関数を用いて, 型を変更しない前処理を続けることができる.
            arguments
                obj PreProcessorBeforeFormat
                rawData RawData
                rawAllDataBeforeFormat RawAllDataBeforeFormat
            end
            processingData = rawData;
            for i = 1:length(obj.preProcessorCore)
                processingData = obj.preProcessorCore{i}(processingData, rawAllDataBeforeFormat);
            end
            modifiedRawData = processingData;
        end
    end
end

