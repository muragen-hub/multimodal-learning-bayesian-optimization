classdef TrainOption
    %TRAINOPTION 訓練のオプション

    properties (SetAccess = immutable)
        option
        trainRepeatAmount
    end

    methods(Access = public)
        function obj = TrainOption(option,trainRepeatAmount)
            arguments
                option
                trainRepeatAmount {mustBePositive}
            end
            obj.option = option;
            obj.trainRepeatAmount = trainRepeatAmount;
        end
    end
end

