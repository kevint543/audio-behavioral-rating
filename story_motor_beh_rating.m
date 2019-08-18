% MATLAB R2018b, Psychtoolbox 3.0.15
% --
% BasicSoundOutputDemo
% DriftDemo
% FontDemo
% KbDemo
% PsychRTBoxDemo
% MouseTraceDemo2

clear; close all;

tic;
AssertOpenGL;

% Perform basic initialization of the sound driver:
InitializePsychSound;

% HideCursor
flag_prac = 1; % for practice run

% sound
repetitions = 1;
device = [];
permutime = 100;

controlfile = dir(fullfile(pwd,'stim','cont*.wav'));
stimulusfile = dir(fullfile(pwd,'stim','stim*.wav'));
practicefile = dir(fullfile(pwd,'stim','prac*.wav'));

for ii = 1:randperm(permutime,1)
    randidx = randperm(length(controlfile));
end
controlfile = controlfile(randidx);
for ii = 1:randperm(permutime,1)
    randidx = randperm(length(stimulusfile));
end
stimulusfile = stimulusfile(randidx);

wavfilename = cat(1,controlfile,stimulusfile,practicefile);
if rem(length(dir('*.mat')),2) % for counter balance
    play_list = [1 5 6 2 3 7 8 4]; % ABBAABBA
else
    play_list = [5 1 2 6 7 3 4 8]; % BAABBAAB
end

if flag_prac
    play_list = 9;
end

% Get the list of screens and choose the one with the highest screen number.
% Screen 0 is, by definition, the display with the menu bar. Often when
% two monitors are connected the one without the menu bar is used as
% the stimulus display.  Chosing the display with the highest dislay number is
% a best guess about where you want the stimulus displayed.
Screen('Preference', 'SkipSyncTests', 1);
setenv('PSYCH_ALLOW_DANGEROUS', '1')
screens = Screen('Screens');
screenNumber = max(screens);

% Find the color values which correspond to white and black: Usually
% black is always 0 and white 255, but this rule is not true if one of
% the high precision framebuffer modes is enabled via the
% PsychImaging() commmand, so we query the true values via the
% functions WhiteIndex and BlackIndex:
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);

% Open a double buffered fullscreen window and select a black background
w = Screen('OpenWindow',screenNumber, black);

% Choose 16 pixel text size:
Screen('TextSize', w, 16);

[width,height] = WindowSize(w);
[xx,yy] = WindowCenter(w);

cross = zeros(height,width);
cross_long = 0.01;
cross_width = 0.001;
cross(round(yy-height*cross_width:yy+height*cross_width),round(xx-width*cross_long:xx+width*cross_long)) = white;
cross(round(yy-height*cross_long:yy+height*cross_long),round(xx-width*cross_width:xx+width*cross_width)) = white;
fixation = Screen('MakeTexture', w, cross);

frame = zeros(height,width);
frame(round(yy-height/4-height*cross_width:yy-height/4+height*cross_width),round(xx-width/4:xx+width/4)) = white;
frame(round(yy+height/4-height*cross_width:yy+height/4+height*cross_width),round(xx-width/4:xx+width/4)) = white;
frame(round(yy-height/4:yy+height/4),round(xx-width/4-width*cross_width:xx-width/4+width*cross_width)) = white;
frame(round(yy-height/4:yy+height/4),round(xx+width/4-width*cross_width:xx+width/4+width*cross_width)) = white;
show_frame = Screen('MakeTexture', w, frame);

% Use realtime priority for better timing precision:
priorityLevel = MaxPriority(w);
Priority(priorityLevel);

flag_ismri = 0;
TR = 2; % for MRI
dummy = 6;
st = {
    'Welcome to the naturalistic auditory exp';
    'Please gaze on the cross at the center of the screen during the exp';
    sprintf('The first %d sec will be blank after the beginning of the exp, do NOT panic :)',TR*dummy);
    'Please do NOT move at all during the entire exp';
    'We are about to start the exp';
    };
total_line = length(st)*3;
st_c = {
    '歡迎參與自然聽覺刺激試驗';
    '實驗過程中請注視螢幕中間十字';
    sprintf('實驗開始後 %d 秒不會有聲音出現',TR*dummy);
    '實驗過程當中請專心聽但是保持頭跟身體都不要動';
    '沒有問題的話實驗準備開始';
    };
post_wait = 10; % wait after the sound stop

param = [];
for sound_idx = 1:length(play_list)
    % Read WAV file from filesystem:
    stim = wavfilename(play_list(sound_idx)).name;
    [y, freq] = psychwavread(fullfile('.','stim',stim));
    wavedata = y';
    nrchannels = size(wavedata,1); % Number of rows == number of channels.
    
    % Make sure we have always 2 channels stereo output.
    % Why? Because some low-end and embedded soundcards
    % only support 2 channels, not 1 channel, and we want
    % to be robust in our demos.
    if nrchannels < 2
        wavedata = [wavedata ; wavedata];
        nrchannels = 2;
    end
    
    % Open the  audio device, with default mode [] (==Only playback),
    % and a required latencyclass of zero 0 == no low-latency mode, as well as
    % a frequency of freq and nrchannels sound channels.
    % This returns a handle to the audio device:
    try
        % Try with the 'freq'uency we wanted:
        pahandle = PsychPortAudio('Open', device, [], 0, freq, nrchannels);
    catch
        % Failed. Retry with default frequency as suggested by device:
        fprintf('\nCould not open device at wanted playback frequency of %i Hz. Will retry with device default frequency.\n', freq);
        fprintf('Sound may sound a bit out of tune, ...\n\n');
        
        psychlasterror('reset');
        pahandle = PsychPortAudio('Open', device, [], 0, [], nrchannels);
    end
    
    % Fill the audio playback buffer with the audio data 'wavedata':
    PsychPortAudio('FillBuffer', pahandle, wavedata);
    
    
    % instruction
    for ii = 1:length(st)
        Screen('DrawText', w, st{ii}, round(xx/3), round(height*(total_line/3+ii)/total_line), white);
    end
    Screen('Flip', w);
