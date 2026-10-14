%% ========================================================================
% F0AM BASE CASE
% FOUR-DAY SPIN-UP + ANALYSIS-DAY O3 DIAGNOSTICS ONLY
%
% Los Angeles | Spin-up: 27-30 July 2019 | Analysis: 31 July 2019 | CB6r2
%
% PURPOSE
%   1) Run the exact base-case spin-up / analysis-day configuration.
%   2) NO isopleths, ridges, temperature sensitivity, or Arrhenius analysis.
%   3) F0AM still integrates at 10-min resolution internally.
%   4) ALL figures and diagnostic tables use HOURLY values only.
%   5) Generate:
%        Figure 1: hourly spin-up convergence + analysis-day comparison
%        Figure 2: continuous hourly spin-up/analysis chronology + observations
%   6) Save figures immediately after creation.
%   7) Save hourly data, convergence diagnostics, and performance statistics
%      immediately to a single Excel workbook.
%
% IMPORTANT CHEMICAL TREATMENT
%   - NO, NO2 and CO reset from hourly observations.
%   - VOC HoldMe treatment unchanged from base case.
%   - Only species already in InitConc are propagated between hourly calls.
%   - Mechanism-generated secondary species are NOT appended to InitConc.
%   - O3 is hard-reset to 15 ppb at July 31 00:00 LT.
%% ========================================================================

clear;
clc;
close all;

set(0,'DefaultFigureRenderer','painters');

%% ========================================================================
% USER SETTINGS
% ========================================================================

xlsx_path = ...
'D:\Final_Temp_inf_on_Ozone_analysis\Refreshed_basecase\INPUT_2019_REFRESHED.xlsx';

out_dir = ...
'D:\Final_Temp_inf_on_Ozone_analysis\Finalization_spinuobasecase\latest\final\finalBasecase_spinupand_converge';

if ~exist(out_dir,'dir')
    mkdir(out_dir);
end

% Master Excel diagnostic workbook
diag_xlsx = fullfile(out_dir,'BaseCase_Spinup_Convergence_Diagnostics.xlsx');

% Start fresh to avoid retaining old worksheets
if exist(diag_xlsx,'file')
    delete(diag_xlsx);
end

%% ========================================================================
% LOCATION / DATES
% ========================================================================

lat = 34.0522;
lon = -118.2437;
UTC_offset = -7;

spinup_start_date = datetime(2019,7,27);
n_spinup_days = 4;

run_date = datetime(2019,7,31);

analysis_O3_reset_ppb = 15.0;

% INTERNAL F0AM integration resolution
dt_minutes = 10;

%% ========================================================================
% CHEMISTRY / MODEL OPTIONS
% ========================================================================

ChemFiles = {
    'CB6r2_K(Met)'
    'CB6r2_J(Met,0)'
    'CB6r2_AllRxns'
    };

for i = 1:numel(ChemFiles)

    fn = regexprep(ChemFiles{i},'\(.*\)','');

    assert(exist([fn '.m'],'file')==2, ...
        'Missing chemistry file: %s.m',fn);

end

ModelOptions.Verbose       = 1;
ModelOptions.EndPointsOnly = 0;
ModelOptions.LinkSteps     = 1;
ModelOptions.IntTime       = dt_minutes*60;

ModelOptions.SavePath = ...
    fullfile(tempdir,'F0AM_tmp_base_spinup_diagnostics');

if ~exist(ModelOptions.SavePath,'dir')
    mkdir(ModelOptions.SavePath);
end

jcorr = 0.5;

% 24-h dilution lifetime
kdil_s = 1/(24*60*60);

%% ========================================================================
% INITIAL CONDITIONS
% ========================================================================

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

BkgdConc = {'DEFAULT',0};

%% ========================================================================
% READ INPUT WORKBOOK
% ========================================================================

assert(exist(xlsx_path,'file')==2, ...
    'Input workbook not found: %s',xlsx_path);

Ttbl = readtable(xlsx_path,'VariableNamingRule','preserve');

vn = lower(regexprep(Ttbl.Properties.VariableNames,'\s+',''));

