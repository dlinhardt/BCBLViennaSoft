function doRetinotopyScan(params)

% doRetinotopyScan - runs retinotopy scans
%
% doRetinotopyScan(params)
%
% Runs any of several retinotopy scans
%
% 99.08.12 RFD wrote it, consolidating several variants of retinotopy scan code.
% 05.06.09 SOD modified for OSX, lots of changes.
% 11.09.15 JW added a check for modality. If modality is ECoG, then call
%           ShowScanStimulus with the argument timeFromT0 == false. See
%           ShowScanStimulus for details.

% defaults
if ~exist('params', 'var'), error('No parameters specified!'); end

% make/load

if strcmp(params.experiment,'wedgesrings') || ...
   strcmp(params.experiment,'wedgesringsalt') || ...
   strcmp(params.experiment,'wedgesringsaltnojump')
    
    TempStim.wedges = retLoadStimulus(params.wedges);
    TempStim.rings = retLoadStimulus(params.rings);
    params=params.wedges;
    
    stimulus=TempStim.wedges;
    stimulus.images=cat(3,TempStim.wedges.images{1},TempStim.rings.images{1});
    
    SeqLength=length(stimulus.seq);
    TotalBlankDuration=SeqLength-(params.scanDuration*params.motionSteps*params.tempFreq);
    StimWithBlankLength=SeqLength/(params.numCycles/2);
    StimLength=StimWithBlankLength-(TotalBlankDuration/4);
    SequenceWithBlank=stimulus.seq(1:StimWithBlankLength);
    Sequence=stimulus.seq(1:StimLength);
    
    if strcmp(params.experiment,'wedgesringsalt')
        
        stimulus.seq(StimWithBlankLength*1+1:StimWithBlankLength*2)=SequenceWithBlank+(params.period*params.motionSteps)/params.tr+1;%SequenceWithBlank+params.period*params.motionSteps+1;
        stimulus.seq(StimWithBlankLength*2+1:StimWithBlankLength*2+StimLength)=flipud(Sequence);
        stimulus.seq(StimWithBlankLength*3+1:StimWithBlankLength*3+StimLength)=flipud(Sequence+(params.period*params.motionSteps)/params.tr+1);
        
    elseif strcmp(params.experiment,'wedgesringsaltnojump')
        
        stimulus.seq(StimWithBlankLength*1+1:StimWithBlankLength*1+StimLength)=[Sequence(1:length(Sequence)/2);flipud(Sequence(length(Sequence)/2+1:end))]+(params.period*params.motionSteps)/params.tr+1;
        stimulus.seq(StimWithBlankLength*2+1:StimWithBlankLength*2+StimLength)=flipud(Sequence);
        stimulus.seq(StimWithBlankLength*3+1:StimWithBlankLength*3+StimLength)=[flipud(Sequence(1:length(Sequence)/2));Sequence(length(Sequence)/2+1:end)]+(params.period*params.motionSteps)/params.tr+1;
        
    else
        
        stimulus.seq(StimWithBlankLength*1+1:StimWithBlankLength*2)=SequenceWithBlank+params.period*params.motionSteps+1;
        stimulus.seq(StimWithBlankLength*3+1:StimWithBlankLength*4)=SequenceWithBlank+params.period*params.motionSteps+1;
    end
    
else
    stimulus = retLoadStimulus(params);
end

%Report Stimulus length in Scan

