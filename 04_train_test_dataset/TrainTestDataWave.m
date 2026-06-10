classdef TrainTestDataWave
    % TRAINTESTDATAWAVE 訓練もしくはテストデータクラス (波形データ用)
    
    properties (SetAccess = immutable)
        data            % {N x 1} セル配列。各要素は [C x W] 行列を格納
        label
        conditionStrings
        labelStrings
        minimumLength   % 各流量条件におけるデータの最小サンプル数 (N_min)
    end
    
    methods (Access = public)
        function obj = TrainTestDataWave(data, label, minimumLength, conditionStrings, labelStrings)
            arguments
                data (:, 1) cell         % {N_Total x 1} セル配列
                label (:, 1) categorical
                minimumLength {mustBeNumeric}
                conditionStrings (1, :) string
                labelStrings (1, :) string
            end
            obj.data = data;
            obj.label = label;
            obj.minimumLength = minimumLength;
            obj.conditionStrings = conditionStrings;
            obj.labelStrings = labelStrings;
        end
        
        function [] = viewWaveFromCondition(obj, saveFolderName, dataColumnValue)
            arguments
                obj TrainTestDataWave
                saveFolderName string
                dataColumnValue {mustBeNumeric} % チャンネルインデックス (例: 1=VF, 2=Pr)
            end
            
            % 保存先の準備
            saveDirName = append(PictureSavePath.path, saveFolderName, "/");
            if not(exist(saveDirName, 'dir'))
                mkdir(saveDirName)
            end
            
            plottingCell = obj.data;
            
            % 該当チャンネル（C）のデータのみを取り出す (例: C=1のデータ)
            % plottingCell{i} は [C x W] 形式なので、C行目を取り出す
            plottingCell = cellfun(@(x) x(dataColumnValue, :), plottingCell, 'UniformOutput', false);
            
            % 全データを1つの長いベクトルに結合 [N_Total * W x 1]
            plottingMat = cell2mat(plottingCell);
            plottingMat = reshape(transpose(plottingMat), [], 1);
            
            % dataWidth は結合後の波形長 W (例: 400)
            dataWidth = size(obj.data{1}, 2); 
            
            figure
            hold on
            
            % 流量条件 (Condition) ごとに波形を描画
            for i = 1:length(obj.conditionStrings)
                start_idx = (i-1) * obj.minimumLength * dataWidth + 1;
                end_idx = i * obj.minimumLength * dataWidth;
                
                if end_idx > length(plottingMat)
                    end_idx = length(plottingMat);
                end
                
                plot(start_idx:end_idx, plottingMat(start_idx:end_idx));
            end
            
            hold off
            legend(obj.conditionStrings, 'location', 'northeastoutside');
            title(sprintf("学習前のデータ (チャンネル: %d)", dataColumnValue), 'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName, "TrainTestDataFromCondition.fig"));
        end
        
        function [] = viewWaveFromLabel(obj, saveFolderName, dataColumnValue)
            arguments
                obj TrainTestDataWave
                saveFolderName string
                dataColumnValue {mustBeNumeric} % チャンネルインデックス (例: 1=VF, 2=Pr)
            end
            
            saveDirName = append(PictureSavePath.path, saveFolderName, "/");
            if not(exist(saveDirName, 'dir'))
                mkdir(saveDirName)
            end
            
            uniquelabel = unique(obj.labelStrings);
            beforeLastIndex = 0;
            
            % dataWidth は結合後の波形長 W (例: 400)
            dataWidth = size(obj.data{1}, 2);
            
            figure
            hold on
            
            % ラベル (Flow Pattern) ごとに波形を描画
            for i = 1:length(uniquelabel)
                labelString = uniquelabel(i);
                idx = labelString == obj.label;
                idxLength = length(nonzeros(idx));
                
                plottingCell = obj.data(idx);
                
                % 該当チャンネル（C）のデータのみを取り出す
                plottingCell = cellfun(@(x) x(dataColumnValue, :), plottingCell, 'UniformOutput', false);
                
                % 全データを1つの長いベクトルに結合
                plottingMat = cell2mat(plottingCell);
                plottingMat = reshape(transpose(plottingMat), [], 1);
                
                dataLength = idxLength * dataWidth;
                
                if beforeLastIndex + 1 <= beforeLastIndex + dataLength
                    plot(beforeLastIndex + 1 : beforeLastIndex + dataLength, plottingMat);
                    beforeLastIndex = beforeLastIndex + dataLength;
                end
            end
            
            hold off
            legend(unique(obj.labelStrings), 'location', 'northeastoutside');
            title(sprintf("学習前のデータ (チャンネル: %d)", dataColumnValue), 'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName, "TrainTestDataFromLabel.fig"));
        end
    end
end