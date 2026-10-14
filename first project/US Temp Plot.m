%% =====================================================================
%  CONFERENCE-QUALITY ΔT2 DECADAL MAP (GEOSHOW / LAMBERT CONIC)
%  ΔT₂ = T2(2011–2020) – T2(1980–1989)
% =====================================================================

clear; close all; clc;

%% ------------------------ Paths ------------------------
addpath('C:\Users\beg24003\OneDrive - University of Connecticut\Desktop\F0AM-4.3.0.1\F0AM-4.3.0.1\Matlab Script HPC');
addpath('C:\Users\beg24003\OneDrive - University of Connecticut\Desktop\F0AM-4.3.0.1\F0AM-4.3.0.1\Matlab Script HPC\shapefiles');

%% ------------------------ Load Data ------------------------
S0 = load('T2_decadal_avg_12PM_figure_data_1980_1989.mat');
S1 = load('T2_decadal_avg_12PM_figure_data_2011_2020.mat');

T0  = S0.figure_data.T2_avg_2D_12pm;
T1  = S1.figure_data.T2_avg_2D_12pm;
LAT = S0.figure_data.XLAT;
LON = S0.figure_data.XLON;

% Kelvin check
if max(T0(:),[],'omitnan') < 150, T0 = T0 + 273.15; end
if max(T1(:),[],'omitnan') < 150, T1 = T1 + 273.15; end

% ΔT2
dT = double(T1) - double(T0);

%% ------------------------ Make Figure & Map Axes ------------------------
f = figure('Position',[100 100 1800 900],'Color','w');

% Lambert conformal conic (gives curved, "smiling" frame)
ax = axesm('lambertstd', ...
    'MapLatLimit',[24 50], ...
    'MapLonLimit',[-125 -66], ...
    'MapParallels',[33 45], ...
    'Origin',[38 -96 0], ...
    'Frame','on', ...
    'FLineWidth',1.4, ...
    'FEdgeColor','k', ...
    'Grid','off', ...
    'MeridianLabel','off', ...
    'ParallelLabel','off');

setm(ax,'FontName','Arial','FontSize',13);

axes(ax); %#ok<LAXES>
hold on;

%% ------------------------ Plot ΔT₂ field ------------------------
hImg = geoshow(LAT, LON, dT, 'DisplayType','texturemap');
set(hImg,'AlphaData',~isnan(dT));   % transparent where NaN

% symmetric limits based on 95th percentile of |ΔT2|
vals = dT(:); vals = vals(isfinite(vals));
rng_val = prctile(abs(vals),95);
if ~isfinite(rng_val) || rng_val==0, rng_val = 1; end

colormap(redblue(256));
caxis([-rng_val rng_val]);

%% ------------------------ State Boundaries ------------------------
states = shaperead('US_states.shp','UseGeoCoords',true);
% FaceColor must be 'none'; use EdgeColor for lines (fixes your error)
geoshow(states, ...
    'FaceColor','none', ...
    'EdgeColor','k', ...
    'LineWidth',0.7);

%% ------------------------ Colorbar & Title ------------------------
cb = colorbar('eastoutside');
cb.Label.String = '\DeltaT_2 (K)';
cb.Label.FontWeight = 'bold';
cb.FontSize = 14;

title({'US July Mean \DeltaT_2 (K)'; '(2011–2020) – (1980–1989)'}, ...
      'FontSize',18,'FontWeight','bold','Interpreter','tex');

tightmap;      % tight frame
gridm off;

%% ------------------------ Save Outputs ------------------------
print(f,'US_DeltaT2_Decadal_12PM_CONUS_Lambert','-dpng','-r450');
exportgraphics(f,'US_DeltaT2_Decadal_12PM_CONUS_Lambert.pdf','ContentType','vector');

disp('✔ Saved high-resolution ΔT₂ map (PNG + PDF)');

%% ------------------------ Local redblue colormap ------------------------
function c = redblue(m)
% Simple red–blue diverging colormap
if nargin < 1, m = size(get(gcf,'colormap'),1); end

if mod(m,2) == 0
    m1 = m*0.5;
    r = (0:m1-1)'/max(m1-1,1);
    g = r;
    r = [r; ones(m1,1)];
    g = [g; flipud(g)];
    b = flipud(r);
else
    m1 = floor(m*0.5);
    r = (0:m1-1)'/max(m1,1);
    g = r;
    r = [r; ones(m1+1,1)];
    g = [g; 1; flipud(g)];
    b = flipud(r);
end
c = [r g b];
end
