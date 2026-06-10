classdef TrainTestDataTwo
    %TRAINTESTDATATWO : FormattedDataTwo を扱う訓練・テストデータクラス
    %
    %   TrainTestData の改良版。
    %   FormattedDataTwo 型データを扱うことを前提としています。
    %   データ構造やプロパティ名は TrainTestData に合わせてあります。
    %
    %   例：
    %   train = TrainTestDataTwo(bundledTrainData, bundledTrainLabel, trainDataMinimumAmount, condition, oneDimTrainLabel);

    properties (SetAccess = immutable)
        CapWaveData         % CapWaveデータ（Cell Array）
        DiffWaveData        % DiffWaveデータ（Cell Array）
        FeatureData         % Featureデータ（Double 行列）
        label               % categorical ラベル
        conditionStrings    % 条件を示す string 配列
        labelStrings        % ラベル名を示す string 配列
        minimumLength       % データ長（最小長など）
    end

    methods
        % === コンストラクタ ===
        function obj = TrainTestDataTwo(capWave, diffWave, feature, label, minimumLength, conditionStrings, labelStrings)
            arguments
                % 🚨 修正: Cell 型の制約を削除し、3D配列 (double) を受け入れられるようにする 🚨
                capWave (:,1) cell          % CapWave: Cell Array を期待
                diffWave (:,1) cell         % DiffWave: Cell Array を期待
                feature double              % Feature: Double 行列
                label (:,1) categorical
                minimumLength {mustBeNumeric}
                conditionStrings (1,:) string
                labelStrings (1,:) string
            end
            obj.CapWaveData = capWave;
            obj.DiffWaveData = diffWave;
            obj.FeatureData = feature;
            obj.label = label;
            obj.minimumLength = minimumLength;
            obj.conditionStrings = conditionStrings;
            obj.labelStrings = labelStrings;
        end

        % === 条件ごとの波形表示 ===
        function [] = viewWaveFromCondition(obj, saveFolderName, dataColumnValue)
            arguments
                obj TrainTestDataTwo
                saveFolderName string
                dataColumnValue {mustBeNumeric}
            end

            saveDirName = append(PictureSavePath.path, saveFolderName, "/");
            if not(exist(saveDirName, 'dir'))
                mkdir(saveDirName)
            end

            % ★ 修正 ★ obj.CapWaveData または obj.DiffWaveData を参照
            if dataColumnValue == 1
                sourceData = obj.CapWaveData;
            elseif dataColumnValue == 2
                sourceData = obj.DiffWaveData;
            else
                error('dataColumnValueは1(CapWave)か2(DiffWave)を指定してください。');
            end
            
            plottingMat = cell2mat(sourceData); % sourceData は既に Cell Array
            plottingMat = reshape(transpose(plottingMat), [], 1);
            dataWidth = length(sourceData{1}); % Cell Array の最初の要素のサイズを参照

            figure
            hold on
            for i = 1:length(obj.conditionStrings)
                plot((i-1)*obj.minimumLength*dataWidth + 1 : i*obj.minimumLength*dataWidth, ...
                     plottingMat((i-1)*obj.minimumLength*dataWidth + 1 : i*obj.minimumLength*dataWidth));
            end
            hold off

            legend(obj.conditionStrings, 'location', 'northeastoutside');
            title("学習前のデータ（TrainTestDataTwo）", 'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName, "TrainTestDataFromCondition_Two.fig"));
        end

        % === ラベルごとの波形表示 ===
        function [] = viewWaveFromLabel(obj, saveFolderName, dataColumnValue)
            saveDirName = append(PictureSavePath.path, saveFolderName, "/");
            if not(exist(saveDirName, 'dir'))
                mkdir(saveDirName)
            end

            if dataColumnValue == 1
                sourceData = obj.CapWaveData;
            elseif dataColumnValue == 2
                sourceData = obj.DiffWaveData;
            else
                error('dataColumnValueは1(CapWave)か2(DiffWave)を指定してください。');
            end
            
            uniquelabel = unique(obj.labelStrings);
            beforeLastIndex = 0;
            dataWidth = length(sourceData{1}); % Cell Array の最初の要素のサイズを参照
            figure
            hold on
            for i = 1:length(uniquelabel)
                idx = uniquelabel(i) == obj.label;
                idxLength = length(nonzeros(idx));
                
                % ★ 修正 ★ sourceData を参照
                plottingMat = sourceData(idx); 
                plottingMat = cell2mat(plottingMat);
                plottingMat = reshape(transpose(plottingMat), [], 1);
                
                plot(beforeLastIndex + 1 : beforeLastIndex + idxLength * dataWidth, plottingMat);
                beforeLastIndex = beforeLastIndex + idxLength * dataWidth;
            end
            hold off

            legend(unique(obj.labelStrings), 'location', 'northeastoutside');
            title("学習前のデータ（TrainTestDataTwo）", 'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName, "TrainTestDataFromLabel_Two.fig"));
        end
    end
end
