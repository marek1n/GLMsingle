%% Add dependencies and download the data.


% Add path to GLMsingle
addpath('./../')
addpath(genpath('./../utilities'))

% You also need fracridge repository to run this code
% https://github.com/nrdg/fracridge.git


clear
clc
close all

outputdir = 'example2outputs';


% Download files to data directory
if ~exist('./data','dir')
    mkdir('data')
end

if  ~exist('./data/nsdflocexampledataset.mat','file')
    % download data with curl
    system('curl -L --output ./data/nsdflocexampledataset.mat https://osf.io/g42tm/download')
end
load('./data/nsdflocexampledataset.mat')
% Data comes from subject1, fLoc session from NSD dataset.
% https://www.biorxiv.org/content/10.1101/2021.02.22.432340v1.full.pdf
%%
clc
whos

% data -> consists of several runs of 4D volume files (x,y,z,t)  where
% (t)ime is the 4th dimention.

% ROI -> manually defined region in the occipital cortex. It is a binary
% matrix where (x,y,z) = 1 corresponds to the cortical area that responded
% to visual stimuli used in the NSD project.

fprintf('There are %d runs in total.\n',length(design));
fprintf('The dimensions of the data for the first run are %s.\n',mat2str(size(data{1})));
fprintf('The stimulus duration is %.6f seconds.\n',stimdur);
fprintf('The sampling rate (TR) is %.6f seconds.\n',tr);
%%
figure(1);clf
%Show example design matrix.

for d = 1:length(design)
    subplot(2,2,d)
    imagesc(design{d}); colormap gray; drawnow
    xlabel('Conditions')
    ylabel('TRs')
    title(sprintf('Design matrix for run%i',d))
    %     axis image
end

%%

% design -> Each run has a corresponding design matrix where each column
% describes a single condition (conditions are repeated across runs). Each
% design matrix is binary with 1 specfing the time (TR) when the stimulus
% is presented on the screen.

% In this NSD fLOC session there were 10 distinct images shown and hence
% there are 10 predictor columns/conditions. Notice that white rectangles
% are pseudo randomized and they indicate when the presentaion of each
% image occurs. Stimulus details are described here
% https://github.com/VPNL/fLoc
%%

% Show an example slice of the first fMRI volume.
figure(2);clf

imagesc(makeimagestack(data{1}(:,:,:,1)));
colormap(gray);
axis equal tight;
colorbar;
title('fMRI data (first volume)');

%% Call GLMestimatesingletrial with default parameters.