iTime = find(ismember(vn,{'time','hour','hr'}),1);

iT = find(ismember(vn, ...
    {'temperature','temperatures','tempk'}),1);

iRH = find(ismember(vn, ...
    {'relativehumidity','rh'}),1);

iP = find(ismember(vn, ...
    {'pressure','p'}),1);

iO3 = find(ismember(vn, ...
    {'observedozone','obs_ozone','ozone','o3'}),1);

assert(~isempty(iT) && ...
       ~isempty(iRH) && ...
       ~isempty(iP) && ...
       ~isempty(iO3), ...
       'Workbook must contain Temperature, RH, Pressure, and observed O3.');

assert(height(Ttbl)>=24, ...
    'Workbook must contain at least 24 hourly rows.');

Temp24  = double(Ttbl{1:24,iT});
RH24    = double(Ttbl{1:24,iRH});
P24     = double(Ttbl{1:24,iP});
O3obs24 = double(Ttbl{1:24,iO3});

if any(~isfinite(O3obs24))

    O3obs24 = fillmissing( ...
        O3obs24,'linear','EndValues','nearest');

end

%% ========================================================================
% HOURLY PRECURSOR PROFILE
% ========================================================================

PrecTbl = Ttbl;
vn_prec = vn;

if ~isempty(iTime)

    hours_vec = double(PrecTbl{:,iTime});

    mask24 = ...
        isfinite(hours_vec) & ...
        hours_vec>=0 & ...
        hours_vec<=23;

    PrecTbl24 = PrecTbl(mask24,:);

    [~,first_idx] = unique( ...
        double(PrecTbl24{:,iTime}),'stable');

    PrecTbl24 = PrecTbl24(first_idx,:);

    [~,ord] = sort( ...
        double(PrecTbl24{:,iTime}));

    PrecTbl24 = PrecTbl24(ord,:);

else

    PrecTbl24 = PrecTbl(1:24,:);

end

assert(height(PrecTbl24)>=24, ...
    'Could not construct complete 24-h precursor profile.');

get_col = @(name) ...
    get_numeric_column(PrecTbl24,vn_prec,name);

prec_cols.CO  = get_col('CO');
prec_cols.NO  = get_col('NO');
prec_cols.NO2 = get_col('NO2');

%% ========================================================================
% PREALLOCATE HOURLY SPIN-UP STORAGE
% ========================================================================

SpinupO3 = nan(n_spinup_days,24);

SpinupDateTime = NaT(n_spinup_days,24);

InitConc_now = InitConc_base;

fprintf('\n=========================================================\n');
fprintf('BASE-CASE FOUR-DAY SPIN-UP\n');
fprintf('27-30 JULY 2019\n');
fprintf('=========================================================\n');

%% ========================================================================
% FOUR-DAY SPIN-UP
% ========================================================================

