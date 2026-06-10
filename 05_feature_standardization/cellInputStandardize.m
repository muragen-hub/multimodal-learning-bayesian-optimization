function [processedTrain, processedTest] = standardize(trainData, testData)
%STANDARDIZE 訓練前の標準化を行う関数
% 時系列標準化 (ベクトル標準化) を適用する。
% 平均が0、分散が1になるようにデータを標準化する。

arguments
   trainData (:, :) cell
   testData (:, :) cell
end

%======================================================================
% 訓練データ 標準化
%======================================================================
trainCapacitanceCell = trainData;
inputSize = size(trainCapacitanceCell{1}, 1); % チャンネル数 C (例: VFのみなら 1, VF/Prなら 2)
dataWidth = size(trainCapacitanceCell{1}, 2); % データ幅 W (例: 400)
trainDataAmount = size(trainCapacitanceCell, 1);
deployedTrainData = cell2mat(trainCapacitanceCell); % [N_total x W] の行列
deployedTrainDataAmount = size(deployedTrainData, 1); 
standardizedTrainData = zeros(trainDataAmount, dataWidth, inputSize);

% muとsigを保持するための配列 (サイズは [dataWidth x inputSize] = [400 x C])
muArray = zeros(dataWidth, inputSize); 
sigArray = zeros(dataWidth, inputSize);

for featuresNum = 1:inputSize
    idx = featuresNum:inputSize:deployedTrainDataAmount;  
    
    % 時系列標準化: 1 を指定し、列方向 (時間軸) の平均/標準偏差を計算
    % mu と sig は [1 x dataWidth] の行ベクトルになる
    mu = mean(deployedTrainData(idx, :), 1); 
    sig = std(deployedTrainData(idx, :), 0, 1);
    
    % sigが非常に小さい場合のエラー回避
    sig(sig < eps) = 1;

    % 標準化実行: [N' x W] - [1 x W] が MATLAB のブロードキャストで正しく動作する
    standardizedTrainData(:,:,featuresNum) = (deployedTrainData(idx,:) - mu) ./ sig;
    
    % muとsigを転置して保持 (後のテストデータでの使用のため [W x 1] に)
    muArray(:, featuresNum) = mu';
    sigArray(:, featuresNum) = sig';
end

clear deployedTrainData;

% 訓練後のデータ形式への変換 (元のセルの形式に戻す)
% [N x W x C] -> num2cell([W x C]) -> {N x [W x C]}
standardizedTrainData = num2cell(standardizedTrainData, [2 3]);

% {N x [W x C]} -> cellfun(@(x) permute(x,[3,2,1])) ->