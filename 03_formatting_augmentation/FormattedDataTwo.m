classdef FormattedDataTwo
    properties
        option DataFormatterOption
        date string
        condition (1,:) string
        label (1,:) string
        capacitanceCell (:,:) cell
        differentialPressureCell (:,:) cell  % 追加
        flowRegimeCell (:,:) cell
        featureCell (:,:) cell
        diffFeatureCell (:,:) cell             % 追加: 差圧特徴量
        machineLearningCell (:,:) cell
        labelCell (1,:) cell
        average (:,:) cell
        max (:,:) cell
        min (:,:) cell
        liquidFlowRateOfEachData (1,:) cell
        gasFlowRateOfEachData (1,:) cell
    end

    methods
        function obj = FormattedDataTwo(option, date, condition, label, ...
                capacitanceCell, differentialPressureCell, flowRegimeCell, ...
                featureCell, diffFeatureCell, machineLearningCell, ...
                labelCell, average, max, min, nameAndVar)

            arguments
                option DataFormatterOption
                date string
                condition (1,:) string
                label (1,:) string
                capacitanceCell (:,:) cell
                differentialPressureCell (:,:) cell
                flowRegimeCell (:,:) cell
                featureCell (:,:) cell
                diffFeatureCell (:,:) cell
                machineLearningCell (:,:) cell
                labelCell (1,:) cell
                average (:,:) cell
                max (:,:) cell
                min (:,:) cell
                nameAndVar.liquidFlowRateOfEachData (1,:) cell = cell.empty();
                nameAndVar.gasFlowRateOfEachData (1,:) cell = cell.empty();
            end

            obj.option = option;
            obj.date = date;
            obj.condition = condition;
            obj.label = label;
            obj.capacitanceCell = capacitanceCell;
            obj.differentialPressureCell = differentialPressureCell;
            obj.flowRegimeCell = flowRegimeCell;
            obj.featureCell = featureCell;
            obj.diffFeatureCell = diffFeatureCell;

            % machineLearningCell に静電容量特徴量と差圧特徴量を縦に連結
            obj.machineLearningCell = cell(1, size(featureCell,2));
            for i = 1:size(featureCell,2)
                obj.machineLearningCell{i} = [featureCell{i}; diffFeatureCell{i}];
            end


            obj.labelCell = labelCell;
            obj.average = average;
            obj.max = max;
            obj.min = min;
            obj.liquidFlowRateOfEachData = nameAndVar.liquidFlowRateOfEachData;
            obj.gasFlowRateOfEachData = nameAndVar.gasFlowRateOfEachData;
        end
    end
end