for iDay = 1:n_spinup_days

    this_date = spinup_start_date + days(iDay-1);

    fprintf('\nSpin-up day %d/%d: %s\n', ...
        iDay,n_spinup_days, ...
        datestr(this_date,'yyyy-mm-dd'));

    for H = 0:23

        %% ---------------------------------------------------------------
        % INTERNAL 10-MINUTE F0AM BLOCK
        % ---------------------------------------------------------------

        [time_blk,sun_blk] = ...
            hour_block_sun( ...
            this_date,UTC_offset,lat,lon,H,dt_minutes);

        assert(numel(time_blk.hour)==6, ...
            'Hourly forcing must contain exactly six points.');

        Met_blk = {
            'P',     P24(H+1)*ones(size(time_blk.hour));
            'T',     Temp24(H+1)*ones(size(time_blk.hour));
            'RH',    RH24(H+1)*ones(size(time_blk.hour));
            'SZA',   sun_blk.zenith;
            'jcorr', jcorr;
            'kdil',  kdil_s
            };

        %% Observed hourly precursor constraints

        InitConc_now = ...
            set_species_value( ...
            InitConc_now,'NO',prec_cols.NO(H+1));

        InitConc_now = ...
            set_species_value( ...
            InitConc_now,'NO2',prec_cols.NO2(H+1));

        InitConc_now = ...
            set_species_value( ...
            InitConc_now,'CO',prec_cols.CO(H+1));

        ModelOptions.TimeStamp = ...
            time_blk.hour + time_blk.min/60;

        %% F0AM

        Sblk = F0AM_ModelCore( ...
            Met_blk, ...
            InitConc_now, ...
            ChemFiles, ...
            BkgdConc, ...
            ModelOptions);

        O3_blk = extract_species_series(Sblk,'O3');

        %% ---------------------------------------------------------------
        % HOURLY OUTPUT ONLY
        %
        % Use end-of-hour O3 because this is the chemical state transferred
        % to the next hourly F0AM call.
        % ---------------------------------------------------------------

        if ~isempty(O3_blk)

            SpinupO3(iDay,H+1) = O3_blk(end);

        end

        SpinupDateTime(iDay,H+1) = ...
            this_date + hours(H);

        %% Limited state transfer - SAME AS BASE CASE

        InitConc_now = ...
            last_state_to_init(Sblk,InitConc_now);

    end

    %% ---------------------------------------------------------------
    % SAVE AFTER EVERY SPIN-UP DAY
    % ---------------------------------------------------------------

    DayTbl = table( ...
        (0:23)', ...
        SpinupO3(iDay,:)', ...
        'VariableNames', ...
        {'Hour_LT','ModeledO3_ppb'});

    writetable( ...
        DayTbl, ...
        diag_xlsx, ...
        'Sheet',sprintf('Spinup_Day_%d',iDay));

end

%% ========================================================================
% FINAL SPIN-UP STATE
% ========================================================================

O3_before_analysis_reset = ...
    get_init_species_value(InitConc_now,'O3');

fprintf('\nFinal spin-up O3 before analysis reset = %.3f ppb\n', ...
    O3_before_analysis_reset);

%% ========================================================================
% HARD O3 RESET - JULY 31 00:00 LT
% ========================================================================

InitConc_now = ...
    set_species_value( ...
    InitConc_now,'O3',analysis_O3_reset_ppb);

O3_after_analysis_reset = ...
    get_init_species_value(InitConc_now,'O3');

assert( ...
    abs(O3_after_analysis_reset-analysis_O3_reset_ppb)<1e-12, ...
    'Analysis-day O3 reset failed.');

fprintf('Analysis O3 reset: %.3f -> %.3f ppb\n', ...
    O3_before_analysis_reset,O3_after_analysis_reset);

%% ========================================================================
% ANALYSIS DAY
% ========================================================================

AnalysisO3_hr = nan(24,1);

fprintf('\n=========================================================\n');
fprintf('ANALYSIS DAY: 31 JULY 2019\n');
fprintf('=========================================================\n');

for H = 0:23

    [time_blk,sun_blk] = ...
        hour_block_sun( ...
        run_date,UTC_offset,lat,lon,H,dt_minutes);

    Met_blk = {
        'P',     P24(H+1)*ones(size(time_blk.hour));
        'T',     Temp24(H+1)*ones(size(time_blk.hour));
        'RH',    RH24(H+1)*ones(size(time_blk.hour));
        'SZA',   sun_blk.zenith;
        'jcorr', jcorr;
        'kdil',  kdil_s
        };

    InitConc_now = ...
        set_species_value( ...
        InitConc_now,'NO',prec_cols.NO(H+1));

    InitConc_now = ...
        set_species_value( ...
        InitConc_now,'NO2',prec_cols.NO2(H+1));

    InitConc_now = ...
        set_species_value( ...
        InitConc_now,'CO',prec_cols.CO(H+1));

    ModelOptions.TimeStamp = ...
        time_blk.hour + time_blk.min/60;

    Sblk = F0AM_ModelCore( ...
        Met_blk, ...
        InitConc_now, ...
        ChemFiles, ...
        BkgdConc, ...
        ModelOptions);

    O3_blk = extract_species_series(Sblk,'O3');

    %% HOURLY MEAN FOR SMOOTH HOURLY ANALYSIS PLOT

    if ~isempty(O3_blk)

        AnalysisO3_hr(H+1) = ...
            mean(O3_blk,'omitnan');

    end

    InitConc_now = ...
        last_state_to_init(Sblk,InitConc_now);

