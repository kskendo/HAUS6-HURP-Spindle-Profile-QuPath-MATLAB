function ShowProfiles(DATA,defaultOptions)
%SHOWPROFILES Summary of this function goes here
%   Detailed explanation goes here
%
%   Nicolas Liaudet
%   Bioimaging Core Facility - UNIGE
%   https://www.unige.ch/medecine/bioimaging/en/bioimaging-core-facility/
% 
%   CC BY-NC 4.0
%
%   v1.0 03-Jun-2025 NL


close all
Meas = {'absDistance','absIntensity','absNormIntensity','relDistance','relIntensity','relNormIntensity'};
%% 

%========================= plot individual traces =========================

varGroups = {'thicknessLbl','marker','condition'};

Colormap = [128, 128, 128;...
255,192,203;...
 102,194,165]/255;
% 
%     252,141,98
%     141,160,203
%     ]/255;


G = groupsummary(DATA,varGroups,@(x) {x},Meas);
G.Properties.VariableNames = erase( cellstr(G.Properties.VariableNames),'fun1_');

PlotProfiles_persample(G,varGroups,Colormap,defaultOptions)

%========================= plot grouped traces =========================
gFun = {@(x) mean(cat(2,x{:})',1,'omitnan'),...
        @(x) std(cat(2,x{:})',1,1,'omitnan'),...
        @(x) sum(~isnan(cat(2,x{:})'),1)};

G_summary = groupsummary(DATA,varGroups,gFun,Meas);
G_summary.Properties.VariableNames = replace( cellstr(G_summary.Properties.VariableNames),'fun1_','mean_');
G_summary.Properties.VariableNames = replace( cellstr(G_summary.Properties.VariableNames),'fun2_','std_');
G_summary.Properties.VariableNames = replace( cellstr(G_summary.Properties.VariableNames),'fun3_','nb_');

idxS  = find(contains(G_summary.Properties.VariableNames,'std_'));
idxNB = find(contains(G_summary.Properties.VariableNames,'nb_'));

VariableNames = replace(G_summary.Properties.VariableNames(contains(G_summary.Properties.VariableNames,'std_')),'std','sem');
%VariableTypes = repmat({'double'},size(VariableNames));

% tmpT = table('Size',[height(G_summary) length(idxS)],'VariableTypes',VariableTypes,'VariableNames',VariableNames);

tmpT = table();
for idx = 1:length(idxS)
    t = table(G_summary{:,idxS(idx)}./sqrt(G_summary{:,idxNB(idx)}));
    t.Properties.VariableNames = VariableNames(idx);
    tmpT = [tmpT,t];
end

G_summary = [G_summary tmpT]; 

PlotProfiles_grouped(G_summary,varGroups,Colormap,defaultOptions)

%========================= Build stats =========================

Isel = {'absIntensity','absNormIntensity','relIntensity','relNormIntensity'};
Tsel = unique(G_summary.thicknessLbl);
Msel = unique(G_summary.marker);


for idxT = 1:length(Tsel)
    for idxM = 1:length(Msel)
        for idxI = 1:length(Isel)
            statsReport = ProfileStats(G,Isel{idxI},char(Tsel(idxT)),char(Msel(idxM)));
            PlotProfiles_stats(G_summary,statsReport,Isel{idxI},char(Tsel(idxT)),char(Msel(idxM)),Colormap,defaultOptions)
        end
    end
end






% %%
% varGroups = {'thicknessLbl','condition','marker'};
% 
% Colormap = [55,126,184;
%             228,26,28            
%             77,175,74
%             ]/255;
% 
% G = groupsummary(DATA,varGroups,@(x) {x},{'absDistance','absIntensity','absNormIntensity','relDistance','relIntensity','relNormIntensity'});
% G.Properties.VariableNames = erase( cellstr(G.Properties.VariableNames),'fun1_');
% 
% PlotProfiles_persample(G,varGroups,Colormap)


end

function PlotProfiles_stats(G_summary,statsReport,Isel,Tsel,Msel,Colormap,defaultOptions)
hfig = figure('Position',[1 41 3264 1228]);
htl  = tiledlayout(hfig,2,1);
ax = gobjects(2,1);
ax(1) = nexttile(htl,1,[1 1]);
ax(2) = nexttile(htl,2,[1 1]);

CONDITIONS = unique(statsReport.Tgrouped.Condition);
for idxC = 1:length(CONDITIONS)
    idxKeep = statsReport.Tgrouped.Condition == CONDITIONS(idxC);
    x     = statsReport.Tgrouped.Distance(idxKeep);
    y_m   = statsReport.Tgrouped.m(idxKeep);
    y_sem = statsReport.Tgrouped.sem(idxKeep);

   
    patch("XData",[x; flipud(x)],...
        "YData",[y_m-y_sem; flipud(y_m+y_sem)],...
        'FaceColor',Colormap(idxC,:),'EdgeColor',Colormap(idxC,:),...
        'FaceAlpha',0.5,'EdgeAlpha',1,...
        'DisplayName',[char(CONDITIONS(idxC)) ' \pm SEM'],...
        'Parent',ax(1,1))
    line(x,y_m,...
        'LineWidth',2,'Color',Colormap(idxC,:),...
        'DisplayName',[char(CONDITIONS(idxC)) ' mean'],...
        'Parent',ax(1,1));    
end
legend(ax(1,1),'Location','Best')
ax(1).Subtitle.String = statsReport.ouputTxt;
if contains(Isel,'rel')
    ax(1).XLabel.String = 'Spindle axis relative position (%)';
    ax(2).XLabel.String = 'Spindle axis relative position (%)';
else
    ax(1).XLabel.String = 'Spindle axis position (\mum)';
    ax(2).XLabel.String = 'Spindle axis position (\mum)';
end

if contains(Isel,'Norm')
    ax(1).YLabel.String = [Msel ' normalized intensity'];
else
    ax(1).YLabel.String = [Msel ' intensity'];
end
ax(1).Box = 'on';
ax(1).XGrid = 'on';
ax(1).YGrid = 'on';

ax(2).Subtitle.String = 'Post-hoc comparisons (Bonferroni corrections)';
ax(2).YLabel.String = 'p-value';
ax(2).Box = 'on';
ax(2).XGrid = 'on';
ax(2).YGrid = 'on';


if ~isempty(statsReport.PostHoc)
    COMPARISON = unique(statsReport.PostHoc.comparison);
    idxColor = nchoosek([1:length(COMPARISON)],2);
    for idxC = 1:length(COMPARISON)
        thiscmap = min([1 1 1;1.1*mean(Colormap(idxColor(idxC,:),:))]);
      
        idxKeep = statsReport.PostHoc.comparison == COMPARISON(idxC);
        line(statsReport.PostHoc.distance(idxKeep),...
            statsReport.PostHoc.pValue(idxKeep),...
            'LineWidth',2,'Color',thiscmap,...
            'DisplayName',char(COMPARISON(idxC)),...
            'Parent',ax(2,1))

    end
    line( [min(statsReport.PostHoc.distance(idxKeep)) max(statsReport.PostHoc.distance(idxKeep))],...
        [0.05 0.05],...
        'LineWidth',1,'Color',[0 0 0],'LineStyle','--',...
        'DisplayName','\alpha = 0.05',...
        'Parent',ax(2,1))

    legend(ax(2,1),'Location','Best')

end
ax(2).YScale = 'log';

linkaxes(ax,'x')
htl.Title.String = ['Metaphase thickness: ' Tsel ' - Channel: ' Msel];
htl.Title.FontWeight = 'bold';

exportgraphics(hfig,fullfile(defaultOptions.lastFolderPath,'compilation.pdf'),'Append',true)

end


function PlotProfiles_grouped(G_summary,varGroups,Colormap,defaultOptions)

%%
grpName1 = unique(G_summary.(varGroups{1}));
grpName2 = unique(G_summary.(varGroups{2}));
grpName3 = unique(G_summary.(varGroups{3}));

measName = {'intensity';...
            'normalized intensity';...
            'intensity';...
            'normalized intensity'};

for idxG1 = 1:length(grpName1)
    idxKeep1 = G_summary.(varGroups{1}) == grpName1(idxG1);

    [hfig, ax] = buildGobject(measName,grpName2,char(grpName1(idxG1)));

    for idxG2 =1:length(grpName2)
        idxKeep2 = G_summary.(varGroups{2}) == grpName2(idxG2);



        for idxG3 =1:length(grpName3)
            idxKeep3 = G_summary.(varGroups{3}) == grpName3(idxG3);

            x_abs = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_absDistance'};
            
            y_abs_m   = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_absIntensity'};
            y_abs_sem = G_summary{idxKeep1&idxKeep2&idxKeep3,'sem_absIntensity'};
            
            y_absNorm_m   = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_absNormIntensity'};
            y_absNorm_sem = G_summary{idxKeep1&idxKeep2&idxKeep3,'sem_absNormIntensity'};


            x_rel = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_relDistance'};

            y_rel_m   = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_relIntensity'};
            y_rel_sem = G_summary{idxKeep1&idxKeep2&idxKeep3,'sem_relIntensity'};

            y_relNorm_m   = G_summary{idxKeep1&idxKeep2&idxKeep3,'mean_relNormIntensity'};
            y_relNorm_sem = G_summary{idxKeep1&idxKeep2&idxKeep3,'sem_relNormIntensity'};


            this_x = x_abs;
            idxDiscard = isnan(y_abs_m)|isnan(y_abs_sem);
            y_abs_m(idxDiscard) = [];
            y_abs_sem(idxDiscard) = [];
            this_x(idxDiscard) = [];
            patch("XData",[this_x fliplr(this_x)],...
                  "YData",[y_abs_m-y_abs_sem fliplr(y_abs_m+y_abs_sem)],...
                  'FaceColor',Colormap(idxG3,:),'EdgeColor',Colormap(idxG3,:),...
                  'FaceAlpha',0.5,'EdgeAlpha',1,...
                  'Parent',ax(idxG2,1))
            tmp = line(this_x,y_abs_m,...
                'LineWidth',2,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,1));
            h_abs(idxG3) = tmp;

            this_x = x_abs;
            idxDiscard = isnan(y_absNorm_m)|isnan(y_absNorm_sem);
            y_absNorm_m(idxDiscard) = [];
            y_absNorm_sem(idxDiscard) = [];
            this_x(idxDiscard) = [];
            patch("XData",[this_x fliplr(this_x)],...
                  "YData",[y_absNorm_m-y_absNorm_sem fliplr(y_absNorm_m+y_absNorm_sem)],...
                  'FaceColor',Colormap(idxG3,:),'EdgeColor',Colormap(idxG3,:),...
                  'FaceAlpha',0.5,'EdgeAlpha',1,...
                  'Parent',ax(idxG2,2))
            tmp = line(this_x,y_absNorm_m,...
                'LineWidth',2,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,2));
            h_absNorm(idxG3) = tmp;

            this_x = x_rel;
            idxDiscard = isnan(y_rel_m)|isnan(y_rel_sem);
            y_rel_m(idxDiscard) = [];
            y_rel_sem(idxDiscard) = [];
            this_x(idxDiscard) = [];
            patch("XData",[this_x fliplr(this_x)],...
                  "YData",[y_rel_m-y_rel_sem fliplr(y_rel_m+y_rel_sem)],...
                  'FaceColor',Colormap(idxG3,:),'EdgeColor',Colormap(idxG3,:),...
                  'FaceAlpha',0.5,'EdgeAlpha',1,...
                  'Parent',ax(idxG2,3))
            tmp = line(this_x,y_rel_m,...
                'LineWidth',2,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,3));
            h_rel(idxG3) = tmp;

            this_x = x_rel;
            idxDiscard = isnan(y_relNorm_m)|isnan(y_relNorm_sem);
            y_relNorm_m(idxDiscard) = [];
            y_relNorm_sem(idxDiscard) = [];
            this_x(idxDiscard) = [];
            patch("XData",[this_x fliplr(this_x)],...
                  "YData",[y_relNorm_m-y_relNorm_sem fliplr(y_relNorm_m+y_relNorm_sem)],...
                  'FaceColor',Colormap(idxG3,:),'EdgeColor',Colormap(idxG3,:),...
                  'FaceAlpha',0.5,'EdgeAlpha',1,...
                  'Parent',ax(idxG2,4))
            tmp = line(this_x,y_relNorm_m,...
                'LineWidth',2,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,4));
            h_relNorm(idxG3) = tmp;
          
        end
        legend(h_abs,'Location','best')
        legend(h_absNorm,'Location','best')
        legend(h_rel,'Location','best')
        legend(h_relNorm,'Location','best')


    end
    exportgraphics(hfig,fullfile(defaultOptions.lastFolderPath,'compilation.pdf'),'Append',true)


end
end

function PlotProfiles_persample(G,varGroups,Colormap,defaultOptions)


grpName1 = unique(G.(varGroups{1}));
grpName2 = unique(G.(varGroups{2}));
grpName3 = unique(G.(varGroups{3}));

measName = {'intensity';...
    'normalized intensity';...
    'intensity';...
    'normalized intensity'};

for idxG1 = 1:length(grpName1)
    idxKeep1 = G.(varGroups{1}) == grpName1(idxG1);

    [hfig, ax] = buildGobject(measName,grpName2,char(grpName1(idxG1)));

    for idxG2 =1:length(grpName2)
        idxKeep2 = G.(varGroups{2}) == grpName2(idxG2);



        for idxG3 =1:length(grpName3)
            idxKeep3 = G.(varGroups{3}) == grpName3(idxG3);

            x_abs = G{idxKeep1&idxKeep2&idxKeep3,'absDistance'};
            x_abs = cell2mat(x_abs{:}');

            y_abs = G{idxKeep1&idxKeep2&idxKeep3,'absIntensity'};
            y_abs = cell2mat(y_abs{:}');

            y_absNorm = G{idxKeep1&idxKeep2&idxKeep3,'absNormIntensity'};
            y_absNorm = cell2mat(y_absNorm{:}');

            x_rel = G{idxKeep1&idxKeep2&idxKeep3,'relDistance'};
            x_rel = cell2mat(x_rel{:}');

            y_rel = G{idxKeep1&idxKeep2&idxKeep3,'relIntensity'};
            y_rel = cell2mat(y_rel{:}');

            y_relNorm = G{idxKeep1&idxKeep2&idxKeep3,'relNormIntensity'};
            y_relNorm = cell2mat(y_relNorm{:}');

            tmp = line(x_abs,y_abs,...
                'LineWidth',1,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,1));
            h_abs(idxG3) = tmp(1);

            tmp = line(x_abs,y_absNorm,...
                'LineWidth',1,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,2));
            h_absNorm(idxG3) = tmp(1);

            tmp = line(x_rel,y_rel,...
                'LineWidth',1,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,3));
            h_rel(idxG3) = tmp(1);

            tmp = line(x_rel,y_relNorm,...
                'LineWidth',1,'Color',Colormap(idxG3,:),...
                'DisplayName',char(grpName3(idxG3)),...
                'Parent',ax(idxG2,4));
            h_relNorm(idxG3) = tmp(1);

        end
        legend(h_abs,'Location','best')
        legend(h_absNorm,'Location','best')
        legend(h_rel,'Location','best')
        legend(h_relNorm,'Location','best')


    end
    exportgraphics(hfig,fullfile(defaultOptions.lastFolderPath,'compilation.pdf'),'Append',false)


end
end

function [hfig,ax ] = buildGobject(measName,grpName2,BigOrSmall)
    hfig = figure('Position',[1 41 3264 1228]);
    htl  = tiledlayout(hfig,length(grpName2),length(measName));
    htl.Title.String = [BigOrSmall ' metaphase thickness'];
    idx = 1;
    ax = gobjects(htl.GridSize);
    for idx_row = 1:htl.GridSize(1)
        for idx_col = 1:htl.GridSize(2)
            ax(idx_row,idx_col) = nexttile(htl,idx,[1 1]);
            ax(idx_row,idx_col).Box = 'on';
            ax(idx_row,idx_col).XGrid = 'on';
            ax(idx_row,idx_col).YGrid = 'on';
            if idx_col<=2
                ax(idx_row,idx_col).XLabel.String = 'distance (\mum)';
            else
                ax(idx_row,idx_col).XLabel.String = 'distance (%)';
            end
            ax(idx_row,idx_col).YLabel.String = [char(grpName2(idx_row)) ' ' measName{idx_col}];

            idx = idx+1;
        end

    end
end


