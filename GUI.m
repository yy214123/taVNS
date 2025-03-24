function dynamicDAQControlECG()

    %% Load parameter settings
    params = daqParameters();
    subjectName = '';
    %% Configure DAQ session
    s = daq.createSession('ni');
    s.Rate = params.samplingRate;
    addAnalogOutputChannel(s, params.device, params.channel, 'Voltage');

    %% Create GUI
    fig = figure('Name', 'Real-time Biphasic DAQ Output', ...
                 'NumberTitle', 'off', ...
                 'KeyPressFcn', @keyPressHandler, ...
                 'CloseRequestFcn', @closeGUI, ...
                 'Position', [100 100 1100 350]);

    % Voltage display text
    amplitude = params.initialAmplitude;
    hText = uicontrol('Style', 'text', ...
                      'Position', [20 20 250 40], ...
                      'String', ['Amplitude: ' num2str(amplitude*1000) ' µA'], ...
                      'FontSize', 14);

    % Start button
    hStartBtn = uicontrol('Style', 'pushbutton', ...
                          'Position', [300 20 120 40], ...
                          'String', 'Start ▶', ...
                          'FontSize', 12, ...
                          'Callback', @startTimerFcn);

    % Stop button
    hStopBtn = uicontrol('Style', 'pushbutton', ...
                         'Position', [430 20 120 40], ...
                         'String', 'Stop ⏸️', ...
                         'FontSize', 12, ...
                         'Enable', 'off', ...
                         'Callback', @stopTimerFcn);

    % Save button
    hSaveBtn = uicontrol('Style', 'pushbutton', ...
                         'Position', [560 20 120 40], ...
                         'String', 'Save 💾', ...
                         'FontSize', 12, ...
                         'Callback', @saveAmplitude);

    % Exit button
    hExitBtn = uicontrol('Style', 'pushbutton', ...
                         'Position', [690 20 120 40], ...
                         'String', 'Exit 🚪', ...
                         'FontSize', 12, ...
                         'Callback', @closeGUI);

    % Create axes (with appropriate margin)
    ax = axes('Parent', fig, 'Position', [0.05 0.25 0.9 0.65]);
    grid(ax, 'on');
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Amplitude (V)');
    ylim(ax, [-params.initialAmplitude*2, params.initialAmplitude*2]); % 上下留空

    % Time axis buffer
    displayDuration = 5; % 5秒視窗
    bufferSize = s.Rate * displayDuration;
    timeBuffer = linspace(-displayDuration, 0, bufferSize);
    dataBuffer = zeros(1, bufferSize);

    % Line object
    hLine = plot(ax, timeBuffer, dataBuffer, 'LineWidth', 1.5);
    title(ax, 'Real-time Biphasic Square Wave');

    % Timer settings
    updateInterval = 0.1; % 每0.1秒更新
    t = timer('ExecutionMode', 'fixedRate', ...
              'Period', updateInterval, ...
              'TimerFcn', @updatePlot);

    %% Keyboard control for amplitude
    function keyPressHandler(~, event)
        switch event.Key
            case 'uparrow'
                amplitude = amplitude + 0.1;  
            case 'downarrow'
                amplitude = amplitude - 0.1;  
            otherwise
                return;
        end
        hText.String = ['Amplitude: ' num2str(amplitude*1000) ' µA'];
        disp(['Updated amplitude: ' num2str(amplitude*1000) ' µA']);
    end

    %% Start button callback
    function startTimerFcn(~, ~)
        if strcmp(t.Running, 'off')
            % If the subject's name is not entered, prompt input dialog
            if isempty(strtrim(subjectName))
                prompt = {'請輸入受試者姓名：'};
                dlgtitle = '輸入姓名';
                dims = [1 35];
                definput = {''};
                answer = inputdlg(prompt, dlgtitle, dims, definput);
    
                if isempty(answer) || isempty(strtrim(answer{1}))
                    uialert(fig, '請輸入姓名以開始刺激。', '姓名未輸入');
                    return;
                end
    
                subjectName = strtrim(answer{1});  % Save to shared variable
            end
    
            start(t);
            hStartBtn.Enable = 'off';
            hStopBtn.Enable = 'on';
    
            disp(['DAQ output started for subject: ' subjectName]);
        end
    end

    %% Stop button callback
    function stopTimerFcn(~, ~)
        if strcmp(t.Running, 'on')
            stop(t);
            hStartBtn.Enable = 'on';
            hStopBtn.Enable = 'off';
            disp('DAQ output stopped.');
        end
    end

    %% Save button callback
    function saveAmplitude(~, ~)
        savedAmplitude = amplitude;
    
        if isempty(strtrim(subjectName))
            uialert(fig, '請先按開始，並輸入受試者姓名。', '無法儲存');
            return;
        end
    
        timestamp = datestr(now, 'yyyy-mm-dd_HH-MM');
        filename = [subjectName '_' timestamp '.mat'];
    
        uisave('savedAmplitude', filename);
        disp(['Amplitude (' num2str(savedAmplitude*1000) ' µA) saved for ' subjectName '.']);
    end

    %% biphasic square wave
    function updatePlot(~,~)
        segmentLength = round(s.Rate * updateInterval);
        dt = 1/s.Rate;
        
        stimSignal = zeros(1, segmentLength);
        samplesPerCycle = floor(s.Rate / params.stimFrequency);
        pulseWidthSamples = floor(params.pulseWidthSec * s.Rate);
        halfCycle = floor(samplesPerCycle / 2);

        for cycleStart = 1:samplesPerCycle:segmentLength
            posEnd = cycleStart + pulseWidthSamples - 1;
            negStart = cycleStart + halfCycle;
            negEnd = negStart + pulseWidthSamples - 1;

            if posEnd <= segmentLength && negEnd <= segmentLength
                stimSignal(cycleStart:posEnd) = amplitude;     % Positive phase
                stimSignal(negStart:negEnd) = -amplitude;      % Negative phase
            end
        end

        % DAQ output
        queueOutputData(s, stimSignal');
        startForeground(s);

        dataBuffer = [dataBuffer(segmentLength+1:end), stimSignal];
        set(hLine, 'YData', dataBuffer);
        drawnow limitrate;
    end

    %% GUI close and resource cleanup
    function closeGUI(~, ~)
        try
            if isvalid(t)
                stop(t);
                delete(t);
            end
        catch ME
            disp(['Error stopping timer: ' ME.message]);
        end

        try
            s.release();
        catch ME
            disp(['Error releasing DAQ: ' ME.message]);
        end

        delete(gcf);
        disp('GUI safely closed.');
    end
end