end

%% ========================================================================
% SAVE COMPLETE HOURLY DATA IMMEDIATELY
% ========================================================================

Hour_LT = (0:23)';

HourlyTbl = table( ...
    Hour_LT, ...
    SpinupO3(1,:)', ...
    SpinupO3(2,:)', ...
    SpinupO3(3,:)', ...
    SpinupO3(4,:)', ...
    AnalysisO3_hr, ...
    O3obs24, ...
    'VariableNames',{ ...
    'Hour_LT', ...
    'Spinup_Day1_O3_ppb', ...
    'Spinup_Day2_O3_ppb', ...
    'Spinup_Day3_O3_ppb', ...
    'Spinup_Day4_O3_ppb', ...
    'AnalysisDay_ModelO3_ppb', ...
    'AnalysisDay_ObservedO3_ppb'});

writetable( ...
    HourlyTbl, ...
    diag_xlsx, ...
    'Sheet','Hourly_O3');

%% ========================================================================
% SPIN-UP CONVERGENCE DIAGNOSTICS
% ========================================================================

% Difference between consecutive spin-up days at corresponding local hours

Delta12 = SpinupO3(2,:)' - SpinupO3(1,:)';
Delta23 = SpinupO3(3,:)' - SpinupO3(2,:)';
Delta34 = SpinupO3(4,:)' - SpinupO3(3,:)';

ConvHourlyTbl = table( ...
    Hour_LT, ...
    Delta12, ...
    Delta23, ...
    Delta34, ...
    abs(Delta12), ...
    abs(Delta23), ...
    abs(Delta34), ...
    'VariableNames',{ ...
    'Hour_LT', ...
    'Day2_minus_Day1_ppb', ...
    'Day3_minus_Day2_ppb', ...
    'Day4_minus_Day3_ppb', ...
    'Abs_Day2_minus_Day1_ppb', ...
    'Abs_Day3_minus_Day2_ppb', ...
    'Abs_Day4_minus_Day3_ppb'});

writetable( ...
    ConvHourlyTbl, ...
    diag_xlsx, ...
    'Sheet','Convergence_Hourly');

%% ========================================================================
% DAILY CONVERGENCE SUMMARY
% ========================================================================

pairs = [
    1 2
    2 3
    3 4
    ];

PairName = strings(3,1);
MeanBias_ppb = nan(3,1);
MeanAbsDiff_ppb = nan(3,1);
RMSE_ppb = nan(3,1);
MaxAbsDiff_ppb = nan(3,1);
Correlation_R = nan(3,1);

for k = 1:3

    A = SpinupO3(pairs(k,1),:)';
    B = SpinupO3(pairs(k,2),:)';

    good = isfinite(A) & isfinite(B);

    A = A(good);
    B = B(good);

    D = B-A;

    PairName(k) = sprintf( ...
        'Day%d_vs_Day%d', ...
        pairs(k,2),pairs(k,1));

    MeanBias_ppb(k) = ...
        mean(D,'omitnan');

    MeanAbsDiff_ppb(k) = ...
        mean(abs(D),'omitnan');

    RMSE_ppb(k) = ...
        sqrt(mean(D.^2,'omitnan'));

    MaxAbsDiff_ppb(k) = ...
        max(abs(D),[],'omitnan');

    if numel(A)>1

        C = corrcoef(A,B);

        Correlation_R(k) = C(1,2);

    end

end

ConvergenceSummary = table( ...
    PairName, ...
    MeanBias_ppb, ...
    MeanAbsDiff_ppb, ...
    RMSE_ppb, ...
    MaxAbsDiff_ppb, ...
    Correlation_R);

writetable( ...
    ConvergenceSummary, ...
    diag_xlsx, ...
    'Sheet','Convergence_Summary');

%% ========================================================================
% ANALYSIS-DAY MODEL PERFORMANCE
% ========================================================================

