function RetStim(varargin)
%RetStim Usage: Eightbars(varargin)
%Performs Eightbars stimulus (TR=1000ms/1250/1500/2000ms) with or without different simulated scotoma,
%various fixation aids, without and with eyetracker using different calibration targets and
%calibration areas. It is also possible to have a moving fixation point to test Eyetracker correction.
%
%TR = TR of the MRI sequence.
%Possible values: 1,1.25,1.5,2
%Default = 1.5
%
%PatientName = If you want a specific edf/FixationPerformancce filename you can enter it here.
%Default = 'none'
%
%StimName = If you know you the name of the Stim File, you can enter it
%directly. In this case SimulatedScotoma and Fixation variables are being ignored.
%Default = 0
%
%StimType = Choose the retinotopic stimulus type
%Possible values = 'fullfield,'eightbars_blanks','wedgeringsaltnojump'
%Default = 'eightbars_blanks'
%
%CustomStimSize = If only a part of the screen is visible, this allows to
%shrink the stimulus
%Possible values = numeric1al -> 5.5 (for 7T)
%Default = []
%
%ShiftStimX,ShiftStimY = Shift stimulus to ensure perfect visibility
%Possible values = [-1,1]
%Default = 0
%
%Repetitions = Number of stimulus repetitions
%Default = 1
%
%SimulatedScotoma = Option to show a centric scotoma overlay of different size.
%Possible values = 0, 1.25, 2.5, 5
%Default = 0
%
%Fixation = Choose the type of color changing overlay
%Possible values: 'disk', 'my thin cross'
%Default ='my thin cross'
%
%StaticBlackFixation = Choose if you want to show an overlay which helps with center fixation.
%Possible values: 'none', 'circle', 'arrow' and 'cross'
%Default ='none'
%
%MovingFixation = Fixation point can move in a circular or random motion.
%Default = 0
%Select center using MovingFixation.Center
%Default = [0.5, 0.5]
%Specify Type with MovingFixation.Type
%Possible values = 'Static, 'Circle', 'Random' and 'SmoothRandom' (using interpolation)
%Default = 'Static'
%Specify radius and speed in MovingFixation.Speed and MovingFixation.Radius.
%Possible values = MovingFixation.Speed=0.05 and MovingFixation.Radius=64
%
%Eyetracker = Choose if you want to use the Eyetracker.
%Possible values: 0, 1
%Default = 0
%
%CalibrationTargetSize = If a patient struggles to fixate the calibration targets you can enlarge them.
%Possible values: 'small', 'medium', 'large', 'giant'
%Default = 'small'
%
%UsePlusCalibrationTarget = Use pluses instead of circle shaped targets for calibration.
%Possible values: 0, 1
%Default = 0
%
%CalibValidRatio = Changes the size of the area where Calibration and Validation is performed.
%Possible Values: [0.1 1]
%Default = 1


Display.numPixels  = [1280 1024];
Display.dimensions = [42 31.5];
Display.pixelSize = Display.dimensions(2)/Display.numPixels(2);
Display.distance = 128;
Display.frameRate = 60; % VGA Projector
Display.backColorIndex=128;

%Create input parser

p = inputParser;

p.addParameter('MeasurementlaptopFolderLocation','/Users/fmri/Dropbox/',@ischar)
p.addParameter('StimulusFolder',fullfile('measurementlaptop','images'),@ischar);
p.addParameter('EDFFolder',fullfile('measurementlaptop','edfFiles'),@ischar);
p.addParameter('FixationPerformanceFolder',fullfile('measurementlaptop','FixationPerformance'),@ischar);
p.addParameter('TR', 1.5,@isnumeric);
p.addParameter('PatientName','none',@ischar);
p.addParameter('StimName',0,@ischar);
p.addParameter('FullStimName','',@ischar);
p.addParameter('StimType',['allInFile'],@ischar);
p.addParameter('CustomStimSize',[],@isnumeric);
p.addParameter('ShiftStimX',0,@isnumeric);
p.addParameter('ShiftStimY',0,@isnumeric);
p.addParameter('Repetitions',1,@isnumeric);
p.addParameter('SimulatedScotoma',0,@isnumeric);
p.addParameter('BackgroundFullscreenColor',[],@isnumeric);
p.addParameter('FixationandBackgroundSizeMult',[],@isnumeric);
p.addParameter('Fixation', 'my thin cross',@ischar);%disk,'my thin cross'
p.addParameter('StaticBlackFixation', 'none',@ischar);
p.addParameter('MovingFixation', 0); % ,@isstruct
p.addParameter('Eyetracker', 0,@isnumeric);
p.addParameter('CalibrationTargetSize', 'small',@ischar);
p.addParameter('UsePlusCalibrationTarget', 0,@isnumeric);
p.addParameter('CalibValidRatio', 1,@isnumeric);
p.addParameter('TriggerKey', 's',@ischar); %only 'prisma' has an effect in pressKey2Begin.m
p.addParameter('ScotomaBorderVisualAngle', 3.5,@isnumeric);
p.addParameter('Display', Display, @isstruct);
p.addParameter('DrawFirstTexture', 0, @isnumeric); % 1 is drawing first image instead of last before scan starts

