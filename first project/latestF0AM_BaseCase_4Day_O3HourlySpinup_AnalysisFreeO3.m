%% ========================================================================
% F0AM BASE CASE - FOUR-DAY DIEL SPIN-UP + ANALYSIS-DAY MAX-O3 ISOPLETH
% Los Angeles | Spin-up: 27-30 July 2019 | Analysis: 31 July 2019 | CB6r2
%
% IMPLEMENTED METHODOLOGY
%   1) Preserve the uploaded script's prescribed-species treatment:
%        - NO, NO2, and CO are reset from the hourly input profile.
%        - VOC initialization/HoldMe settings are unchanged from InitConc_base.
%        - Only species already represented in InitConc are passed between
%          hourly calls; mechanism-generated secondary species are NOT added
%          to the next hourly InitConc.
%   2) Four complete spin-up days (27-30 July) use a continuous date/SZA diel
%      cycle and repeat the same 24-h meteorology/precursor concentration profile.
%   3) At the end of the four-day spin-up, the carried O3 endpoint is reported.
%      At 31 July 00:00 LT, O3 is HARD RESET to 15 ppb before analysis begins.
%   4) Every hourly forcing block contains exactly six points:
%          H:00, H:10, H:20, H:30, H:40, H:50.
%      The next hourly call starts at (H+1):00, so no duplicated boundary point.
%   5) Analysis/isopleth window = 08:00-20:00 LT (08:00 through 19:50).
%   6) The exact 10-min maximum modeled O3 in that analysis window identifies
%      the parent hour. The start-of-hour NOx/VOC state for that parent hour
%      is used as the isopleth base, preserving the uploaded script's
%      start-of-hour precursor initialization convention.
%   7) Isopleth response = genuine maximum modeled O3 over 08:00-20:00 LT.
%   8) Temperatures = 290, 295, 300, 305 K; grid = 31 x 31:
%          NOx 0-50 ppb; VOC 0-150 ppb.
%   9) Each temperature is saved and plotted immediately after it completes;
%      the cumulative ridge summary is also written immediately.
%  10) Corrected ridge criterion is retained from the uploaded script.
%% ========================================================================

clear; clc; close all;
set(0,'DefaultFigureRenderer','painters');
city_name = 'LosAngeles';

%% ---------------- USER SETTINGS ----------------
xlsx_path = 'D:\Final_Temp_inf_on_Ozone_analysis\Refreshed_basecase\INPUT_2019_REFRESHED.xlsx';
out_dir   = 'D:\Final_Temp_inf_on_Ozone_analysis\Finalization_spinuobasecase\latest\final';
if ~exist(out_dir,'dir'), mkdir(out_dir); end

lat = 34.0522;
lon = -118.2437;
UTC_offset = -7;
run_date   = datetime(2019,7,31);
spinup_start_date = datetime(2019,7,27);
n_spinup_days = 4;
analysis_O3_reset_ppb = 15.0;
dt_minutes = 10;

temps_sens = [290 295 300 305];

% Isopleth integration window used for genuine maximum O3
iso_start_hour = 8;
iso_end_hour   = 20;

% Common final grid for base and real cases
n_nox = 31;
n_voc = 31;
NOx_ppb_levels = linspace(0,50,n_nox);
VOC_ppb_levels = linspace(0,150,n_voc);
[NOx_ppb_grid,VOC_ppb_grid] = meshgrid(NOx_ppb_levels,VOC_ppb_levels);

%% ---------------- CHEMISTRY / MODEL OPTIONS ----------------
ChemFiles = {'CB6r2_K(Met)'; 'CB6r2_J(Met,0)'; 'CB6r2_AllRxns'};
for i = 1:numel(ChemFiles)
    fn = regexprep(ChemFiles{i},'\(.*\)','');
    assert(exist([fn '.m'],'file')==2,'Missing chemistry file: %s.m',fn);
end

ModelOptions.Verbose       = 1;
ModelOptions.EndPointsOnly = 0;
ModelOptions.LinkSteps     = 1;
ModelOptions.IntTime       = dt_minutes*60;
ModelOptions.SavePath      = fullfile(tempdir,'F0AM_tmp_base_final');
if ~exist(ModelOptions.SavePath,'dir'), mkdir(ModelOptions.SavePath); end

jcorr  = 0.5;
kdil_s = 1/(24*60*60);  % 24-h dilution lifetime

%% ---------------- INITIAL CONDITIONS: 2019 BASE CASE ----------------
InitConc_base = {
  'O3',   15.0,  0;
  'CO',   274,   0;
  'NO',   1.21,  0;
  'NO2',  14.2,  0;
  'ETHA', 19.2,  1;
  'PRPA', 10.2,  1;
  'ETH',  1.4,   1;
  'PAR',  2.9,   1;
  'OLE',  0.4,   1;
  'IOLE', 0.09,  1;
  'TOL',  0.43,  1;
  'XYL',  0.31,  1;
  'BENZ', 0.18,  1;
  'ALD2', 1.4,   1;
  'FORM', 3.52,  1;
  'ACET', 3.5,   1;
  'ETHY', 0.62,  1;
  'ISOP', 3.04,  1;
};