% Outputs and figures will be stored in a folder (you can specify it's name
% as the 5th output to GLMestimatesingletrial. Model estimates can be also
% saved to the results variable which is the only output of
% GLMestimatesingletrial

% Optional parameters below can be assigned to a strucutre i.e
% opt = struct('wantlibrary',1,'wantglmdenoise',1); Options are the 6th
% input to GLMestimatesingletrial.

% DEFAULT OPTIONS:

% wantlibrary = 1 -> Fit HRF to each voxel
% wantglmdenoise = 1 -> Use GLMdenoise
% wantfracridge = 1  -> Use ridge regression to improve beta estimates
% chunknum = 50000 -> is the number of voxels that we will process at the
%   same time. For setups with lower memory deacrease this number.
%

% wantmemoryoutputs is a logical vector [A B C D] indicating which of the
%     four model types to return in the output <results>. The user must be
%     careful with this, as large datasets can require a lot of RAM. If you
%     do not request the various model types, they will be cleared from
%     memory (but still potentially saved to disk).
%     Default: [0 0 0 1] which means return only the final type-D model.

% wantfileoutputs is a logical vector [A B C D] indicating which of the
%     four model types to save to disk (assuming that they are computed).
%     A = 0/1 for saving the results of the ONOFF model
%     B = 0/1 for saving the results of the FITHRF model
%     C = 0/1 for saving the results of the FITHRF_GLMdenoise model
%     D = 0/1 for saving the results of the FITHRF_GLMdenoise_RR model
%     Default: [1 1 1 1] which means save all computed results to disk.

% numpcstotry (optional) is a non-negative integer indicating the maximum
%     number of PCs to enter into the model. Default: 10.

% fracs (optional) is a vector of fractions that are greater than 0
%     and less than or equal to 1. We automatically sort in descending
%     order and ensure the fractions are unique. These fractions indicate
%     the regularization levels to evaluate using fractional ridge
%     regression (fracridge) and cross-validation. Default:
%     fliplr(.05:.05:1). A special case is when <fracs> is specified as a
%     single scalar value. In this case, cross-validation is NOT performed
%     for the type-D model, and we instead blindly use the supplied
%     fractional value for the type-D model.

% For the purpose of this example we will keep all outputs in the memory.
opt = struct('wantmemoryoutputs',[1 1 1 1]);

% Load GLMsingle outputs if they exist on disk; else, run from scratch
if ~exist([outputdir '/GLMsingle'],'dir')
    
    [results] = GLMestimatesingletrial(design,data,stimdur,tr,[outputdir '/GLMsingle'],opt);
    models.FIT_HRF = results{2};
    models.FIT_HRF_GLMdenoise = results{3};
    models.FIT_HRF_GLMdenoise_RR = results{4};
    
    % We assign outputs of GLMestimatesingletrial to "models" structure. Note
    % that results{1} contains GLM estimates from an ONOFF model, where
    % all images are treated as the same condition. These estimates could be
    % potentially used to find cortical areas that respond to visual
    % stimuli. We want to compare beta weights between conditions therefore we
    % are not going to store the ONOFF GLM results.
    
else
    % Load existing file outputs if they exist
    results = load([outputdir '/GLMsingle/TYPEB_FITHRF.mat']);
    models.FIT_HRF = results;
    results = load([outputdir '/GLMsingle/TYPEC_FITHRF_GLMDENOISE.mat']);
    models.FIT_HRF_GLMdenoise = results;
    results = load([outputdir '/GLMsingle/TYPED_FITHRF_GLMDENOISE_RR.mat']);
    models.FIT_HRF_GLMdenoise_RR = results;
end

% Important outputs:

% R2 -> is model accuracy expressed in terms of R^2 (percentage).
% modelmd -> is the full set of single-trial beta weights (X x Y x Z x
% TRIALS). Beta weights are arranged in a chronological order)
% HRFindex -> is the 1-index of the best fit HRF. HRFs can be recovered
% with getcanonicalHRFlibrary(stimdur,tr)
% FRACvalue -> is the fractional ridge regression regularization level
% chosen for each voxel. Values closer to 1 mean less regularization.

%% Plot a slice of brain with GLMsingle outputs.

% We are going to plot several outputs from the FIT_HRF_GLMdenoise_RR GLM,
% which contains the full set of GLMsingle optimizations.

slice_v1 = 20; % Choose a slice

% Mask out voxels that are outside the brain
brainmask = models.FIT_HRF_GLMdenoise_RR.meanvol(:,5:end-5,slice_v1) > 250;

val2plot = {'meanvol';'R2';'HRFindex';'FRACvalue'};
cmaps = {gray;hot;jet;copper};
figure(3);clf

for v = 1 : length(val2plot)
    
    f=subplot(2,2,v);
    
    % Set non-brain voxels to nan to ease visualization
    plotdata = models.FIT_HRF_GLMdenoise_RR.(val2plot{v})(:,5:end-5,slice_v1);
    plotdata(~brainmask) = nan;
    
    % Plot
    imagesc(plotdata); axis off image;
    colormap(f,cmaps{v}) 
    colorbar
    title(val2plot{v})
    set(gca,'FontSize',20)
    
end

set(gcf,'Position',[1224 840 758 408])

%% Run a baseline GLM to compare with GLMsingle.

% Additionally, for comparison purposes we are going to run a standard GLM
% without HRF fitting, GLMdenoise or ridge regression regularization. We
% will change the default settings by using the "opt" structure.

opt.wantlibrary = 0; % switch off HRF fitting
opt.wantglmdenoise = 0; % switch off GLMdenoise
opt.wantfracridge = 0; % switch off ridge regression
opt.wantfileoutputs = [0 1 0 0];
opt.wantmemoryoutputs = [0 1 0 0];

% Check for existing output; load if possible, else run GLMsingle
if ~exist([outputdir '/GLMbaseline'],'dir')
    
    [ASSUME_HRF] = GLMestimatesingletrial(design,data,stimdur,tr,[outputdir '/GLMbaseline'],opt);
    models.ASSUME_HRF = ASSUME_HRF{2};
    
