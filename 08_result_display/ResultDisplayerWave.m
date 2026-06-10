classdef ResultDisplayerWave
%RESULTDISPLAYERWAVE 学習結果を可視化するクラス（流動様式別のみ）
% 混同行列、精度、推定ラベルのプロットなどを表示する
    properties (SetAccess = immutable)
        result TrainResult
        option TrainOption
    end
    methods (Access = public)
        function obj = ResultDisplayerWave(result, option)
            arguments
                result TrainResult
                option TrainOption
            end
            obj.result = result;
            obj.option = option;
        end
        
        function [] = displayResult(obj, folderName)
            arguments
                obj ResultDisplayerWave
                folderName string
            end
            dirName = append(PictureSavePath.path, folderName);
            if ~exist(dirName, 'dir')
                mkdir(dirName)
            end
            
            % 流量条件ごとの推定ラベルプロット
            obj.displayFlowToLabel(dirName);
            
            % ヒートマップ表示（流動様式別）- 混同行列の表示
            % 【修正版】confusionchartを使用するように変更
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
                obj ResultDisplayerWave
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
            % 流動様式別のヒートマップ表示（混同行列）
            % 【修正版】confusionchartを使用してスタイルを刷新
            arguments
                obj ResultDisplayerWave
                dirName string
            end
            trueFlowRegime = obj.result.testLabel;
            predFlowRegime = obj.result.predictedLabel;
            
            % 表示順序の定義
            labels_order_str = ["Annular", "Slug", "Plug", "Stratified"];
            
            % string配列をcategorical配列に変換し、順序を指定
            % これにより、グラフ上でのクラスの並び順が固定されます
            trueLabelCat = categorical(trueFlowRegime, labels_order_str);
            predLabelCat = categorical(predFlowRegime, labels_order_str);
            
            figure
            % confusionchartを作成
            % 正解データと予測データを直接渡すことで、行列計算を自動化
            cm = confusionchart(trueLabelCat, predLabelCat);
            
            % === スタイルのカスタマイズ ===
            
            % タイトルと軸ラベルの設定（元に合わせて英語のままにしています）
            cm.Title = 'Confusion Matrix (Normalized)';
            cm.XLabel = '予想されたクラス';
            cm.YLabel = '真のクラス';
            
            % 右側と下側に行・列ごとのサマリー（正解率）を表示
            cm.RowSummary = 'row-normalized';    % 右側のRecall表示
            cm.ColumnSummary = 'column-normalized'; % 下側のPrecision表示
            
            % カラーマップを「白から濃い青」へのグラデーションに設定
            % (二枚目の画像のスタイルを再現)
            %white_to_blue = [linspace(1, 0, 256)', linspace(1, 0.447, 256)', linspace(1, 0.741, 256)'];
            %cm.Colormap = white_to_blue;
            
            % 数値の表示形式をパーセンテージに設定（必要に応じて'absolute'で個数表示に変更可）
            % cm.Normalization = 'row-normalized'; % これを有効にするとセル内も％表示になります

            % 図の保存
            saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Style2.fig"))
            % PNG形式でも保存しておくと確認が楽です
            saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Style2.png"))
        end
        
        function [] = displayNetGraph(obj, dirName)
            arguments
                obj ResultDisplayerWave
                dirName string
            end
            % 最初のネットワークの層グラフを利用してプロット
            lgraph = layerGraph(obj.result.net{1}.Layers); 
            figure
            plot(lgraph)
            title('Neural Network Layer Graph');
            saveas(gcf, fullfile(dirName, "LayerMap.fig"))
        end
    end
end

% classdef ResultDisplayerWave
% %RESULTDISPLAYERWAVE 学習結果を可視化するクラス（流動様式別のみ）
% % 混同行列、精度、推定ラベルのプロットなどを表示する
%     properties (SetAccess = immutable)
%         result TrainResult
%         option TrainOption
%     end
%     methods (Access = public)
%         function obj = ResultDisplayerWave(result, option)
%             arguments
%                 result TrainResult
%                 option TrainOption
%             end
%             obj.result = result;
%             obj.option = option;
%         end
% 
%         function [] = displayResult(obj, folderName)
%             arguments
%                 obj ResultDisplayerWave
%                 folderName string
%             end
%             dirName = append(PictureSavePath.path, folderName);
%             if ~exist(dirName, 'dir')
%                 mkdir(dirName)
%             end
% 
%             % 流量条件ごとの推定ラベルプロット
%             obj.displayFlowToLabel(dirName);
% 
%             % ヒートマップ表示（流動様式別）- 混同行列の表示
%             % ※ここでエラーが出ていた箇所を修正済みの関数を呼び出します
%             obj.displayHeatMapByFlowRegime(dirName); 
% 
%             % ネットワーク構造図
%             obj.displayNetGraph(dirName);
% 
%             % === 学習精度表示 ===
%             trainAcc = obj.result.trainAccuracy;
%             testAcc = obj.result.testAccuracy;
%             overfitRate = trainAcc - testAcc;
% 
%             fprintf("=== 学習結果 ===\n");
%             fprintf("訓練データ精度: %.5f\n", trainAcc);
%             fprintf("テストデータ精度: %.5f\n", testAcc);
%             fprintf("過学習率 (train - test): %.5f\n", overfitRate);
% 
%             % 結果をテキストファイルに保存
%             resultFile = fullfile(dirName, "TrainingResultSummary.txt");
%             fid = fopen(resultFile, "w");
%             fprintf(fid, "訓練データ精度: %.5f\n", trainAcc);
%             fprintf(fid, "テストデータ精度: %.5f\n", testAcc);
%             fprintf(fid, "過学習率 (train - test): %.5f\n", overfitRate);
%             fclose(fid);
%         end
%     end
% 
%     methods (Access = private)
%         function [] = displayFlowToLabel(obj, dirName)
%             % 流量設定条件ごとにどのようにラベルが推移するかを見る.
%             arguments
%                 obj ResultDisplayerWave
%                 dirName string
%             end
%             figure
%             plot(obj.result.predictedLabel, '-')
%             hold on
%             plot(obj.result.testLabel)
%             hold off
%             ylabel("Flow State")
%             title("Predicted Flow State")
%             legend(["Predicted" "Test Data"])
%             saveas(gcf, fullfile(dirName, "PredictedFlowState.fig"))
%         end
% 
%         function [] = displayHeatMapByFlowRegime(obj, dirName)
%             % 流動様式別のヒートマップ表示（混同行列）
%             % 【修正版】heatmapではなくimagescを使用することでtextエラーを回避
%             arguments
%                 obj ResultDisplayerWave
%                 dirName string
%             end
%             trueFlowRegime = obj.result.testLabel;
%             predFlowRegime = obj.result.predictedLabel;
% 
%             % ユニークな流動様式を抽出
%             labels = unique([trueFlowRegime; predFlowRegime]);
% 
%             % Y軸の表示順序を定義
%             labels_y_order_str = ["Annular", "Slug", "Plug", "Stratified"]; 
%             labels_y_order = categorical(labels_y_order_str);
% 
%             % 実際のデータに含まれるラベルのみを抽出
%             labels_y = intersect(labels_y_order, labels, 'stable'); 
%             labels_x = labels_y;
% 
%             % 混同行列（個数）の計算
%             [cmat, ~] = confusionmat(trueFlowRegime, predFlowRegime, 'Order', labels_y); 
% 
%             % --- 1. 個数プロット (imagescに変更) ---
%             figure
%             imagesc(cmat); 
%             colormap(jet);
%             colorbar;
% 
%             % 軸ラベルの設定
%             xticks(1:length(labels_x));
%             xticklabels(labels_x);
%             yticks(1:length(labels_y));
%             yticklabels(labels_y);
%             xlabel('Predicted Flow Regime');
%             ylabel('True Flow Regime');
%             title('Confusion Matrix by Flow Regime (Count)');
% 
%             % 数値の描画 (text関数)
%             for i = 1:size(cmat, 1)
%                 for j = 1:size(cmat, 2)
%                     text(j, i, num2str(cmat(i, j)), ...
%                          'HorizontalAlignment', 'center', ...
%                          'VerticalAlignment', 'middle', ...
%                          'Color', 'white', ...
%                          'FontWeight', 'bold');
%                 end
%             end
%             saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Count.fig"))
% 
%             % --- 2. 正規化行列の計算 ---
%             testDataAmount = sum(cmat, 2); 
%             cmat_per = cmat ./ repmat(testDataAmount, 1, size(cmat, 2)) * 100;
%             percent_total_col = repmat(100.0, size(cmat, 1), 1);
%             cmat_per_normalized = [cmat_per, percent_total_col];
%             cmat_with_sum = [cmat, testDataAmount];
% 
%             labelNames_normalized = [labels_x.', {'Total'}]; 
% 
%             % --- 3. 正規化プロット (imagescに変更) ---
%             figure
%             imagesc(cmat_per_normalized);
%             colormap(jet(256));
% 
%             % 軸ラベルの設定
%             xticks(1:length(labelNames_normalized));
%             xticklabels(labelNames_normalized);
%             yticks(1:length(labels_y));
%             yticklabels(labels_y);
%             xlabel('Predicted Flow Regime');
%             ylabel('True Flow Regime');
%             title('Confusion Matrix (Normalized)');
% 
%             % 数値の描画
%             cmat_to_plot = cmat_per_normalized;
%             cmat_count_to_plot = cmat_with_sum;
% 
%             for i = 1:size(cmat_to_plot, 1)
%                 for j = 1:size(cmat_to_plot, 2)
%                     if j <= size(cmat, 2)
%                         % 混同行列部分
%                         text_to_display = num2str(cmat_count_to_plot(i, j));
%                     else
%                         % Total列部分
%                         text_to_display = sprintf('%.1f%%', cmat_to_plot(i, j));
%                     end
% 
%                     text(j, i, text_to_display, ...
%                          'HorizontalAlignment', 'center', ...
%                          'VerticalAlignment', 'middle', ...
%                          'Color', 'white', ...
%                          'FontWeight', 'bold');
%                 end
%             end
% 
%             % Total列との区切り線
%             line([size(cmat, 2) + 0.5, size(cmat, 2) + 0.5], [0.5, size(cmat, 1) + 0.5], ...
%                  'Color', 'black', 'LineWidth', 2);
% 
%             saveas(gcf, fullfile(dirName, "ConfusionMatrixByFlowRegime_Normalized.fig"))
%         end
% 
%         function [] = displayNetGraph(obj, dirName)
%             arguments
%                 obj ResultDisplayerWave
%                 dirName string
%             end
%             % 最初のネットワークの層グラフを利用してプロット
%             lgraph = layerGraph(obj.result.net{1}.Layers); 
%             figure
%             plot(lgraph)
%             title('Neural Network Layer Graph');
%             saveas(gcf, fullfile(dirName, "LayerMap.fig"))
%         end
%     end
% end