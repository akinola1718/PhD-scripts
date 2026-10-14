%% ========================================================================
% F0AM REAL CASE - 4-DAY SPIN-UP + ANALYSIS-DAY DIAGNOSTICS
% Los Angeles historical 5-year blocks | CB6r2
%
% Matches the finalized base-case treatment:
%   * 4 complete spin-up days + retained analysis day
%   * limited state transfer: only species already in InitConc propagate hour-to-hour
%   * primary VOC HoldMe treatment retained; no daily VOC reset
%   * NO, NO2 and CO constrained hourly
%   * O3 hard-reset at 00:00 of analysis day to block initial O3
%   * exactly six forcing points/hour: H:00,...,H:50
%   * fixed 24-h dilution lifetime, kdil = 1/(24*3600) s^-1
%   * analysis-day maximum modeled O3 in 08:00-20:00 is isopleth parent state
%   * 31 x 31 VOC-NOx isopleth, block-specific historical temperature
%
% Additional analysis-day outputs for EACH historical block:
%   1) complete F0AM chemical state at 10-min resolution (CSV)
%   2) O3 rate diagnostic + HO2/OH evolution (CSV + figures)
%   3) peroxyl radicals (HO2, RO2, HO2+RO2) in ppt (CSV + figure)
%   4) observed vs modeled O3 growth rate (CSV + figure)
%   5) publication-quality diurnal, continuous spin-up, convergence figures
%
% NOTE ON RO2:
% If F0AM exposes an explicit species/family named RO2, it is used directly.
% Otherwise RO2 is left NaN (not invented from an undocumented species list),
% while HO2 is still exported and plotted.
%% ========================================================================

clear; clc; close all;
set(0,'DefaultFigureRenderer','painters');
city_name='LosAngeles';

%% ---------------- USER SETTINGS ----------------
input_root = 'D:\Final_Temp_Inf_on_Ozone_analysis';
out_root   = 'D:\Final_Temp_inf_on_Ozone_analysis\Finalization_spinuobasecase\latest\final\FinalizedRealcase_withVOCholdme';


if ~exist(out_root,'dir'), mkdir(out_root); end

blocks_to_run = 1:5;
block_labels = {'1996_2000','2001_2005','2006_2010','2011_2015','2016_2020'};
block_years  = [2000 2005 2010 2015 2020];
block_temps  = [290.6 290.4 290.9 290.7 293.0];

lat=34.0522; lon=-118.2437; UTC_offset=-7;
spinup_days=4; dt_minutes=10;
iso_start_hour=8; iso_end_hour=20;

n_nox=31; n_voc=31;
NOx_ppb_levels=linspace(0,50,n_nox);
VOC_ppb_levels=linspace(0,150,n_voc);
[NOx_ppb_grid,VOC_ppb_grid]=meshgrid(NOx_ppb_levels,VOC_ppb_levels);

%% ---------------- CHEMISTRY / MODEL OPTIONS ----------------
ChemFiles={'CB6r2_K(Met)';'CB6r2_J(Met,0)';'CB6r2_AllRxns'};
for i=1:numel(ChemFiles)
    fn=regexprep(ChemFiles{i},'\(.*\)','');
    assert(exist([fn '.m'],'file')==2,'Missing chemistry file: %s.m',fn);
end
ModelOptions.Verbose=1;
ModelOptions.EndPointsOnly=0;
ModelOptions.LinkSteps=1;
ModelOptions.IntTime=dt_minutes*60;
ModelOptions.SavePath=fullfile(tempdir,'F0AM_tmp_realcase_final');
if ~exist(ModelOptions.SavePath,'dir'),mkdir(ModelOptions.SavePath);end
jcorr=0.5;
kdil_s=1/(24*3600);
BkgdConc={'DEFAULT',0};
voc_species={'ETHA','ETHY','PRPA','ALD2','FORM','ACET','ETH','PAR','OLE','IOLE','TOL','XYL','BENZ','ISOP'};

