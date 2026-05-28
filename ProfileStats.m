function statsReport = ProfileStats(G,measLbl,thicknessLbl,markerLbl)
%PROFILESTATS Summary of this function goes here
%   Detailed explanation goes here
%
%   Nicolas Liaudet
%   Bioimaging Core Facility - UNIGE
%   https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
% 
%   CC BY-NC 4.0
%
%   v1.0 10-Jun-2025 NL

% measLbl = 'relIntensity';

if contains(measLbl,'abs')
    distLbl = 'absDistance';
    distance = G.absDistance{1}{1};
elseif contains(measLbl,'rel')
    distLbl = 'relDistance';
    distance = G.relDistance{1}{1};
end
distance =  table(distance);
Gr = G(G.thicknessLbl == thicknessLbl & G.marker == markerLbl,:);

% Create a condition variable matching the row-level repeated observations
condition = cell(height(Gr),1);
for idxG = 1:height(Gr)
    condition{idxG } = repmat(Gr.condition(idxG),[Gr.GroupCount(idxG) 1]);
end
condition = cat(1,condition{:});
condition = table(condition);

% Flatten the nested measurement data
measurement = cat(1,Gr{:,measLbl}{:});
measurement = cat(2,measurement{:})';

% Remove any columns with NaN
idxKillNaN  = any(isnan(measurement),1);
measurement(:,idxKillNaN) = [];
distance(idxKillNaN,:) = [];

% Create measurement table for fitrm
measurement    = array2table(measurement);
measurementLBL = measurement.Properties.VariableNames;

% Combine into repeated measures design table
rma_table = [condition measurement];
rm = fitrm(rma_table,[measurementLBL{1} '-' measurementLBL{end} '~ condition'],'WithinDesign',distance,'WithinModel','separatemeans');

% Compute mean and sem
ms_g = groupsummary(rma_table,'condition',{@(x) mean(x),@(x) std(x)});
c = ms_g{:,1};
n = ms_g{:,2};
idx = contains(ms_g.Properties.VariableNames,'fun1');
m = ms_g{:,idx};
idx = contains(ms_g.Properties.VariableNames,'fun2');
s = ms_g{:,idx};

c = repelem(c,size(m,2));
n = repelem(n,size(m,2));
m = m';
m = m(:);
s = s';
s = s(:);
sem = s./n;
d = repelem({distance.distance},height(ms_g),1);
d = cat(1,d{:});
T = table(c,d,n,m,s,sem);
T.Properties.VariableNames(1:2) = {'Condition','Distance'};




% Run MANOVA to test effect of condition
manova_table = manova(rm);
pval_condition = manova_table.pValue(1);

% Run RANOVA for within-subject effects and interaction
ranova_table = ranova(rm);
idxI = strcmp(ranova_table.Properties.RowNames, 'condition:distance');
idxD = strcmp(ranova_table.Properties.RowNames, '(Intercept):distance');
idxC = strcmp(ranova_table.Properties.RowNames, 'condition');

% Mauchly's test for sphericity
mauchly_table = mauchly(rm);
mauchly_p = mauchly_table.pValue;

% Decide whether to correct based on Mauchly's test
if mauchly_p <= 0.05
   pval_interaction = ranova_table.pValueGG(idxI);
   pval_distance    = ranova_table.pValueGG(idxD); 
   sphericity_text = 'sphericity violated';   
   correction_used = 'Greenhouse-Geisser';
else
   pval_interaction = ranova_table.pValue(idxI);
   pval_distance    = ranova_table.pValueGG(idxD);        
   sphericity_text = 'sphericity assumed';
   correction_used = 'no';
end

% Post-hoc analysis only if interaction is significant
if pval_interaction < 0.05
    posthoc = multcompare(rm, 'condition', 'By', 'distance','ComparisonType','bonferroni');
    posthoc.comparison = strcat(string(posthoc.condition_1), " vs ", string(posthoc.condition_2));
    posthoc.comparison = categorical(posthoc.comparison);
    posthoc_text = 'significant: post-hoc tests performed';

    % Organize posthoc comparisons
    CONDITIONS = unique(condition.condition);
    compairedConditions = nchoosek(CONDITIONS,2);

    group_all = cell(size(compairedConditions,1),1);
    for idxC = 1:size(compairedConditions,1)
        idx = posthoc.condition_1 == compairedConditions(idxC,1) & posthoc.condition_2 == compairedConditions(idxC,2);
        group_all{idxC} = posthoc(idx,:);
    end

    group_all = cat(1,group_all{:});
else
    posthoc = [];
    group_all = [];
    posthoc_text = 'not significant: no post-hoc tests';
end



title_str = sprintf([
    'Repeated Measures ANOVA Results:\n' ...
    'Mauchly''s test p-val = %.3e , %s: %s correction used \n' ...
    'Condition effect (MANOVA) p-val = %.3e, distance effect p-val = %.3e, Condition*Distance interaction p-val = %.3e\n' ...
    'Condition*Distance %s'], ...
    mauchly_p, sphericity_text, correction_used,...
    pval_condition, pval_distance,pval_interaction,...  
    posthoc_text);

statsReport.Tgrouped   = T;
statsReport.rm_tbl     = rm;
statsReport.RANOVA_tbl = ranova_table;
statsReport.MANOVA_tbl = manova_table;
statsReport.PostHoc    = group_all;
statsReport.ouputTxt   = title_str;


end

