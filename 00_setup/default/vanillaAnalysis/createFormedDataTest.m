conditions_6_11= ["L6G1"  "L6G5" "L6G10" "L6G15" "L6G20" "L6G25" "L6G30" "L6G35" "L6G40" "L6G45" "L6G50"];
[data, label, representative]  = createFormedData("resources/data/20201030",conditions_6_11, 1,0, 300);


%{
    学習部もラップする必要を感じた時用のガジェット的な
    % 学習用(モデル内の重みの更新に使われる)とテスト用(重みの更新をしても精度がもう上がりきらないかどうかを決めるために使われる)のデータの生成
    [trainStr,trainConditionsIndex ,~] = intersect(sortedCondition, trainConditions);
    [testStr, testConditionsIndex, ~] = intersect(sortedCondition, testConditions);
    disp(['trainData: ', trainStr]);
    disp(['testData', testStr]);
%}