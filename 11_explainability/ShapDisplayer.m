classdef ShapDisplayer
    %SHAPDISPLAYER モダリティ単位のシャープレイ値を可視化するクラス
    %   ResultDisplayerTwo (08_result_display) と同じ流儀で,
    %   図を PictureSavePath.path 配下に保存する.
    properties (SetAccess = immutable)
        modalityNames (1,3) string = ["CapWave" "DiffWave" "FeatureData"]
    end

    methods (Access = public)
        function obj = ShapDisplayer(nameAndVar)
            arguments
                nameAndVar.modalityNames (1,3) string = ["CapWave" "DiffWave" "FeatureData"]
            end
            obj.modalityNames = nameAndVar.modalityNames;
        end

        function [] = displaySingleQuery(obj, explainer, folderName, nameAndVar)
            % 1件のクエリ点のモダリティ別Shapley値を棒グラフ表示・保存する
            arguments
                obj ShapDisplayer
                explainer
                folderName string
                nameAndVar.fileName string = "ShapleyValues_Modality"
            end

            dirName = append(PictureSavePath.path, folderName, "/");
            if ~exist(dirName, 'dir')
                mkdir(dirName)
            end

            shapTable = explainer.Shapley;

            figure
            bar(categorical(obj.modalityNames), shapTable.Value)
            ylabel("Shapley値 (平均予測からの偏差への寄与)")
            title("モダリティ別 寄与度 (1サンプル)")
            saveas(gcf, append(dirName, nameAndVar.fileName, ".fig"))

            fprintf("Intercept (背景データの平均予測値): %.5f\n", explainer.Intercept);
            fprintf("このクエリ点の予測値: %.5f\n", explainer.BlackboxFitted);
            disp(shapTable)
        end

        function meanAbsShap = displayAggregated(obj, explainerArray, folderName, nameAndVar)
            % 複数クエリ点(例:同一流動様式の複数サンプル)の平均|Shapley値|を棒グラフ表示・保存する
            arguments
                obj ShapDisplayer
                explainerArray (1,:) cell
                folderName string
                nameAndVar.fileName string = "ShapleyValues_Modality_Aggregated"
            end

            dirName = append(PictureSavePath.path, folderName, "/");
            if ~exist(dirName, 'dir')
                mkdir(dirName)
            end

            numQueries = numel(explainerArray);
            valuesMat = zeros(numQueries, numel(obj.modalityNames));
            for i = 1:numQueries
                shapTable = explainerArray{i}.Shapley;
                valuesMat(i, :) = abs(shapTable.Value)';
            end
            meanAbsShap = mean(valuesMat, 1);

            figure
            bar(categorical(obj.modalityNames), meanAbsShap)
            ylabel("平均 |Shapley値|")
            title(sprintf("モダリティ別 平均寄与度 (n=%d)", numQueries))
            saveas(gcf, append(dirName, nameAndVar.fileName, ".fig"))
        end
    end
end