voc_species = {'ETHA','ETHY','PRPA','ALD2','FORM','ACET','ETH', ...
               'PAR','OLE','IOLE','TOL','XYL','BENZ','ISOP'};

%% ---------------- READ INPUT WORKBOOK ----------------
assert(exist(xlsx_path,'file')==2,'Input workbook not found: %s',xlsx_path);
Ttbl = readtable(xlsx_path,'VariableNamingRule','preserve');
vn = lower(regexprep(Ttbl.Properties.VariableNames,'\s+',''));

iTime = find(ismember(vn,{'time','hour','hr'}),1);
iT    = find(ismember(vn,{'temperature','temperatures','tempk'}),1);
iRH   = find(ismember(vn,{'relativehumidity','rh'}),1);
iP    = find(ismember(vn,{'pressure','p'}),1);
iO3   = find(ismember(vn,{'observedozone','obs_ozone','ozone','o3'}),1);
assert(~isempty(iT)&&~isempty(iRH)&&~isempty(iP)&&~isempty(iO3), ...
    'Workbook must contain Temperature, RH, Pressure, and observed O3 columns.');
assert(height(Ttbl)>=24,'Workbook must contain at least 24 hourly rows.');

Temp24 = double(Ttbl{1:24,iT});
RH24   = double(Ttbl{1:24,iRH});
P24    = double(Ttbl{1:24,iP});
O3obs24 = double(Ttbl{1:24,iO3});
if any(~isfinite(O3obs24))
    O3obs24 = fillmissing(O3obs24,'linear','EndValues','nearest');
end

% Hourly precursor columns from same workbook
PrecTbl = Ttbl;
vn_prec = vn;
iHourPrec = iTime;
if ~isempty(iHourPrec)
    hours_vec = double(PrecTbl{:,iHourPrec});
    mask24 = isfinite(hours_vec) & hours_vec>=0 & hours_vec<=23;
    PrecTbl24 = PrecTbl(mask24,:);
    [~,first_idx] = unique(double(PrecTbl24{:,iHourPrec}),'stable');
    PrecTbl24 = PrecTbl24(first_idx,:);
    [~,ord] = sort(double(PrecTbl24{:,iHourPrec}));
    PrecTbl24 = PrecTbl24(ord,:);
else
    PrecTbl24 = PrecTbl(1:24,:);
end
assert(height(PrecTbl24)>=24,'Could not construct a complete 24-h precursor profile.');

get_col = @(name) get_numeric_column(PrecTbl24,vn_prec,name);
prec_cols.CO  = get_col('CO');
prec_cols.NO  = get_col('NO');
prec_cols.NO2 = get_col('NO2');

%% ---------------- FOUR-DAY SPIN-UP + ANALYSIS-DAY DIURNAL ----------------
BkgdConc = {'DEFAULT',0};

% The original prescribed concentration/HoldMe settings are retained.
% The same 24-h concentration/meteorology profile is repeated on each spin-up
% day, while the calendar date advances so SZA follows a continuous diel cycle.
InitConc_now = InitConc_base;

SpinupDay = [];
SpinupHour = [];
SpinupO3_End_ppb = [];

fprintf('\n============================================================\n');
fprintf('FOUR-DAY SPIN-UP: 27-30 JULY 2019\n');
fprintf('============================================================\n');

for iDay = 1:n_spinup_days

    this_date = spinup_start_date + days(iDay-1);

    fprintf('Spin-up day %d/%d: %s\n', ...
        iDay,n_spinup_days,datestr(this_date,'yyyy-mm-dd'));

    for H = 0:23

        [time_blk,sun_blk] = ...
            hour_block_sun(this_date,UTC_offset,lat,lon,H,dt_minutes);

        % hour_block_sun returns exactly H:00...H:50 (6 forcing points).
        assert(numel(time_blk.hour)==6, ...
            'Hourly forcing must contain exactly 6 points (H:00-H:50).');

        Met_blk = {
            'P',     P24(H+1)*ones(size(time_blk.hour));
            'T',     Temp24(H+1)*ones(size(time_blk.hour));
            'RH',    RH24(H+1)*ones(size(time_blk.hour));
            'SZA',   sun_blk.zenith;
            'jcorr', jcorr;
            'kdil',  kdil_s
        };

        % Preserve uploaded-script concentration logic.
        InitConc_now = set_species_value(InitConc_now,'NO', prec_cols.NO(H+1));
        InitConc_now = set_species_value(InitConc_now,'NO2',prec_cols.NO2(H+1));
        InitConc_now = set_species_value(InitConc_now,'CO', prec_cols.CO(H+1));

        ModelOptions.TimeStamp = time_blk.hour + time_blk.min/60;

        Sblk = F0AM_ModelCore( ...
            Met_blk,InitConc_now,ChemFiles,BkgdConc,ModelOptions);

        O3_blk = extract_species_series(Sblk,'O3');

        if isempty(O3_blk)
            spinEndO3 = NaN;
        else
            spinEndO3 = O3_blk(end);
        end

        SpinupDay(end+1,1) = iDay; %#ok<SAGROW>
        SpinupHour(end+1,1) = H; %#ok<SAGROW>
        SpinupO3_End_ppb(end+1,1) = spinEndO3; %#ok<SAGROW>

        % IMPORTANT: retain the uploaded script's limited state transfer.
        % This updates only species already present in InitConc_now.
        % It does NOT append mechanism-generated secondary species.
        InitConc_now = last_state_to_init(Sblk,InitConc_now);

    end
