function [data, label, representative] = createFormedData(src, conditions, stride, intervalBetweenData,dataWidth)
    %src, conditionsに入力された実験データから学習用の訓練データとテストデータを作成する. 
    %stride: 取得した実験データを分割して学習させるにあたり分割されたデータの最後と次の分割されたデータの最初のデータ間隔(1個飛ばしはstride=2に相当)
    %intervalBetweenData: データセットを作る際に, あるデータと次のデータの間で飛ばすデータの個数. 意図的に取得Hzを落とすために用いる.
    %dataWidth: 取得した実験データを分割して学習させるにあたり分割されたデータの個数
    
    %パスの作成. data以下に適切に実験データが配置されていることを確認. (gitignoreによりcloneしてきたままではdata以下には何も入っていない)
    conditionsLength = length(conditions);
    sources = append(src,"/", conditions,"/ALLDATA.csv");
    
    rawdata_time = cell(1, conditionsLength);
    rawdata_capa = cell(1, conditionsLength);
    %データの形式として, ALLDATAの１列目が時間で２列目が静電容量
    for i = 1:conditionsLength
        tmp= readmatrix(sources(i));
        rawdata_time{i} = tmp(51: end,1); %最初の数プロっトはCメータの関係上うまく取れていない可能性があるので除去. とりあえず50プロットほど除去しておく.
        rawdata_capa{i} = tmp(51: end,2);
    end
    
    min = transpose(cellfun(@min, rawdata_capa));
    idx = transpose(min<0);
    for i =1:conditionsLength
        if idx(i) == 1
            rawdata_capa{i} = rmoutliers(rawdata_capa{i}, 'ThresholdFactor',10); % エラーデータ(外れ値)を削除. これ本当に10で良いのか.
            rawdata_time{i} = rmoutliers(rawdata_time{i},'ThresholdFactor',10); 
        end
    end
    
    %代表値の取り出し
    timeValue = transpose(cellfun(@numel,rawdata_time));
    capaValue = transpose(cellfun(@numel,rawdata_capa));
    average = transpose(cellfun(@mean, rawdata_capa));
    min = transpose(cellfun(@min, rawdata_capa));
    max = transpose(cellfun(@max, rawdata_capa));
    %見やすくするため、テーブル配列を作成する
    condition = transpose(conditions); 
    representative = table(condition, timeValue, capaValue,  max, min, average);
    %テーブルに値は格納したので解放する
    clear timeValue capaValue average min max
    
    % 加工済みデータ用のcell配列を用意する
    data = cell(1, conditionsLength);
    % 教師データYを用意する
    label= cell(1,conditionsLength);
    
    for i = 1:conditionsLength
        %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
        %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
        oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
        datasetAmount = (numel(rawdata_capa{i})-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
        datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
        data{i} = zeros(datasetAmount, dataWidth);
        label{i} = string(zeros(datasetAmount, 1));
        
         % data_width，strideに合わせて加工
        for j=1:datasetAmount
         %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
         %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
        data{i}(j,1:dataWidth)=rawdata_capa{i}(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);                      %(1+(j-1)*stride:(j-1)*stride+dataWidth);
        label{i}(j,1)=conditions(i);
        end
    label{i}=categorical(label{i});%categoricalにしてメモリ節約
    end
end
    