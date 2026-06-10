classdef TrainOptionCreatorTwo
    %TRAINOPTIONCREATOR trainOptionの作成を担当するクラス
    
    properties (SetAccess = immutable)
        trainData TrainTestDataTwo
        testData TrainTestDataTwo
        validationData TrainTestDataTwo
    end
    
    methods
        function obj = TrainOptionCreatorTwo(trainData,testData, NameAndVariableArg)
            arguments
                trainData TrainTestDataTwo
                testData TrainTestDataTwo 
                NameAndVariableArg.ValidationData TrainTestDataTwo = TrainTestDataTwo.empty();
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
             stopnumber = round(length(obj.trainData.label)/(miniBatchSize*frequencynumber))*5;

            if stopnumber == 0
                disp('データ数が不足しています。stopnumber が０になっていますので, stopNumberはInfで開始されます')
                stopnumber = Inf;
            end

            option =  trainingOptions('adam', ...
                'ExecutionEnvironment','auto', ...
                'GradientThreshold',1, ...
                'InitialLearnRate', initialLearnRate, ...
                'MaxEpochs',maxEpochs, ...
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
             stopnumber = round(length(obj.trainData.label)/(miniBatchSize*frequencynumber))*5;

            if stopnumber == 0
                disp('データ数が不足しています。stopnumber が０になっていますので, stopNumberはInfで開始されます')
                stopnumber = Inf;
            end

            option =  trainingOptions('adam', ...
                'ExecutionEnvironment','auto', ...
                'GradientThreshold',1, ...
                'MaxEpochs',maxEpochs, ...
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
