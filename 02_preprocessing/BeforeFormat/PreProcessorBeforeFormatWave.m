classdef PreProcessorBeforeFormatWave
    % PREPROCESSORBEFOREFORMATWAVE 
    % RawDataWave および RawAllDataBeforeFormatWave に対応した前処理クラス。
    % 登録する関数は, 第一引数が RawDataWave型, 第二引数が RawAllDataBeforeFormatWave型で、
    % 返り値は RawDataWave型 にすること。
    
    properties (Access = private)
        preProcessorCore
    end
    
    methods (Access = public)
        
        function obj = PreProcessorBeforeFormatWave(funcs)
            arguments
                funcs (1,:) cell
            end
            % 処理関数のセル配列を格納
            obj.preProcessorCore = funcs;
        end
        
       % PreProcessorBeforeFormatWave.m 内の最終修正案

    function modifiedData = process(obj, wrapperData, rawAllDataBeforeFormatWave)
        arguments
            obj PreProcessorBeforeFormatWave
            wrapperData ModifiedDataBeforeFormatWave 
            rawAllDataBeforeFormatWave RawAllDataBeforeFormatWave
        end
        
        rawDataWaveArray = wrapperData.modifiedRawDataWave;
        numSamples = length(rawDataWaveArray);
        
        % 1. 処理済みの結果を格納するためのセル配列を初期化
        % RawDataWaveの配列ではなく、結果を格納するためのセル配列を使用し、最後にRawDataWave配列に戻す
        processedRawDataCell = cell(1, numSamples); 
        
        % 2. 全てのサンプルをループで処理し、前処理関数を適用
        for j = 1:numSamples
            processingData = rawDataWaveArray(j); % 1x1 の RawDataWave インスタンス
            
            % 登録された関数を順番に呼び出す
            for i = 1:length(obj.preProcessorCore)
                processingData = obj.preProcessorCore{i}(processingData, rawAllDataBeforeFormatWave);
            end
            
            % 処理済み 1x1 の RawDataWave をセル配列に格納
            processedRawDataCell{j} = processingData;
        end
        
        % 3. セル配列を RawDataWave 配列に変換 (セル展開による水平連結)
        % 処理済みの RawDataWave インスタンスを全て結合し、1xNumSamplesのRawDataWave配列を生成
        processedRawDataWaveArray = [processedRawDataCell{:}]; 
        
        % 4. 最終結果を ModifiedDataBeforeFormatWave 型でラップして返す
        modifiedData = ModifiedDataBeforeFormatWave(processedRawDataWaveArray);
    end
            
        function modifiedRawData = processRemainRawData(obj, rawDataWave, rawAllDataBeforeFormatWave)
        % processRemainRawData: 型を変更せずに前処理を続けるための関数
            arguments
                obj PreProcessorBeforeFormatWave
                rawDataWave RawDataWave
                rawAllDataBeforeFormatWave RawAllDataBeforeFormatWave
            end
            
            processingData = rawDataWave;
            for i = 1:length(obj.preProcessorCore)
                % 登録された関数を順番に呼び出す
                processingData = obj.preProcessorCore{i}(processingData, rawAllDataBeforeFormatWave);
            end
            
            % 型を RawDataWave のまま返す
            modifiedRawData = processingData;
        end
    end
end