else
    
    results = load([outputdir '/GLMbaseline/TYPEB_FITHRF.mat']);
    models.ASSUME_HRF = results;
    
end
%%

% Now, "models" variable holds solutions for 4 GLM models
disp(fieldnames(models))

%% Organize GLM outputs to enable calculation of voxel reliability

% To compare the results of different GLMs we are going to calculate the
% voxel-wise split-half reliablity for each model. Reliablity index
% represents a correlation between beta weights for repeated presentations
% of the same stimuli. In short, we are going to check how
% reliable/reproducible are single trial responses to repeated images
% estimated with each GLM type.

% In the code below, we are attempting to locate the
% indices in the beta weight GLMsingle outputs modelmd(x,y,z,trials) that
% correspond to repated conditions.

% Consolidate design matrices
designALL = cat(1,design{:});

% Construct a vector containing 1-indexed condition numbers in chronological
% order.

corder = [];
for p=1:size(designALL,1)
    if any(designALL(p,:))
        corder = [corder find(designALL(p,:))];
    end
end

%%

model_names = fieldnames(models);
model_names = model_names([4 1 2 3]);
% We arrange models from least to most sophisticated (for visualization
% purposes)

%%

% In order to compute split-half reliability, we have to do some indexing.
% We want to find all repetitions of the same condition. For example we can
% look up when during the 4 blocks image 1 was repeated. Each condition should
% be repeated exactly 24 times. 

fprintf('Condition 1 was repeated %i times, with GLMsingle betas at the following indices:\n',length(find(corder==1)));
find(corder==1)

%% Compute median split-half reliability for each GLM version.

% To calculate the split-half reliability we are going to average the odd
% and even beta weights extracted from the same condition and calculate the
% correlation coefficent between these values. We do this for each voxel
% inside two visual ROIs.

% Create output variable
vox_reliabilities = cell(1,length(models));

% For each GLM...
for m = 1 : length(model_names)
    
    % Get the GLM betas
    modelmd = models.(model_names{m}).modelmd;
    
    dims = size(modelmd);
    Xdim = dims(1);
    Ydim = dims(2);
    Zdim = dims(3);
    
    cond = size(design{1},2);
    reps = dims(4)/cond;
    
    % Create an empty variable for storing betas grouped together by
    % condition (X, Y, Z, nReps, nConditions)
    betas = nan(Xdim,Ydim,Zdim,reps,cond);
    
    % Populate repetition beta variable by iterating through conditions
    for c = 1 : length(unique(corder))
        
        indx = find(corder == c);
        betas(:,:,:,:,c) = modelmd(:,:,:,indx);
        
    end

    % Output variable for reliability values
    vox_reliability = NaN(Xdim, Ydim, Zdim);

    % Loop through voxels in the fMRI volume
    for i = 1:Xdim
        for j = 1:Ydim
            for k = 1:Zdim
                
                % Calculate the reliability only for voxels within the
                % V1 and FFA ROIs, for the sake of efficiency
                
                if visual.ROI(i,j,k) > 0 || floc.ROI(i,j,k) > 0
                    
                    vox_data  = squeeze(betas(i,j,k,:,:));
                    even_data = nanmean(vox_data(1:2:end,:));
                    odd_data  = nanmean(vox_data(2:2:end,:));
                    
                    % Reliability is the split-half correlation between odd
                    % and even presentations
                    vox_reliability(i,j,k) = corr(even_data', odd_data');
                    
                end
            end
        end
    end
    

    % Store reliablity for each model
    vox_reliabilities{m} = vox_reliability;
    
    
end


%% Compare visual voxel reliabilities between beta versions in V1 and FFA ROIs.
figure(5);clf
set(gcf,'Position',[491   709   898   297])

% For each GLM type we will calculate median reliability for voxels within the
% visual ROIs and draw a bar plot for FFA and V1.

slice_v1 = 10;
slice_ffa = 3;

