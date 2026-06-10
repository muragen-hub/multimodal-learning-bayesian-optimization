function processedData = correctWithCapacitanceBase(rawData, rawAllDataBeforeFormat)
%CORRECTWITHCAPACITANCEBASE ボイド率計の樹脂の特性なのか, 実験を進めるにつれて基準値が変化してしまうことへの対応のためのコード
% 用いる基準値のデータ名は,気相100, 液相100でそれぞれ　G30_before_L1.5G1, L100_before_L1.5G1 とする. (例. 条件の部分は適宜変更する)
% 基準値の測定をG30L0で30秒, G0L100で30秒ずつ, 本測定の前に行い, その値を用いて上下を決定し, それに合うように, 次の処理を行う
%1. G30L0の測定値の平均を求め, その値を全データから引く(下限値を固定する. )
%2. G30L0とG0L100のそれぞれの平均値の差分を求め, その差分がに掛けると1*10^(-13)になるような数Xを求める.
%3. 求めた数Xを全データに掛ける.
% [MEMO] 気相条件の数は全液相条件に対して等しいものと仮定する.
arguments
    rawData RawData
    rawAllDataBeforeFormat RawAllDataBeforeFormat
end
if ~rawData.isNeedCorrect
    processedData = rawData; % もし補正がいらないとあればそのまま返す.
    return;
end

rawDataCreator = RawDataCreator();

conditionsLength = length(rawData.conditions);
processedData_capa = cell(1, conditionsLength);

gasCalibrationRawdata_capa = cell(1, 1);
liquidCalibrationRawdata_capa = cell(1, 1);

for i = 1:conditionsLength
    if i==1 || rawData.correctConditions(i-1) ~= rawData.correctConditions(i)
        % 気相100%
        gasCalibrationSource = append(DataPath.path,rawData.date,"/",CorrectConditions.LiquidPureFlowPrefix, rawData.correctConditions(i),"/ALLDATA.csv");

        % 💡 修正箇所: ファイル存在チェック
         if exist(gasCalibrationSource, 'file') ~= 2
                warning('気相100%%の基準データ (%s) が見つかりません。この条件の静電容量補正をスキップします。', gasCalibrationSource);
                
                % 補正をスキップするための値を設定: (data - 0) * 1 となる
                gasAverageValue = 0; 
                liquidAverageValue = 1; 
                calibrationDividingNum = 1; 
                
                % このスキップ処理が発動した場合、液相100%の読み込みもスキップ
         else
          % ファイルが見つかった場合の通常処理
        tmp= readmatrix(gasCalibrationSource);
        gasCalibrationRawdata_capa{1} = tmp(1: end,2); % [MEMO] 平均のみを取りたいので持ってくるのは静電容量の方だけでよい.
        gasAverageValue =  mean(rmoutliers(gasCalibrationRawdata_capa{1}, 'ThresholdFactor',10));
         end

        % 液相100%
        % [MEMO] こちらは液100%の場合の平均を持ってくる.
        liquidCalibrationSource = append(DataPath.path,rawData.date, "/",rawData.correctConditions(i) ,CorrectConditions.gasPreFlowSuffix,"/ALLDATA.csv");
        if exist(liquidCalibrationSource, 'file') ~= 2
                % 液相100%の基準データが見つからない場合
                warning('液相100%%の基準データ (%s) が見つかりません。この条件の静電容量補正をスキップします。', liquidCalibrationSource);
                
                % 補正をスキップするための値を設定: (data - 0) * 1 となる
                gasAverageValue = 0;
                liquidAverageValue = 1;
                calibrationDividingNum = 1;
                
        else
        tmp= readmatrix(liquidCalibrationSource);
        liquidCalibrationRawdata_capa{1} = tmp(1: end,2);
        %liquidAverageValue = mean(liquidCalibrationRawdata_capa{1});
        liquidAverageValue = mean(rmoutliers(liquidCalibrationRawdata_capa{1}, 'ThresholdFactor',10));

        gasLiquidAverageDiff = liquidAverageValue - gasAverageValue;
        calibrationDividingNum = 1/gasLiquidAverageDiff;%気相100と液相100の間の距離を1に揃える. (前は10^(-13)に揃えていたが後で標準化するため1以外に揃える意味がない)
        end
    end

    processedData_capa{i} = (rawData.capacitanceCell{i} - gasAverageValue)*calibrationDividingNum;
end
processedData = rawDataCreator.createFromArray(rawData.date,rawData.measuredFreq,rawData.conditions,rawData.labels,rawData.isNeedCorrect,rawData.correctConditions,rawData.timeCell,rawData.timeCell_second,processedData_capa,rawData.labelCell,rawData.liquidFlowRate,rawData.gasFlowRate);
end

