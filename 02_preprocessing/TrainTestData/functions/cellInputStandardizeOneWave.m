function processedData = cellInputStandardizeOneWave(inputData, dataWidthOverride)
arguments
    inputData (:, 1) cell
    dataWidthOverride (1, 1) double
end

% -------------------------------------------------------------
% (1) すべてのセルを [W × 1] の2次元形状に統一する
% -------------------------------------------------------------
normalizedCell = cell(size(inputData));
for i = 1:numel(inputData)
    X = inputData{i};
    % N x W x C (C=1) から W x 1 にする
    if ndims(X) >= 2
        X = squeeze(X); 
    end
    normalizedCell{i} = X; % [W × 1]
end

% -------------------------------------------------------------
% (2) データ展開 (W=400 を保持するよう手動で結合)
% -------------------------------------------------------------
inputSize = 1; % C=1 に固定
dataWidth = dataWidthOverride; % W=400
inputDataAmount = numel(normalizedCell);
deployedDataAmount = inputDataAmount; % サンプル数

% deployedDataを [N_total x W] サイズで確保
deployedData = zeros(deployedDataAmount, dataWidth); 

% データの再配置と結合 ([W x 1] のデータを [1 x W] に転置して格納)
for i_sample = 1:inputDataAmount 
    current_data_W1 = normalizedCell{i_sample}; % [W x 1] (400 x 1)
    
    % [W x 1] を [1 x W] の行ベクトルに転置
    current_data_W = current_data_W1'; % [1 x W] (1 x 400)
    
    % deployedDataに格納
    deployedData(i_sample, :) = current_data_W;
end
% 最終的な deployedData は [N_total x W] サイズ (30643 x 400) になります。

tempStandardizedData = zeros(deployedDataAmount, dataWidth);

% -------------------------------------------------------------
% (3) 標準化 (スカラー標準化 + エラー回避)
% -------------------------------------------------------------
% 単一波形なのでループは不要、または ch=1 のみ
% ch = 1:inputSize のループは不要だが、将来的な拡張性を残すため ch=1 で実行
for ch = 1:1 % inputSize=1
    idx = 1:deployedDataAmount; % 全行を選択 (ch:inputSize:deployedDataAmount の ch=1, inputSize=1 の場合)
    
    current_data = deployedData(idx,:);
    N_prime = size(current_data, 1);
    
    % スカラー標準化 ('all')
    mu = mean(current_data, 'all'); % 平均 (スカラー)
    sig = std(current_data, 0, 'all'); % 標準偏差 (スカラー)
    
    if sig < eps
        sig = 1;
    end
    
    % repmatで手動ブロードキャストし、代入エラーを回避
    mu_rep = repmat(mu, N_prime, dataWidth); 
    sig_rep = repmat(sig, N_prime, dataWidth);

    % 標準化実行
    tempStandardizedData(idx,:) = (current_data - mu_rep) ./ sig_rep;
end

% -------------------------------------------------------------
% (4) [N × W × C] に戻す
% -------------------------------------------------------------
% 単一チャンネルなので [N x W] で保持
standardizedDataMatrix = tempStandardizedData; 

% -------------------------------------------------------------
% (5) 最終セルに戻す
% -------------------------------------------------------------
processedData = cell(inputDataAmount, 1);
for i = 1:inputDataAmount
    % [1 x W] の行を [W x 1] の列に戻す
    processedData{i} = standardizedDataMatrix(i, :)'; 
end
end