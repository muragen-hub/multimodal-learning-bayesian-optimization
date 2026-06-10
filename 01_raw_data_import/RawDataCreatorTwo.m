classdef RawDataCreatorTwo
    %RAWDATACREATOR: ExcelデータからRawDataTwoクラスを作るFactory
    % 静電容量、差圧、流量を統合して RawDataTwo を生成

    properties (Constant)
        sourcePathHeader = DataPath.path;
    end

    methods (Access = public)
        function obj = RawDataCreatorTwo()
        end

        %% 完全版 create メソッド
        function createdRawDataTwo = create(obj, date, measuredFreq, conditions, labels, isNeedCorrect, correctConditions)
            arguments
                obj RawDataCreatorTwo
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string
                isNeedCorrect logical
                correctConditions (1,:) string
            end

            featureNumber = 2; % 特徴量数
            conditionsLength = length(conditions);
            sources = append(RawDataCreatorTwo.sourcePathHeader, date, "/", conditions, "/ALLDATA.csv");

            % --- 初期化 ---
            timeCell = cell(1, conditionsLength);
            timeCell_second = cell(1, conditionsLength);
            capacitanceCell = cell(1, conditionsLength);
            differentialPressureCell = cell(1, conditionsLength);
            liquidFlowCell = cell(1, conditionsLength);
            gasFlowCell = cell(1, conditionsLength);
            flowRegimeCell = cell(1, conditionsLength);
            featureCell = cell(featureNumber, conditionsLength);
            machineLearningCell = cell(featureNumber + 3, conditionsLength); % +差圧
            labelCell = cell(1, conditionsLength);

            for i = 1:conditionsLength
                tmp = readmatrix(sources(i));

                % 時間・静電容量
                timeCell{i} = tmp(51:end,1);
                capacitanceCell{i} = tmp(51:end,2);

                % 流量
                liquidFlowCell{i} = tmp(51:end,4);
                gasFlowCell{i} = tmp(51:end,5);

                % 差圧
                pressure6 = tmp(51:end,6);
                pressure8 = tmp(51:end,8);
                differentialPressureCell{i} = pressure6 - pressure8;

                % 正解ラベル
                flowRegimeCell{i} = RawDataCreatorTwo.correctFlowRegime(conditions(i));
                labelCell{i} = categorical(flowRegimeCell{i});
            end

            % --- 外れ値処理 (NaN置換, 長さ維持) ---
            for i = 1:conditionsLength
                % 静電容量の外れ値検出 (閾値 10)
                [~, idx_rm_capa] = rmoutliers(capacitanceCell{i}, 'ThresholdFactor', 10);

                % 差圧の外れ値検出 (閾値 3.5)
                % ここは 5.0 を検討していましたが、提示された 3.5 を採用します。
                [~, idx_rm_dp] = rmoutliers(differentialPressureCell{i}, 'ThresholdFactor', 3.5);

                % *** 修正点：静電容量と差圧のいずれかで外れ値と判定されたら、すべてを NaN にする ***
                idx_rm_common = idx_rm_capa | idx_rm_dp; 

                % 共通インデックスで NaN 置換
                capacitanceCell{i}(idx_rm_common) = NaN;
                differentialPressureCell{i}(idx_rm_common) = NaN;
                liquidFlowCell{i}(idx_rm_common) = NaN;
                gasFlowCell{i}(idx_rm_common) = NaN;
                
                % 秒単位に変換
                timeCell_second{i} = (timeCell{i} - timeCell{i}(1)) / 1e5;
            end

            % --- RawDataTwo 作成 ---
            createdRawDataTwo = RawDataTwo(date, measuredFreq, conditions, labels, ...
                isNeedCorrect, correctConditions, ...
                timeCell, timeCell_second, ...
                capacitanceCell, flowRegimeCell, featureCell, machineLearningCell, ...
                labelCell, ...
                cell.empty(),...
                "liquidFlowRate", liquidFlowCell, ...
                "gasFlowRate", gasFlowCell, ...
                "differentialPressure", differentialPressureCell);
        end

        %% createFromArray メソッド (前処理後のデータセットから RawDataTwo を生成)
    function createdRawDataTwo = createFromArray(obj, date, measuredFreq, conditions, labels, ...
            isNeedCorrect, correctConditions, timeCell, timeCell_second, ...
            capacitanceCell, flowRegimeCell, featureCell, machineLearningCell, ...
            labelCell, liquidFlowCell, gasFlowRateCell, differentialPressureCell)

        arguments
            obj RawDataCreatorTwo
            date string
            measuredFreq {mustBePositive}
            conditions (1,:) string
            labels (1,:) string
            isNeedCorrect logical
            correctConditions (1,:) string
            timeCell (1,:) cell
            timeCell_second (1,:) cell
            capacitanceCell (1,:) cell
            flowRegimeCell (1,:) cell
            featureCell (:,:) cell
            machineLearningCell (:,:) cell
            labelCell (1,:) cell
            liquidFlowCell (1,:) cell % liquidFlowRate プロパティに対応
            gasFlowRateCell (1,:) cell % gasFlowRate プロパティに対応
            differentialPressureCell (1,:) cell % differentialPressure プロパティに対応
        end

        % RawDataTwo コンストラクタを呼び出し、プロパティを直接設定
        createdRawDataTwo = RawDataTwo(date, measuredFreq, conditions, labels, ...
            isNeedCorrect, correctConditions, ...
            timeCell, timeCell_second, ...
            capacitanceCell, flowRegimeCell, featureCell, machineLearningCell, ...
            labelCell, ...
            cell.empty(), ... 
            "liquidFlowRate", liquidFlowCell, ...
            "gasFlowRate", gasFlowRateCell, ...
            "differentialPressure", differentialPressureCell);
    end
    end

    methods (Static)
        function p = correctFlowRegime(condition)
            % 条件文字列 → 流動様式
            slug = ["L0.5G20" "L0.7G20" "L1G20" "L1.5G25" "L1.5G50" "L2G20" "L3G20" "L3G25" "L3G50" "L4.5G25" "L4.5G50" "L5G20" "L6G20" "L6G25" "L6G50" "L3G70" "L6G70"];
            plug = ["L0.7G3" "L1G1" "L1G3" "L1.5G1" "L3G1" "L3G3" "L4.5G1" "L6G1" "L6G3"];
            bubbly = ["L10G1" "L10G3" "L10G20" "L10G70" "L14G1" "L14G3" "L14G20" "L14G50" "L14G70"];
            annular = ["L0.5G70" "L0.7G70" "L1G70" "L1G90" "L3G90" "L5G90"];
            stratified = ["L0.05G1" "L0.05G3" "L0.05G10" "L0.5G1" "L0.5G3" "L0.7G1"];

            if ismember(condition, slug)
                p = "Slug";
            elseif ismember(condition, plug)
                p = "Plug";
            elseif ismember(condition, bubbly)
                p = "Bubbly";
            elseif ismember(condition, annular)
                p = "Annular";
            elseif ismember(condition, stratified)
                p = "Stratified";
            else
                p = "Unknown";
            end
        end
    end
end





