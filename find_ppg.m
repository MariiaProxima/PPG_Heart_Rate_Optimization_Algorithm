function [ppg_signal, fs] = find_ppg(data, default_fs)

% Input parameters:
% data - structure loaded from MAT-file
% default_fs - sampling rate by default (32 Hz for PPG-DaLiA)

% Output parameters:
% ppg_signal - found PPG signal (vector)
% fs - sampling rate (if found, otherwise default_fs)

if nargin < 2
    default_fs = 32;
end

ppg_signal = [];
fs = default_fs;

% If PPG signal exists
if isfield(data, 'data') && isstruct(data.data)
    if isfield(data.data, 'ppg')
        ppg_signal = double(data.data.ppg(:));
        fprintf('PPG signal is found: data.data.ppg (length: %d)\n', length(ppg_signal));

        if isfield(data.data, 'fs')
            fs = data.data.fs;
            fprintf('Sampling rate: data.data.fs = %.1f Hz\n', fs);
        elseif isfield(data, 'fs')
            fs = data.fs;
            fprintf('Sampling rate: data.fs = %.1f Hz\n', fs);
        end
        return;
    end
end

% If PPG signal does not exist
if isfield(data, 'data') && isstruct(data.data)
    if isfield(data.data, 'ecg')
        ppg_signal = double(data.data.ecg(:));
        fprintf('PPG signal is not found: using ECG (length: %d)\n', length(ppg_signal));

        if isfield(data.data, 'fs')
            fs = data.data.fs;
        end
        return;
    end
end

% Direct ppg field 
if isfield(data, 'ppg')
    ppg_signal = double(data.ppg(:));
    fprintf('PPG signal is found: data.ppg (length: %d)\n', length(ppg_signal));
    return;
end

% Direct signal field 
if isfield(data, 'signal')
    ppg_signal = double(data.signal(:));
    fprintf('PPG signal is found: data.signal (length: %d)\n', length(ppg_signal));
    return;
end

% Recursive search in every structure fields