[MB,NMB,NRMSE,RMSE,MAE,R] = ...
    performance_stats_extended( ...
    AnalysisO3_hr,O3obs24);

PerformanceTbl = table( ...
    MB,NMB,RMSE,NRMSE,MAE,R, ...
    'VariableNames',{ ...
    'MB_ppb', ...
    'NMB_percent', ...
    'RMSE_ppb', ...
    'NRMSE_percent', ...
    'MAE_ppb', ...
    'Pearson_R'});

writetable( ...
    PerformanceTbl, ...
    diag_xlsx, ...
    'Sheet','Model_Performance');

%% ========================================================================
% RUN SUMMARY
% ========================================================================

RunSummary = table( ...
    n_spinup_days, ...
    dt_minutes, ...
    24, ...
    O3_before_analysis_reset, ...
    analysis_O3_reset_ppb, ...
    mean(abs(Delta34),'omitnan'), ...
    max(abs(Delta34),[],'omitnan'), ...
    'VariableNames',{ ...
    'Number_Spinup_Days', ...
    'Internal_F0AM_dt_minutes', ...
    'Dilution_Lifetime_hours', ...
    'FinalSpinupO3_ppb', ...
    'AnalysisResetO3_ppb', ...
    'Day4_vs_Day3_MeanAbsDifference_ppb', ...
    'Day4_vs_Day3_MaxAbsDifference_ppb'});

writetable( ...
    RunSummary, ...
    diag_xlsx, ...
    'Sheet','Run_Summary');

%% ========================================================================
% FIGURE 1
% HOURLY SPIN-UP CONVERGENCE + ANALYSIS DAY
% ========================================================================

f1 = figure( ...
    'Color','w', ...
    'Position',[100 80 1300 760]);

hold on;

% Four spin-up days
plot(Hour_LT,SpinupO3(1,:)', ...
    '-','LineWidth',2.0, ...
    'DisplayName','Spin-up Day 1: Jul 27');

plot(Hour_LT,SpinupO3(2,:)', ...
    '-','LineWidth',2.0, ...
    'DisplayName','Spin-up Day 2: Jul 28');

plot(Hour_LT,SpinupO3(3,:)', ...
    '-','LineWidth',2.0, ...
    'DisplayName','Spin-up Day 3: Jul 29');

plot(Hour_LT,SpinupO3(4,:)', ...
    '-','LineWidth',2.3, ...
    'DisplayName','Spin-up Day 4: Jul 30');

% Analysis modeled
plot(Hour_LT,AnalysisO3_hr, ...
    '-','LineWidth',2.6, ...
    'DisplayName','Analysis Day: Jul 31 modeled');

% Analysis observed
plot(Hour_LT,O3obs24, ...
    'o-','LineWidth',2.0, ...
    'MarkerSize',5, ...
    'MarkerFaceColor','w', ...
    'DisplayName','Analysis Day: Jul 31 observed');

xlabel('Hour (LT)','FontSize',14);

ylabel('O_3 (ppb)','FontSize',14);

title( ...
    'Los Angeles Base Case: Spin-up Convergence and Analysis-Day O_3', ...
    'FontSize',16, ...
    'FontWeight','bold');

xlim([0 23]);
xticks(0:3:23);

allY = [
    SpinupO3(:);
    AnalysisO3_hr;
    O3obs24
    ];

goodY = allY(isfinite(allY));

if ~isempty(goodY)

    ymax = max(goodY);

    ylim([0 max(10,ceil(1.15*ymax/10)*10)]);

end

grid on;
box on;

ax = gca;
ax.FontSize = 12;
ax.LineWidth = 1.0;
ax.Layer = 'top';

% Legend deliberately outside the data region
lgd = legend( ...
    'Location','eastoutside');

lgd.FontSize = 11;
lgd.Box = 'off';

%% Stats box - outside trend region