%     if sound_idx == 1 % works only on mac
%         for ii = 1:length(st_c)
%             system(sprintf('say %s',st_c{ii}));
%             WaitSecs(0.5);
%         end
%     end

    RT = [];
    resp = [];
    stillDown = 0;
    % NCCU response box
    % Key code -> num
    % 49,50,51,52,54,55,56,57 -> 1!,2@,3#,4$,6^,7&,8*,9(
    % 83 -> s
    
    rating = [];
    rating_reso = 0.23; % s
    idle_time = 5.1; % s
    idle_time_rating = round(idle_time/rating_reso);
    show_timewindow = 17; % s
    show_timewiddow_rating = round(show_timewindow/rating_reso);
    if show_timewiddow_rating > xx
        show_timewiddow_rating = xx;
    end
    
    this_time = 0; % to recored the very first time point rating = 0
    show_rating_yaxis = ones(show_timewiddow_rating,1)*(yy);
    show_rating_xaxis = floor(linspace(width/4,width*3/4,show_timewiddow_rating));
    show_rating_xaxis = show_rating_xaxis(:);
    line_color = [white, black, black, white]; % rgba
    
    % Wait for MRI trigger or key press
    run_start = KbPressWait;
    
    SetMouse(width*3/4,yy,screenNumber);
    Screen('DrawTexture', w, fixation);
    Screen('Flip', w);
    
    if flag_ismri
        WaitSecs(TR*(dummy-3)); % the first three are dummy scan
    else
        Beeper;
        WaitSecs(TR*dummy);
    end
    
    % Start audio playback for 'repetitions' repetitions of the sound data,
    % start it immediately (0) and wait for the playback to start, return onset
    % timestamp.
    sound_start = PsychPortAudio('Start', pahandle, repetitions, 0, 1);
    
    fprintf('Audio playback started, press s key to quit.\n');
    
    flag_conti = 1;
    s = PsychPortAudio('GetStatus', pahandle);
    
    % Stay in a little loop until keypress:
    while flag_conti && s.Active
        s = PsychPortAudio('GetStatus', pahandle);
        [keyIsDown, secs, keyCode, ~] = KbCheck;
        keyCode = find(keyCode, 1);
        if keyIsDown && xor(keyIsDown,stillDown) && keyCode == 4 % "a" key to response
            RT = cat(1,RT,secs);
            resp = cat(1,resp,keyCode);
        elseif keyIsDown && xor(keyIsDown,stillDown) && keyCode == 22 % "s" key to quit
            flag_conti = 0;
        end
        stillDown = keyIsDown;
        
        time_to_rate = s.CurrentStreamTime-this_time;
        if time_to_rate >= rating_reso
            [x,y,~] = GetMouse(screenNumber);
            rating = cat(1,rating,-((y-yy)/yy));
            if rating(end) ~= 0 && (s.CurrentStreamTime-s.StartTime > idle_time) && (length(rating) > idle_time_rating)
                if length(unique(rating(end:-1:end-idle_time_rating+1))) == 1
                    SetMouse(x,yy,screenNumber);
                end
            end
            
            show_rating_yaxis = [show_rating_yaxis(2:end);floor((y+yy)/2)];
            thePoints = [show_rating_xaxis, show_rating_yaxis];
            Screen('DrawTexture', w, show_frame);
            for ii= 1:show_timewiddow_rating-1
                Screen('DrawLine',w,line_color,thePoints(ii,1),thePoints(ii,2),thePoints(ii+1,1),thePoints(ii+1,2),3);
            end
            % DrawFormattedText(w, sprintf('Rating: %d',round(rating(end))), 'center', 20, white);
            Screen('Flip', w);
            this_time = s.CurrentStreamTime;
        end
    end
    
    % save data
    param(sound_idx).stim = stim;
    param(sound_idx).resp = resp;
    param(sound_idx).RT = RT;
    param(sound_idx).run_start = run_start;
    param(sound_idx).sound_start = sound_start;
    param(sound_idx).rating = rating;
    
    % Stop playback:
    PsychPortAudio('Stop', pahandle);
    
    % Close the audio device:
    PsychPortAudio('Close', pahandle);
    
    % Black screen
    Screen('DrawText', w, 'THIS RUN FINISHED...', round(xx/3), round(height/2), white);
    Screen('Flip', w);
    figure, plot(rating)
    WaitSecs(post_wait);
end

% Done.
Priority(0);
% ShowCursor;

% Close all textures. This is not strictly needed, as
% Screen('CloseAll') would do it anyway. However, it avoids warnings by
% Psychtoolbox about unclosed textures. The warnings trigger if more
% than 10 textures are open at invocation of Screen('CloseAll') and we
% have 12 textues here:
Screen('Close');
setenv('PSYCH_ALLOW_DANGEROUS', '0')
Screen('Preference', 'SkipSyncTests', 0);

% Close window:
sca;

total_exp_time = toc;

% Save data
tt = clock;
if ~flag_prac
    fn = sprintf('beh-%d-%02d-%02d-%02d-%02d.mat',tt(1),tt(2),tt(3),tt(4),tt(5));
    save(fn,'param','total_exp_time','flag_ismri');
    fprintf('%s saved, bye!\n',fn);
end