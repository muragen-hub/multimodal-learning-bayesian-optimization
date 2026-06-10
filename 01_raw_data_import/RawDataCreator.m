classdef RawDataCreator
    %RAWDATACREATOR コードの上で扱い安くするためにExcelから持ってきた生データ(rawDataクラス)を作るFactory
    %   詳細説明をここに記述

    properties (Constant)
        sourcePathHeader = DataPath.path;
    end

    methods (Access = public)
        function RawDataCreator = RawDataCreator()
        end

        function createdRawData = createVF(obj, date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions)
            arguments
                obj RawDataCreator %MATLABはこういうところがダメで, コンストラクタ以外の全てのメソッドの先頭にはinstanceを示すobjを引数に入れないといけない.　そのくせして型でミスを防止しようとすると, 先頭のobjが入っていないとおこる. 回避法あれば修正してください.
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string %Labelの役割は最初にconditionごとにラベル付けをするために使う以外にはクラスの分類先がいくつあるのかなどに使う．
                isNeedCorrect logical
                correctConditions (1,:) string
            end


            %RAWDATA このクラスのインスタンスを作成
            %put ALLDATA into variant "sources"
            conditionsLength = length(conditions);
            sources = append(RawDataCreator.sourcePathHeader,date,"/",conditions,"/ALLDATA.csv");

            timeCell = cell(1, conditionsLength);
            timeCell_second = cell(1,conditionsLength);
            capacitanceCell = cell(1, conditionsLength);
            labelCell = cell(1, conditionsLength);
            %データの形式として, ALLDATAの１列目が時間で２列目が静電容量
            for i = 1:conditionsLength
                tmp= readmatrix(sources(i));
                timeCell{i} = tmp(51: end,1); %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておく.
                capacitanceCell{i} = tmp(51: end,2);
                labelCell{i}=categorical(labels(i));%categoricalにしてメモリ節約
            end

            min = transpose(cellfun(@min,capacitanceCell));
            idx = transpose(min<0);
            % 行列の列でまるごとけしてくれるため, transposeしてからrmoutliersしないといけない. 
            %rmoutliers removes outliers in data
            for i =1:conditionsLength
                if idx(i) == 1
                    tmp_rm = capacitanceCell{i};
                    [tmp_rm, idx_rm] = rmoutliers(tmp_rm, 'ThresholdFactor',10);  % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
                    capacitanceCell{i} = tmp_rm;
                    tmp_rm = timeCell{i};
                    tmp_rm = tmp_rm(~idx_rm);
                    timeCell{i} = tmp_rm;
                end

                % 異常値の除去が終わった後で, 単位を秒に直したものも保存する.  0.02秒が2000となっているため, 記録の時間の単位は10μSである.
                timeCell_second{i}(:,1) = (timeCell{i}(:,1) -timeCell{i}(1,1)) / 10^5;
            end

            createdRawData = RawData(date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell,labelCell);
        end

        function createdRawData = createPr(obj, date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions)
            arguments
                obj RawDataCreator %MATLABはこういうところがダメで, コンストラクタ以外の全てのメソッドの先頭にはinstanceを示すobjを引数に入れないといけない.　そのくせして型でミスを防止しようとすると, 先頭のobjが入っていないとおこる. 回避法あれば修正してください.
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string %Labelの役割は最初にconditionごとにラベル付けをするために使う以外にはクラスの分類先がいくつあるのかなどに使う．
                isNeedCorrect logical
                correctConditions (1,:) string
            end


            %RAWDATA このクラスのインスタンスを作成
            %put ALLDATA into variant "sources"
            conditionsLength = length(conditions);
            sources = append(RawDataCreator.sourcePathHeader,date,"/",conditions,"/ALLDATA.csv");

            timeCell = cell(1, conditionsLength);
            timeCell_second = cell(1,conditionsLength);
            pressureDifferenceCell = cell(1, conditionsLength);
            labelCell = cell(1, conditionsLength);

            %データの形式として, ALLDATAの１列目が時間で２列目が静電容量
            for i = 1:conditionsLength
                tmp= readmatrix(sources(i));
                timeCell{i} = tmp(51: end,1); %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておく.
                pressureDifferenceCell{i} = tmp(51: end,6) - tmp(51:end,8);
                labelCell{i}=categorical(labels(i));%categoricalにしてメモリ節約
            end

            min = transpose(cellfun(@min,pressureDifferenceCell));
            idx = transpose(min<0);
            % 行列の列でまるごとけしてくれるため, transposeしてからrmoutliersしないといけない. 
            %rmoutliers removes outliers in data
            for i =1:conditionsLength
                if idx(i) == 1
                    tmp_rm = pressureDifferenceCell{i};
                    [tmp_rm, idx_rm] = rmoutliers(tmp_rm, 'ThresholdFactor',10);  % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
                    pressureDifferenceCell{i} = tmp_rm;
                    tmp_rm = timeCell{i};
                    tmp_rm = tmp_rm(~idx_rm);
                    timeCell{i} = tmp_rm;
                end

                % 異常値の除去が終わった後で, 単位を秒に直したものも保存する.  0.02秒が2000となっているため, 記録の時間の単位は10μSである.
                timeCell_second{i}(:,1) = (timeCell{i}(:,1) -timeCell{i}(1,1)) / 10^5;
            end

            createdRawData = RawData(date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, pressureDifferenceCell,labelCell);
        end

        % 流量計計測データも含める. 重くなるため注意
        function createdRawData = createWithFlowRate(obj, date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions)
            arguments
                obj RawDataCreator %MATLABはこういうところがダメで, コンストラクタ以外の全てのメソッドの先頭にはinstanceを示すobjを引数に入れないといけない.　そのくせして型でミスを防止しようとすると, 先頭のobjが入っていないとおこる. 回避法あれば修正してください.
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string
                isNeedCorrect logical
                correctConditions (1,:) string
            end


            %RAWDATA このクラスのインスタンスを作成
            conditionsLength = length(conditions);
            sources = append(RawDataCreator.sourcePathHeader,date,"/",conditions,"/ALLDATA.csv");

            timeCell = cell(1, conditionsLength);
            timeCell_second = cell(1,conditionsLength);
            capacitanceCell = cell(1, conditionsLength);
            labelCell = cell(1, conditionsLength);
            liquidCell = cell(1,conditionsLength);
            gasCell = cell(1,conditionsLength);
            %データの形式として, ALLDATAの１列目が時間で２列目が静電容量. 更に, とんで4列目が液相流量で, 5列目が気相流量. 
            for i = 1:conditionsLength
                tmp= readmatrix(sources(i));
                timeCell{i} = tmp(51: end,1); %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておく.
                capacitanceCell{i} = tmp(51: end,2);
                labelCell{i}=categorical(labels(i));%categoricalにしてメモリ節約
                liquidCell{i} = tmp(51:end,4);
                gasCell{i} = tmp(51:end,5);
            end

            min = transpose(cellfun(@min,capacitanceCell));
            idx = transpose(min<0);
            % 行列の列でまるごとけしてくれるため, transposeしてからrmoutliersしないといけない. 
            for i =1:conditionsLength
                if idx(i) == 1
                    tmp_rm = capacitanceCell{i};
                    [tmp_rm, idx_rm] = rmoutliers(tmp_rm, 'ThresholdFactor',10);  % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
                    capacitanceCell{i} = tmp_rm;
                    tmp_rm = timeCell{i};
                    tmp_rm = tmp_rm(~idx_rm);
                    timeCell{i} = tmp_rm; % capacitanceCellではずれ値出したものは全てここで外されて後々intervalUniformerでtimeCellの値をもとに補完されるので実験で多少ピークノイズが立つのはok
                    liquidCell{i} = liquidCell{i}(~idx_rm);
                    gasCell{i} = gasCell{i}(~idx_rm);
                end

                % 異常値の除去が終わった後で, 単位を秒に直したものも保存する.  0.02秒が2000となっているため, 記録の時間の単位は10μSである.
                timeCell_second{i}(:,1) = (timeCell{i}(:,1) -timeCell{i}(1,1)) / 10^5;
            end

            createdRawData = RawData(date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell,labelCell,"liquidFlowRate",liquidCell,"gasFlowRate",gasCell);
        end

        %保守性のために本コードではなるべくimmutableにすることでクラス内部で変化する状態を持たせないようにしている. 
        %既存のrawDataから新しくrawDataクラスを作るときにはこの関数を使う.  
        function createdRawData = createFromArray(obj,date,measuredFreq, conditions, labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell,labelCell,liquidCell, gasCell)
            arguments
                obj RawDataCreator
                date string
                measuredFreq {mustBePositive}
                conditions (1,:) string
                labels (1,:) string
                isNeedCorrect logical
                correctConditions (1,:) string
                timeCell (1,:) cell
                timeCell_second (1,:) cell
                capacitanceCell (1,:) cell
                labelCell (1,:) cell
                liquidCell (1,:) cell
                gasCell (1,:) cell
            end
            createdRawData = RawData(date,measuredFreq,conditions,labels, isNeedCorrect, correctConditions, timeCell, timeCell_second, capacitanceCell,labelCell,"liquidFlowRate",liquidCell,"gasFlowRate",gasCell);
        end
    end
end

