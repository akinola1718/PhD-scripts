% =========================================================
% PAMS July Hourly Extracts for Met Variables + Decadal Hourly Averages
%  Variables: Barometric Pressure, Relative Humidity, Outdoor Temperature
%  Site filter: State=06, County=37, Site=1103; Month=July (LOCAL date/time)
%  Inputs (robust): 
%     ...\PAMS Hourly Data\<BaseDir?>\<prefix>_<YEAR>\<prefix>_<YEAR>.(csv|xlsx)
%     where <BaseDir?> is optional (e.g., "Temperature", "Relative Humidity", "Barometric Pressure")
%  Outputs: per-year per-parameter XLSX + decadal (24h & 31×24 Day×Hour) + QA sheets
%  Notes:
%    • Equal-by-Year averages ignore missing years per hour/day-hour
%    • De-dup identical timestamps by mean(omitnan)
%    • Leading zero codes normalized via numeric compare
%    • ZEROS are kept (no zero->NaN) for met variables
%    • No 'continue' statements used
% =========================================================
clear; clc;

%% -------- USER SETTINGS --------
years = 2011:2020;

DATA_ROOT = fullfile('C:','Users','beg24003','CONUSDATA','PAMS Hourly Data');
OUT_DIR   = fullfile('C:','Users','beg24003','CONUSDATA','PAMS Hourly Data','Met_merged');
if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end

STATE_CODE  = 6;   % California
COUNTY_CODE = 37;  % Los Angeles
SITE_NUM    = 1103;

% Parameter specs:
%  label  : safe file-friendly label for outputs
%  prefix : subfolder/file prefix (prefix_YEAR\prefix_YEAR.csv|xlsx)
%  pname  : "Parameter Name" string to match in data
%  basedirs: candidate base subfolders to try under DATA_ROOT (order matters)
PARAMS = struct( ...
  'label',   {'Barometric_Pressure', 'Relative_Humidity',  'Outdoor_Temperature'}, ...
  'prefix',  {'hourly_PRESS',        'hourly_RH_DP',        'hourly_TEMP'}, ...
  'pname',   {'Barometric Pressure', 'Relative Humidity',   'Outdoor Temperature'}, ...
  'basedirs',{{ {'Barometric Pressure','PRESS','Meteorology','Met',''}, ...
                {'Relative Humidity','RH','RH_DP','Meteorology','Met',''}, ...
                {'Temperature','TEMP','Meteorology','Met',''} }} ...
);

%% -------- Logging --------
summary_path = fullfile(OUT_DIR,'Met_Extraction_Summary.txt');
if exist(summary_path,'file'), delete(summary_path); end
sfid = fopen(summary_path,'w');
fprintf(sfid,"Met Extraction Summary (Barometric Pressure, RH, Temperature)\n");
fprintf(sfid,"============================================================\n");
fprintf(sfid,"Years: %d-%d | Filters: State=06, County=37, Site=1103 | Month: July\n", years(1), years(end));
fprintf(sfid,"Local Date/Time used; de-dup identical timestamps by mean(omitnan)\n");
fprintf(sfid,"Decadal Equal-by-Year for 24h & Day×Hour (denominators exclude missing years)\n\n");
%% -------- Containers --------
year_hour_map = containers.Map('KeyType','char','ValueType','any');  % per-parameter: S.years, S.M (Nyears×24)
latlon_map    = containers.Map('KeyType','char','ValueType','any');  % per-parameter lat/lon
miss_by_year  = containers.Map('KeyType','char','ValueType','any');  % per-parameter missing date-hours
dedup_by_year = containers.Map('KeyType','char','ValueType','any');  % per-parameter dedup stats
year_tables   = containers.Map('KeyType','char','ValueType','any');  % per-parameter stored per-year dedup tables

