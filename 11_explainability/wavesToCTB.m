function dlX = wavesToCTB(vfBatch, prBatch)
%WAVESTOCTB VF波形セル配列とPr波形セル配列を [2 x W x N] の 'CTB' 形式dlarrayに変換する.
%   vfBatch, prBatch: {N x 1} セル配列. 各要素は長さWの数値ベクトル(1行目=VF, 2行目=Pr).
%   deepLearning_wave_multimodalClassification.mlx の学習済みdlnetworkに対して
%   predict(net, dlX, Outputs=["softmax"]) の形でそのまま渡せる.
    arguments
        vfBatch (:,1) cell
        prBatch (:,1) cell
    end

    n = numel(vfBatch);
    w = numel(vfBatch{1});
    X = zeros(2, w, n);
    for i = 1:n
        X(1, :, i) = vfBatch{i}(:)';
        X(2, :, i) = prBatch{i}(:)';
    end
    dlX = dlarray(X, 'CTB');
end
