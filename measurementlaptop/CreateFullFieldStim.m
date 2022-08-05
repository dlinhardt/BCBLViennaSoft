function CreateFullFieldStim(StimName,TR)
% create some default parameters
params = retCreateDefaultGUIParams; 

% modify them
params.experiment       =  'full-field, on-off';
%params.experiment       =  'experiment from file';
params.fixation         =  'my thin cross';%'disk'; % edit in retSetFixationParams.m
params.modality         =  'fMRI';
params.savestimparams   =  1;
%params.savestimparams   =  0;
params.repetitions      =  1;  
params.runPriority      =  7;
params.skipCycleFrames  =  0;
params.prescanDuration  =  0;  
params.period           =  20;%18; %Period of on+off
params.numCycles        =  15; %How often is the Stimulus presented during one run
params.motionSteps      =  2;
params.tempFreq         =  4;
params.contrast         =  1;
params.interleaves      =  [];
params.tr               =  TR;%1.5;
params.loadMatrix       =  [];
%params.loadMatrix       =  ['/Users/fmri/Dropbox/measurementlaptop/images/',StimName,'_images.mat'];
%params.saveMatrix       =  [];
params.saveMatrix       =  [datestr(now,30),'_',StimName,'_tr',num2str(TR),'_images.mat'];
params.calibration      =  []; % Was calibrated with Photometer
%params.calibration      =  '3T2_projector_800x600temp';
params.stimSize         =  4.75%5%5.5;%'max';
params.triggerKey       =  '6'; % For different trigger device see pressKey2Begin.m
%params.trigger          = '5';
params.BackgroundFullscreen = 0;
params.ShiftStim = [0,600]; %x and y centre position
%params.MovingFixation.Type='Static';
%params.MovingFixation.Center=[0 0];
%params.PatientName='Test';

display.screenNumber = max(Screen('screens'));
[width, height] = Screen('WindowSize',display.screenNumber);
display.numPixels       = [width height];
display.dimensions      = [24.6 18.3];
display.pixelSize       = min(display.dimensions./display.numPixels);
display.distance        = 43.0474; 
params.ImageSize=round(2 * angle2pix(display, params.stimSize));

%Gesichtsfeldausfall (Gesichtsfeld = 800x800)

%Ausfall von 1 Balken
%params.xfailure= 101:200;
%params.yfailure= 1:768;

%Ausfall alles au?er 1 Balken
%params.xfailure= [1:334,434:768];
%params.yfailure= 1:768;

%Ausfall von einem Kreis

%resolution= 1024 * 768 (size stimulus = 384)
%r=192;
%xm=384;
%ym=384;
r=(params.ImageSize/2)/3.5; %r=2? scotoma for 7T 
xm=params.ImageSize/2;
ym=params.ImageSize/2;
 
params.mycircle='full';
params.myradius=r;
params.xfailure=xm;
params.yfailure=ym;

%resolution= 1024 * 768 (size stimulus = 384)
% r=192;
% xm=384;
% ym=384;

% params.mycircle='fullhalfleft';
% params.myradius=r;
% params.xfailure=xm;
% params.yfailure=ym;

% r=192;
% xm=384;
% ym=384;
% 
% params.mycircle='fullhalfright';
% params.myradius=r;
% params.xfailure=xm;
% params.yfailure=ym;

%Ausfall alles au?er einem Kreis

%  r=192;
%  xm=384;
%  ym=384;
%  
%  params.mycircle='empty';
%  params.myradius=r;
%  params.xfailure=xm;
%  params.yfailure=ym;

%  r=192;
%  xm=384;
%  ym=384;
%  
%  params.mycircle='emptyhalfleft';
%  params.myradius=r;
%  params.xfailure=xm;
%  params.yfailure=ym;

%  r=192;
%  xm=384;
%  ym=384;
%  
%  params.mycircle='emptyhalfright';
%  params.myradius=r;
%  params.xfailure=xm;
%  params.yfailure=ym;


% run it

ret(params)

end