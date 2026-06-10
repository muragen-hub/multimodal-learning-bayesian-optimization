function func = singleInputCrossEntropyLoss(outputLayerName)
%SINGLEINPUTCROSSENTROPYLOSS 
% MiniBatchQueueがデータ処理と dlarray 変換を完了していることを前提とし、
% ネットワークへの入力と損失計算のみを行います。

    arguments
            outputLayerName string
    end

    % 1. dlfevalが呼び出す内部関数へのハンドルを割り当て
    func = @crossEntropyCore;

    % crossEntropyCore は dlfeval から渡される3つの引数のみを受け取ります。
    function [loss,gradients,state] = crossEntropyCore(net,trainData,label)
            
            % -----------------------------------------------------------------
            % I. データ処理 (MiniBatchQueue がすべて処理済みと仮定)
            % -----------------------------------------------------------------
            
            % trainData は MiniBatchQueue によって dlarray (CTB形式: 1 x 400 x B)
            % として渡されるため、そのままネットワーク入力として使用します。
            inputToNet = trainData; 
            
            % -----------------------------------------------------------------
            % II. フォワードパスと損失計算
            % -----------------------------------------------------------------

            % outputLayerName はスコープを通じてアクセスされます
            [predictedLiquid, state] = forward(net, inputToNet, Outputs=[outputLayerName]); 
            
            % 損失計算
            loss = crossentropy(predictedLiquid, label);
            
            % 勾配計算
            gradients = dlgradient(loss, net.Learnables);
            
    end
end