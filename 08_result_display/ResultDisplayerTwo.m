classdef ResultDisplayerTwo
    %RESULTDISPLAYER 学習結果を可視化するクラス（流動様式別のみ）
    properties (SetAccess = immutable)
        result TrainResult
        option TrainOption
    end

    methods (Access = public)
        function obj = ResultDisplayerTwo(result, option)
            arguments
                result TrainResult
                option TrainOption
            end
            obj.result = result;
            obj.option = option;
        end

        function [] = displayResult(obj, folderName)
            arguments
                obj ResultDisplayerTwo
                folderName string
            end

            dirName = append(PictureSavePath.path, folderName);
            if ~exist(dirName, 'dir')
                mkdir(dirName)
            end

            % 流量条件ごとの推定ラベルプロット
            obj.displayFlowToLabel(dirName);

            % ヒートマップ表示（流動様式別）
            obj.displayHeatMapByFlowRegime(dirName);

            % ネットワーク構造図
            obj.displayNetGraph(dirName);

            % === 学習精度表示 ===
            trainAcc = obj.result.trainAccuracy;
            testAcc = obj.result.testAccuracy;
            overfitRate = trainAcc - testAcc;

            fprintf("=== 学習結果 ===\n");
            fprintf("訓練データ精度: %.5f\n", trainAcc);
            fprintf("テストデータ精度: %.5f\n", testAcc);
            fprintf("過学習率 (train - test): %.5f\n", overfitRate);

            % 結果をテキストファイルに保存
            resultFile = fullfile(dirName, "TrainingResultSummary.txt");
            fid = fopen(resultFile, "w");
            fprintf(fid, "訓練データ精度: %.5f\n", trainAcc);
            fprintf(fid, "テストデータ精度: %.5f\n", testAcc);
            fprintf(fid, "過学習率 (train - test): %.5f\n", overfitRate);
            fclose(fid);
        end
    end

    methods (Access = private)
        function [] = displayFlowToLabel(obj, dirName)
            % 流量設定条件ごとにどのようにラベルが推移するかを見る.
            arguments
                obj ResultDisplayerTwo
                dirName string
            end

            figure
            plot(obj.result.predictedLabel, '-')
            hold on
            plot(obj.result.testLabel)
            hold off
            ylabel("Flow State")
            title("Predicted Flow State")
            legend(["Predicted" "Test Data"])
            saveas(gcf, fullfile(dirName, "PredictedFlowState.fig"))
        end

        function [] = displayHeatMapByFlowRegime(obj, dirName)
            % 流動様式別のヒートマップ表示（カスタムカラーなし）
            arguments
                obj ResultDisplayerTwo
                dirName string
            end

            trueFlowRegime = obj.result.testLabel;
            predFlowRegime = obj.result.predictedLabel;

            % ユニークな流動様式 (5種類が格納されているはず)
            labels = unique([trueFlowRegime; predFlowRegime]);

            % 混同行列（個数）
            [cmat, labelNames] = confusionmat(trueFlowRegime, predFlowRegime, 'Order', labels);
            
            figure
            h = heatmap(labelNames, labelNames, cmat);
            h.YDisplayData = flip(labels); % Y軸のラベルを反転
            xlabel('Predicted Flow Regime');
            ylabel('True Flow Regime');
            title('Confusion Matrix by Flow Regime (Count)');
            
            % ★カスタムカラーの設定ロジックを削除したため、自動的に標準形式に戻ります。
            % 以前のデバッグで確認されたデータ数制限の問題が解決していれば、
            % $1.2e+05$ のような大きな値が表示されるはずです。

            saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Count.fig"))

            % 混同行列（%）
            % 各行の合計 (真のクラスごとのデータ総数) を取得 (N x 1 縦ベクトル)
            testDataAmount = sum(cmat, 2); 
            
            % 行列の要素ごとの除算
            cmat_per = cmat ./ repmat(testDataAmount, 1, size(cmat, 2)) * 100;
            
            figure
            h = heatmap(labelNames, labelNames, cmat_per);
            h.YDisplayData = flip(labels);
            xlabel('Predicted Flow Regime');
            ylabel('True Flow Regime');
            title('Confusion Matrix by Flow Regime (%)');
            saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Percent.fig"))
        end

        function [] = displayNetGraph(obj, dirName)
            arguments
                obj ResultDisplayerTwo
                dirName string
            end

            lgraph = layerGraph(obj.result.net{1}.Layers); % 最初のネットワークを利用
            figure
            plot(lgraph)
            saveas(gcf, fullfile(dirName, "LayerMap.fig"))
        end
    end
end