

clear;
close all hidden;
conditions_12= ["L1.5G1" "L1.5G25" "L1.5G50" "L3G1" "L3G25" "L3G50" "L4.5G1" "L4.5G25" "L4.5G50" "L6G1" "L6G25" "L6G50"];
liquidConditions = ["L1.5" "L3" "L4.5" "L6"]; 
stride = 1;
intervalBetweenData = 0;
dataWidth = 300;
filterThreshold = 40;
measuredFrequency = 80;

[cellOfTimeTables_1209,~]= createCalibratedConstFreqTimeTable("resources/data/20211209",conditions_12,liquidConditions,measuredFrequency);
cellOfFilterdTimeTable_1209 = lowPassFilterWrapper(cellOfTimeTables_1209,filterThreshold);
[data_1209, label_1209]  = createFormedDataFromTimeTable(conditions_12, cellOfFilterdTimeTable_1209,stride ,intervalBetweenData,dataWidth);

outputCalibratedInitialWidthWave(conditions_12, data_1209,append("2021Result/1209Wave/",string(filterThreshold),"threshold/"), append(string(filterThreshold),"HzFilter"))
outputFFTGraph(measuredFrequency, conditions_12,cellOfFilterdTimeTable_1209,append("2021Result/1209Wave/FFT/",string(filterThreshold),"threshold/"),append(string(filterThreshold),"HzFilter"));