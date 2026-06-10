classdef LayerSettingCreatorTwo
    %LAYERCREATOR レイヤーの作製を行うクラス
    properties(SetAccess = immutable)
        trainData TrainTestDataTwo
        testData TrainTestDataTwo
    end
    methods
        function obj = LayerSettingCreatorTwo(trainData, testData)
            obj.trainData = trainData;
            obj.testData = testData;
        end

        % 通常版
        function layerSetting = createSingleLSTMLayer(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorTwo
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting = [
                sequenceInputLayer(inputSize, 'Name', 'Seq')
                bilstmLayer(hiddenUnitAmount, 'OutputMode', 'last', 'Name', 'biLSTM')
                dropoutLayer(0.5, 'Name', 'dropout1') % ★ Dropout層を追加
                fullyConnectedLayer(classAmount, 'Name', 'fc')
                softmaxLayer('Name', 'softmax')
                classificationLayer('Name', 'classification')
            ];
        end

        % カスタム損失関数用
        function layerSetting = createSingleLSTMLayerForCustomLossFunc(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorTwo
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting = [
                sequenceInputLayer(inputSize, 'Name', 'Seq')
                bilstmLayer(hiddenUnitAmount, 'OutputMode', 'last', 'Name', 'biLSTM')
                dropoutLayer(0.5, 'Name', 'dropout1') % ★ Dropout層を追加
                fullyConnectedLayer(classAmount, 'Name', 'fc')
                softmaxLayer('Name', 'softmax')
            ];
        end

        % 複数入力用
        function layerSetting = createSingleSeqToProbLSTMLayer(obj, inputSize, hiddenUnitAmount)
            arguments
                obj LayerSettingCreatorTwo
                inputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
            end
            classAmount = length(unique(obj.trainData.labelStrings));
            layerSetting = [
                sequenceInputLayer(inputSize, 'Name', 'Seq')
                bilstmLayer(hiddenUnitAmount, 'OutputMode', 'last', 'Name', 'biLSTM')
                dropoutLayer(0.5, 'Name', 'dropout1') % ★ Dropout層を追加
                fullyConnectedLayer(classAmount, 'Name', 'fc')
                softmaxLayer('Name', 'softmax')
                classificationLayer
            ];
        end
        
        %差圧を含めたbiLSTMモデル
        function lgraph = createMultimodalLayerGraph(obj, capInputSize, diffInputSize, featureInputSize, hiddenUnitAmount, denseUnitAmount)
            arguments
                obj LayerSettingCreatorTwo
                capInputSize {mustBeNumeric}
                diffInputSize {mustBeNumeric}
                featureInputSize {mustBeNumeric}
                hiddenUnitAmount {mustBeNumeric}
                denseUnitAmount {mustBeNumeric}
            end
            
            numClasses = length(unique(obj.trainData.labelStrings));
            
            % グラフ構造の初期化
            lgraph = layerGraph();

            %% 1. CapWave branch (bi-LSTM)
            capLayers = [
                sequenceInputLayer(capInputSize, 'Name','CapInput')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','CapLSTM')
                dropoutLayer(0.2,'Name','CapDrop')
                fullyConnectedLayer(denseUnitAmount,'Name','CapFC') 
            ];
            lgraph = addLayers(lgraph, capLayers);

            %% 2. DiffWave branch (bi-LSTM)
            diffLayers = [
                sequenceInputLayer(diffInputSize,'Name','DiffInput')
                bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','DiffLSTM')
                dropoutLayer(0.2,'Name','DiffDrop')
                fullyConnectedLayer(denseUnitAmount,'Name','DiffFC') 
            ];
            lgraph = addLayers(lgraph, diffLayers);

            %% 3. LSTM outputs → Concatenate
            concatLSTM = concatenationLayer(1, 2, 'Name','ConcatLSTM'); 
            lgraph = addLayers(lgraph, concatLSTM);
            lgraph = connectLayers(lgraph, 'CapFC', 'ConcatLSTM/in1');
            lgraph = connectLayers(lgraph, 'DiffFC', 'ConcatLSTM/in2');

            %% 4. Feature vector branch (Dense)
            featureLayers = [
                featureInputLayer(featureInputSize,'Name','FeatureInput')
                fullyConnectedLayer(20,'Name','FeatureFC')
                reluLayer('Name','FeatureReLU')
            ];
            lgraph = addLayers(lgraph, featureLayers);

            %% 5. Final concatenation 
            finalConcat = concatenationLayer(1, 2, 'Name','ConcatFinal');
            lgraph = addLayers(lgraph, finalConcat);
            lgraph = connectLayers(lgraph, 'ConcatLSTM', 'ConcatFinal/in1');
            lgraph = connectLayers(lgraph, 'FeatureReLU', 'ConcatFinal/in2');

            %% 6. Classification block
            finalLayers = [
                fullyConnectedLayer(numClasses,'Name','FinalFC')
                softmaxLayer('Name','Softmax')
            ];
            lgraph = addLayers(lgraph, finalLayers);
            lgraph = connectLayers(lgraph, 'ConcatFinal', 'FinalFC');
        end
        
      

        % 複数入力（波形二つのみ）用
        function lgraph = createDualWaveLayerGraph(obj, capInputSize, diffInputSize, hiddenUnitAmount, denseUnitAmount)
            arguments
                obj LayerSettingCreatorTwo
                capInputSize {mustBeNumeric} % 現在は 1
                diffInputSize {mustBeNumeric} % 現在は 1
                hiddenUnitAmount {mustBeNumeric}
                denseUnitAmount {mustBeNumeric}
            end
            
            numClasses = length(unique(obj.trainData.labelStrings));
            
            % グラフ構造の初期化
            lgraph = layerGraph();
            
            % --- 🚨 修正: 冗長だが厳格なレイヤー定義と接続を行う 🚨 ---

            % 1. CapWave branch (bi-LSTM) の定義
            CapInput = sequenceInputLayer(capInputSize, 'Name','CapInput');
            CapLSTM = bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','CapLSTM');
            CapDrop = dropoutLayer(0.2,'Name','CapDrop');
            CapFC = fullyConnectedLayer(denseUnitAmount,'Name','CapFC'); 
            
            % レイヤーを追加
            lgraph = addLayers(lgraph, CapInput);
            lgraph = addLayers(lgraph, CapLSTM);
            lgraph = addLayers(lgraph, CapDrop);
            lgraph = addLayers(lgraph, CapFC);
            
            % レイヤーを接続 (CapWave)
            lgraph = connectLayers(lgraph, 'CapInput', 'CapLSTM');
            lgraph = connectLayers(lgraph, 'CapLSTM', 'CapDrop');
            lgraph = connectLayers(lgraph, 'CapDrop', 'CapFC');


            % 2. DiffWave branch (bi-LSTM) の定義
            DiffInput = sequenceInputLayer(diffInputSize,'Name','DiffInput');
            DiffLSTM = bilstmLayer(hiddenUnitAmount,'OutputMode','last','Name','DiffLSTM');
            DiffDrop = dropoutLayer(0.2,'Name','DiffDrop');
            DiffFC = fullyConnectedLayer(denseUnitAmount,'Name','DiffFC'); 

            % レイヤーを追加
            lgraph = addLayers(lgraph, DiffInput);
            lgraph = addLayers(lgraph, DiffLSTM);
            lgraph = addLayers(lgraph, DiffDrop);
            lgraph = addLayers(lgraph, DiffFC);

            % レイヤーを接続 (DiffWave)
            lgraph = connectLayers(lgraph, 'DiffInput', 'DiffLSTM');
            lgraph = connectLayers(lgraph, 'DiffLSTM', 'DiffDrop');
            lgraph = connectLayers(lgraph, 'DiffDrop', 'DiffFC');


            % 3. LSTM outputs → Concatenate (最終結合)
            finalConcat = concatenationLayer(1, 2, 'Name','ConcatFinal');
            lgraph = addLayers(lgraph, finalConcat);
            lgraph = connectLayers(lgraph, 'CapFC', 'ConcatFinal/in1');
            lgraph = connectLayers(lgraph, 'DiffFC', 'ConcatFinal/in2');
            
            
            % 4. Classification block
            FinalFC = fullyConnectedLayer(numClasses,'Name','FinalFC');
            Softmax = softmaxLayer('Name','Softmax');
            ClassificationOutput = classificationLayer('Name', 'ClassificationOutput');

            % レイヤーを追加
            lgraph = addLayers(lgraph, FinalFC);
            lgraph = addLayers(lgraph, Softmax);
            lgraph = addLayers(lgraph, ClassificationOutput);

            % レイヤーを接続 (最終分類)
            lgraph = connectLayers(lgraph, 'ConcatFinal', 'FinalFC');
            lgraph = connectLayers(lgraph, 'FinalFC', 'Softmax');
            lgraph = connectLayers(lgraph, 'Softmax', 'ClassificationOutput');

        end
        
    end
end
