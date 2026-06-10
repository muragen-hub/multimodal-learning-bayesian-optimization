classdef TrainResult
    %TRAINRESULT 学習の結果を保存するクラス
    
    properties (SetAccess = immutable)
        net (1,:) cell
        condition (1,:) string
        label (:,1) categorical
        predictedLabel (:,1) categorical
        testLabel (:,1) categorical 
    end
    
    methods
        function obj = TrainResult(net, condition, label, predictedLabel, testLabel)
            %arguments
            %end
            obj.net = net;
            obj.condition =  condition;
            obj.label = label;
            obj.predictedLabel = predictedLabel;
            obj.testLabel = testLabel;
        end
    end
end