AllPerformance=table(); AllRidgeSummary=table();
CombinedDiurnal=table((0:23)','VariableNames',{'Hour'});

%% ========================================================================
% LOOP OVER REAL-CASE BLOCKS
%% ========================================================================
for ib=blocks_to_run
    block=block_labels{ib}; TK=block_temps(ib);
    run_date=datetime(block_years(ib),7,31);
    xlsx_path=fullfile(input_root,['Input ' block '.xlsx']);
    out_dir=fullfile(out_root,block);
    if ~exist(out_dir,'dir'),mkdir(out_dir);end
    assert(exist(xlsx_path,'file')==2,'Missing workbook: %s',xlsx_path);

    fprintf('\n============================================================\n');
    fprintf('REAL CASE %s | T = %.3f K | tau_dil = 24 h\n',strrep(block,'_','-'),TK);
    fprintf('============================================================\n');

    InitConc_base=get_block_initial_conditions(block);
    O3_reset_ppb=init_species_value(InitConc_base,'O3');

    %% ---------------- READ REPRESENTATIVE 24-H PROFILE ----------------
    Ttbl=readtable(xlsx_path,'VariableNamingRule','preserve');
    vn=lower(regexprep(Ttbl.Properties.VariableNames,'[^a-zA-Z0-9]',''));
    iTime=find(ismember(vn,{'time','hour','hr'}),1);
    iT=find(ismember(vn,{'temperature','temperatures','tempk'}),1);
    iRH=find(ismember(vn,{'relativehumidity','rh'}),1);
    iP=find(ismember(vn,{'pressure','p'}),1);
    iO3=find(ismember(vn,{'observedozone','obsozone','ozone','o3'}),1);
    assert(~isempty(iT)&&~isempty(iRH)&&~isempty(iP)&&~isempty(iO3),'Workbook %s lacks required meteorology/O3.',xlsx_path);
    if ~isempty(iTime)
        hv=double(Ttbl{:,iTime}); m=isfinite(hv)&hv>=0&hv<=23;
        T24=Ttbl(m,:); [~,u]=unique(double(T24{:,iTime}),'stable'); T24=T24(u,:);
        [~,ord]=sort(double(T24{:,iTime})); T24=T24(ord,:);
    else
        T24=Ttbl(1:min(24,height(Ttbl)),:);
    end
    assert(height(T24)>=24,'Could not construct complete 24-h profile for %s.',block); T24=T24(1:24,:);
    Temp24=double(T24{:,iT}); RH24=double(T24{:,iRH}); P24=double(T24{:,iP}); O3obs24=double(T24{:,iO3});
    O3obs24=fillmissing(O3obs24,'linear','EndValues','nearest');
    vn24=lower(regexprep(T24.Properties.VariableNames,'[^a-zA-Z0-9]',''));
    precNO=get_numeric_column(T24,vn24,'NO'); precNO2=get_numeric_column(T24,vn24,'NO2'); precCO=get_numeric_column(T24,vn24,'CO');

    %% ---------------- 3-DAY SPIN-UP ----------------
    InitConc_now=InitConc_base;
    nDaysTotal=spinup_days+1;
    O3_day_hourly=nan(24,nDaysTotal);
    day_dates=[(run_date-days(spinup_days)):days(1):run_date]';
    continuous_time=datetime.empty(0,1); continuous_O3=[];

    for iDay=1:spinup_days
        this_date=run_date-days(spinup_days-iDay+1);
        fprintf('Spin-up day %d/%d: %s\n',iDay,spinup_days,datestr(this_date,'yyyy-mm-dd'));
        for H=0:23
            [time_blk,sun_blk]=hour_block_sun(this_date,UTC_offset,lat,lon,H,dt_minutes);
            InitConc_now=set_species_value(InitConc_now,'NO',precNO(H+1));
            InitConc_now=set_species_value(InitConc_now,'NO2',precNO2(H+1));
            InitConc_now=set_species_value(InitConc_now,'CO',precCO(H+1));
            Met_blk={'P',P24(H+1)*ones(6,1);'T',Temp24(H+1)*ones(6,1);'RH',RH24(H+1)*ones(6,1); ...
                     'SZA',sun_blk.zenith;'jcorr',jcorr;'kdil',kdil_s};
            ModelOptions.TimeStamp=time_blk.hour+time_blk.min/60;
            Sblk=F0AM_ModelCore(Met_blk,InitConc_now,ChemFiles,BkgdConc,ModelOptions);
            O3b=extract_species_series(Sblk,'O3'); n=min(6,numel(O3b));
            if n>0
                O3_day_hourly(H+1,iDay)=mean(O3b(1:n),'omitnan');
                continuous_time=[continuous_time; this_date+hours(H)+minutes((0:10:50)')]; %#ok<AGROW>
                continuous_O3=[continuous_O3; O3b(1:n)]; %#ok<AGROW>
            end
            InitConc_now=last_state_to_init(Sblk,InitConc_now);
        end
    end
    spinup_end_O3=init_species_value(InitConc_now,'O3');

    %% ---------------- ANALYSIS DAY ----------------
    InitConc_now=set_species_value(InitConc_now,'O3',O3_reset_ppb);
    fprintf('Analysis-day O3 reset = %.4f ppb; spin-up endpoint = %.4f ppb\n',O3_reset_ppb,spinup_end_O3);

    O3_model_hr=nan(24,1); NOx_init_at_hour=nan(24,1); VOC_init_at_hour=nan(24,1);
    analysis_time=datetime.empty(0,1); analysis_O3=[]; AnalysisState=table();
    ParentInitByHour=cell(24,1);

    for H=0:23
        [time_blk,sun_blk]=hour_block_sun(run_date,UTC_offset,lat,lon,H,dt_minutes);
        InitConc_now=set_species_value(InitConc_now,'NO',precNO(H+1));
        InitConc_now=set_species_value(InitConc_now,'NO2',precNO2(H+1));
        InitConc_now=set_species_value(InitConc_now,'CO',precCO(H+1));
        NOx_init_at_hour(H+1)=init_sum_NOx(InitConc_now);
        VOC_init_at_hour(H+1)=init_sum_VOC(InitConc_now,voc_species);
        ParentInitByHour{H+1}=InitConc_now;
        Met_blk={'P',P24(H+1)*ones(6,1);'T',Temp24(H+1)*ones(6,1);'RH',RH24(H+1)*ones(6,1); ...
                 'SZA',sun_blk.zenith;'jcorr',jcorr;'kdil',kdil_s};
        ModelOptions.TimeStamp=time_blk.hour+time_blk.min/60;
        Sblk=F0AM_ModelCore(Met_blk,InitConc_now,ChemFiles,BkgdConc,ModelOptions);
        O3b=extract_species_series(Sblk,'O3'); n=min(6,numel(O3b));
        if n>0
            tb=run_date+hours(H)+minutes((0:10:50)'); tb=tb(1:n);
            O3_model_hr(H+1)=mean(O3b(1:n),'omitnan');
            analysis_time=[analysis_time;tb]; analysis_O3=[analysis_O3;O3b(1:n)]; %#ok<AGROW>
            AnalysisState=[AnalysisState;state_to_table(Sblk,tb)]; %#ok<AGROW>
            continuous_time=[continuous_time;tb]; continuous_O3=[continuous_O3;O3b(1:n)]; %#ok<AGROW>
        end
        InitConc_now=last_state_to_init(Sblk,InitConc_now);
    end
    O3_day_hourly(:,end)=O3_model_hr;

    %% ---------------- SAVE FULL ANALYSIS-DAY CHEMICAL STATE ----------------
    state_csv=fullfile(out_dir,sprintf('%s_AnalysisDay_FullChemicalState_10min.csv',block));
    writetable(AnalysisState,state_csv);

    %% ---------------- DIURNAL + PERFORMANCE ----------------
    DiurnalTbl=table((0:23)',O3obs24,O3_model_hr,NOx_init_at_hour,VOC_init_at_hour, ...
        'VariableNames',{'Hour','ObservedO3_ppb','ModeledO3_ppb','StartHour_NOx_ppb','StartHour_VOC_ppb'});
    writetable(DiurnalTbl,fullfile(out_dir,sprintf('%s_Diurnal.csv',block)));
    [MB,NMB,RMSE,NRMSE]=performance_stats(O3_model_hr,O3obs24);
    AllPerformance=[AllPerformance;table(string(block),TK,MB,NMB,RMSE,NRMSE, ...
        'VariableNames',{'Block','TempK','MB_ppb','NMB_percent','RMSE_ppb','NRMSE_percent'})]; %#ok<AGROW>
    CombinedDiurnal.(['Observed_' block])=O3obs24;
    CombinedDiurnal.(['Modeled_' block])=O3_model_hr;

    f=figure('Color','w','Units','inches','Position',[1 1 8.2 5.5]); hold on;
    plot(0:23,O3obs24,'ko-','LineWidth',2.2,'MarkerSize',6,'MarkerFaceColor','w','DisplayName','Observed');
    plot(0:23,O3_model_hr,'s-','LineWidth',2.0,'MarkerSize',5.5,'DisplayName','Modeled');
    xlabel('Local time (h)'); ylabel('O_3 (ppb)'); title(sprintf('Los Angeles Real Case %s',strrep(block,'_','-')));
    xlim([0 23]); xticks(0:3:23); grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_AnalysisDay_Diurnal',block)); close(f);

    %% ---------------- CONTINUOUS SPIN-UP + ANALYSIS FIGURE ----------------
    f=figure('Color','w','Units','inches','Position',[1 1 10.5 5.7]); hold on;
    plot(continuous_time,continuous_O3,'LineWidth',2.0,'DisplayName','Modeled O_3');
    obs_t=run_date+hours((0:23)'); plot(obs_t,O3obs24,'o-','LineWidth',1.8,'MarkerSize',5,'DisplayName','Observed O_3 - analysis day');
    for dd=1:spinup_days, xline(run_date-days(spinup_days-dd+1),'--','LineWidth',1.0,'HandleVisibility','off'); end
    xline(run_date,'--','LineWidth',1.2,'HandleVisibility','off');
    xlabel('Local date and time'); ylabel('O_3 (ppb)'); title(sprintf('Los Angeles %s: Continuous Spin-up and Analysis',strrep(block,'_','-')));
    grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_Continuous_Spinup_Analysis',block)); close(f);

    %% ---------------- CONVERGENCE FIGURE ----------------
    f=figure('Color','w','Units','inches','Position',[1 1 8.2 5.5]); hold on;
    for d=1:nDaysTotal
        lw=1.5; if d==nDaysTotal,lw=2.7;end
        plot(0:23,O3_day_hourly(:,d),'LineWidth',lw,'DisplayName',datestr(day_dates(d),'mmm dd'));
    end
    xlabel('Hour (LT)'); ylabel('Modeled O_3 (ppb)'); title(sprintf('%s Spin-up Convergence',strrep(block,'_','-')));
    xlim([0 23]); xticks(0:3:23); grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_Spinup_Convergence',block)); close(f);
    ConvTbl=array2table([(0:23)' O3_day_hourly]); ConvTbl.Properties.VariableNames=[{'Hour'},cellstr("Day_"+string(1:nDaysTotal))];
    writetable(ConvTbl,fullfile(out_dir,sprintf('%s_Spinup_Convergence.csv',block)));

    %% ---------------- ANALYSIS-DAY RADICAL / O3 RATE DIAGNOSTICS ----------------
    HO2=get_table_species(AnalysisState,'HO2');
    OH=get_table_species(AnalysisState,'OH');
    RO2=get_table_species(AnalysisState,'RO2');
    if all(~isfinite(RO2)), warning('%s: no explicit RO2 field/family found in S.Conc; RO2 output left NaN.',block); end
    Peroxyl_ppt=1000*(HO2+RO2); HO2_ppt=1000*HO2; RO2_ppt=1000*RO2; OH_ppt=1000*OH;
    local_hour=hour(AnalysisState.Time_LT)+minute(AnalysisState.Time_LT)/60;
    model_rate_10min=gradient(analysis_O3,10/60); % ppb h^-1
    RadicalRateTbl=table(AnalysisState.Time_LT,local_hour,analysis_O3,model_rate_10min,OH,HO2,RO2,OH_ppt,HO2_ppt,RO2_ppt,Peroxyl_ppt, ...
        'VariableNames',{'Time_LT','LocalHour','O3_ppb','Modeled_dO3dt_ppb_h','OH_ppb','HO2_ppb','RO2_ppb','OH_ppt','HO2_ppt','RO2_ppt','TotalPeroxyl_HO2plusRO2_ppt'});
    writetable(RadicalRateTbl,fullfile(out_dir,sprintf('%s_AnalysisDay_O3Rate_OH_HO2_RO2.csv',block)));

    f=figure('Color','w','Units','inches','Position',[1 1 8.2 5.5]); hold on;
    plot(local_hour,HO2_ppt,'LineWidth',2.0,'DisplayName','HO_2'); plot(local_hour,OH_ppt,'--','LineWidth',2.0,'DisplayName','OH');
    xlabel('Local time (h)'); ylabel('Radical concentration (ppt)'); title(sprintf('%s: HO_2 and OH Evolution',strrep(block,'_','-')));
    xlim([0 23]); xticks(0:3:23); grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_HO2_OH_Evolution',block)); close(f);

    f=figure('Color','w','Units','inches','Position',[1 1 8.2 5.5]); hold on;
    plot(local_hour,Peroxyl_ppt,'LineWidth',2.2,'DisplayName','HO_2 + RO_2');
    plot(local_hour,HO2_ppt,'--','LineWidth',1.5,'DisplayName','HO_2');
    if any(isfinite(RO2_ppt)), plot(local_hour,RO2_ppt,':','LineWidth',1.8,'DisplayName','RO_2'); end
    xlabel('Local time (h)'); ylabel('Peroxyl radical concentration (ppt)'); title(sprintf('%s: Analysis-Day Peroxyl Radicals',strrep(block,'_','-')));
    xlim([0 23]); xticks(0:3:23); grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_Peroxyl_Radicals',block)); close(f);

    %% ---------------- OBSERVED VS MODELED O3 GROWTH RATE ----------------
    % Hourly gradients are used here so observed and modeled rates share the same time support.
    obs_rate=gradient(O3obs24,1); model_rate_hr=gradient(O3_model_hr,1);
    GrowthTbl=table((0:23)',O3obs24,O3_model_hr,obs_rate,model_rate_hr, ...
        'VariableNames',{'Hour','ObservedO3_ppb','ModeledO3_ppb','Observed_dO3dt_ppb_h','Modeled_dO3dt_ppb_h'});
    writetable(GrowthTbl,fullfile(out_dir,sprintf('%s_Observed_vs_Modeled_O3_GrowthRate.csv',block)));
    f=figure('Color','w','Units','inches','Position',[1 1 8.2 5.5]); hold on;
    yline(0,'k:','HandleVisibility','off');
    plot(0:23,obs_rate,'ko-','LineWidth',2.0,'MarkerSize',5,'MarkerFaceColor','w','DisplayName','Observed');
    plot(0:23,model_rate_hr,'s-','LineWidth',2.0,'MarkerSize',5,'DisplayName','Modeled');
    xlabel('Local time (h)'); ylabel('O_3 growth rate (ppb h^{-1})'); title(sprintf('%s: Observed vs Modeled O_3 Growth Rate',strrep(block,'_','-')));
    xlim([0 23]); xticks(0:3:23); grid on; box on; legend('Location','best','Box','off'); publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_O3_GrowthRate_Observed_vs_Modeled',block)); close(f);

    %% ---------------- PEAK FULL-STATE PARENT + ISOPLETH ----------------
    mask=analysis_time>=run_date+hours(iso_start_hour) & analysis_time<run_date+hours(iso_end_hour) & isfinite(analysis_O3);
    assert(any(mask),'No finite modeled O3 in 08:00-20:00 for %s.',block);
    ii=find(mask); [peakO3,jj]=max(analysis_O3(mask),[],'omitnan'); idxPeak=ii(jj); peak_time=analysis_time(idxPeak);
    ph=hour(peak_time);
    InitIso=ParentInitByHour{ph+1};
    base_NOx=init_sum_NOx(InitIso); base_VOC=init_sum_VOC(InitIso,voc_species);
    P_base=P24(ph+1); RH_base=RH24(ph+1);
    ParentTbl=table(string(block),TK,peak_time,peakO3,base_NOx,base_VOC,P_base,RH_base,kdil_s,spinup_end_O3,O3_reset_ppb, ...
        'VariableNames',{'Block','TempK','PeakTime_LT','PeakO3_ppb','PeakNOx_ppb','PeakVOC_ppb','P_parent','RH_parent','kdil_s','SpinupEndO3_ppb','AnalysisO3Reset_ppb'});
    writetable(ParentTbl,fullfile(out_dir,sprintf('%s_Isopleth_PeakFullState.csv',block)));

    t_iso=(run_date+hours(iso_start_hour)):minutes(dt_minutes):(run_date+hours(iso_end_hour)-minutes(dt_minutes)); t_iso=t_iso(:);
    o=ones(size(t_iso)); ti.year=year(t_iso).*o;ti.month=month(t_iso).*o;ti.day=day(t_iso).*o;ti.hour=hour(t_iso);ti.min=minute(t_iso);ti.sec=second(t_iso);ti.UTC=UTC_offset.*o;
    sun_iso=sun_position(ti,struct('latitude',lat,'longitude',lon,'altitude',90));
    OptIso=ModelOptions; OptIso.EndPointsOnly=0; OptIso.TimeStamp=hour(t_iso)+minute(t_iso)/60;
    fNOx=NOx_ppb_grid./max(base_NOx,1e-12); fVOC=VOC_ppb_grid./max(base_VOC,1e-12);
    MetIso={'P',P_base*o;'T',TK*o;'RH',RH_base*o;'SZA',sun_iso.zenith;'jcorr',jcorr;'kdil',kdil_s};
    vals=run_isopleth_grid_maxO3(MetIso,InitIso,ChemFiles,BkgdConc,OptIso,fNOx,fVOC,voc_species);
    O3grid=reshape(vals,n_voc,n_nox);
    GridTbl=table(VOC_ppb_grid(:),NOx_ppb_grid(:),fVOC(:),fNOx(:),O3grid(:),repmat(TK,numel(O3grid),1),repmat(string(block),numel(O3grid),1), ...
        'VariableNames',{'VOC_ppb','NOx_ppb','VOC_factor','NOx_factor','MaxO3_08_20_ppb','TempK','Block'});
    writetable(GridTbl,fullfile(out_dir,sprintf('%s_Isopleth_T%sK.csv',block,strrep(num2str(TK),'.','_'))));
    [RidgeTbl,DiagTbl,SumRow]=corrected_ridge_NOx(O3grid,VOC_ppb_levels,NOx_ppb_levels,TK);
    RidgeTbl.Block=repmat(string(block),height(RidgeTbl),1); DiagTbl.Block=repmat(string(block),height(DiagTbl),1); SumRow.Block=string(block);
    writetable(RidgeTbl,fullfile(out_dir,sprintf('%s_CorrectedRidge.csv',block))); writetable(DiagTbl,fullfile(out_dir,sprintf('%s_RidgeBoundary.csv',block)));
    AllRidgeSummary=[AllRidgeSummary;SumRow]; %#ok<AGROW>
    f=figure('Color','w','Units','inches','Position',[1 1 7.2 5.8]);
    contourf(VOC_ppb_levels,NOx_ppb_levels,O3grid',linspace(0,140,21),'LineStyle','none'); hold on;
    clim([0 140]);
    contour(VOC_ppb_levels,NOx_ppb_levels,O3grid',12,'LineColor',[.25 .25 .25],'LineWidth',.65); cb=colorbar; cb.Label.String='Maximum O_3, 08:00-20:00 LT (ppb)';
    if height(RidgeTbl)>0,plot(RidgeTbl.VOC_ppb,RidgeTbl.RidgeNOx_ppb,'k-','LineWidth',2,'DisplayName','Ridge');end
    plot(base_VOC,base_NOx,'kp','MarkerSize',11,'LineWidth',1.4,'MarkerFaceColor','w','DisplayName','Peak-state base');
    xlabel('VOC (ppb)');ylabel('NO_x (ppb)');title(sprintf('Real Case %s, T = %.1f K',strrep(block,'_','-'),TK)); box on; publication_axes(gca);
    save_publication_figure(f,out_dir,sprintf('%s_Isopleth_CorrectedRidge',block)); close(f);
end

%% ---------------- MASTER OUTPUTS / COMBINED DIURNAL ----------------
writetable(AllPerformance,fullfile(out_root,'RealCase_Diurnal_Performance.csv'));
writetable(AllRidgeSummary,fullfile(out_root,'RealCase_Corrected_Ridge_Summary.csv'));
writetable(AllRidgeSummary,fullfile(out_root,'RealCase_Corrected_Ridge_Summary.xlsx'));
writetable(CombinedDiurnal,fullfile(out_root,'RealCase_AllBlocks_Diurnal.csv'));

% Combined analysis-day diurnal: all historical modeled scenarios + observed profiles.
f=figure('Color','w','Units','inches','Position',[1 1 9.0 6.0]); hold on;
for ib=blocks_to_run
    block=block_labels{ib};
    plot(0:23,CombinedDiurnal.(['Modeled_' block]),'-','LineWidth',2.0,'DisplayName',strrep(block,'_','-'));
end
xlabel('Local time (h)');ylabel('Modeled O_3 (ppb)');title('Los Angeles Real Cases: Analysis-Day Diurnal O_3');
xlim([0 23]);xticks(0:3:23);grid on;box on;legend('Location','best','Box','off');publication_axes(gca);
save_publication_figure(f,out_root,'RealCase_AllBlocks_Modeled_Diurnal');close(f);

fprintf('\nREAL-CASE ANALYSIS COMPLETE. Outputs: %s\n',out_root);

%% ========================================================================
% LOCAL FUNCTIONS
%% ========================================================================
function Init=get_block_initial_conditions(block)
switch block
case '1996_2000', Init={'O3',6.2,0;'CO',839.4,1;'NO',23.6,0;'NO2',35.2,0;'ETHA',9.9,1;'PRPA',7.6,1;'ETH',6.5,1;'PAR',20.0,1;'OLE',2.6,1;'IOLE',0.4,1;'TOL',3.0,1;'XYL',2.1,1;'BENZ',1.0,1;'ALD2',1.6,1;'FORM',5.0,1;'ACET',7.7,1;'ETHY',5.0,1;'ISOP',0.2,1};
case '2001_2005', Init={'O3',10.4,0;'CO',481,1;'NO',10.8,0;'NO2',27.0,0;'ETHA',8.8,1;'PRPA',8.2,1;'ETH',5.5,1;'PAR',16.8,1;'OLE',1.3,1;'IOLE',0.4,1;'TOL',2.1,1;'XYL',1.36,1;'BENZ',0.6,1;'ALD2',1.2,1;'FORM',5.4,1;'ACET',7.7,1;'ETHY',3.6,1;'ISOP',0.1,1};
case '2006_2010', Init={'O3',9.3,0;'CO',296.1,1;'NO',6.3,0;'NO2',24.3,0;'ETHA',6.4,1;'PRPA',5.2,1;'ETH',2.1,1;'PAR',6.5,1;'OLE',0.5,1;'IOLE',0.1,1;'TOL',0.9,1;'XYL',0.6,1;'BENZ',0.3,1;'ALD2',1.5,1;'FORM',4.1,1;'ACET',5.0,1;'ETHY',1.9,1;'ISOP',0.1,1};
case '2011_2015', Init={'O3',9.5,0;'CO',304,1;'NO',2.1,0;'NO2',15.8,0;'ETHA',6.0,1;'PRPA',8.2,1;'ETH',1.8,1;'PAR',17.51,1;'OLE',0.62,1;'IOLE',0.1,1;'TOL',0.74,1;'XYL',5.2,1;'BENZ',0.24,1;'ALD2',1.3,1;'FORM',3.7,1;'ACET',6.9,1;'ETHY',1.6,1;'ISOP',0.1,1};
case '2016_2020', Init={'O3',16,0;'CO',280,1;'NO',1.8,0;'NO2',13.5,0;'ETHA',6.6,1;'PRPA',3.4,1;'ETH',1.2,1;'PAR',4.1,1;'OLE',0.45,1;'IOLE',0.1,1;'TOL',0.4,1;'XYL',0.35,1;'BENZ',0.17,1;'ALD2',1.31,1;'FORM',3.71,1;'ACET',3.34,1;'ETHY',0.87,1;'ISOP',0.07,1};
otherwise,error('Unknown block %s',block);end
end

function v=get_numeric_column(T,vn,name)
key=lower(regexprep(name,'[^a-zA-Z0-9]',''));idx=find(strcmp(vn,key),1);assert(~isempty(idx),'Required column %s not found.',name);v=double(T{:,idx});v=v(:);
end
function Init=set_species_value(Init,sp,val)
if ~isfinite(val),return;end;i=find(strcmpi(Init(:,1),sp),1);if isempty(i),Init(end+1,:)={sp,max(double(val),0),0};else,Init{i,2}=max(double(val),0);end
end
function v=init_species_value(Init,sp)
i=find(strcmpi(Init(:,1),sp),1);if isempty(i),v=NaN;else,v=double(Init{i,2});end
end
function [time_blk,sun_blk]=hour_block_sun(d,UTC,lat,lon,H,dt)
t=d+hours(H)+minutes((0:dt:50)');assert(numel(t)==6,'Expected six H:00-H:50 points.');o=ones(size(t));time_blk.year=year(t).*o;time_blk.month=month(t).*o;time_blk.day=day(t).*o;time_blk.hour=hour(t);time_blk.min=minute(t);time_blk.sec=second(t);time_blk.UTC=UTC.*o;sun_blk=sun_position(time_blk,struct('latitude',lat,'longitude',lon,'altitude',90));
end
function s=extract_species_series(S,sp)
s=[];if ~isfield(S,'Conc'),return;end
if isstruct(S.Conc),f=fieldnames(S.Conc);j=find(strcmpi(f,sp),1);if ~isempty(j),s=S.Conc.(f{j});end
elseif istable(S.Conc),f=S.Conc.Properties.VariableNames;j=find(strcmpi(f,sp),1);if ~isempty(j),s=S.Conc{:,j};end
elseif isnumeric(S.Conc),names={};if isfield(S,'Cnames'),names=S.Cnames;elseif isfield(S,'Chem')&&isfield(S.Chem,'AllSpc'),names=S.Chem.AllSpc;end;j=find(strcmpi(names,sp),1);if ~isempty(j),s=S.Conc(:,j);end,end
s=double(s(:));
end
function InitNext=last_state_to_init(S,InitTemplate)
% Limited transfer matching base case: update only species already in InitTemplate.
InitNext=InitTemplate; names={}; concM=[];
if istable(S.Conc)
    names=S.Conc.Properties.VariableNames; concM=S.Conc{end,:};
elseif isstruct(S.Conc)
    names=fieldnames(S.Conc); concM=nan(1,numel(names));
    for q=1:numel(names)
        x=S.Conc.(names{q});
        if isnumeric(x)||islogical(x)
            x=double(x(:)); x=x(isfinite(x));
            if ~isempty(x), concM(q)=x(end); end
        end
    end
elseif isnumeric(S.Conc)
    if isfield(S,'Cnames'), names=S.Cnames; elseif isfield(S,'Chem')&&isfield(S.Chem,'AllSpc'), names=S.Chem.AllSpc; else, return; end
    concM=double(S.Conc(end,:));
else
    return;
end
for q=1:size(InitNext,1)
    j=find(strcmpi(names,InitNext{q,1}),1);
    if ~isempty(j)&&j<=numel(concM)&&isfinite(concM(j)), InitNext{q,2}=max(double(concM(j)),0); end
end
end

function val=init_sum_NOx(Init)
a=find(strcmpi(Init(:,1),'NO'),1);b=find(strcmpi(Init(:,1),'NO2'),1);if isempty(a)||isempty(b),val=NaN;else,val=double(Init{a,2})+double(Init{b,2});end
end
function val=init_sum_VOC(Init,list)
val=0;for q=1:numel(list),i=find(strcmpi(Init(:,1),list{q}),1);if ~isempty(i)&&isnumeric(Init{i,2}),val=val+double(Init{i,2});end,end
end
function T=state_to_table(S,tvec)
if isstruct(S.Conc),raw=fieldnames(S.Conc);n=numel(tvec);for q=1:numel(raw),x=S.Conc.(raw{q});if isnumeric(x)||islogical(x),n=min(n,numel(x));end,end;C=table();valid=matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(raw));for q=1:numel(raw),x=S.Conc.(raw{q});if ~(isnumeric(x)||islogical(x)),continue;end;x=double(x(:));C.(valid{q})=x(1:n);end
elseif istable(S.Conc),n=min(height(S.Conc),numel(tvec));C=S.Conc(1:n,:);
elseif isnumeric(S.Conc),if isfield(S,'Cnames'),raw=S.Cnames;elseif isfield(S,'Chem')&&isfield(S.Chem,'AllSpc'),raw=S.Chem.AllSpc;else,error('No species names.');end;names=matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(raw));n=min(size(S.Conc,1),numel(tvec));C=array2table(S.Conc(1:n,:),'VariableNames',names);
else,error('Unsupported S.Conc.');end
T=addvars(C,tvec(1:n),'Before',1,'NewVariableNames','Time_LT');
end
function v=get_table_species(T,sp)
v=nan(height(T),1);names=T.Properties.VariableNames;j=find(strcmpi(names,matlab.lang.makeValidName(sp))|strcmpi(names,sp),1);if ~isempty(j),x=T{:,j};if isnumeric(x),v=double(x(:));end,end
end
function Init=table_state_to_init(T,row)
vars=T.Properties.VariableNames;vars(strcmp(vars,'Time_LT'))=[];Init=cell(numel(vars),3);for q=1:numel(vars),Init(q,:)={vars{q},max(double(T.(vars{q})(row)),0),0};end
end
function vals=run_isopleth_grid_maxO3(Met,InitBase,Chem,Bkgd,Opts,fNOx,fVOC,vocs)
vals=nan(numel(fNOx),1);for i=1:numel(fNOx),Init=InitBase;a=find(strcmpi(Init(:,1),'NO'),1);b=find(strcmpi(Init(:,1),'NO2'),1);Init{a,2}=Init{a,2}*fNOx(i);Init{b,2}=Init{b,2}*fNOx(i);for q=1:numel(vocs),j=find(strcmpi(Init(:,1),vocs{q}),1);if ~isempty(j),Init{j,2}=Init{j,2}*fVOC(i);end,end;S=F0AM_ModelCore(Met,Init,Chem,Bkgd,Opts);O=extract_species_series(S,'O3');O=O(isfinite(O));if ~isempty(O),vals(i)=max(O);end,end
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


function [MB,NMB,RMSE,NRMSE]=performance_stats(M,O)
m=isfinite(M)&isfinite(O);M=M(m);O=O(m);if isempty(M),MB=NaN;NMB=NaN;RMSE=NaN;NRMSE=NaN;return;end;MB=mean(M-O);NMB=100*sum(M-O)/sum(O);RMSE=sqrt(mean((M-O).^2));NRMSE=100*RMSE/mean(O);
end
function publication_axes(ax)
ax.FontName='Arial';ax.FontSize=12;ax.LineWidth=1.1;ax.TickDir='out';ax.Layer='top';
end
function save_publication_figure(f,folder,stem)
try, savefig(f,fullfile(folder,[stem '.fig'])); catch ME, warning('FIG save failed: %s',ME.message); end
try, exportgraphics(f,fullfile(folder,[stem '.png']),'Resolution',600); catch ME, warning('PNG export failed; simulation continues: %s',ME.message); end
try, exportgraphics(f,fullfile(folder,[stem '.pdf']),'ContentType','vector'); catch ME, warning('PDF export failed; simulation continues: %s',ME.message); end
end