statsText = sprintf([ ...
    'Spin-up convergence\n' ...
    'Day 4 vs Day 3\n' ...
    'Mean |\\DeltaO_3| = %.2f ppb\n' ...
    'Max |\\DeltaO_3| = %.2f ppb\n' ...
    'RMSE = %.2f ppb\n' ...
    'r = %.3f\n\n' ...
    'Analysis-day performance\n' ...
    'MB = %.2f ppb\n' ...
    'NMB = %.1f%%\n' ...
    'RMSE = %.2f ppb\n' ...
    'NRMSE = %.1f%%\n' ...
    'r = %.3f'], ...
    MeanAbsDiff_ppb(3), ...
    MaxAbsDiff_ppb(3), ...
    RMSE_ppb(3), ...
    Correlation_R(3), ...
    MB,NMB,RMSE,NRMSE,R);

% Reserve right side of figure for legend/stats
ax.Position = [0.08 0.11 0.65 0.81];

annotation( ...
    f1,'textbox', ...
    [0.765 0.14 0.21 0.30], ...
    'String',statsText, ...
    'FitBoxToText','off', ...
    'BackgroundColor','w', ...
    'EdgeColor',[0.35 0.35 0.35], ...
    'LineWidth',1.0, ...
    'FontSize',10.5, ...
    'Interpreter','tex');

drawnow;

savefig( ...
    f1, ...
    fullfile(out_dir, ...
    'Figure_Spinup_Convergence_Analysis.fig'));

exportgraphics( ...
    f1, ...
    fullfile(out_dir, ...
    'Figure_Spinup_Convergence_Analysis.png'), ...
    'Resolution',600);

exportgraphics( ...
    f1, ...
    fullfile(out_dir, ...
    'Figure_Spinup_Convergence_Analysis.pdf'), ...
    'ContentType','vector');

%% ========================================================================
% FIGURE 2
% CONTINUOUS HOURLY CHRONOLOGY
% ========================================================================

% Construct chronological hourly model vector:
% 4 spin-up days + analysis day

continuousModel = [
    SpinupO3(1,:)'
    SpinupO3(2,:)'
    SpinupO3(3,:)'
    SpinupO3(4,:)'
    AnalysisO3_hr
    ];

continuousTime = ...
    (spinup_start_date:hours(1): ...
    run_date+hours(23))';

assert( ...
    numel(continuousTime)==numel(continuousModel), ...
    'Continuous chronology size mismatch.');

ContinuousTbl = table( ...
    continuousTime, ...
    continuousModel, ...
    'VariableNames',{ ...
    'LocalDateTime', ...
    'ModeledO3_ppb'});

% Add observed analysis O3 only at Jul 31
ObservedContinuous = nan(size(continuousModel));

ObservedContinuous(end-23:end) = O3obs24;

ContinuousTbl.ObservedO3_ppb = ...
    ObservedContinuous;

writetable( ...
    ContinuousTbl, ...
    diag_xlsx, ...
    'Sheet','Continuous_Hourly');

%% Plot

f2 = figure( ...
    'Color','w', ...
    'Position',[80 80 1450 720]);

hold on;

plot( ...
    continuousTime, ...
    continuousModel, ...
    '-', ...
    'LineWidth',2.3, ...
    'DisplayName','Modeled O_3');

analysisTimes = ...
    run_date + hours(0:23);

plot( ...
    analysisTimes, ...
    O3obs24, ...
    'o-', ...
    'LineWidth',2.0, ...
    'MarkerSize',5.5, ...
    'MarkerFaceColor','w', ...
    'DisplayName','Observed O_3 - July 31');

% Day boundaries
for d = 1:4

    xline( ...
        spinup_start_date+days(d), ...
        '--', ...
        'LineWidth',1.0, ...
        'HandleVisibility','off');

end

xlabel('Local Date and Time','FontSize',14);

ylabel('O_3 (ppb)','FontSize',14);

title( ...
    'Los Angeles Base Case: Continuous Spin-up and Analysis', ...
    'FontSize',16, ...
    'FontWeight','bold');

grid on;
box on;

ax = gca;
ax.FontSize = 12;
ax.LineWidth = 1.0;
ax.Layer = 'top';

xlim([ ...
    spinup_start_date ...
    run_date+hours(23)]);

% Clean date formatting
xtickformat('MMM dd, HH:mm');

allY2 = [
    continuousModel;
    O3obs24
    ];

