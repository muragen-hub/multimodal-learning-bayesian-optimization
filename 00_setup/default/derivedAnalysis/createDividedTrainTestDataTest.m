conditions_12= ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50" "L6G1" "L6G25" "L6G50"];
classAmount = length(conditions_12);
stride=1;
intervalBetweenData = 0;
dataWidth=300;

[data_1209, label_1209, ~]  = createFormedData("resources/data/20211209", conditions_12, stride,intervalBetweenData ,dataWidth);
[trainData, trainLabel, testData, testLabel] = createDividedTrainTestData(data_1209, label_1209);
