classdef DataFormatter
    %DATAFORMATTER stride, intervalなど, 実験一つ一つごとにデータとしての体裁を整えたFormatDataクラスのファクトリ
    % もしrawDataに何か追加するときはこことか, その他もろもろ全て書き直さないといけないことに注意. これは阿久津のソフトウェア設計ミス. 
    % 本来はどんなに取得データの入力を増やしてもそのまま使えるようにしておく必要がある. 

    properties(SetAccess = immutable)
        option DataFormatterOption
    end

    methods(Access = public)
        function obj = DataFormatter(option)
            arguments
                option DataFormatterOption
            end
            obj.option = option;
        end

        function formattedData = Format(obj,modifiedDataBeforeFormat)
            %[Obsolete]　使用非推奨
            arguments
                obj DataFormatter
                modifiedDataBeforeFormat ModifiedDataBeforeFormat
            end
            rawData = modifiedDataBeforeFormat.rawData;
            [capacitance, label,averageTmp,maxTmp,minTmp,liquidFlowRate, gasFlowRate] = obj.FormatDataCore(rawData);
            formattedData = FormattedData(obj.option, rawData.date,rawData.conditions,rawData.labels,capacitance, label,averageTmp,maxTmp,minTmp,"liquidFlowRateOfEachData",liquidFlowRate,"gasFlowRateOfEachData",gasFlowRate);
        end

        function formattedData = formatAnyDimension(obj,modifiedDataBeforeFormat)
            %単一でも, 複数入力でも対応可能なformatter
            arguments
                obj DataFormatter
                modifiedDataBeforeFormat ModifiedDataBeforeFormat
            end
            rawData = modifiedDataBeforeFormat.rawData;
            conditionsLength = length(modifiedDataBeforeFormat.rawData.conditions);

            clear modifiedDataBeforeFormat

            % 加工済みデータ用のcell配列を用意する
            capacitance = cell(1, conditionsLength);
            % 教師データYを用意する
            label= cell(1,conditionsLength);
            % 一応データとして取っておく
            averageTmp = cell(1, conditionsLength);
            maxTmp = cell(1, conditionsLength);
            minTmp = cell(1, conditionsLength);
            %正確な流量
            amountLimitedLiquidFlowRate = cell(1, conditionsLength);
            amountLimitGasFlowRate = cell(1, conditionsLength);

            intervalBetweenData = obj.option.intervalBetweenData;
            dataWidth = obj.option.dataWidth;
            stride = obj.option.stride;

            % 複数入力の場合は3次元配列になっているのでsizeでとる. 
            vectorDimension = size(rawData.capacitanceCell{1},2);
            oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
            
            for i = 1:conditionsLength
                %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
                %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
                datasetAmount = (size(rawData.capacitanceCell{i},1)-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
                datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
                % 個数を制限された場合はそれ以上はとらない
                datasetAmount = min(datasetAmount,obj.option.lengthLimitInEachCondition);
                
                capacitance{i} = zeros(datasetAmount, dataWidth, vectorDimension);
                label{i} = categorical(zeros(datasetAmount, 1));


                averageTmp{i} = zeros(datasetAmount,vectorDimension);
                maxTmp{i} = zeros(datasetAmount,vectorDimension);
                minTmp{i} = zeros(datasetAmount,vectorDimension);


                % data_width，strideに合わせて加工
                for k = 1:vectorDimension
                    for j=1:datasetAmount
                        %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
                        %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
                        capacitance{i}(j,1:dataWidth,k)=rawData.capacitanceCell{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence,k);    %(1+(j-1)*stride:(j-1)*stride+dataWidth);
                        averageTmp{i}(j) = mean(capacitance{i}(j,1:dataWidth,k));
                        maxTmp{i}(j,k) = max(capacitance{i}(j,1:dataWidth,k));
                        minTmp{i}(j,k) = min(capacitance{i}(j,1:dataWidth,k));
                        label{i}(j,1)=rawData.labelCell{i};
                        amountLimitedLiquidFlowRate{i}(j,1) = rawData.liquidFlowRate{i}(j);
                        amountLimitGasFlowRate{i}(j,1) = rawData.gasFlowRate{i}(j);
                    end
                end
                % 個数の制限の追加により, 他のあらゆる引数も個数を制限する. 
                
            end
            formattedData = FormattedData(obj.option, rawData.date,rawData.conditions,rawData.labels,capacitance, label,averageTmp,maxTmp,minTmp,"liquidFlowRateOfEachData",amountLimitedLiquidFlowRate,"gasFlowRateOfEachData",amountLimitGasFlowRate);
        end

        % 逆転した配列も突っ込む
        function formattedData = formatNormalAndFlipData(obj,modifiedDataBeforeFormat)
            arguments
                obj DataFormatter
                modifiedDataBeforeFormat ModifiedDataBeforeFormat
            end
            rawData = modifiedDataBeforeFormat.rawData;
            conditionsLength = length(modifiedDataBeforeFormat.rawData.conditions);

            % 加工済みデータ用のcell配列を用意する
            capacitance = cell(1, conditionsLength);
            % 教師データYを用意する
            label= cell(1,conditionsLength);
            % dataFormatterOptionによる平均や最大値, 最小値のばらつきを調査したいので, 専用の配列を用意しておく.
            averageTmp = cell(1, conditionsLength);
            maxTmp = cell(1, conditionsLength);
            minTmp = cell(1, conditionsLength);

            intervalBetweenData = obj.option.intervalBetweenData;
            dataWidth = obj.option.dataWidth;
            stride = obj.option.stride;

            for i = 1:conditionsLength
                %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
                %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
                oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
                datasetAmount = (numel(rawData.capacitanceCell{i})-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
                datasetAmount = int16(fix(datasetAmount))*2; %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
                datasetAmount = min(datasetAmount,obj.option.lengthLimitInEachCondition);
                capacitance{i} = zeros(datasetAmount, dataWidth);
                label{i} = categorical(zeros(datasetAmount, 1));

                averageTmp{i} = zeros(datasetAmount,1);
                maxTmp{i} = zeros(datasetAmount,1);
                minTmp{i} = zeros(datasetAmount,1);

                % data_width，strideに合わせて加工
                for j=1:datasetAmount/2
                    %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
                    %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
                    capacitance{i}(2*j-1,1:dataWidth)=rawData.capacitanceCell{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);    %(1+(j-1)*stride:(j-1)*stride+dataWidth);
                    capacitance{i}(2*j,1:dataWidth)= flip(capacitance{i}(j,1:dataWidth));
                    averageTmp{i}(j) = mean(capacitance{i}(j,1:dataWidth));
                    maxTmp{i}(j) = max(capacitance{i}(j,1:dataWidth));
                    minTmp{i}(j) = min(capacitance{i}(j,1:dataWidth));
                    label{i}(2*j-1,1)=rawData.labelCell{i};
                    label{i}(2*j,1)=rawData.labelCell{i};
                end
            end
            formattedData = FormattedData(obj.option, rawData.date,rawData.conditions,rawData.labels,capacitance, label,averageTmp,maxTmp,minTmp);
        end

        % 周波数ごとでフィルタをかけた時のものを複数次元だけつなげる時に必要になったクラス.
        % 入力の直前でデータを分けるのではなく, そもそも生のデータに対して何らかの変換を施す時に必要になる.
        % こっちをデフォルトとして使いたい?
        function formattedData = FormatMultiVectorModifiedData(obj,modifiedDataBeforeFormat)
            %[Obsolete] 使用非推奨
            arguments
                obj DataFormatter
                modifiedDataBeforeFormat MultiVectorModifiedDataBeforeFormat
            end
            rawData = modifiedDataBeforeFormat.rawData;
            conditionsLength = length(modifiedDataBeforeFormat.rawData.conditions);

            % 加工済みデータ用のcell配列を用意する
            capacitance = cell(1, conditionsLength);
            % 教師データYを用意する
            label= cell(1,conditionsLength);
            % 一応データとして取っておく
            averageTmp = cell(1, conditionsLength);
            maxTmp = cell(1, conditionsLength);
            minTmp = cell(1, conditionsLength);

            intervalBetweenData = obj.option.intervalBetweenData;
            dataWidth = obj.option.dataWidth;
            stride = obj.option.stride;

            % 複数入力の場合は3次元配列になっている.
            vectorDimension = size(modifiedDataBeforeFormat.multiVectorData{1},2);

            for i = 1:conditionsLength
                %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
                %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
                oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
                datasetAmount = (numel(rawData.capacitanceCell{i})-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
                datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
                datasetAmount = min(datasetAmount,obj.option.lengthLimitInEachCondition);
                capacitance{i} = zeros(datasetAmount, dataWidth, vectorDimension);
                label{i} = categorical(zeros(datasetAmount, 1));

                averageTmp{i} = zeros(datasetAmount,vectorDimension);
                maxTmp{i} = zeros(datasetAmount,vectorDimension);
                minTmp{i} = zeros(datasetAmount,vectorDimension);

                % data_width，strideに合わせて加工
                for k = 1:vectorDimension
                    for j=1:datasetAmount
                        %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
                        %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
                        capacitance{i}(j,1:dataWidth,k)=modifiedDataBeforeFormat.multiVectorData{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence,k);    %(1+(j-1)*stride:(j-1)*stride+dataWidth);
                        averageTmp{i}(j) = mean(capacitance{i}(j,1:dataWidth,k));
                        maxTmp{i}(j,k) = max(capacitance{i}(j,1:dataWidth,k));
                        minTmp{i}(j,k) = min(capacitance{i}(j,1:dataWidth,k));
                        label{i}(j,1)=rawData.labelCell{i};
                    end
                end
            end
            formattedData = FormattedData(obj.option, rawData.date,rawData.conditions,rawData.labels,capacitance, label,averageTmp,maxTmp,minTmp);
        end
    end
    methods(Access=private)
        function [capacitance, label,averageTmp,maxTmp,minTmp,liquidFlowRate, gasFlowRate] = FormatDataCore(obj,rawData)
            arguments
                obj DataFormatter
                rawData RawData
            end
            conditionsLength = length(rawData.conditions);

            % 加工済みデータ用のcell配列を用意する
            capacitance = cell(1, conditionsLength);
            % 教師データYを用意する
            label= cell(1,conditionsLength);
            % dataFormatterOptionによる平均や最大値, 最小値のばらつきを調査したいので, 専用の配列を用意しておく.
            averageTmp = cell(1, conditionsLength);
            maxTmp = cell(1, conditionsLength);
            minTmp = cell(1, conditionsLength);
            % どちらか片方しか使わないということはないと思うため, 液相側のみの分岐としている.
            if(~isempty(rawData.liquidFlowRate))
                liquidFlowRate = cell(1, conditionsLength);
                gasFlowRate = cell(1, conditionsLength);
            else
                liquidFlowRate = rawData.liquidFlowRate;
                gasFlowRate = rawData.gasFlowRate;
            end

            intervalBetweenData = obj.option.intervalBetweenData;
            dataWidth = obj.option.dataWidth;
            stride = obj.option.stride;

            for i = 1:conditionsLength
                %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
                %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
                oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
                datasetAmount = (size(rawData.capacitanceCell{i},1)-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
                datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
                datasetAmount = min(datasetAmount,obj.option.lengthLimitInEachCondition);
                capacitance{i} = zeros(datasetAmount, dataWidth);
                label{i} = categorical(zeros(datasetAmount, 1));

                if(~isempty(rawData.liquidFlowRate))
                    liquidFlowRate{i} = zeros(datasetAmount, 1);
                    gasFlowRate{i} = zeros(datasetAmount, 1);
                end

                averageTmp{i} = zeros(datasetAmount,1);
                maxTmp{i} = zeros(datasetAmount,1);
                minTmp{i} = zeros(datasetAmount,1);

                % data_width，strideに合わせて加工
                if(~isempty(rawData.liquidFlowRate)) % forの中で分岐を回すのは遅い
                    for j=1:datasetAmount
                        %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
                        %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
                        capacitance{i}(j,1:dataWidth)=rawData.capacitanceCell{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);    %(1+(j-1)*stride:(j-1)*stride+dataWidth);
                        averageTmp{i}(j) = mean(capacitance{i}(j,1:dataWidth));
                        maxTmp{i}(j) = max(capacitance{i}(j,1:dataWidth));
                        minTmp{i}(j) = min(capacitance{i}(j,1:dataWidth));
                        label{i}(j,1)=rawData.labelCell{i};
                        liquidFlowRate{i}(j,1) = mean(rawData.liquidFlowRate{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence));
                        gasFlowRate{i}(j,1) = mean(rawData.gasFlowRate{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence));
                    end
                else
                    for j=1:datasetAmount
                        capacitance{i}(j,1:dataWidth)=rawData.capacitanceCell{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);    %(1+(j-1)*stride:(j-1)*stride+dataWidth);
                        averageTmp{i}(j) = mean(capacitance{i}(j,1:dataWidth));
                        maxTmp{i}(j) = max(capacitance{i}(j,1:dataWidth));
                        minTmp{i}(j) = min(capacitance{i}(j,1:dataWidth));
                        label{i}(j,1)=rawData.labelCell{i};
                    end
                end
            end
        end
    end
end