%% -------- MAIN: per-parameter then per-year --------
for p = 1:numel(PARAMS)
    LABEL   = PARAMS(p).label;
    PREFIX  = PARAMS(p).prefix;
    PNAME   = PARAMS(p).pname;
    BASES   = PARAMS(p).basedirs{1};  % cell array of candidate base folders

    % init per-param maps
    if ~isKey(year_hour_map, LABEL)
        S.years = years(:); S.M = NaN(numel(S.years),24);
        year_hour_map(LABEL) = S;
    end
    if ~isKey(year_tables, LABEL)
        Y.years = years(:); Y.tables = cell(numel(Y.years),1);
        year_tables(LABEL) = Y;
    end

    for y = years
        skipYear = false;

        % Try to locate the file under any of the base directories
        [fpath, okFile, triedPaths] = locate_multi_file(DATA_ROOT, BASES, PREFIX, y);

        T = table(); T1 = table(); DT = NaT(0,1);
        if ~okFile
            fprintf('[%s] Missing expected file for %d. Tried:\n', LABEL, y);
            for iTry=1:numel(triedPaths), fprintf('  - %s\n', triedPaths{iTry}); end
            skipYear = true;
        else
            try
                opts = detectImportOptions(fpath,'PreserveVariableNames',true);
                T = readtable(fpath, opts);
            catch ME
                fprintf('[%s] Read fail (%s): %s\n', LABEL, fpath, ME.message);
                skipYear = true;
            end
        end
        if skipYear || isempty(T), continue; end

        % Columns
        iState = vfind(T, {'State Code','StateCode'});
        iCounty= vfind(T, {'County Code','CountyCode'});
        iSite  = vfind(T, {'Site Num','Site Number','SiteNum'});
        iLat   = vfind(T, {'Latitude','Site Latitude'});
        iLon   = vfind(T, {'Longitude','Site Longitude'});
        iParam = vfind(T, {'Parameter Name','ParameterName'});
        iValue = vfind(T, {'Sample Measurement','Arithmetic Mean','Value','Observation'});

        if any(cellfun(@isempty,{iState,iCounty,iSite,iParam,iValue}))
            fprintf('[%s] Missing required columns in %s\n', LABEL, fpath);
            skipYear = true;
        end
        if skipYear, continue; end

        % site & parameter filter (normalize leading zeros by numeric compare)
        state_ok  = eqnum(T{:, iState},  STATE_CODE);
        county_ok = eqnum(T{:, iCounty}, COUNTY_CODE);
        site_ok   = eqnum(T{:, iSite},   SITE_NUM);
        rowsParam = strcmpi(string(T{:, iParam}), PNAME);
        sel = state_ok & county_ok & site_ok & rowsParam;

        if ~any(sel)
            fprintf('[%s] No rows for site/param in %d (%s)\n', LABEL, y, fpath);
            skipYear = true;
        end
        if skipYear, continue; end

        T1 = T(sel,:);

        % Local DateTime + July filter
        [DT, okDT, whyDT] = make_datetime_local_only(T1);
        if ~okDT
            fprintf('[%s] Local datetime parse failed (%d): %s\n', LABEL, y, whyDT);
            skipYear = true;
        end
        if skipYear, continue; end

        isJuly = month(DT)==7;
        T1 = T1(isJuly,:); DT = DT(isJuly);
        if isempty(T1)
            fprintf('[%s] No July rows in %d.\n', LABEL, y);
            skipYear = true;
        end
        if skipYear, continue; end

        % Dedup identical timestamps (mean)
        Lat_col = getcol(T1, iLat);
        Lon_col = getcol(T1, iLon);
        Val_col = T1{:, iValue};

        Tmp = table(DT,Lat_col,Lon_col,Val_col, ...
            'VariableNames',{'DateTimeLocal','Latitude','Longitude','Value'});
        [G, keyDT] = findgroups(Tmp.DateTimeLocal);
        Val_agg = splitapply(@(x) mean(x,'omitnan'), Tmp.Value, G);
        Lat_agg = splitapply(@first_non_nan, Tmp.Latitude, G);
        Lon_agg = splitapply(@first_non_nan, Tmp.Longitude, G);
        SrcCount = splitapply(@numel, Tmp.Value, G);
        OmitCount= SrcCount - 1;

        outTbl = table( ...
            repmat(STATE_CODE,numel(keyDT),1), repmat(COUNTY_CODE,numel(keyDT),1), repmat(SITE_NUM,numel(keyDT),1), ...
            Lat_agg, Lon_agg, repmat(string(PNAME),numel(keyDT),1), keyDT, Val_agg, SrcCount, OmitCount, ...
            'VariableNames',{'StateCode','CountyCode','SiteNum','Latitude','Longitude','ParameterName','DateTimeLocal','Value','SrcCountAtThisTimestamp','OmittedValueCountAtThisTimestamp'});
        outTbl = sortrows(outTbl,'DateTimeLocal');

        % per-year file
        perYearName = sprintf('%s_%d.xlsx', LABEL, y);
        perYearPath = fullfile(OUT_DIR, perYearName);
        writetable(outTbl, perYearPath, 'FileType','spreadsheet');

        % store for decadal Day×Hour
        Y = year_tables(LABEL);
        iyTbl = find(Y.years==y,1,'first');
        Y.tables{iyTbl} = outTbl;
        year_tables(LABEL) = Y;

        % yearly 24h averages
        hrsY = hour(outTbl.DateTimeLocal);
        mY = NaN(1,24);
        for h=0:23
            vv = outTbl.Value(hrsY==h);
            if ~isempty(vv), mY(h+1) = mean(vv,'omitnan'); end
        end
        S = year_hour_map(LABEL);
        iy = find(S.years==y,1,'first');
        S.M(iy,:) = mY;
        year_hour_map(LABEL) = S;

        % QA: missing date-hours per year
        dvec = (datetime(y,7,1):datetime(y,7,eomday(y,7)))'; dvec.TimeZone='';
        presentDT = dateshift(outTbl.DateTimeLocal,'start','hour');
        miss24 = cell(24,1);
        for h=0:23
            allDT_h = dvec + hours(h);
            miss24{h+1} = allDT_h(~ismember(allDT_h, unique(presentDT)));
        end
        if ~isKey(miss_by_year, LABEL)
            Q.years = years(:); Q.missByYear = cell(numel(Q.years),1);
            miss_by_year(LABEL)=Q;
        end
        Q = miss_by_year(LABEL); Q.missByYear{iy}=miss24; miss_by_year(LABEL)=Q;

        % QA: dedup stats
        if ~isKey(dedup_by_year, LABEL)
            D.years=years(:); D.TotalCollapsed=NaN(numel(D.years),1);
            D.CollapsedPerHour=cell(numel(D.years),1);
            D.CollapsedTimestampsByHour=cell(numel(D.years),1);
            dedup_by_year(LABEL)=D;
        end
        D = dedup_by_year(LABEL);
        hrsAgg = hour(keyDT);
        perHour = zeros(24,1); tsByHour = cell(24,1);
        for h=0:23
            idxh = (hrsAgg==h) & (OmitCount>0);
            perHour(h+1) = sum(OmitCount(idxh),'omitnan');
            tsByHour{h+1} = keyDT(idxh);
        end
        D.TotalCollapsed(iy) = sum(OmitCount);
        D.CollapsedPerHour{iy} = perHour;
        D.CollapsedTimestampsByHour{iy} = tsByHour;
        dedup_by_year(LABEL)=D;

        % lat/lon cache
        if ~isKey(latlon_map, LABEL)
            iok = find(~isnan(outTbl.Latitude) & ~isnan(outTbl.Longitude),1,'first');
            if ~isempty(iok), latlon_map(LABEL) = [outTbl.Latitude(iok), outTbl.Longitude(iok)];
            else, latlon_map(LABEL) = [NaN,NaN]; end
        end
    end
