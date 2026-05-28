function [DATA_long,defaultOptions] = LoadData(defaultOptions)
%LOADDATA Summary of this function goes here
%   Detailed explanation goes here
%
%   Nicolas Liaudet
%   Bioimaging Core Facility - UNIGE
%   https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
% 
%   CC BY-NC 4.0
%
%   v1.0 03-Jun-2025 NL
%%
DATA = [];

lastFolderPath = uigetdir(defaultOptions.lastFolderPath,'Where are your measurements?');

if ~isnumeric(lastFolderPath)
    defaultOptions.lastFolderPath = lastFolderPath;
    save(fullfile('mfiles','defaultOptions.mat'),'defaultOptions')
else    
    return
end

fnames = dir(fullfile(lastFolderPath,'*.csv'));
fileNames = {fnames.name}';
filePaths = fullfile({fnames.folder}',fileNames);

% tmp = regexp(fileNames,'(?<condition>si\w*)_(?<sample>\d+_\d+_\d+)\w*_(?<thicknessLbl>(big|small))','names');

tmp = regexp(fileNames,'(?<condition>si(?:CTRL|HURP|Haus6|HAUS6))_(?<sample>.*?)_(?:R\dD_D\dD_)?(?<thicknessLbl>big|small)','names');

DATA = struct2table([tmp{:}]);
DATA.fileNames = fileNames;
DATA.filePaths = filePaths;

DATA.condition = categorical(DATA.condition);
DATA.condition = mergecats(DATA.condition,'siHaus6','siHAUS6');

DATA.thicknessLbl = categorical(DATA.thicknessLbl);

T = cell(height(DATA),1);
for idxD = 1:height(DATA)
    T{idxD} = readtable(DATA.filePaths{idxD},'VariableNamingRule','preserve');
end


signal1Lbl = unique(cellfun(@(x) x.Properties.VariableNames{2},T,'UniformOutput',false));
signal2Lbl = unique(cellfun(@(x) x.Properties.VariableNames{3},T,'UniformOutput',false));
signal3Lbl = unique(cellfun(@(x) x.Properties.VariableNames{4},T,'UniformOutput',false));

if length(signal1Lbl)~=1 | length(signal2Lbl)~=1 | length(signal3Lbl)~=1
    DATA = [];
    return
end
MarkerNames = [signal1Lbl signal2Lbl signal3Lbl];


DATA.('Measured Distance')  = cellfun(@(x) x.('Distance (µm)'),T,'UniformOutput',false);

for idxC= 1:length(MarkerNames)
    DATA.(['Measured ' MarkerNames{idxC}]) = cellfun(@(x) x.(MarkerNames{idxC}),T,'UniformOutput',false);
    DATA.(['Measured Background ' MarkerNames{idxC}]) = cellfun(@(x) unique(x.(['Background ' MarkerNames{idxC}])),T,'UniformOutput',true);
end
DATA.('Measured Thickness')        = cellfun(@(x) unique(x.('Thickness (µm)')),T,'UniformOutput',true);
DATA.('Measured Distance pixel spacing')    = cellfun(@(x) unique(x.('Pixel spacing (µm)')),T,'UniformOutput',true);
DATA.('Measured Image resolution') = cellfun(@(x) unique(x.('Image resolution (µm)')),T,'UniformOutput',true);
  

VarDef = {'condition','categorical';...
          'sample','cell';...
          'thicknessLbl','categorical';...
          'marker','cell';...

          'distance','cell';...
          'intensity','cell';...
          'background','double';...
          
          'pixelSpacing','double';...
          'thicknessValue','double';...
          'imageResolution','double';...
          
          'fileName','cell';...
          'filePath','cell'};

DATA_long = cell(height(DATA)*length(MarkerNames),1);
idx = 1;
for idxD = 1:height(DATA)
    Tsub = T{idxD};

    newRow = table('Size',[1 size(VarDef,1)],'VariableTypes',VarDef(:,2),'VariableNames',VarDef(:,1));
    for idxC = 1:length(MarkerNames)    

        newRow.condition       = DATA.condition(idxD);        
        newRow.sample          = DATA.sample(idxD);
        newRow.thicknessLbl    = DATA.thicknessLbl(idxD);
        newRow.marker          = MarkerNames(idxC);
        
        newRow.distance        = {Tsub.('Distance (µm)')};
        newRow.intensity       = {Tsub.(MarkerNames{idxC})};
        newRow.background      = unique(Tsub.(['Background ', MarkerNames{idxC}]));
       
        newRow.pixelSpacing    = unique(Tsub.('Pixel spacing (µm)'));
        newRow.thicknessValue  = unique(Tsub.('Thickness (µm)'));
        newRow.imageResolution = unique(Tsub.('Image resolution (µm)'));
        
        newRow.fileName        = DATA.fileNames(idxD);        
        newRow.filePath        = DATA.filePaths(idxD);
      

        DATA_long{idx}= newRow;
        idx = idx+1;
    end
end

DATA_long = cat(1,DATA_long{:});
DATA_long.sample = categorical(DATA_long.sample);
DATA_long.marker = categorical(DATA_long.marker);


end

