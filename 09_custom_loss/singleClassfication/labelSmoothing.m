function func = labelSmoothing(outputLayerName)
arguments
    outputLayerName string
end
%LABELSMOOTHING 正解ラベルの値を1でなく1よりも少しだけ小さな値にすることで、logitが発散するのを抑制する手法。
% cf. https://zenn.dev/bilzard/scraps/d3875d0c5c5e92
% 学習率と連動させてオンライン化するのも面白いかもね. https://qiita.com/T-STAR/items/a3bdcd1ae00150fe1402
function [loss,gradients,state] = labelSmoothingCore(net,trainData,label)
        [predictedLiquid, state] = forward(net,trainData,Outputs=[outputLayerName]);
        %Loss Functionを改造したい時はこの一行を変えてください. ================================
        %predictedLiquid は条件数(12条件とか)*MiniBatchSize(64とか)のdlArrayです. 
        %labelも同じです. どちらもone-hot-表現で出てきます. 
        noise = 0.3; % これ, 色々変えてみてください.  正解クラス以外にどれだけノイズを分配するかです. 
        modifiedTarget = label*(1-noise)+noise/size(label,1);
        lossBeforeMean = -sum((modifiedTarget).*log(predictedLiquid));
        loss = mean(lossBeforeMean); % ミニバッチのため,平均化
        %======================================================================================
        gradients = dlgradient(loss,net.Learnables);
    end
func = @labelSmoothingCore;
end

