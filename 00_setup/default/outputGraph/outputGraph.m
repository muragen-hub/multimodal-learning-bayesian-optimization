function outputGraph(conditions, prediction, testLabel, folderName)
%結果の画像をfig形式で保存する関数. 
%condition: ヒートマップに表示する順番の流量条件
%prediction: モデルから予測されたもの 
%testLabel: 元々の正解ラベル
%folderName: 画像専用のpicturesフォルダの中での保存先のフォルダー, 最後の/を忘れないで.(面倒なので引数の検証とか省いてます.)
    dirName = append("pictures/",folderName);
    if not(exist( dirName ,'dir'))
        mkdir( dirName )
    end
   
    figure
    plot(prediction, '-')
    hold on
    plot(testLabel)
    hold off
    
    ylabel("Flow State")
    title("Predicted Flow State")
    legend(["Predicted" "Test Data"])
    saveas(gcf, append( dirName , "Predicted Flow State.fig"))
   
    figure
    [cmat,classNames]=confusionmat(testLabel,prediction,'Order', categorical(conditions));
    heatmap(classNames,classNames,cmat);
    xlabel('Predicted Class');
    ylabel('True Class');
    title('Confusion Matrix');
    saveas(gcf, append( dirName , "Confusion Matrix.fig"))
    
    %横一列上の個数　正確なクラス一つに注目にした時にそれが100%のうちどれだけ分配されたかを調べたい.
    testDataAmount = transpose(sum(cmat,2));
    
    
    figure
    cmat_per=cmat./testDataAmount*100;
    heatmap(classNames,classNames,cmat_per);
    xlabel('Predicted Class');
    ylabel('True Class');
    title('Confusion Matrix (%)');
    saveas(gcf,append( dirName , "Confusion Matrix(%).fig"))
    
    %学習推移の保存
    trainPlot = findall(groot, 'Tag', 'NNET_CNN_TRAININGPLOT_FIGURE');
    %matlab 2021bだとタグの名前が変化している.
    if isempty(trainPlot)
        trainPlot = findall(groot, 'Tag', 'NNET_CNN_TRAININGPLOT_UIFIGURE');
        savefig(trainPlot, append(dirName, "trainPlot.fig"))
    else
        saveas(trainPlot, append( dirName , "trainPlot.png"));
    end
end