end

spinup_final_O3_ppb = get_init_species_value(InitConc_now,'O3');

fprintf('\nFinal carried spin-up O3 before analysis reset = %.4f ppb\n', ...
    spinup_final_O3_ppb);
fprintf('Requested/expected spin-up endpoint noted by user = approximately 26 ppb.\n');

SpinupTbl = table(SpinupDay,SpinupHour,SpinupO3_End_ppb, ...
    'VariableNames',{'SpinupDay','Hour_LT','EndHour_O3_ppb'});
writetable(SpinupTbl,fullfile(out_dir,'BaseCase_FourDay_Spinup_O3.csv'));

%% ---------------- HARD O3 RESET AT JULY 31 00:00 ----------------
O3_before_analysis_reset = get_init_species_value(InitConc_now,'O3');
InitConc_now = set_species_value(InitConc_now,'O3',analysis_O3_reset_ppb);
O3_after_analysis_reset = get_init_species_value(InitConc_now,'O3');

fprintf('July 31 00:00 O3 hard reset: %.4f -> %.4f ppb\n', ...
    O3_before_analysis_reset,O3_after_analysis_reset);

assert(abs(O3_after_analysis_reset-analysis_O3_reset_ppb)<1e-12, ...
    'July 31 O3 hard reset to 15 ppb failed.');

%% ---------------- JULY 31 ANALYSIS-DAY RUN ----------------
O3_model_hr      = nan(24,1);
NOx_init_at_hour = nan(24,1);
VOC_init_at_hour = nan(24,1);

% Store all six 10-min O3 points per hour and the corresponding start-hour
% prescribed parent state. This is used only to identify the maximum-O3 hour.
AnalysisTime = NaT(24*6,1);
AnalysisO3   = nan(24*6,1);
AnalysisHour = nan(24*6,1);
rowA = 0;

ParentInitByHour = cell(24,1);

fprintf('\n============================================================\n');
fprintf('ANALYSIS DAY: 31 JULY 2019\n');
fprintf('============================================================\n');

