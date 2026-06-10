function func = multiCrossEntropyLoss(outputLayerName)
    arguments
            outputLayerName string
    end
   % multiCrossEntropyLoss.m 内の修正箇所
function [loss,gradients,state] = crossEntropyCore(net,trainData,label)
    [predictedLiquid, state] = forward(net,trainData,Outputs=[outputLayerName]);
    
    % ★★★ 診断コードを修正 ★★★
    %disp('--- Predicted Liquid (出力) ---');
    %disp(['サイズ: ' mat2str(size(predictedLiquid))]);
    % disp(['フォーマット: ' predictedLiquid.Format]); 
    
    %disp('--- Label (ターゲット) ---');
    %disp(['サイズ: ' mat2str(size(label))]);
    
    %try
        %disp('フォーマットの取得はスキップ (バージョン互換性のため)');
    %catch ME
        %disp('フォーマットの取得はスキップ (バージョン互換性のため)');
    %end
    
    % ★★★ 診断コード終了 ★★★
    
   % ラベルから Batch Size (B) を取得 (これが最も確実な B の情報源)
    B = size(label, 2); 
    C = size(label, 1);
    
    % ★★★ 最終的な修正: reshape を使用し、次元を [C x B] に強制変換する ★★★
    % predictedLiquidは [C x T] のように見えているが、Batch=B のデータセットの予測値。
    % Time次元を捨てて、正しい [C x B] に変形します。
    
    % predictedLiquidを [C x B] に強制的に変形
    predictedLiquidReshaped = reshape(predictedLiquid, [C, B]); 
    
    %Loss Functionを改造したい時はこの一行を変えてください. ================================
    % ★★★ 修正箇所: DataFormat='CB' を追加 ★★★
    loss = crossentropy(predictedLiquidReshaped, label, 'DataFormat', 'CB'); % ← reshapeされた変数を使用
    %======================================================================================
    
    gradients = dlgradient(loss,net.Learnables);
end
    func = @crossEntropyCore;
end