classdef ResultDisplayer
    %HEATMAPDISPLAYER ヒートマップ生成を担当するクラス

    properties (SetAccess = immutable)
        result TrainResult
        option TrainOption
    end

    methods (Access = public)
        function obj = ResultDisplayer(result,option)
            arguments
                result TrainResult
                option TrainOption
            end
            obj.result = result;
            obj.option = option;
        end

        function [] = displayResult(obj,folderName)
            arguments
                obj ResultDisplayer
                folderName string
            end

            dirName = append(PictureSavePath.path,folderName);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end

            obj.displayFlowToLabel(dirName);
            obj.displayHeatMap(dirName);
            obj.displayNetGraph(dirName);
        end
    end

    methods (Access = private)
        function [] = displayFlowToLabel(obj,dirName)
            %流量設定条件ごとにどのようにラベルが推移するかを見る.
            arguments
                obj ResultDisplayer
                dirName string
            end
            figure
            plot(obj.result.predictedLabel, '-')
            hold on
            plot(obj.result.testLabel)
            hold off

            ylabel("Flow State")
            title("Predicted Flow State")
            legend(["Predicted" "Test Data"])
            saveas(gcf, append( dirName , "Predicted Flow State.fig"))
        end

        function [] = displayHeatMap(obj,dirName)
            %ヒートマップの表示_個数表示
            arguments
                obj ResultDisplayer
                dirName string
            end
            labels = unique(obj.result.label);
            figure
            [cmat,labelNames]=confusionmat(obj.result.testLabel,obj.result.predictedLabel,'Order', categorical(labels));

            h= heatmap(labelNames,labelNames,cmat); 
            h.YDisplayData = categorical(flip(labels));%右肩上がりの方が, 表現したい(うまく判別できているということ)ことを直観的に表現できるはずなのでflip
            xlabel('Predicted Class');
            ylabel('True Class');
            title('Confusion Matrix');
            saveas(gcf, append( dirName , "Confusion Matrix.fig"))

            %横一列上の個数　正確なクラス一つに注目にした時にそれが100%のうちどれだけ分配されたかを調べたい.
            testDataAmount = transpose(sum(cmat,2));

            figure
            cmat_per=cmat./testDataAmount*100;

            h = heatmap(labelNames,labelNames,cmat_per); 
            h.YDisplayData = categorical(flip(labels));
            xlabel('Predicted Class');
            ylabel('True Class');
            title('Confusion Matrix (%)');
            saveas(gcf,append( dirName , "Confusion Matrix(%).fig"))
        end

        

        function [] = displayNetGraph(obj, dirName)
            arguments
                obj ResultDisplayer
                dirName string
            end
            lgraph = layerGraph(obj.result.net{1}.Layers); %グラフ構成は同じはずなので繰り返し計算したもののうち最初のものを使う.
            figure
            plot(lgraph)
            saveas(gcf, append( dirName , "Layer Map.fig"))
        end
    end
end

