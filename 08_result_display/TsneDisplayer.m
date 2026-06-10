classdef TsneDisplayer
    %TSNEDISPLAYER 層のt-sne結果を示すためのクラス
    %   詳細説明をここに記述

    properties(SetAccess = immutable)
        result TrainResult
        test TrainTestData
    end

    methods (Access = public)
        function obj = TsneDisplayer(result,test)
            arguments
                result TrainResult
                test TrainTestData
            end
            obj.result = result;
            obj.test = test;
        end

        function [] = displayTsne(obj,layerName,activationNetNumber,saveFolderName,isDoPCA,dimensionNumAfterPCA)
            arguments
                obj TsneDisplayer
                layerName (:,1) string %層の名前. 層の名前は LayerSetting を見る.(右クリックでクラスへ飛べる)
                activationNetNumber {mustBePositive}
                saveFolderName string
                isDoPCA logical
                dimensionNumAfterPCA {mustBePositive}
            end

            dirName = append(PictureSavePath.path,saveFolderName);
            if not(exist( dirName ,'dir'))
                mkdir( dirName )
            end

            tSneDictatedLayerLength = length(layerName);
            activatedNet = obj.result.net{activationNetNumber};
            for i = 1:tSneDictatedLayerLength
                obj.displayTsneCore(activatedNet,layerName(i),isDoPCA,dimensionNumAfterPCA,dirName);
            end
        end
    end

    methods (Access = private)
        function [] = displayTsneCore(obj,net,layerName,isDoPCA,dimensionNumAfterPCA,dirName)
            arguments
                obj TsneDisplayer
                net
                layerName string
                isDoPCA logical
                dimensionNumAfterPCA {mustBePositive}
                dirName string
            end
            %詳細はこちら https://jp.mathworks.com/help/stats/visualize-high-dimensional-data-using-t-sne.html
            % https://jp.mathworks.com/help/deeplearning/ug/view-network-behavior-using-tsne.html

            Activation = activations(net,obj.test.data,layerName,"OutputAs","rows");
            if isDoPCA
            tsneResult = tsne(Activation,'Algorithm','barneshut','NumPCAComponents',dimensionNumAfterPCA);
            else
            tsneResult = tsne(Activation,'Algorithm','barneshut');
            end
            predictionLabel=classify(net,obj.test.data);

            misclassifiedIndex = predictionLabel ~= obj.test.label; %判別ミスデータのインデックス
            R = maxk(Activation,2,2); % 各行の中で最も大きな2つの値を拾ってくる.
            ambiguity = R(:,2)./R(:,1);
            ambiguityIndex = ambiguity >=0.8; % 判別の曖昧さを拾ってくる. 曖昧さはの基準は, 判別先の最大の割合に対して, その次の判別の先の割合が0.8以上であること.

            markerSize = 20;
            figure;
            hold on;
            gscatter(tsneResult(:,1),tsneResult(:,2),obj.test.label, ...
                [],'.',markerSize);
            title(append(layerName,"層の次元圧縮結果"));
            legend(obj.test.LabelStrings,'Location','northeastoutside');
            l = legend;

            % グラフの上に, 曖昧なresultへのplotを追加
            scatter(tsneResult(ambiguityIndex, 1), tsneResult(ambiguityIndex, 2), markerSize,...
                'black','LineWidth',0.001);
            l.String{end} = 'Ambiguity';

            % グラフの上に, 誤判別のplotの追加
            scatter(tsneResult(misclassifiedIndex, 1), tsneResult(misclassifiedIndex, 2), ...
                markerSize,'k','d','LineWidth',0.001);
            l.String{end} = 'misClasified';
            hold off;
            saveas(gcf, append( dirName , "layerName_" ,"t-sne_result.fig"))
        end
    end
end

