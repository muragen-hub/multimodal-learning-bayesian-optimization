function func = crossEntropyLoss(outputLayerName)
%CROSSENTHOROPY クロスエントロピー誤差
arguments
    outputLayerName string
end
function [loss,gradients,state] = crossEntropyCore(net,trainData,label)
        [predictedLiquid, state] = forward(net,trainData,Outputs=[outputLayerName]);
        %Loss Functionを改造したい時はこの一行を変えてください. ================================
        %predictedLiquid は条件数(12条件とか)*MiniBatchSize(64とか)のdlArrayです. 
        %labelも同じです. どちらもone-hot-表現で出てきます. 
        loss = crossentropy(predictedLiquid,label);
        %======================================================================================
        gradients = dlgradient(loss,net.Learnables);
    end
func = @crossEntropyCore;
end