p.parse(varargin{:})
Screen('Preference', 'SkipSyncTests', 1);
Screen('Preference', 'VisualDebugLevel', 0);
%Show inputs

input = p.Results



%Prepend MeasurementlaptopFolderLocation to Paths
input.StimulusFolder=fullfile(input.MeasurementlaptopFolderLocation,input.StimulusFolder);
input.EDFFolder=fullfile(input.MeasurementlaptopFolderLocation,input.EDFFolder);
input.FixationPerformanceFolder=fullfile(input.MeasurementlaptopFolderLocation,input.FixationPerformanceFolder);

if ischar(input.StimName)
    
    Stimulus=input.StimName;
    disp(['[',mfilename,'] StimName specified! SimulatedScotoma and Fixation variables are being ignored!'])
    
else
    
    %Create Stimulus Name
    
    Stimulus=input.StimType;
    
    if ~isempty(input.CustomStimSize)
        
        Stimulus=[Stimulus,'_StimSize',strrep(num2str(input.CustomStimSize),'.','dot')];
        
    end
    
    if input.SimulatedScotoma
        
        Stimulus=[Stimulus,'_r',strrep(num2str(input.SimulatedScotoma),'.','dot'),'degree_center'];
        
    end
    
    if ~strcmp(input.StaticBlackFixation,'none')
        
        Stimulus=[Stimulus,'_',input.StaticBlackFixation,'_fixation'];
        
    end
    
end

%Check if Stimulus exists
if isempty(input.FullStimName)
    FullStimulusName=[Stimulus,'_tr',num2str(input.TR)];
    FullStimulusPath=fullfile(input.StimulusFolder,[FullStimulusName,'_images.mat']);
    %FullStimulusName = Stimulus;
    %FullStimulusPath=fullfile(input.StimulusFolder,[FullStimulusName,'.mat']);
else
    [~,FullStimulusName,ext] = fileparts(input.FullStimName);
    FullStimulusName = strcat(FullStimulusName,ext);
    FullStimulusPath = input.FullStimName;
end

% convert file names to char
FullStimulusPath = char(FullStimulusPath);
FullStimulusName = char(FullStimulusName);

if exist(FullStimulusPath,'file') || strcmp(input.StimType,'prismacentersurround')
    
    display(strcat("[",string(mfilename),"] Performing Stimulus: ",FullStimulusName))
    
else
    
    disp(['[',mfilename,'] Stimulus: ',FullStimulusPath,' doesn''t exist. Build it with one of the "Create..." functions.'])
    return
    
end

%Disable Psychtoolbox welcome screen & Sync Failure Visual Warning
Screen('Preference', 'VisualDebuglevel', 1);

