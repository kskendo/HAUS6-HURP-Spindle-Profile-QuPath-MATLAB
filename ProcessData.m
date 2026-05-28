function DATA = ProcessData(DATA,defaultOptions)
%PROCESSDATA Summary of this function goes here
%   Detailed explanation goes here
%
%   Nicolas Liaudet
%   Bioimaging Core Facility - UNIGE
%   https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
% 
%   CC BY-NC 4.0
%
%   v1.0 03-Jun-2025 NL

d_min = cellfun(@(x) min(x),DATA.distance,'UniformOutput',true);
d_max =  cellfun(@(x) max(x),DATA.distance,'UniformOutput',true);
d_min = min(d_min);
d_max = max(d_max);

pixelSpacing = mean(DATA.pixelSpacing);

d_abs = [d_min:pixelSpacing:d_max]';
d_rel = [-50:0.1:50]';


VarDef = {'absDistance','cell';...
          'absIntensity','cell';...
          'absNormIntensity','cell';...
          
          'relDistance','cell';...
          'relIntensity','cell';...
          'relNormIntensity','cell'};

tmpT = table('Size',[height(DATA) size(VarDef,1)],'VariableTypes',VarDef(:,2),'VariableNames',VarDef(:,1));
for idxD = 1:height(DATA)
    x     = DATA.distance{idxD};
    [~,idx_O] = min(abs(x));
    x_rel = 100*(x-x(idx_O))/(max(x)-min(x));

    v = DATA.intensity{idxD};

    vq_abs = interp1(x,    v, d_abs,'linear',nan);
    vq_rel = interp1(x_rel,v, d_rel,'linear','extrap');

    % clf
    % subplot(2,1,1)
    % plot(x,v,'o')
    % hold on
    % plot(d_abs,vq_abs,'-')
    %
    % subplot(2,1,2)
    % plot(x_rel,v,'o')
    % hold on
    % plot(d_rel,vq_rel,'-')
    % pause(1)

    bkg = DATA.background(idxD);
    
    vq_abs = vq_abs-bkg;
    vq_rel = vq_rel-bkg;

    vq_abs_norm = rescale(vq_abs);
    vq_rel_norm = rescale(vq_rel);

    tmpT.absDistance{idxD}      = d_abs;
    tmpT.absIntensity{idxD}     = vq_abs;
    tmpT.absNormIntensity{idxD} = vq_abs_norm;

    tmpT.relDistance{idxD}      = d_rel;
    tmpT.relIntensity{idxD}     = vq_rel;
    tmpT.relNormIntensity{idxD} = vq_rel_norm;

end


DATA = [DATA tmpT];