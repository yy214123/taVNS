% daqParameters - Define NI DAQ and stimulation parameters
%
% Usage:
% params = daqParameters('condition1'); % For 25 Hz, 250 μs
% params = daqParameters('condition2'); % For 30 Hz, 250 μs
%
% Output:
% params - Struct containing all parameters
function params = daqParameters(condition)
    if nargin < 1
        condition = 'condition1'; % Default to condition1
    end

    % NI DAQ parameter settings
    params.device = 'Dev1';       
    params.channel = 0;           
    params.samplingRate = 10000;  % in Hz

    % Common setting
    params.totalTime = 1;               % Duration of stimulation in seconds
    params.initialAmplitude = 0.1;        % Initial output voltage (0.1V = 0.1 mA = 100 µA)

    % Condition-specific stimulation parameters
    switch lower(condition)
        case 'condition1'
            params.stimFrequency = 25;              % Hz
            params.pulseWidthSec = 250e-6;          % 250 μs

        case 'condition2'
            params.stimFrequency = 30;              % Hz
            params.pulseWidthSec = 250e-6;          % 250 μs

        otherwise
            error('Unknown condition: %s. Use "condition1" or "condition2".', condition);
    end
end