classdef RawAllDataBeforeFormatTwo
    % 学習とテストに使いたい全てのRawDataTwoを束ねるクラス.
    % 前処理に使う関数の引数になる.

    properties (SetAccess = immutable)
        mainTable           % 元データをまとめたテーブル (1行=1 RawDataTwoインスタンス)
        flatTable           % 条件・サンプルごとに展開したテーブル (1行=1 条件データ)
        condition           % 条件名リスト
    end

    properties (Constant)
        savePathHeader = PictureSavePath.path;
    end

    methods (Access = public)
        function obj = RawAllDataBeforeFormatTwo(rawDataArray)
            arguments
                rawDataArray (1,:) RawDataTwo
            end

            obj.condition = rawDataArray(1).conditions;
            rawDataArrayLength = length(rawDataArray);
            cellLength = length(rawDataArray(1).timeCell);

            %% --- mainTable の初期化と格納 (RawDataTwoインスタンスごとに1行) ---
            tmpSize = [rawDataArrayLength, 6];
            varTypes = ["string" "cell" "cell" "cell" "cell" "cell"];
            varNames = ["date" "label" "time" "time_second" "capacitance" "differentialPressure"];
            obj.mainTable = table('Size', tmpSize, 'VariableTypes', varTypes, 'VariableNames', varNames);

            for i = 1:rawDataArrayLength
                % 💡 修正: Cellを二重にネストしないように外側の{}を削除
                obj.mainTable(i,:) = {rawDataArray(i).date, ...
                                      {rawDataArray(i).labelCell}, ...
                                      {rawDataArray(i).timeCell}, ...
                                      {rawDataArray(i).timeCell_second}, ...
                                      {rawDataArray(i).capacitanceCell}, ...
                                      {rawDataArray(i).differentialPressure}};
            end

            %% --- flatTable の初期化と格納 (条件/サンプルごとに1行) ---
            tmpSize = [cellLength*rawDataArrayLength, 6];
            varTypes_flat = ["string" "categorical" "cell" "cell" "cell" "cell"];
            obj.flatTable = table('Size', tmpSize, 'VariableTypes', varTypes_flat, 'VariableNames', varNames);

            for i = 1:rawDataArrayLength
                for j = 1:cellLength
                    rowIndex = (i-1)*cellLength + j;
                    % flatTableでは、各要素は単一のCellに格納される
                    obj.flatTable(rowIndex,:) = {rawDataArray(i).date, ...
                                                 rawDataArray(i).labelCell{j}, ...
                                                 rawDataArray(i).timeCell{j}, ...
                                                 rawDataArray(i).timeCell_second{j}, ...
                                                 rawDataArray(i).capacitanceCell{j}, ...
                                                 rawDataArray(i).differentialPressure{j}};
                end
            end
        end

        %% --- 可視化関数 ---
        function [] = viewALLData(obj, saveFolderName, ylim)
            % 全てのデータセットの同じ条件の時系列データを1つのグラフにまとめて表示する(全く手を付けてないので、差圧に未対応、村田）
            arguments
                obj RawAllDataBeforeFormatTwo
                saveFolderName string
                ylim (1,:)
            end
            saveDirName = append(obj.savePathHeader, saveFolderName, "/");
            if ~exist(saveDirName, 'dir')
                mkdir(saveDirName)
            end
            obj.allWaveInOneGraph(saveDirName, ylim)
        end
    end

    methods (Access = private)
        function [] = allWaveInOneGraph(obj, saveDirName, ylimRange)
            legendString = strings(height(obj.mainTable),1);

            % i: 測定条件 (Condition) のインデックス
            for i = 1:length(obj.condition)
                figure; hold on;
                
                % j: RawDataTwoのインスタンス (日付/データセット) のインデックス
                for j = 1:height(obj.mainTable)
                    % 💡 修正: mainTableの構造変更に伴い、データアクセスを修正 (外側の{1}を削除)
                    % mainTable(j,:).time_second は全条件のtime_secondを格納したセル配列
                    % その i 番目の要素 (現在の条件のtime_second) を取得
                    x = obj.mainTable(j,:).time_second{i};
                    y = obj.mainTable(j,:).capacitance{i};
                    plot(x, y, '-'); 

                    % 差圧を同じグラフにプロットしたい場合は以下も使用できますが、
                    % 縦軸のスケールが異なる場合は別のグラフに分けることを推奨します。（ここも使ってないです）
                    % y_dp = obj.mainTable(j,:).differentialPressure{i};
                    % plot(x, y_dp, '--'); 
                    
                    legendString(j) = string(obj.mainTable(j,:).date);
                end
                hold off;

                ylim(ylimRange);
                ylabel("静電容量 F")
                xlabel("時間 s")
                legend(legendString, 'Interpreter','none');
                title(obj.condition(i), 'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
                
                % ファイル名が長くなりすぎる可能性を考慮し、末尾のstrjoinは削除
                saveas(gcf, append(saveDirName, obj.condition(i), "_AllWave.fig"))
                close all hidden
            end
        end
    end
end