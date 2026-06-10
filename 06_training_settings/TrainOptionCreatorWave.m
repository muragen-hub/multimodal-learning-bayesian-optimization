classdef TrainOptionCreatorWave
    % TRAINOPTIONCREATORWAVE
    % Wave データ専用の trainingOptions を作成するクラス
    %
    % 呼び出し形式は従来の TrainOptionCreator と完全互換。
    %
    % option = creator.createNormalTrainOptionWave( ...
    %     initialLearnRate, maxEpoch, miniBatchSize, frequency, ...
    %     trainRepeatAmount, toleranceTimesForNotImproving);

    properties (SetAccess = immutable)
        trainData TrainTestDataWave
        testData TrainTestDataWave
        validationData TrainTestDataWave
    end

    methods
        function obj = TrainOptionCreatorWave(trainData, testData, NameAndVariableArg)
            arguments
                trainData TrainTestDataWave
                testData TrainTestDataWave
                NameAndVariableArg.ValidationData TrainTestDataWave = TrainTestDataWave.empty();
            end

            obj.trainData = trainData;
            obj.testData = testData;
            obj.validationData = NameAndVariableArg.ValidationData;
        end

        %==========================================================
        %     ★ 普通の学習用オプション作成（従来の形式に完全対応）
        %==========================================================
        function option = createNormalTrainOptionWave( ...
                obj, initialLearnRate, maxEpochs, miniBatchSize, frequency, ...
                trainRepeatAmount, toleranceTimesForNotImproving)

            arguments
                obj
                initialLearnRate {mustBeNumeric}
                maxEpochs {mustBeNumeric}
                miniBatchSize {mustBeNumeric}
                frequency {mustBeNumeric}
                trainRepeatAmount {mustBeNumeric}
                toleranceTimesForNotImproving {mustBePositive}
            end

            % ミニバッチ × 周期で何回見なきゃいけないか？（従来と同じロジック）
            stopnumber = round(length(obj.trainData.data) / (miniBatchSize * frequency)) * 5;
            if stopnumber == 0
                disp("データ数が不足しています。stopnumber は Inf になります。");
                stopnumber = Inf;
            end

            %==========================
            % trainingOptions
            %==========================
            optionRaw = trainingOptions("adam", ...
                "ExecutionEnvironment","auto", ...
                "GradientThreshold",1, ...
                "InitialLearnRate", initialLearnRate, ...
                "MaxEpochs", maxEpochs, ...
                "ValidationData",{obj.testData.data, obj.testData.label}, ...
                "ValidationFrequency", frequency, ...
                "ValidationPatience", stopnumber, ...
                "MiniBatchSize", miniBatchSize, ...
                "Shuffle","every-epoch", ...
                "Verbose",0, ...
                "VerboseFrequency",2, ...
                "Plots","training-progress", ...
                "OutputFcn",@(info)stopIfAccuracyNotImproving(info, toleranceTimesForNotImproving));

            % TrainOptionWrapper に格納
            option = TrainOption(optionRaw, trainRepeatAmount);
        end
    end
end
