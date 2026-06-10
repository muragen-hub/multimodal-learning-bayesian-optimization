classdef RawAllDataBeforeFormat
    % 学習とテストに使いたい全てのRawDataを束ねるクラス. 前処理に使う関数の引数になる.

    properties (SetAccess = immutable)
        mainTable
        flatTable
        condition
    end

    properties (Constant)
        savePathHeader = PictureSavePath.path;
    end

    methods (Access = public)
        function obj =  RawAllDataBeforeFormat(rawDataArray)
            arguments
                rawDataArray (1,:) RawData
            end
            obj.condition = rawDataArray(1).conditions;

            rawDataArrayLength = length(rawDataArray);
            tmpSize = [rawDataArrayLength, 5];
            varTypes = ["string" "cell" "cell" "cell" "cell"];
            varNames = ["date" "label" "time" "time_second" "capacitance"];
            obj.mainTable = table('Size',tmpSize,'VariableTypes',varTypes,'VariableNames',varNames);

            for i = 1:rawDataArrayLength
                obj.mainTable(i,:) = {rawDataArray(i).date, {rawDataArray(i).labelCell},{rawDataArray(i).timeCell},{rawDataArray(i).timeCell_second}, {rawDataArray(i).capacitanceCell}};
            end

            cellLength = length(rawDataArray(1).timeCell);

            tmpSize = [cellLength*rawDataArrayLength, 5];
            varTypes_flat = ["string" "categorical" "cell" "cell" "cell"];
            obj.flatTable = table('Size',tmpSize,'VariableTypes',varTypes_flat,'VariableNames',varNames);

            for i = 1:rawDataArrayLength
                for j = 1:cellLength
                    rowIndex = (i-1)*cellLength+j;
                    obj.flatTable(rowIndex,:) = {rawDataArray(i).date, rawDataArray(i).labelCell{j}, rawDataArray(i).timeCell{j}, rawDataArray(i).timeCell_second{j}, rawDataArray(i).capacitanceCell{j}};
                end
            end
        end

        function [] = viewALLData(obj,saveFolderName,ylim)
            saveDirName = append(obj.savePathHeader,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir(saveDirName)
            end
            obj.allWaveInOneGraph(saveDirName,ylim)
        end
    end

    methods (Access = private)
        function [] = allWaveInOneGraph(obj,saveDirName, ylimRange)
            legendString = strings(height(obj.mainTable),1);
            for i = 1:length(obj.condition)

                figure;
                hold on;
                for j = 1:height(obj.mainTable)
                    x = obj.mainTable(j,:).time_second{1}{i}; % 一つのセルにcondition分のセルをまとめているため, まず{1}で一つにまとめたセルの中身を展開してconditions分のセルにしないといけない.
                    y = obj.mainTable(j,:).capacitance{1}{i};
                    plot(x,y)      %,'.','MarkerSize',4);
                    legendString(j) = string(obj.mainTable(j,:).date);
                end
                hold off;

                ylim(ylimRange);
                ylabel("静電容量 F")
                xlabel("時間 s")
                legend(legendString, 'Interpreter','none');
                title(obj.condition(i),'Units', 'normalized', 'Position', [0.5, -0.135, 0])
                saveas(gcf, append( saveDirName,obj.condition(i),append("of_ ",strjoin(string(legendString)), ".fig")))
            end
        end
    end
end