for H = 0:23

    [time_blk,sun_blk] = ...
        hour_block_sun(run_date,UTC_offset,lat,lon,H,dt_minutes);

    assert(numel(time_blk.hour)==6, ...
        'Hourly forcing must contain exactly 6 points (H:00-H:50).');

    Met_blk = {
        'P',     P24(H+1)*ones(size(time_blk.hour));
        'T',     Temp24(H+1)*ones(size(time_blk.hour));
        'RH',    RH24(H+1)*ones(size(time_blk.hour));
        'SZA',   sun_blk.zenith;
        'jcorr', jcorr;
        'kdil',  kdil_s
    };

    % Preserve uploaded-script concentration logic.
    InitConc_now = set_species_value(InitConc_now,'NO', prec_cols.NO(H+1));
    InitConc_now = set_species_value(InitConc_now,'NO2',prec_cols.NO2(H+1));
    InitConc_now = set_species_value(InitConc_now,'CO', prec_cols.CO(H+1));

    NOx_init_at_hour(H+1) = init_sum_NOx(InitConc_now);
    VOC_init_at_hour(H+1) = init_sum_VOC(InitConc_now,voc_species);

    % Save the actual start-of-hour parent state used by the uploaded
    % initialization convention. No generated secondary species are appended.
    ParentInitByHour{H+1} = InitConc_now;

    ModelOptions.TimeStamp = time_blk.hour + time_blk.min/60;

    Sblk = F0AM_ModelCore( ...
        Met_blk,InitConc_now,ChemFiles,BkgdConc,ModelOptions);

    O3_blk = extract_species_series(Sblk,'O3');

    if ~isempty(O3_blk)
        O3_model_hr(H+1) = mean(O3_blk,'omitnan');

        nsave = min(numel(O3_blk),6);
        idx = rowA + (1:nsave);

        AnalysisTime(idx) = ...
            run_date + hours(H) + minutes((0:nsave-1)'*dt_minutes);

        AnalysisO3(idx) = O3_blk(1:nsave);
        AnalysisHour(idx) = H;

        rowA = rowA + nsave;
    end

    % Preserve uploaded-script limited transfer: initialized species only.
    InitConc_now = last_state_to_init(Sblk,InitConc_now);

end

AnalysisTime = AnalysisTime(1:rowA);
AnalysisO3   = AnalysisO3(1:rowA);
AnalysisHour = AnalysisHour(1:rowA);

Analysis10minTbl = table(AnalysisTime,AnalysisHour,AnalysisO3, ...
    'VariableNames',{'LocalTime','ParentHour_LT','ModeledO3_ppb'});
writetable(Analysis10minTbl, ...
    fullfile(out_dir,'BaseCase_AnalysisDay_10min_O3.csv'));

%% ---------------- DIURNAL OUTPUT ----------------
DiurnalTbl = table((0:23)',O3obs24,O3_model_hr,NOx_init_at_hour,VOC_init_at_hour, ...
    'VariableNames',{'Hour','ObservedO3_ppb','ModeledO3_ppb', ...
                     'StartHour_NOx_ppb','StartHour_VOC_ppb'});
writetable(DiurnalTbl,fullfile(out_dir,'BaseCase_Diurnal.csv'));

[MB,NMB,NRMSE] = performance_stats(O3_model_hr,O3obs24);
PerfTbl = table(MB,NMB,NRMSE,'VariableNames',{'MB_ppb','NMB_percent','NRMSE_percent'});
writetable(PerfTbl,fullfile(out_dir,'BaseCase_Diurnal_Performance.csv'));

fD = figure('Color','w','Position',[120 120 900 520]); hold on;
plot(0:23,O3obs24,'o-','LineWidth',1.8,'MarkerSize',6,'DisplayName','Observed O_3');
plot(0:23,O3_model_hr,'s-','LineWidth',1.8,'MarkerSize',6,'DisplayName','Modeled O_3');
xlabel('Hour (LT)'); ylabel('O_3 (ppb)');
title('Los Angeles Base Case: Observed vs Modeled O_3');
grid on; box on; legend('Location','best');
stats_txt = sprintf('MB = %.2f ppb\nNMB = %.2f%%\nNRMSE = %.2f%%',MB,NMB,NRMSE);
annotation(fD,'textbox',[0.68 0.18 0.20 0.16],'String',stats_txt, ...
    'FitBoxToText','on','BackgroundColor','w','EdgeColor',[0.3 0.3 0.3], ...
    'FontSize',10,'Interpreter','none');
savefig(fD,fullfile(out_dir,'BaseCase_Diurnal.fig'));
exportgraphics(fD,fullfile(out_dir,'BaseCase_Diurnal.png'),'Resolution',300);

%% ---------------- ANALYSIS-DAY MAX-O3 PARENT/BASE STATE ----------------
% Window definition is 08:00 <= t < 20:00, i.e. 08:00 through 19:50.
mask_peak = ...
    hour(AnalysisTime)>=iso_start_hour & ...
    hour(AnalysisTime)<iso_end_hour & ...
    isfinite(AnalysisO3);

assert(any(mask_peak), ...
    'No finite modeled O3 values in the 08:00-20:00 LT analysis window.');

candidate_idx = find(mask_peak);
[peak_O3_ppb,jLocal] = max(AnalysisO3(mask_peak),[],'omitnan');
idxPeak = candidate_idx(jLocal);

peak_time = AnalysisTime(idxPeak);
peak_parent_hour = AnalysisHour(idxPeak);

% Preserve the uploaded script's start-of-hour precursor convention:
% the exact 10-min O3 maximum identifies the PARENT HOUR, and the NOx/VOC
% concentrations initialized at the beginning of that hour define the
% isopleth base state.
PeakParentInit = ParentInitByHour{peak_parent_hour+1};

base_NOx = init_sum_NOx(PeakParentInit);
base_VOC = init_sum_VOC(PeakParentInit,voc_species);

% P and RH are taken from the same parent hour.
P_base  = P24(peak_parent_hour+1);
RH_base = RH24(peak_parent_hour+1);

assert(isfinite(base_NOx)&&base_NOx>0, ...
    'Peak-parent NOx is invalid.');
assert(isfinite(base_VOC)&&base_VOC>0, ...
    'Peak-parent VOC is invalid.');

BaseStateTbl = table( ...
    peak_time,peak_O3_ppb,peak_parent_hour, ...
    base_NOx,base_VOC,P_base,RH_base,kdil_s, ...
    'VariableNames', ...
    {'PeakModeledO3_Time_LT','PeakModeledO3_ppb','ParentHour_LT', ...
     'BaseNOx_ppb','BaseVOC_ppb','ParentHour_P','ParentHour_RH','kdil_s'});

writetable(BaseStateTbl, ...
    fullfile(out_dir,'BaseCase_Isopleth_MaxO3_ParentState.csv'));

fprintf('\n============================================================\n');
fprintf('ANALYSIS-DAY MAX-O3 ISOPLETH PARENT STATE\n');
fprintf('============================================================\n');
fprintf('Peak modeled O3 = %.4f ppb at %s LT\n', ...
    peak_O3_ppb,datestr(peak_time,'HH:MM'));
fprintf('Parent hour      = %02d:00 LT\n',peak_parent_hour);
fprintf('Base NOx         = %.4f ppb\n',base_NOx);
fprintf('Base VOC         = %.4f ppb\n',base_VOC);
fprintf('Parent-hour P    = %.4f\n',P_base);
fprintf('Parent-hour RH   = %.4f\n',RH_base);
fprintf('Dilution lifetime = 24 h; kdil = %.6e s^-1\n',kdil_s);

%% ---------------- ISOPLETH TIMEBASE: 08:00-19:50 ----------------
% Exactly six forcing points per hour; no 20:00 endpoint is included.
t_iso = (run_date+hours(iso_start_hour)):minutes(dt_minutes): ...
        (run_date+hours(iso_end_hour)-minutes(dt_minutes));
t_iso = t_iso(:);

expected_iso_points = ...
    (iso_end_hour-iso_start_hour)*(60/dt_minutes);

assert(numel(t_iso)==expected_iso_points, ...
    'Isopleth timebase must contain 72 points for 08:00-19:50 at 10-min resolution.');

oiso = ones(size(t_iso));
time_iso.year=year(t_iso).*oiso;
time_iso.month=month(t_iso).*oiso;
time_iso.day=day(t_iso).*oiso;
time_iso.hour=hour(t_iso);
time_iso.min=minute(t_iso);
time_iso.sec=second(t_iso);
time_iso.UTC=UTC_offset*oiso;

sun_iso = sun_position( ...
    time_iso, ...
    struct('latitude',lat,'longitude',lon,'altitude',90));

ModelOptions_iso = ModelOptions;
ModelOptions_iso.EndPointsOnly = 0;
ModelOptions_iso.TimeStamp = hour(t_iso) + minute(t_iso)/60;

% The analysis-day maximum-O3 parent state is the isopleth parent.
% Preserve exactly the uploaded script's NOx/VOC scaling logic.
InitConc_iso_base = set_NOx_sum(PeakParentInit,base_NOx);
InitConc_iso_base = set_VOC_basket_sum( ...
    InitConc_iso_base,base_VOC,voc_species);

fNOx_grid = NOx_ppb_grid./base_NOx;
fVOC_grid = VOC_ppb_grid./base_VOC;

%% ---------------- RUN 4 MAXIMUM-O3 TEMPERATURE ISOPLETHS ----------------
O3_alltemps = cell(numel(temps_sens),1);
RidgeSummary = table();

for it = 1:numel(temps_sens)
    TK = temps_sens(it);
    Met_iso = {
        'P',P_base*ones(size(t_iso));
        'T',TK*ones(size(t_iso));
        'RH',RH_base*ones(size(t_iso));
        'SZA',sun_iso.zenith;
        'jcorr',jcorr;
        'kdil',kdil_s
    };

    o3_values = run_isopleth_grid_maxO3(Met_iso,InitConc_iso_base,ChemFiles, ...
        BkgdConc,ModelOptions_iso,fNOx_grid,fVOC_grid,voc_species);

    O3grid = reshape(o3_values,n_voc,n_nox);
    O3_alltemps{it} = O3grid;

    % Each isopleth value is the genuine maximum modeled O3 over 08:00-20:00 LT.
    GridTbl = table(fVOC_grid(:),fNOx_grid(:),VOC_ppb_grid(:),NOx_ppb_grid(:), ...
        O3grid(:),repmat(TK,numel(O3grid),1), ...
        'VariableNames',{'VOC_factor','NOx_factor','VOC_ppb','NOx_ppb', ...
                         'MaxO3_08_20_ppb','TempK'});
    writetable(GridTbl,fullfile(out_dir,sprintf('LosAngeles_BaseCase_Isopleth_T%dK.csv',round(TK))));

    % Corrected ridge + boundary diagnosis.
    [RidgeTbl,DiagTbl,SumRow] = corrected_ridge_NOx(O3grid,VOC_ppb_levels,NOx_ppb_levels,TK);
    writetable(RidgeTbl,fullfile(out_dir,sprintf('LosAngeles_BaseCase_CorrectedRidge_T%dK.csv',round(TK))));
    writetable(DiagTbl,fullfile(out_dir,sprintf('LosAngeles_BaseCase_RidgeBoundary_T%dK.csv',round(TK))));
    RidgeSummary = [RidgeSummary; SumRow]; %#ok<AGROW>
    RidgeSummary = sortrows(RidgeSummary,'TempK');
    writetable(RidgeSummary, ...
        fullfile(out_dir,'BaseCase_Corrected_Ridge_Summary_RUNNING.csv'));
    writetable(RidgeSummary, ...
        fullfile(out_dir,'BaseCase_Corrected_Ridge_Summary_RUNNING.xlsx'));

    fprintf('\nRIDGE SUMMARY AFTER T = %d K\n',round(TK));
    disp(RidgeSummary);

    % Plot isopleth and corrected ridge.
    f = figure('Color','w','Position',[110 80 920 700]);
    contourf(VOC_ppb_levels,NOx_ppb_levels,O3grid.',20,'LineStyle','none'); hold on;
    contour(VOC_ppb_levels,NOx_ppb_levels,O3grid.',12,'LineColor',[0.25 0.25 0.25],'LineWidth',0.7);
    cb=colorbar; cb.Label.String='Maximum O_3, 08:00-20:00 LT (ppb)';
    plot(base_VOC,base_NOx,'kp','MarkerSize',12,'MarkerFaceColor','w', ...
        'LineWidth',1.5,'DisplayName','Analysis-day max-O_3 parent state');
    if ~isempty(RidgeTbl)
        plot(RidgeTbl.VOC_ppb,RidgeTbl.RidgeNOx_ppb,'ko-','LineWidth',2.0, ...
            'MarkerSize',5,'MarkerFaceColor','w','DisplayName','Corrected ridge');
    end
    ub = DiagTbl.Classification=="Upper NOx boundary maximum";
    if any(ub)
        plot(DiagTbl.VOC_ppb(ub),max(NOx_ppb_levels)*ones(sum(ub),1),'rs', ...
            'LineWidth',1.4,'MarkerSize',7,'DisplayName','Upper-boundary maximum');
    end
    xlabel('VOC (ppb)'); ylabel('NO_x (ppb)');
    title(sprintf('Base Case Maximum O_3 Isopleth, T = %d K',round(TK)));
    grid on; box on; legend('Location','best');
    savefig(f,fullfile(out_dir,sprintf('BaseCase_Isopleth_CorrectedRidge_T%dK.fig',round(TK))));
    exportgraphics(f,fullfile(out_dir,sprintf('BaseCase_Isopleth_CorrectedRidge_T%dK.png',round(TK))),'Resolution',300);
end

RidgeSummary = sortrows(RidgeSummary,'TempK');

%% ---------------- ARRHENIUS SELECTIVITY ----------------
A_NO_O3=2.07e-12; B_NO_O3=-1400;
A_HO2_NO=3.45e-12; B_HO2_NO=270;
Tvec=RidgeSummary.TempK;
RidgeSummary.k_NO_O3 = A_NO_O3.*exp(B_NO_O3./Tvec);
RidgeSummary.k_HO2_NO = A_HO2_NO.*exp(B_HO2_NO./Tvec);
RidgeSummary.KineticSelectivity = RidgeSummary.k_HO2_NO./RidgeSummary.k_NO_O3;

% Normalized ridge response relative to 290 K.
Rref = RidgeSummary.Mean_Ridge_VOC_to_NOx(1);
RidgeSummary.Relative_to_290K = RidgeSummary.Mean_Ridge_VOC_to_NOx./Rref;
RidgeSummary.PercentChange_from_290K = 100*(RidgeSummary.Mean_Ridge_VOC_to_NOx-Rref)./Rref;
RidgeSummary.TSI = log(RidgeSummary.Mean_Ridge_VOC_to_NOx)-log(Rref);

writetable(RidgeSummary,fullfile(out_dir,'BaseCase_Corrected_Ridge_Summary.csv'));
writetable(RidgeSummary,fullfile(out_dir,'BaseCase_Corrected_Ridge_Summary.xlsx'));

%% ---------------- RIDGE RATIO VS TEMPERATURE ----------------
fR = figure('Color','w','Position',[180 120 800 580]);
plot(RidgeSummary.TempK,RidgeSummary.Mean_Ridge_VOC_to_NOx,'o-', ...
    'LineWidth',2,'MarkerSize',8,'MarkerFaceColor','w');
xlabel('Temperature (K)'); ylabel('Mean ridge VOC/NO_x');
title('Base Case: Corrected Ridge VOC/NO_x vs Temperature'); grid on; box on;
savefig(fR,fullfile(out_dir,'BaseCase_Corrected_RidgeRatio_vs_T.fig'));
exportgraphics(fR,fullfile(out_dir,'BaseCase_Corrected_RidgeRatio_vs_T.png'),'Resolution',300);

fprintf('\nFINAL BASE-CASE RIDGE SUMMARY\n');
disp(RidgeSummary);
fprintf('\nAll revised base-case outputs written to:\n%s\n',out_dir);

%% ========================================================================
% LOCAL FUNCTIONS
%% ========================================================================
function v = get_numeric_column(T,vn,name)
    key = lower(regexprep(name,'\s+',''));
    idx = find(strcmpi(vn,key),1);
    assert(~isempty(idx),'Required column "%s" not found.',name);
    v = double(T{:,idx});
end

function InitConc = set_species_value(InitConc,sp,val)
    if ~isfinite(val), return; end
    idx=find(strcmpi(InitConc(:,1),sp),1);
    if ~isempty(idx), InitConc{idx,2}=max(double(val),0); end
end

function [time_blk,sun_blk] = hour_block_sun(run_date,UTC_offset,lat,lon,H,dt_minutes)
    t0=run_date+hours(H);
    % Exactly six points for dt=10 min: H:00,H:10,...,H:50.
    % Exclude (H+1):00 to avoid duplicated hourly-boundary forcing.
    t_local=(t0:minutes(dt_minutes):(t0+hours(1)-minutes(dt_minutes)))';
    o=ones(size(t_local));
    time_blk.year=year(t_local).*o; time_blk.month=month(t_local).*o;
    time_blk.day=day(t_local).*o; time_blk.hour=hour(t_local);
    time_blk.min=minute(t_local); time_blk.sec=second(t_local);
    time_blk.UTC=UTC_offset*o;
    loc.latitude=lat; loc.longitude=lon; loc.altitude=90;
    sun_blk=sun_position(time_blk,loc);
end

function val=get_init_species_value(InitConc,sp)
    idx=find(strcmpi(InitConc(:,1),sp),1);
    if isempty(idx) || ~isnumeric(InitConc{idx,2})
        val=NaN;
    else
        val=double(InitConc{idx,2});
    end
end

function val=init_sum_NOx(InitConc)
    iNO=find(strcmpi(InitConc(:,1),'NO'),1); iNO2=find(strcmpi(InitConc(:,1),'NO2'),1);
    if isempty(iNO)||isempty(iNO2), val=NaN; else, val=InitConc{iNO,2}+InitConc{iNO2,2}; end
end

function val=init_sum_VOC(InitConc,voc_list)
    val=0;
    for k=1:numel(voc_list)
        idx=find(strcmpi(InitConc(:,1),voc_list{k}),1);
        if ~isempty(idx)&&isnumeric(InitConc{idx,2}), val=val+InitConc{idx,2}; end
    end
end

function s=extract_species_series(S,spc)
    s=[];
    if isfield(S,'Conc') && istable(S.Conc) && any(strcmpi(S.Conc.Properties.VariableNames,spc))
        s=S.Conc.(S.Conc.Properties.VariableNames{find(strcmpi(S.Conc.Properties.VariableNames,spc),1)});
    elseif isfield(S,'Conc') && isstruct(S.Conc) && isfield(S.Conc,spc)
        s=S.Conc.(spc);
    elseif isfield(S,'Chem')&&isfield(S.Chem,'AllSpc')&&isnumeric(S.Conc)
        j=find(strcmpi(S.Chem.AllSpc,spc),1); if ~isempty(j), s=S.Conc(:,j); end
    end
    if isrow(s), s=s'; end
end

function InitConc_next=last_state_to_init(S,InitConc_template)
    InitConc_next=InitConc_template; names={}; concM=[];
    if istable(S.Conc)
        names=S.Conc.Properties.VariableNames; concM=S.Conc{end,:};
    elseif isstruct(S.Conc)
        names=fieldnames(S.Conc); concM=cellfun(@(f)S.Conc.(f)(end),names);
    elseif isfield(S,'Chem')&&isfield(S.Chem,'AllSpc')&&isnumeric(S.Conc)
        names=S.Chem.AllSpc; concM=S.Conc(end,:);
    end
    for i=1:size(InitConc_next,1)
        j=find(strcmpi(names,InitConc_next{i,1}),1);
        if ~isempty(j)&&isfinite(concM(j)), InitConc_next{i,2}=concM(j); end
    end
end

function InitConc2=set_NOx_sum(InitConc1,NOx_sum)
    iNO=find(strcmpi(InitConc1(:,1),'NO'),1); iNO2=find(strcmpi(InitConc1(:,1),'NO2'),1);
    NOv=InitConc1{iNO,2}; NO2v=InitConc1{iNO2,2};
    if NOv+NO2v<=0, frac=0.5; else, frac=NOv/(NOv+NO2v); end
    InitConc2=InitConc1; InitConc2{iNO,2}=NOx_sum*frac; InitConc2{iNO2,2}=NOx_sum*(1-frac);
end

function InitConc2=set_VOC_basket_sum(InitConc1,VOC_sum,voc_list)
    cur=init_sum_VOC(InitConc1,voc_list);
    if cur<=0, scale=0; else, scale=VOC_sum/cur; end
    InitConc2=InitConc1;
    for k=1:numel(voc_list)
        idx=find(strcmpi(InitConc1(:,1),voc_list{k}),1);
        if ~isempty(idx), InitConc2{idx,2}=InitConc1{idx,2}*scale; end
    end
end

function vals=run_isopleth_grid_maxO3(Met,InitBase,ChemFiles,Bkgd,Opts,fNOx,fVOC,voc_species)
    vals=nan(numel(fNOx),1);
    for i=1:numel(fNOx)
        Init=InitBase;
        iNO=find(strcmpi(Init(:,1),'NO'),1); iNO2=find(strcmpi(Init(:,1),'NO2'),1);
        Init{iNO,2}=Init{iNO,2}*fNOx(i); Init{iNO2,2}=Init{iNO2,2}*fNOx(i);
        for v=1:numel(voc_species)
            idx=find(strcmpi(Init(:,1),voc_species{v}),1);
            if ~isempty(idx), Init{idx,2}=Init{idx,2}*fVOC(i); end
        end
        S=F0AM_ModelCore(Met,Init,ChemFiles,Bkgd,Opts);
        O3=extract_species_series(S,'O3');
        if isempty(O3), continue; end
        O3=O3(isfinite(O3));
        if ~isempty(O3), vals(i)=max(O3,[],'omitnan'); end
    end
end

function [RidgeTbl,DiagTbl,SumRow]=corrected_ridge_NOx(O3grid,VOClevels,NOxlevels,TK)
% CORRECTED_RIDGE_NOX
% Ridge definition at fixed VOC:
%   dO3/dNOx = 0 with a + to - sign change AND d2O3/dNOx2 < 0.
% If multiple valid local maxima occur, retain the one with highest O3.
%
% Boundary diagnostics are INDEPENDENT of ridge classification. Thus a VOC
% row can contain an interior local maximum and still be flagged if O3 is
% rising again at the upper NOx boundary. This is important for detecting a
% truncated NOx domain without changing the ridge-selection rule.

    nV=numel(VOClevels);
    rv=[]; rn=[]; ro=[]; rd2=[]; nmax=[];
    class=strings(nV,1);
    dUpper=nan(nV,1); discreteNOx=nan(nV,1); discreteO3=nan(nV,1);
    upperStillIncreasing=false(nV,1);
    upperDominatesInterior=false(nV,1);
    hasInterior=false(nV,1);

    derivTol=1e-8;
    o3Tol=1e-8;

    for iv=1:nV
        x=NOxlevels(:);
        z=O3grid(iv,:)';
        good=isfinite(x)&isfinite(z);
        x=x(good); z=z(good);

        if numel(x)<5
            class(iv)="Unclassified";
            continue;
        end

        d1=gradient(z,x);
        d2=gradient(d1,x);
        dUpper(iv)=d1(end);
        upperStillIncreasing(iv)=isfinite(d1(end)) && d1(end)>derivTol;

        cx=[]; co=[]; cd2=[];
        for k=1:numel(x)-1
            if isfinite(d1(k))&&isfinite(d1(k+1))&&d1(k)>=0&&d1(k+1)<0
                den=d1(k+1)-d1(k);
                if abs(den)<eps
                    f=0.5;
                else
                    f=-d1(k)/den;
                end
                f=max(0,min(1,f));
                x0=x(k)+f*(x(k+1)-x(k));
                o0=interp1(x,z,x0,'pchip');
                d20=interp1(x,d2,x0,'linear');
                if isfinite(o0)&&isfinite(d20)&&d20<0
                    cx(end+1,1)=x0; %#ok<AGROW>
                    co(end+1,1)=o0; %#ok<AGROW>
                    cd2(end+1,1)=d20; %#ok<AGROW>
                end
            end
        end

        [zm,im]=max(z);
        discreteNOx(iv)=x(im);
        discreteO3(iv)=zm;

        if ~isempty(cx)
            hasInterior(iv)=true;
            [~,b]=max(co);
            rv(end+1,1)=VOClevels(iv); %#ok<AGROW>
            rn(end+1,1)=cx(b); %#ok<AGROW>
            ro(end+1,1)=co(b); %#ok<AGROW>
            rd2(end+1,1)=cd2(b); %#ok<AGROW>
            nmax(end+1,1)=numel(cx); %#ok<AGROW>
            class(iv)="Resolved interior ridge";

            % Independent diagnostic: is upper boundary higher than the
            % selected interior local maximum? If so, the current domain may
            % contain another branch whose maximum lies beyond the boundary.
            upperDominatesInterior(iv)=z(end)>co(b)+o3Tol;
        else
            if im==numel(x)
                class(iv)="Upper NOx boundary maximum";
            elseif im==1
                class(iv)="Lower NOx boundary maximum";
            else
                class(iv)="Unclassified";
            end
        end
    end

    ratio=rv./rn;
    valid=rv>0 & rn>0 & isfinite(ratio);

    RidgeTbl=table(repmat(TK,numel(rv),1),rv,rn,ro,ratio,rd2,nmax, ...
        'VariableNames',{'TempK','VOC_ppb','RidgeNOx_ppb','RidgeO3_ppb', ...
        'VOC_NOx_Ratio','d2O3_dNOx2','NumberOfLocalMaximaAtVOC'});

    DiagTbl=table(repmat(TK,nV,1),VOClevels(:),class,hasInterior,dUpper, ...
        upperStillIncreasing,upperDominatesInterior,discreteNOx,discreteO3, ...
        'VariableNames',{'TempK','VOC_ppb','Classification','HasInteriorRidge', ...
        'dO3dNOx_at_UpperBoundary','UpperBoundary_StillIncreasing', ...
        'UpperBoundary_O3_DominatesInterior','DiscreteMaximumNOx_ppb', ...
        'DiscreteMaximumO3_ppb'});

    meanR=mean(ratio(valid),'omitnan');
    medR=median(ratio(valid),'omitnan');
    meanV=mean(rv(valid),'omitnan');
    meanN=mean(rn(valid),'omitnan');
    meanO=mean(ro(valid),'omitnan');

    resolved=sum(class=="Resolved interior ridge");
    upperMax=sum(class=="Upper NOx boundary maximum");
    lower=sum(class=="Lower NOx boundary maximum");
    still=sum(upperStillIncreasing);
    upperDom=sum(upperDominatesInterior);
    needsLarger=(still>0)||(upperDom>0)||(upperMax>0);

    SumRow=table(TK,meanR,medR,meanV,meanN,meanO,sum(valid),resolved,nV, ...
        100*resolved/nV,upperMax,100*upperMax/nV,still,upperDom,lower,needsLarger, ...
        'VariableNames',{'TempK','Mean_Ridge_VOC_to_NOx','Median_Ridge_VOC_to_NOx', ...
        'Mean_Ridge_VOC_ppb','Mean_Ridge_NOx_ppb','Mean_Ridge_O3_ppb', ...
        'RatioPointsUsed','Resolved_Ridge_Rows','Total_VOC_Rows', ...
        'Resolved_Ridge_Percent','Upper_NOx_Boundary_Maximum_Rows', ...
        'Upper_NOx_Boundary_Maximum_Percent','UpperBoundary_StillIncreasing_Rows', ...
        'UpperBoundary_O3_DominatesInterior_Rows','Lower_NOx_Boundary_Rows', ...
        'Needs_Larger_NOx_Domain'});
end

function [MB,NMB,NRMSE]=performance_stats(M,O)
    m=isfinite(M)&isfinite(O); M=M(m); O=O(m);
    if isempty(M), MB=NaN; NMB=NaN; NRMSE=NaN; return; end
    MB=mean(M-O); NMB=100*sum(M-O)/sum(O);
    RMSE=sqrt(mean((M-O).^2)); NRMSE=100*RMSE/mean(O);
end