allY2 = allY2(isfinite(allY2));

if ~isempty(allY2)

    ylim([0 max(10,ceil(1.15*max(allY2)/10)*10)]);

end

legend( ...
    'Location','northwest', ...
    'Box','off', ...
    'FontSize',11);

%% Performance stats box
% Place in lower-right area to avoid daytime O3 maxima.

statsText2 = sprintf([ ...
    'July 31 model performance\n' ...
    'MB = %.2f ppb\n' ...
    'NMB = %.1f%%\n' ...
    'RMSE = %.2f ppb\n' ...
    'NRMSE = %.1f%%\n' ...
    'MAE = %.2f ppb\n' ...
    'r = %.3f'], ...
    MB,NMB,RMSE,NRMSE,MAE,R);

annotation( ...
    f2,'textbox', ...
    [0.74 0.15 0.19 0.20], ...
    'String',statsText2, ...
    'FitBoxToText','on', ...
    'BackgroundColor','w', ...
    'EdgeColor',[0.35 0.35 0.35], ...
    'LineWidth',1.0, ...
    'FontSize',10.5, ...
    'Interpreter','tex');

drawnow;

savefig( ...
    f2, ...
    fullfile(out_dir, ...
    'Figure_Continuous_Spinup_Analysis.fig'));

exportgraphics( ...
    f2, ...
    fullfile(out_dir, ...
    'Figure_Continuous_Spinup_Analysis.png'), ...
    'Resolution',600);

exportgraphics( ...
    f2, ...
    fullfile(out_dir, ...
    'Figure_Continuous_Spinup_Analysis.pdf'), ...
    'ContentType','vector');

%% ========================================================================
% FIGURE DIAGNOSTICS SHEET
% ========================================================================

FigureDiagnostics = table( ...
    ["Spinup convergence"; ...
     "Continuous chronology"], ...
    ["Hourly";"Hourly"], ...
    ["600 dpi PNG + vector PDF + MATLAB FIG"; ...
     "600 dpi PNG + vector PDF + MATLAB FIG"], ...
    ["Day-to-day convergence + July 31 performance"; ...
     "July 31 observed-model performance"], ...
    'VariableNames',{ ...
    'Figure', ...
    'PlotResolution', ...
    'SavedFormats', ...
    'DiagnosticsShown'});

writetable( ...
    FigureDiagnostics, ...
    diag_xlsx, ...
    'Sheet','Figure_Diagnostics');

%% ========================================================================
% COMMAND-WINDOW SUMMARY
% ========================================================================

fprintf('\n=========================================================\n');
fprintf('SPIN-UP CONVERGENCE SUMMARY\n');
fprintf('=========================================================\n');

disp(ConvergenceSummary);

fprintf('\n=========================================================\n');
fprintf('JULY 31 MODEL PERFORMANCE\n');
fprintf('=========================================================\n');

disp(PerformanceTbl);

fprintf('\nFinal spin-up O3 before reset = %.3f ppb\n', ...
    O3_before_analysis_reset);

fprintf('Analysis-day reset O3         = %.3f ppb\n', ...
    analysis_O3_reset_ppb);

fprintf('\nAll diagnostics saved to:\n%s\n',out_dir);

fprintf('\nExcel diagnostic workbook:\n%s\n',diag_xlsx);

fprintf('\nDONE. Isopleth calculations were NOT executed.\n');

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================

function v = get_numeric_column(T,vn,name)

    key = lower(regexprep(name,'\s+',''));

    idx = find(strcmpi(vn,key),1);

    assert(~isempty(idx), ...
        'Required column "%s" not found.',name);

    v = double(T{:,idx});

end

% -------------------------------------------------------------------------

function InitConc = ...
    set_species_value(InitConc,sp,val)

    if ~isfinite(val)
        return;
    end

    idx = find( ...
        strcmpi(InitConc(:,1),sp),1);

    if ~isempty(idx)
        InitConc{idx,2} = max(double(val),0);
    end

end

% -------------------------------------------------------------------------

