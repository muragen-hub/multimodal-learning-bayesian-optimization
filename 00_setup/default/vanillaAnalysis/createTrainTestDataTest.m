conditions_6_22= ["L6G1"  "L6G5" "L6G10" "L6G15" "L6G20" "L6G25" "L6G30" "L6G35" "L6G40" "L6G45" "L6G50" "L3G1"  "L3G5" "L3G10" "L3G15" "L3G20" "L3G25" "L3G30" "L3G35" "L3G40" "L3G45" "L3G50"];
stride=1;
intervalBetweenData = 0;
dataWidth=300;

[data_6_22_0506, label_6_22_0506, ~]  = createFormedData("resources/data/20210506", conditions_6_22, stride,intervalBetweenData ,dataWidth);
[data_6_22_0514, label_6_22_0514, ~]  = createFormedData("resources/data/20210514", conditions_6_22, stride,intervalBetweenData , dataWidth);

[trainData, trainLabel, testData, testLabel] = createTrainTestData(conditions_6_22, {data_6_22_0514}, {label_6_22_0514},{data_6_22_0506},{label_6_22_0506});