for s = 1 : 5
    
    subplot(2,5,s)
    underlay = data{1}(:,:,slice_v1,1);
    overlay  = visual.ROI(:,:,slice_v1)==1;
    underlay_im = cmaplookup(underlay,min(underlay(:)),max(underlay(:)),[],gray(256));
    overlay_im = cmaplookup(overlay,-0.5,0.5,[],[0 0 1]);
    mask = visual.ROI(:,:,slice_v1)==1;
    
    hold on
    imagesc(imrotate(underlay_im,180));
    imagesc(imrotate(overlay_im,180), 'AlphaData', imrotate(mask,180));
    title(sprintf('V1 voxels, slice = %i',slice_v1))
    slice_v1 = slice_v1 + 1;
    axis image
    axis off
    
    subplot(2,5,s+5)
    underlay = data{1}(:,:,slice_ffa,1);
    overlay  = floc.ROI(:,:,slice_ffa)==2;
    underlay_im = cmaplookup(underlay,min(underlay(:)),max(underlay(:)),[],gray(256));
    overlay_im = cmaplookup(overlay,-0.5,0.5,[],round([237 102 31]/255,2));
    mask = floc.ROI(:,:,slice_ffa)==2;
    
    hold on
    imagesc(imrotate(underlay_im,180));
    imagesc(imrotate(overlay_im,180), 'AlphaData', imrotate(mask,180));
    title(sprintf('FFA voxels, slice = %i',slice_ffa))
    slice_ffa = slice_ffa + 1;
    axis image
    axis off
    
end

%% Plot reliability for each beta version

figure(6)

cmap = [0.2314    0.6039    0.6980
    0.8615    0.7890    0.2457
    0.8824    0.6863         0
    0.9490    0.1020         0];

% For each GLM type we calculate median reliability for voxels within the
% V1 and FFA and plot it as a bar plot.

mydata = zeros(length(vox_reliabilities),2);
for m = 1 : 4
    
    vox_reliability = vox_reliabilities{m};
    mydata(m,:) = [nanmedian(vox_reliability(floc.ROI==2)) nanmedian(vox_reliability(visual.ROI==1))];
    
end

bar(mydata)
ylabel('Median reliability')
set(gca,'Fontsize',12)
set(gca,'TickLabelInterpreter','none')
xtickangle(0)
legend({'FFA';'V1'},'Interpreter','None','Location','NorthWest')
set(gcf,'Position',[418   412   782   605])
title('Median voxel split-half reliability of GLM models')
xticklabels(model_names')

% This localizer dataset provides an interesting test case for GLMsingle, since the design is a block
% structure containing different stimuli from the same domain presented
% rapidly in time within each block. The fact that GLMsingle confers clear
% benefit in both a low-level visual region (V1) and a higher-level region
% (FFA) is notable. Moreover, it is reasonable to expect that overall
% reliability would be higher in FFA, since that ROI may yield responses
% that are more category-invariant than those in V1, and the optimizations within GLMsingle
% treat all images within a localizer block as the "same"
% condition, even though there are different images comprising each block.
% As such, it makes sense that voxels in FFA (with larger receptive fields
% and more category invariance) would show higher reliability using the
% split-half metric than those in V1.

%%

% We now plot the improvement of reliability when comparing FIT_HRF_GLMDENOISE_RR
% with ASSUME_HRF, with higher positive values reflecting greater benefit
% from applying GLMsingle

figure(7)
set(gcf,'Position',[616   227   863   790])

% Comparison is the final output (FIT_HRF_GLMDENOISE_RR) vs. the baseline
% GLM (ASSUME_HRF)
vox_improvement = vox_reliabilities{4} - vox_reliabilities{1};

slice = 3;

ROI = visual.ROI == 1 | floc.ROI == 2;

for s = 1:15
    
    subplot(5,3,s) 
    underlay = data{1}(:,:,slice,1);
    overlay  = vox_improvement(:,:,slice);
    underlay_im = cmaplookup(underlay,min(underlay(:)),max(underlay(:)),[],gray(256));
    overlay_im = cmaplookup(overlay,-0.3,0.3,[],cmapsign2);
    mask = ROI(:,:,slice)==1;
    hold on
    imagesc(imrotate(underlay_im,180));
    imagesc(imrotate(overlay_im,180), 'AlphaData', imrotate(mask,180));
    title(sprintf('slice idx %i',slice))
    slice = slice + 1;
    axis image
    colormap(cmapsign2)
    c = colorbar;
    c.TickLabels = {'-0.3';'0';'0.3'};
    xticks([])
    yticks([])
    
end
    
title('change in V1 and FFA voxel reliability due to GLMsingle (r)','Interpreter','none')