function [time_blk,sun_blk] = ...
    hour_block_sun( ...
    run_date,UTC_offset,lat,lon,H,dt_minutes)

    t0 = run_date + hours(H);

    t_local = ...
        (t0:minutes(dt_minutes): ...
        (t0+hours(1)-minutes(dt_minutes)))';

    o = ones(size(t_local));

    time_blk.year  = year(t_local).*o;
    time_blk.month = month(t_local).*o;
    time_blk.day   = day(t_local).*o;

    time_blk.hour = hour(t_local);
    time_blk.min  = minute(t_local);
    time_blk.sec  = second(t_local);

    time_blk.UTC = UTC_offset*o;

    loc.latitude  = lat;
    loc.longitude = lon;
    loc.altitude  = 90;

    sun_blk = ...
        sun_position(time_blk,loc);

end

% -------------------------------------------------------------------------

function val = ...
    get_init_species_value(InitConc,sp)

    idx = find( ...
        strcmpi(InitConc(:,1),sp),1);

    if isempty(idx) || ...
            ~isnumeric(InitConc{idx,2})

        val = NaN;

    else

        val = double(InitConc{idx,2});

    end

end

% -------------------------------------------------------------------------

function s = extract_species_series(S,spc)

    s = [];

    if isfield(S,'Conc') && ...
            istable(S.Conc) && ...
            any(strcmpi( ...
            S.Conc.Properties.VariableNames,spc))

        j = find( ...
            strcmpi( ...
            S.Conc.Properties.VariableNames,spc),1);

        s = S.Conc.( ...
            S.Conc.Properties.VariableNames{j});

    elseif isfield(S,'Conc') && ...
            isstruct(S.Conc) && ...
            isfield(S.Conc,spc)

        s = S.Conc.(spc);

    elseif isfield(S,'Chem') && ...
            isfield(S.Chem,'AllSpc') && ...
            isnumeric(S.Conc)

        j = find( ...
            strcmpi(S.Chem.AllSpc,spc),1);

        if ~isempty(j)
            s = S.Conc(:,j);
        end

    end

    if isrow(s)
        s = s';
    end

end

% -------------------------------------------------------------------------

function InitConc_next = ...
    last_state_to_init(S,InitConc_template)

    InitConc_next = InitConc_template;

    names = {};
    concM = [];

    if istable(S.Conc)

        names = ...
            S.Conc.Properties.VariableNames;

        concM = S.Conc{end,:};

    elseif isstruct(S.Conc)

        names = fieldnames(S.Conc);

        concM = cellfun( ...
            @(f)S.Conc.(f)(end),names);

    elseif isfield(S,'Chem') && ...
            isfield(S.Chem,'AllSpc') && ...
            isnumeric(S.Conc)

        names = S.Chem.AllSpc;
        concM = S.Conc(end,:);

    end

    % IMPORTANT:
    % update ONLY species already contained in InitConc_template

    for i = 1:size(InitConc_next,1)

        j = find( ...
            strcmpi(names, ...
            InitConc_next{i,1}),1);

        if ~isempty(j) && ...
                isfinite(concM(j))

            InitConc_next{i,2} = ...
                concM(j);

        end

    end

end

% -------------------------------------------------------------------------

function [MB,NMB,NRMSE,RMSE,MAE,R] = ...
    performance_stats_extended(M,O)

    good = ...
        isfinite(M) & ...
        isfinite(O);

    M = M(good);
    O = O(good);

    if isempty(M)

        MB    = NaN;
        NMB   = NaN;
        NRMSE = NaN;
        RMSE  = NaN;
        MAE   = NaN;
        R     = NaN;

        return;

    end

    MB = mean(M-O);

    if sum(O)~=0
        NMB = 100*sum(M-O)/sum(O);
    else
        NMB = NaN;
    end

    RMSE = sqrt( ...
        mean((M-O).^2));

    if mean(O)~=0
        NRMSE = ...
            100*RMSE/mean(O);
    else
        NRMSE = NaN;
    end

    MAE = mean(abs(M-O));

    if numel(M)>1

        C = corrcoef(M,O);
        R = C(1,2);

    else

        R = NaN;

    end

end