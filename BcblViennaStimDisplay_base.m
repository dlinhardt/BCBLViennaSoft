%% This script creates the images that will be morphed lsqater on

% RUN THIS LINE FIRST, THEN USE THE RUN COMMAND FOR THE WHOLE FILE
% EVERY TIME WE ARE RUNNING THE STIMULUS
%{ 
   tbUse BCBLViennaSoft;
%} 

close all; clear all;

PatientName = 'test';  
% Edit EyeTracker. Options: 0 | 1
Eyetracker = 0;

% Edit TR. Options: 1|0
TR = 1;  

% Edit imageName. Options: 'hrf'|'bar'
imageName = 'bar_nojump_dur-240_ecc-9_width-2_tr1_images.mat';

% click here after start:
% 

% shift stimulus
ShiftStimX = 0;
ShiftStimY = 0  ;

% Edit macEcc. Options: 8 | 9
maxEcc = 9; % 3T = 9, , 7T = 6


% No options for these for now
stimSize     = 1024;
barWidth     = 2;
scanDuration = 300;

%% EDIT THIS DIFFERENTLY IN BCBL/VIENNA
params = retCreateDefaultGUIParams;
% Paste here data from both Vienna and SS

% BCBL
%{
% masks = string(fullfile(pmRootPath,'data','images','maskimages.mat'));
masks = string(fullfile(bvRootPath,"morphing","DATA","retWordsMagno","maskimages.mat")); % both are the same
stimulusdir = string(fullfile(bvRootPath,"morphing","DATA","retWordsMagno"));
% Screen size and distance
params.display.numPixels  = [1280 1024];
params.display.dimensions = [42 31.5];
params.display.pixelSize = params.display.dimensions(2)/params.display.numPixels(2);
params.display.distance = 128;
params.display.frameRate = 60; % VGA Projector
params.display.backColorIndex=128;
% Calculate radius (calculator: https://www.sr-research.com/visual-angle-calculator/)
params.radius = rad2deg(atan(params.display.dimensions(2)/params.display.distance)/2);
TriggerKey = 'bcbl';
triggerDeviceDetector = 'KeyWarrior8 Flex';
DrawFirstTexture = 0;
%}

% VIENNA
% {
% masks = string(fullfile(bvRootPath,'data','images','maskimages.mat'));
% masks = "~/soft/morphing/DATA/retWordsMagno/maskimages.mat"; % both are the same
stimulusdir="/Users/fmri/BCBLViennaSoft/morphing/DATA/retWordsMagno";
params.display.numPixels  = [12860 1024];
params.display.dimensions = [38.000 30.4000];
params.display.pixelSize = params.display.dimensions(2)/params.display.numPixels(2);
params.display.distance  = 94.;
params.display.frameRate = 60; % VGA Projector
% Calculate radius (calculator: https://www.sr-research.com/visual-angle-calculator/)
params.radius = rad2deg(atan(params.display.dimensions(2)/params.display.distance)/2);
TriggerKey = '7t'; % In Vienna use the same thing as always
% triggerDeviceDetector = '904';
DrawFirstTexture = 1;
%}

% This values modify the retstim, these are all the vars that it takes that are
% not in the call

%% EDIT THIS AT EXPERIMENT LEVEL, SHOULD BE SAME IN BCBL/VIENNA
% For RetStim (pass them all, always)
PatientName                     = PatientName;
MeasurementlaptopFolderLocation = bvRootPath;
FixationPerformanceFolder       = fullfile('measurementlaptop', 'FixationPerformance');
StimType                        = 'allInFile'; % Provide file with params and stimuli
SimulatedScotoma                = 0; 
FixationandBackgroundSizeMult   = [];
StaticBlackFixation             =  'none';
MovingFixation                  = 0;
CalibrationTargetSize           = 'small';
UsePlusCalibrationTarget        = 0;
CalibValidRatio                 = .8;
ScotomaBorderVisualAngle        = 0; % 3.5;
Repetitions                     = 1;



% For params, some where defaults within the file, load/edit them here and do
% not change them later. This travels Vienna/BCBL with the stimulus file
params.tr               = TR;
params.scanDuration     = scanDuration;
params.experiment       = 'experiment from file';
params.fixation         = 'disk';%'thin cross';%
params.modality         = 'fMRI';
params.repetitions      = Repetitions;
params.BackgroundFullscreenColor = 30; % 0=Black, 255=White
params.calibration      =  []; % Was calibrat66666qed with Photometer
params.stimSize         =  'max';
params.skipCycleFrames  =  0;
params.prescanDuration  =  0;
% params.numImages        = round((params.scanDuration + params.prescanDuration)/params.tr);
params.ShiftStim        = [0 0];
params.display.gammaTable = [linspace(0,1,256);linspace(0,1,256);linspace(0,1,256)]';
params.runPriority      =  7;


totalduration = params.scanDuration;

%% RUN RetStim


% Generate file name to read (created with the python code) 
if strcmp(imageName, 'hrf')
    stim_to_use = 'optimal_hrf_tr1_images.mat';
elseif strcmp(imageName, 'bar')
    stim_to_use = 'bar_nojump_dur-240_ecc-9_width-2_tr1_images.mat';
else
    stim_to_use = imageName;
end

loadMatrix = fullfile(bvRootPath,'images', stim_to_use);


if isfile(loadMatrix)
    RetStim('FullStimName', loadMatrix, ...
            'PatientName', PatientName, ...
            'Eyetracker', Eyetracker, ...
            'StimType', StimType, ...
            'SimulatedScotoma', SimulatedScotoma, ...
            'FixationandBackgroundSizeMult', FixationandBackgroundSizeMult, ...
            'FixationPerformanceFolder', FixationPerformanceFolder, ...
            'StaticBlackFixation', StaticBlackFixation, ...
            'MovingFixation', MovingFixation, ...
            'CalibrationTargetSize', CalibrationTargetSize, ...
            'UsePlusCalibrationTarget', UsePlusCalibrationTarget, ...
            'CalibValidRatio', CalibValidRatio, ...
            'ScotomaBorderVisualAngle', ScotomaBorderVisualAngle, ...
            'TriggerKey', TriggerKey, ...
            'TR', TR, ...
            'Repetitions', Repetitions, ...
            'DrawFirstTexture', DrawFirstTexture, ...;
            'MeasurementlaptopFolderLocation', MeasurementlaptopFolderLocation, ...
            'ShiftStimX', ShiftStimX, ...
            'ShiftStimY', ShiftStimY,...
            'BackgroundFullscreenColor', params.BackgroundFullscreenColor, ...
            'Fixation', params.fixation);
else
    error('Check the file %s exists, otherwise create it with the python code',loadMatrix)
end
