classdef TrainTestData
    %TRAINTESTDATA 訓練もしくはテストデータクラス

    properties (SetAccess = immutable)
        data
        label
        conditionStrings
        labelStrings
        minimumLength
    end

    methods (Access = public)
        function obj = TrainTestData(data, label,minimumLength,conditionStrings,labelStrings)
            arguments
                data (:,:) cell
                label (:,1) categorical
                minimumLength {mustBeNumeric}
                conditionStrings (1,:) string
                labelStrings (1,:) string
            end
            obj.data = data;
            obj.label = label;
            obj.minimumLength = minimumLength;
            obj.conditionStrings = conditionStrings;
            obj.labelStrings = labelStrings;
        end

        function [] = viewWaveFromCondition(obj, saveFolderName,dataColumnValue)
            arguments
                obj TrainTestData
                saveFolderName string
                dataColumnValue {mustBeNumeric} %将来的に, trainTestData内の列は増える可能性があるのでこれで列をしていできるようにしておく.
            end
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end

            plottingMat = cell2mat(obj.data(:,dataColumnValue));
            plottingMat = reshape(transpose(plottingMat),[],1);
            dataWidth = length(obj.data{1});
            figure
            hold on
            for i = 1:length(obj.conditionStrings)
                plot((i-1)*obj.minimumLength*dataWidth+1:i*obj.minimumLength*dataWidth,plottingMat((i-1)*obj.minimumLength*dataWidth+1:i*obj.minimumLength*dataWidth));
            end
            hold off

            legend(obj.conditionStrings,'location','northeastoutside');
            title("学習前のデータ",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"TrainTestDataFromCondition.fig"));
        end

        function [] = viewWaveFromLabel(obj, saveFolderName,dataColumnValue)
            saveDirName = append( PictureSavePath.path,saveFolderName,"/");
            if not(exist( saveDirName ,'dir'))
                mkdir( saveDirName )
            end

            uniquelabel = unique(obj.labelStrings);
            beforeLastIndex = 0;
            dataWidth = length(obj.data{1});
            figure
            hold on
            for i = 1:length(uniquelabel)
                idx = uniquelabel(i) == obj.label;
                idxLength = length(nonzeros(idx));
                plottingMat = obj.data(:,dataColumnValue);
                plottingMat = cell2mat(plottingMat(idx));
                plottingMat = reshape(transpose(plottingMat),[],1);
                plot(beforeLastIndex+1:beforeLastIndex+idxLength*dataWidth, plottingMat);
                beforeLastIndex = beforeLastIndex + idxLength*dataWidth;
            end
            hold off

            legend(unique(obj.labelStrings),'location','northeastoutside');
            title("学習前のデータ",'Units', 'normalized', 'Position', [0.5, -0.135, 0]);
            saveas(gcf, append(saveDirName,"TrainTestDataFromLabel.fig"));
        end
    end
end

