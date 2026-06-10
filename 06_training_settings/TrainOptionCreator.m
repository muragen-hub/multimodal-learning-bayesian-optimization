classdef TrainOptionCreator
    %TRAINOPTIONCREATOR trainOptionの作成を担当するクラス
    
    properties (SetAccess = immutable)
        trainData TrainTestData
        testData TrainTestData
        validationData TrainTestData
    end
    
    methods
        function obj = TrainOptionCreator(trainData,testData, NameAndVariableArg)
            arguments
                trainData TrainTestData
                testData TrainTestData 
                NameAndVariableArg.ValidationData TrainTestData = TrainTestData.empty();
            end
            obj.trainData = trainData;
            obj.testData = testData;
            obj.validationData = NameAndVariableArg.ValidationData;
        end
        
        function option = createNormalTrainOption(obj, initialLearnRate, maxEpochs, miniBatchSize, frequencynumber,trainRepeatAmount,toleranceTimesForNotImproving)
            arguments
                obj
                initialLearnRate {mustBeNumeric}
                maxEpochs {mustBeNumeric}
                miniBatchSize {mustBeNumeric}
                frequencynumber {mustBeNumeric}
                trainRepeatAmount {mustBeNumeric}
                toleranceTimesForNotImproving {mustBePositive}
            end
             stopnumber = round(length(obj.trainData.data)/(miniBatchSize*frequencynumber))*5;

            if stopnumber == 0
                disp('データ数が不足しています。stopnumber が０になっていますので, stopNumberはInfで開始されます')
                stopnumber = Inf;
            end

            option =  trainingOptions('adam', ...
                'ExecutionEnvironment','auto', ...
                'GradientThreshold',1, ...
                'InitialLearnRate', initialLearnRate, ...
                'MaxEpochs',maxEpochs, ...
                'ValidationData',{obj.testData.data, obj.testData.label}, ... %検証用データ. テストデータとは厳密には異なることに注意. (最後のミニバッチにおける検証用データがテストデータに相当か. 本来は恐らく別にするべき.)
                'ValidationFrequency',frequencynumber, ...％訓練何回ごとにテストデータと突き合わせて正確さを測定するか
                'ValidationPatience',stopnumber, ... %損失が更新されなくなったら終了.の基準
                'MiniBatchSize',miniBatchSize, ...
                'Shuffle','every-epoch', ...
                'Verbose',0, ... % 1にすると,コマンドライン表示
                'VerboseFrequency',2, ...
                'Plots','training-progress', ...
                'OutputFcn',@(info)stopIfAccuracyNotImproving(info,toleranceTimesForNotImproving));% 進捗表示

            option = TrainOption(option,trainRepeatAmount);
        end

        % 検証用データを使う場合
        function option = createValidationTrainOption(obj,maxEpochs, miniBatchSize, frequencynumber,trainRepeatAmount,toleranceTimesForNotImproving)
            arguments
                obj
                maxEpochs {mustBeNumeric}
                miniBatchSize {mustBeNumeric}
                frequencynumber {mustBeNumeric}
                trainRepeatAmount {mustBeNumeric}
                toleranceTimesForNotImproving {mustBePositive}
            end
             stopnumber = round(length(obj.trainData.data)/(miniBatchSize*frequencynumber))*5;

            if stopnumber == 0
                disp('データ数が不足しています。stopnumber が０になっていますので, stopNumberはInfで開始されます')
                stopnumber = Inf;
            end

            option =  trainingOptions('adam', ...
                'ExecutionEnvironment','auto', ...
                'GradientThreshold',1, ...
                'MaxEpochs',maxEpochs, ...
                'ValidationData',{obj.validationData.data, obj.validationData.label}, ... %検証用データ. テストデータとは厳密には異なることに注意. (最後のミニバッチにおける検証用データがテストデータに相当か. 本来は恐らく別にするべき.)
                'ValidationFrequency',frequencynumber, ...％訓練何回ごとにテストデータと突き合わせて正確さを測定するか
                'ValidationPatience',stopnumber, ... %損失が更新されなくなったら終了.の基準
                'MiniBatchSize',miniBatchSize, ...
                'Shuffle','every-epoch', ...
                'Verbose',0, ... % 1にすると,コマンドライン表示
                'VerboseFrequency',2, ...
                'Plots','training-progress', ...
                'OutputFcn',@(info)stopIfAccuracyNotImproving(info,toleranceTimesForNotImproving));% 進捗表示

            option = TrainOption(option,trainRepeatAmount);
        end
    end
end