% Using Eyetracker?
if input.Eyetracker==1
    
    %Modifying CalibValidRatio
    CalibValidRatio=[0.88,0.83];
    
    if input.CalibValidRatio~=1
        
        CalibValidRatio=CalibValidRatio*input.CalibValidRatio;
        
    end
    
    for PresentRun=1:input.Repetitions
        
        display(['[',mfilename,'] PERFORMING RUN ',num2str(PresentRun)])
        
        
        [EyelinkParameters, edfFile, width,height]=ConfigEyetracker(PresentRun,...
            input.CalibrationTargetSize,...
            input.UsePlusCalibrationTarget,...
            CalibValidRatio);
        DriftCorrection(EyelinkParameters);
        
        StartEyetracker(width,height);
        
        switch input.StimType
            case {'fullfield'}
                LoadFullFieldStim(FullStimulusPath,input);
            case {'eightbars_blanks'}
                LoadEightbarsStim(FullStimulusPath,input);
            case {'allInFile'}
                readParams = load(FullStimulusPath,'params');
                readParams.params.loadMatrix   = FullStimulusPath;
                readParams.params.experiment   = 'experiment from file';
                readParams.params.triggerKey   = input.TriggerKey;
                readParams.params.runPriority  = 7;
                readParams.params.repetitions  = input.Repetitions;
                readParams.params.display      = input.Display;
                readParams.params.startScan    = 0;
                readParams.params.prescanDuration = 0;
                readParams.params.DrawFirstTexture = input.DrawFirstTexture;
                readParams.params.MeasurementlaptopFolderLocation = input.MeasurementlaptopFolderLocation;
                readParams.params.FixationPerformanceFolder = input.FixationPerformanceFolder;
                readParams.params.PatientName = input.PatientName;
                readParams.params.BackgroundFullscreen = input.BackgroundFullscreenColor;
                readParams.params.fixation = input.Fixation;
                LoadAllInFile(readParams.params, input);
            case {'wedgeringsaltnojump'}
                LoadRingAndWedgeStim(FullStimulusPath,input);
            case {'prismacentersurround'}
                CreatePrismaCenterSurroundStim(input.ScotomaBorderVisualAngle,...
                    input.TR,...
                    input.TriggerKey,...
                    input.Eyetracker)
            otherwise
                disp(['[',mfilename,'] Stimulus type ',input.StimType,' not known. Aborting...'])
                return
        end
        
        StopEyetracker(width,height);
        ETstopNow = datestr(now, 'yyyyddmm_HHMMSS');
        
        %Define Patient Name for EDF File automatically if not specified
        if strcmp(input.PatientName,'none')
            
            EDFLocalFilename=fullfile(input.EDFFolder,['EyeTrackerDataReceivedOn_',ETstopNow]);
            
        elseif input.Repetitions>1
            
            EDFLocalFilename=fullfile(input.EDFFolder,[input.PatientName,'_r',num2str(PresentRun),'_',ETstopNow]);
            
        else
            
            EDFLocalFilename=fullfile(input.EDFFolder,[input.PatientName,'_',ETstopNow]);
            
        end
        
        GetEDFDataFile(edfFile,EDFLocalFilename);
        
        Eyelink('ShutDown');
        
        % Read out gaze position
        
        [x,y]=ExtractFromEDFfile(EDFLocalFilename);
        
        save([EDFLocalFilename,'_',ETstopNow,'_gaze.mat'],'x','y')
        
    end
    
else
    
    for PresentRun=1:input.Repetitions
        switch input.StimType
            case {'fullfield'}
                LoadFullFieldStim(FullStimulusPath,input);
            case {'eightbars_blanks'}
                LoadEightbarsStim(FullStimulusPath,input);
            case {'allInFile'}
                readParams = load(FullStimulusPath,'params');
                readParams.params.loadMatrix   = FullStimulusPath;
                readParams.params.experiment   = 'experiment from file';
                readParams.params.triggerKey   = input.TriggerKey;
                readParams.params.runPriority  = 7;
                readParams.params.repetitions  = input.Repetitions;
                readParams.params.display      = input.Display;
                readParams.params.startScan    = 0;
                readParams.params.prescanDuration = 0;
                readParams.params.DrawFirstTexture = input.DrawFirstTexture;
                readParams.params.MeasurementlaptopFolderLocation = input.MeasurementlaptopFolderLocation;
                readParams.params.FixationPerformanceFolder = input.FixationPerformanceFolder;
                readParams.params.PatientName = input.PatientName;
                readParams.params.BackgroundFullscreen = input.BackgroundFullscreenColor;                readParams.params.fixation = input.Fixation;
                readParams.params.fixation = input.Fixation;
                LoadAllInFile(readParams.params, input);
            case {'wedgeringsaltnojump'}
                LoadRingAndWedgeStim(FullStimulusPath,input);
            case {'prismacentersurround'}
                CreatePrismaCenterSurroundStim(input.ScotomaBorderVisualAngle,input.TR,input.TriggerKey,input.Eyetracker)
            otherwise
                disp(['[',mfilename,'] Stimulus type ',input.StimType,' not known. Aborting...'])
                return
        end
    end
    
end

end

