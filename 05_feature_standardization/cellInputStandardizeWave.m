function processedData = cellInputStandardizeWave(inputData, dataWidthOverride)
arguments
    inputData (:, 1) cell
    dataWidthOverride (1, 1) double
end
% -------------------------------------------------------------
% (1) すべてのセルを [W × C] の2次元形状に統一する
% -------------------------------------------------------------
normalizedCell = cell(size(inputData));
for i = 1:numel(inputData)
    X = inputData{i};
    if ndims(X) == 3
        X = squeeze(X); % [1 × W × C] でも [N × W × C] でも 2Dになる
    end
    normalizedCell{i} = X; % [W × C]
end
% -------------------------------------------------------------
% (2) [W x C] → [C x W]
% -------------------------------------------------------------
inputPermutedCell = cellfun(@(x) x.', normalizedCell, 'UniformOutput', false);
inputSize = size(inputPermutedCell{1}, 1); % C
inputDataAmount = numel(inputPermutedCell);
deployedData = cell2mat(inputPermutedCell);
deployedDataAmount = size(deployedData, 1);
dataWidth = dataWidthOverride;
tempStandardizedData = zeros(deployedDataAmount, dataWidth);
% -------------------------------------------------------------
% (3) チャンネルごとに標準化 (ここで次元エラーが発生)
% -------------------------------------------------------------
for ch = 1:inputSize
    idx = ch:inputSize:deployedDataAmount;
    mu = mean(deployedData(idx,:), 'all');
    sig = std(deployedData(idx,:), 0, 'all');
    if sig < eps
        sig = 1;
    end
    tempStandardizedData(idx,:) = (deployedData(idx,:) - mu) ./ sig; % ★ エラー発生箇所
end
% -------------------------------------------------------------
% (4) [N × W × C] に戻す
% -------------------------------------------------------------
standardizedDataMatrix = zeros(inputDataAmount, dataWidth, inputSize);
for i = 1:inputSize
    idx = i:inputSize:deployedDataAmount;
    standardizedDataMatrix(:,:,i) = tempStandardizedData(idx,:);
end
% -------------------------------------------------------------
% (5) 最終セルに戻す
% -------------------
% -------------------------------------------------------------
processedData = cell(inputDataAmount, 1);
for i = 1:inputDataAmount
    processedData{i} = squeeze(standardizedDataMatrix(i, :, :));  % [W × C]
end
end