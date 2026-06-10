function [data, label] = createFormedDataFromTimeTable(conditions,CellArrayOfTimeTabledDataCell,stride, intervalBetweenData,dataWidth)
%　TimeTabledDataCell: TImeTable形式で保存されたデータのセル配列.
%  TODO: class化, conditionsのちゃんとした扱いが関数じゃ無理.

    %テーブルに値は格納したので解放する
    clear value average min max
    
    conditionsLength = length(conditions);
    % 加工済みデータ用のcell配列を用意する
    data = cell(1, conditionsLength);
    % 教師データYを用意する
    label= cell(1,conditionsLength);

    %フィルターの影響を取り除く. 一番最初の10点と最後の10点を抜く.
    for i = 1:conditionsLength
        CellArrayOfTimeTabledDataCell{i} = lag(CellArrayOfTimeTabledDataCell{i},-10);
        CellArrayOfTimeTabledDataCell{i} = CellArrayOfTimeTabledDataCell{i}(1:end-20,:); %シフトしたことで10点NANになっているため
    end
    
    for i = 1:conditionsLength
        %データの実質的な一つの長さ. 学習用データを作る際に, 重なり条件を検証するためにデータ間に間隔(interval)を開ける.
        %strideはデータ間ではなく, データ列間のずらしであることに注意(株価予測で1時間ずつずらして一定時間のデータをとってきて学習用データを作るように.)
        oneDataSequence = intervalBetweenData*(dataWidth-1)+dataWidth;
        datasetAmount = (numel(CellArrayOfTimeTabledDataCell{i})-(oneDataSequence)) / stride+1;%データセットとして連続する元の生データからstrideずつずらしながらdataWidth分だけ取り出して作る時いくつ作成できるか. (長い列があって, そこから, 作成順に縦列に取った時, 階段上になるようにデータセットが作られる) matlabのforは整数型でなくとも切り捨てて回せる
        datasetAmount = int16(fix(datasetAmount)); %strideを1でない数にした場合で, 上方向に丸められてしまった場合に, indexがオーバーしているエラーを吐く.
        data{i} = zeros(datasetAmount, dataWidth);
        label{i} = string(zeros(datasetAmount, 1));
        
         % data_width，strideに合わせて加工
        for j=1:datasetAmount
         %データを特に抜かすことなく取るならintervalBetweenDataには0と入ることが期待されるが,
         %matlabの文法上(1:0:8)などは空の配列が返されてしまうため, ここには+1を入れて調整する.
        data{i}(j,1:dataWidth)=CellArrayOfTimeTabledDataCell{i}.capa(1+(j-1)*stride:intervalBetweenData+1:(j-1)*stride+oneDataSequence);                      %(1+(j-1)*stride:(j-1)*stride+dataWidth);
        label{i}(j,1)=conditions(i);
        end
    label{i}=categorical(label{i});%categoricalにしてメモリ節約
    end
end
    