% disp(['[',mfilename,'] Displaying the stimulus will take a total of ', ...
%     num2str((length(stimulus.seq)/(params.motionSteps*params.tempFreq))/params.tr'),...
%     ' scans at a TR of ',num2str(params.tr),' secs.'])
%disp(['[',mfilename,'] For TR=1.25 each blank has a duration of 12.5 seconds. 
% For all other TRs each of the four blanks has a duration of ceil(1/3 single bar screen pass)'])
% disp(['[',mfilename,'] Each of the four blanks has a duration of 1/3 period ' ...
%       '(bar screen pass, wedge rotation, circle period)'])


%Use to create stimuli for presentation
% save('stimulus','params','stimulus')

%Background Color Outside Stimulus
if isfield(params,'BackgroundFullscreen')
    params.display.backColorRgb=params.BackgroundFullscreen;
end

% loading mex functions for the first time can be
% extremely slow (seconds!), so we want to make sure that
% the ones we are using are loaded.
KbCheck;GetSecs;WaitSecs(0.001);

%try
% check for OpenGL
AssertOpenGL;

% to skip annoying warning message on display (but not terminal)
%Screen('Preference', 'Verbosity', 2);
Screen('Preference', 'VisualDebugLevel', 0);
Screen('Preference','SkipSyncTests', 1);

% Open the screen
params.display                = openScreen(params.display);
params.display.devices        = params.devices;

params.display.fixType = params.fixation;

% to allow blending
Screen('BlendFunction', params.display.windowPtr, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

% Shift Stimulus
if isfield(params,'ShiftStim') && max(abs(params.ShiftStim))~=0
    %MaxShift is maximum stimulus shift without cutting off the
    %stimulus
    MaxShift=min(params.display.numPixels)-params.StimSizePixel.y;
    ShiftStimPixDim(1,1)=params.ShiftStim(1)*MaxShift;
    ShiftStimPixDim(2,1)=params.ShiftStim(2)*-MaxShift;
    params.display.rect=[ShiftStimPixDim(1) ShiftStimPixDim(2) params.display.rect(3) params.display.rect(4)];
    
    MaxShiftFixation=params.display.numPixels(2)/2-round(params.StimSizePixel.y/2);
    ShiftStimFixationPixDim(1,1)=params.ShiftStim(1)*MaxShiftFixation;
    ShiftStimFixationPixDim(2,1)=params.ShiftStim(2)*-MaxShiftFixation;
end

% Store the images in textures
stimulus = createTextures(params.display,stimulus);

% If necessary, flip the screen LR or UD  to account for mirrors
% We now do a single screen flip before the experiment starts (instead
% of flipping each image). This ensures that everything, including
% fixation, stimulus, countdown text, etc, all get flipped.
retScreenReverse(params, stimulus);

% If we are doing ECoG, then add photodiode flash to every other frame
% of stimulus. This can be used later for syncing stimulus to electrode
% outputs.
%stimulus = retECOGtrigger(params, stimulus);

for n = 1:params.repetitions
    % set priority
    Priority(params.runPriority);
    
    % reset colormap?
    retResetColorMap(params);
    
    
    if isfield(params,'MovingFixation')
        
        % For Moving Fixation:
        nFrames = length(stimulus.seq);
        
        if strcmp(params.MovingFixation.Type,'Static')
            
            params.MovingFixation.ArraySize=nFrames;
            params.MovingFixation.Array(1,:)=zeros(1,nFrames);
            params.MovingFixation.Array(2,:)=zeros(1,nFrames);
            
        elseif strcmp(params.MovingFixation.Type,'Circle')
            
            ArrayNormalized=0:params.MovingFixation.Speed:2*pi;
            params.MovingFixation.Array=cos(ArrayNormalized)*params.MovingFixation.Radius;
            params.MovingFixation.ArraySize=size(Array,2);
            
        elseif strcmp(params.MovingFixation.Type,'SmoothRandom')
            
            %Rand. distributed integer numbers from -radius to radius
            
            xArrayShort = randi(2*params.MovingFixation.Radius,[1,int8(nFrames*params.MovingFixation.Speed)])-params.MovingFixation.Radius;
            yArrayShort = randi(2*params.MovingFixation.Radius,[1,int8(nFrames*params.MovingFixation.Speed)])-params.MovingFixation.Radius;
            
            xArrayLong = round(imresize(xArrayShort,[1,nFrames]));
            yArrayLong = round(imresize(yArrayShort,[1,nFrames]));
            
            params.MovingFixation.ArraySize=nFrames;
            params.MovingFixation.Array(1,:)=xArrayLong;
            params.MovingFixation.Array(2,:)=yArrayLong;
            
        elseif strcmp(params.MovingFixation.Type,'Random')
            
            %Rand. distributed integer numbers from -radius to radius
            xArrayShort = randi(2*params.MovingFixation.Radius,[1,nFrames*params.MovingFixation.Speed])-params.MovingFixation.Radius;
            yArrayShort = randi(2*params.MovingFixation.Radius,[1,nFrames*params.MovingFixation.Speed])-params.MovingFixation.Radius;
            
            xArrayLong = imresize(xArrayShort,[1,nFrames],'nearest');
            yArrayLong = imresize(yArrayShort,[1,nFrames],'nearest');
            
            params.MovingFixation.ArraySize=nFrames;
            params.MovingFixation.Array(1,:)=xArrayLong;
            params.MovingFixation.Array(2,:)=yArrayLong;
            
        end
        
        PatientName=params.PatientName;
        MovingFixationParameters=params.MovingFixation;
        
        if ispc
            save(['C:\Users\fMRI Stimulus\Dropbox\measurementlaptop\FixationDotSequences\',PatientName],'MovingFixationParameters')
        else
            save(['/Users/fmri/Dropbox/measurementlaptop/FixationDotSequences/',PatientName],'MovingFixationParameters')
        end
    end
    
    
    %params.display.backColorRgb=100;
    if ~isfield(params,'DrawFirstTexture')
        params.DrawFirstTexture=0;
    end
    % wait for go signal
    onlyWaitKb = false;
    if isfield(params,'ShiftStim') && max(abs(params.ShiftStim))~=0
        if isfield(params, 'MovingFixation')
            ResponseDeviceNumber=pressKey2Begin(params.display, onlyWaitKb, [], [], params.triggerKey,stimulus,params.DrawFirstTexture,ShiftStimFixationPixDim, params.MovingFixation);
        else
            ResponseDeviceNumber=pressKey2Begin(params.display, onlyWaitKb, [], [], params.triggerKey,stimulus,params.DrawFirstTexture,ShiftStimFixationPixDim);
        end
    elseif isfield(params, 'MovingFixation')
            ResponseDeviceNumber=pressKey2Begin(params.display, onlyWaitKb, [], [], params.triggerKey,stimulus,params.DrawFirstTexture,0, params.MovingFixation);
    else
        switch params.triggerKey
            case {'bcbl'}
                pressKey2Begin_bcbl(params.display, onlyWaitKb, [], [], params.triggerKey);
                ResponseDeviceNumber = 2;
            otherwise
                ResponseDeviceNumber = pressKey2Begin(params.display, onlyWaitKb, [], [], params.triggerKey,stimulus,params.DrawFirstTexture);
        end
    end
    
    % If we are doing eCOG, then signal to photodiode that expt is
    % starting by giving a patterned flash
    %retECOGdiode(params);
    
    % countdown + get start time (time0)
    [time0] = countDown(params.display,params.countdown,params.startScan, params.trigger);
    time0   = time0 + params.startScan; % we know we should be behind by that amount
    
    if isfield(params,'EyetrackerExperiment') && params.EyetrackerExperiment==1
        
        Eyelink('Message', ['Experiments Starts. Time is: ',num2str(now)]);
        display(['Experiments start time (',num2str(now),') successfully sent to Eyetracker.'])
        
    end
    
    
    % go
    if isfield(params, 'modality') && strcmpi(params.modality, 'ecog')
        timeFromT0 = false;
    else timeFromT0 = true;
    end
    
    if ~isfield(params,'fovgrid')
        params.fovgrid=0;
    end
    
    if isfield(params,'MovingFixation')
        if isfield(params,'ShiftStim') && max(abs(params.ShiftStim))~=0
            [response, timing, quitProg] = showScanStimulus(params.display,stimulus,time0, timeFromT0,ResponseDeviceNumber,params.fovgrid, params.triggerKey,params.MovingFixation,ShiftStimFixationPixDim); %#ok<ASGLU>
        else
            [response, timing, quitProg] = showScanStimulus(params.display,stimulus,time0, timeFromT0,ResponseDeviceNumber,params.fovgrid, params.triggerKey,params.MovingFixation); %#ok<ASGLU>
        end
    elseif isfield(params,'ShiftStim') && max(abs(params.ShiftStim))~=0
        
        [response, timing, quitProg] = showScanStimulus(params.display,stimulus,time0, timeFromT0,ResponseDeviceNumber,params.fovgrid, params.triggerKey,[],ShiftStimFixationPixDim); %#ok<ASGLU>
        
    else
        
        [response, timing, quitProg] = showScanStimulus(params.display,stimulus,time0, timeFromT0,ResponseDeviceNumber,params.fovgrid, params.triggerKey); %#ok<ASGLU>
        
    end
    
    if isfield(params,'EyetrackerExperiment')&&params.EyetrackerExperiment==1
        
        Eyelink('Message', ['Experiments Stops. Time is: ',num2str(now)]);
        display(['Experiments stop time (',num2str(now),') successfully sent to Eyetracker.'])
        
    end
    
    % reset priority
    Priority(0);
    
    % get performance
    [pc,rc] = getFixationPerformance(params.fix,stimulus,response);
    fprintf('[%s]: percent correct: %.1f %%, reaction time: %.1f secs',mfilename,pc,rc);
    if isfield(params,'PatientName') && ~strcmp(params.PatientName,'none')
        SubjectName=params.PatientName;
    else
        SubjectName=date;
    end
    
    if ~isempty(params.loadMatrix) && isfield(params,'FixationPerformanceFolder')
        [~,LoadStimName]=fileparts(params.loadMatrix);
        fid = fopen(fullfile(params.FixationPerformanceFolder,[SubjectName,'.txt']), 'a+');
        fprintf(fid,'Fixation performance of run "%s", which finished on %s:\n',LoadStimName,datestr(now));
        fprintf(fid,'percent correct: %.1f %%, reaction time: %.1f secs\n',pc,rc);
        fclose(fid);
    end
    
    % save
    % if params.savestimparams && isfield(params,'MeasurementlaptopFolderLocation')
    if isfield(params,'MeasurementlaptopFolderLocation')    
        filename = fullfile(params.MeasurementlaptopFolderLocation,'/measurementlaptop/logfiles/',[datestr(now,30),'.mat']);
        save(filename);                % save parameters
        fprintf('[%s]:Saving in %s.',mfilename,filename);
    end;
    
    % don't keep going if quit signal is given
    if quitProg, break; end;
    
end;

% Close the one on-screen and many off-screen windows
closeScreen(params.display);
% We just need sca to remove the white screen at the end
try
    sca;
end

%catch ME
% clean up if error occurred

%    myerror=ME
%    Screen('CloseAll'); setGamma(0); Priority(0); ShowCursor;
%    warning(ME.identifier, ME.message);
%    error(ME.message)

%end;


return;