end

%% -------- DECADAL (2011–2020): Summary 24h + Day×Hour (31×24) + QA --------
for p = 1:numel(PARAMS)
    LABEL = PARAMS(p).label;  PNAME = PARAMS(p).pname;

    canDo = isKey(year_hour_map,LABEL) && isKey(year_tables,LABEL);
    if ~canDo, continue; end
    S  = year_hour_map(LABEL);
    YT = year_tables(LABEL);

    % Summary 24h Equal-by-Year
    Hour = (0:23).';
    Mean_EQ = NaN(24,1); Nyears = zeros(24,1); YearsMissingList = strings(24,1);
    for h=1:24
        vh = S.M(:,h);
        Nyears(h) = sum(~isnan(vh));
        Mean_EQ(h)= mean(vh,'omitnan');
        YearsMissingList(h) = strjoin(string(S.years(isnan(vh))),',');
    end

    % Lat/Lon
    latlon = [NaN,NaN]; if isKey(latlon_map,LABEL), latlon = latlon_map(LABEL); end
    Lat = repmat(latlon(1),24,1); Lon = repmat(latlon(2),24,1);

    outname = sprintf('DecadalHourlyAvg_%s_Site1103_%d-%d.xlsx', LABEL, years(1), years(end));
    outpath = fullfile(OUT_DIR, outname);

    decTbl = table( ...
        repmat(STATE_CODE,24,1), repmat(COUNTY_CODE,24,1), repmat(SITE_NUM,24,1), ...
        Lat,Lon, repmat(string(PNAME),24,1), Hour, ...
        Mean_EQ, Nyears, YearsMissingList, ...
        'VariableNames',{'StateCode','CountyCode','SiteNum','Latitude','Longitude','ParameterName','Hour', ...
        'DecadalHourlyMean_EQ_BY_YEAR','NyearsUsed','YearsMissingList'});
    writetable(decTbl, outpath, 'FileType','spreadsheet','Sheet','Summary');

    % Decadal Day×Hour (31×24) Equal-by-Year
    nDays=31; nH=24;
    SUM = zeros(nDays,nH); CNT = zeros(nDays,nH); hasAny=false;

    for iy = 1:numel(YT.years)
        Tyear = YT.tables{iy};
        if isempty(Tyear), continue; end
        dmo = day(Tyear.DateTimeLocal,'dayofmonth');
        hhr = hour(Tyear.DateTimeLocal);
        V   = Tyear.Value;

        Myr = NaN(nDays,nH);
        for dd=1:nDays
            for hh=0:23
                idx = (dmo==dd) & (hhr==hh);
                if any(idx), Myr(dd,hh+1) = mean(V(idx),'omitnan'); end
            end
        end

        mask = ~isnan(Myr);
        SUM(mask) = SUM(mask) + Myr(mask);
        CNT(mask) = CNT(mask) + 1;
        hasAny = true;
    end

    DH_EQ  = NaN(nDays,nH); DH_Nyr = CNT;
    if hasAny
        DH_EQ = SUM ./ max(CNT,1);
        DH_EQ(CNT==0) = NaN;
    end

    % Emit tall table: 744 rows with DayOfMonth
    nrows = nDays*nH;
    DayOfMonth = repelem((1:nDays).',nH);
    HourCol    = repmat((0:23).',nDays,1);
    Decadal_EQ_DH = reshape(DH_EQ.', nrows, 1);
    Nyr_DH        = reshape(DH_Nyr.', nrows, 1);

    DH_tbl = table(DayOfMonth, HourCol, Decadal_EQ_DH, Nyr_DH, ...
        'VariableNames', {'DayOfMonth','Hour','DecadalHourlyMean_EQ_BY_YEAR_DH','NyearsActuallyUsed'});
    writetable(DH_tbl, outpath, 'FileType','spreadsheet','Sheet','Decadal_DayHour_EQ');

    % QA_Missing
    if isKey(miss_by_year, LABEL)
        Q = miss_by_year(LABEL);
        QA1_rows = {};
        for iy = 1:numel(Q.years)
            miss24 = Q.missByYear{iy}; if isempty(miss24), continue; end
            for h=0:23
                dts = miss24{h+1}; nmiss=numel(dts);
                listStr = ""; if nmiss>0, listStr = strjoin(cellstr(datestr(dts,'yyyy-mm-dd HH:MM')), ', '); end
                QA1_rows = [QA1_rows; {Q.years(iy), h, nmiss, listStr}]; %#ok<AGROW>
            end
        end
        if ~isempty(QA1_rows)
            QA_Missing = cell2table(QA1_rows,'VariableNames',{'Year','Hour','NOmittedDateHours','OmittedDateHoursList'});
            writetable(QA_Missing, outpath, 'FileType','spreadsheet', 'Sheet','QA_Missing');
        end
    end

    % QA_Dedup
    if isKey(dedup_by_year, LABEL)
        D = dedup_by_year(LABEL);
        QA2_rows = {};
        for iy = 1:numel(D.years)
            perHour = D.CollapsedPerHour{iy}; tsByH = D.CollapsedTimestampsByHour{iy};
            if isempty(perHour), continue; end
            totalY = D.TotalCollapsed(iy);
            for h=0:23
                ncol = perHour(h+1); tlist = tsByH{h+1};
                listStr = "";
                if ~isempty(tlist), listStr = strjoin(cellstr(datestr(tlist,'yyyy-mm-dd HH:MM')), ', '); end
                QA2_rows = [QA2_rows; {D.years(iy), h, ncol, totalY, listStr}]; %#ok<AGROW>
            end
        end
        if ~isempty(QA2_rows)
            QA_Dedup = cell2table(QA2_rows,'VariableNames',{'Year','Hour','CollapsedRowsAtHour','TotalCollapsedRowsYear','CollapsedTimestampsList'});
            writetable(QA_Dedup, outpath, 'FileType','spreadsheet', 'Sheet','QA_Dedup');
        end
    end
end

fclose(sfid);
fprintf('\n=== Done. Files saved in: %s ===\n', OUT_DIR);

%% ===================== LOCAL FUNCTIONS =====================
function [fpath, ok, tried] = locate_multi_file(DATA_ROOT, baseDirs, prefix, y)
% Try multiple candidate base folders + the root (''), return first that exists.
% Expected structure under candidate root:
%    <root>\<prefix>_<YEAR>\<prefix>_<YEAR>.(csv|xlsx)
    ok = false; fpath = ''; tried = {};
    % Ensure '' (plain root) is last as fallback if not already present
    if ~any(cellfun(@(s) isequal(s,''), baseDirs)), baseDirs = [baseDirs, {''}]; end
    for i = 1:numel(baseDirs)
        if isempty(baseDirs{i})
            ydir = fullfile(DATA_ROOT, sprintf('%s_%d', prefix, y));
        else
            ydir = fullfile(DATA_ROOT, baseDirs{i}, sprintf('%s_%d', prefix, y));
        end
        base = fullfile(ydir, sprintf('%s_%d', prefix, y));
        cand = { [base '.csv'], [base '.xlsx'], [base '.CSV'], [base '.XLSX'] };
        for j=1:numel(cand)
            tried{end+1} = cand{j}; %#ok<AGROW>
            if exist(cand{j}, 'file')
                fpath = cand{j}; ok = true; return;
            end
        end
    end
end

function idx = vfind(tbl, candidates)
    vars = string(tbl.Properties.VariableNames);
    cand = string(candidates);
    [~, idx] = ismember(lower(cand), lower(vars));
    idx = idx(idx > 0);
    if ~isempty(idx), idx = idx(1); else, idx = []; end
end

function tf = eqnum(col, target)
    try, tf = (col == target); return; catch, end
    tf = (str2double(string(col)) == target);
end

function [dt, ok, why] = make_datetime_local_only(T)
% Use Date Local + Time Local only; if Time Local missing, midnight.
    ok = true; why = '';
    try
        iDate = vfind(T, {'Date Local','DATE LOCAL','Local Date'});
        if isempty(iDate), error('Date Local missing'); end
        datecol = T{:, iDate};
        if isdatetime(datecol), d = dateshift(datecol,'start','minute');
        else, d = try_dates(datecol); end
        iTime = vfind(T, {'Time Local','TIME LOCAL','Local Time'});
        if ~isempty(iTime)
            timecol = T{:, iTime};
            if isdatetime(timecol), t = timeofday(timecol);
            else, t = try_times_local(timecol); end
            dt = d + t;
        else
            dt = d;
        end
        dt.TimeZone = '';
    catch ME
        ok=false; dt=NaT(0,1); why=ME.message;
    end
end

function d = try_dates(x)
    fmts = {'yyyy-MM-dd','M/d/yyyy','MM/dd/yyyy','M-d-yyyy','MM-dd-yyyy','dd-MMM-yyyy','yyyy/MM/dd'};
    for k=1:numel(fmts)
        try, d = datetime(x,'InputFormat',fmts{k}); return; catch, end
    end
    try, d = datetime(x); return; catch, end
    error('Could not parse Date Local column.');
end

function t = try_times_local(x)
    fmts = {'HH:mm:ss','H:mm:ss','HH:mm','H:mm','hh:mm a','h:mm a','HHmm'};
    for k=1:numel(fmts)
        try, tt = datetime(x,'InputFormat',fmts{k}); t = timeofday(tt); return; catch, end
    end
    try, tt = datetime(x); t = timeofday(tt); return; catch, end
    tt = datetime(repmat("00:00:00",size(x)),'InputFormat','HH:mm:ss'); t = timeofday(tt);
end

function y = first_non_nan(x)
    i = find(~isnan(x),1,'first'); if isempty(i), y=NaN; else, y=x(i); end
end

function col = getcol(T, idx)
    if isempty(idx), col = NaN(height(T),1); else, col = T{:, idx}; end
end
