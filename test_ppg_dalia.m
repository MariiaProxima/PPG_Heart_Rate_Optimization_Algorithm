clear; clc; close all;

fprintf('----------------------------\n');
fprintf('-- PPG-DaLiA DATASET TEST --\n');
fprintf('----------------------------\n');

%% PPG-DaLiA data load
raw_dir = fullfile(pwd, 'data/raw');
mat_files = dir(fullfile(raw_dir, '*.mat'));

if isempty(mat_files)
    error('No .mat files. Download dataset from Zenodo.');
end

% First file load for test
fprintf('File "%s" load\n ', mat_files(1).name);
data = load(fullfile(raw_dir, mat_files(1).name));

% PPG-DaLiA data structure analysis
fprintf('\Uploaded data structure:\n');
disp(fieldnames(data));

% PPG signal and sampling rate search
if isfield(data, 'ppg')
    ppg_signal = data.ppg;
    fs = 32; 
elseif isfield(data, 'signal')
    ppg_signal = data.signal;
    fs = 32;
else
    fprintf('\nAdapt upload to your structure\n');
    fprintf('The content of data variable:\n');
    disp(data);
    error('PPG signal is not found.');
end

fprintf('\nPPG signal is uploaded: %d counts (%.1f sec)\n', ...
    length(ppg_signal), length(ppg_signal)/fs);

%% Optimized algorithm running
fprintf('\nAlgorithm running...\n');

results = optimized_ppg_algorithm(ppg_signal, fs, 'visualize', true);

%% Results output
fprintf('\n--- РЕЗУЛЬТАТЫ ---\n');
fprintf('┌────────────────────────────────┬─────────────┐\n');
fprintf('│ Показатель                     │ Значение    │\n');
fprintf('├────────────────────────────────┼─────────────┤\n');
if ~isnan(results.heart_rate)
    fprintf('│ Частота сердечных сокращений    │ %5.1f уд/мин │\n', results.heart_rate);
else
    fprintf('│ Частота сердечных сокращений    │   Н/Д       │\n');
end
fprintf('│ Количество обнаруженных пиков   │ %5d         │\n', length(results.peaks));
fprintf('│ Среднее качество пиков          │ %5.2f       │\n', mean(results.peak_qualities));
fprintf('│ SNR до обработки                │ %5.1f дБ    │\n', results.snr_before);
fprintf('│ SNR после обработки             │ %5.1f дБ    │\n', results.snr_after);
fprintf('│ Улучшение SNR                   │ %+5.1f дБ   │\n', results.snr_after - results.snr_before);
fprintf('│ Время обработки                 │ %5.2f сек   │\n', results.processing_time);
fprintf('└─────────────────────────────────┴─────────────┘\n');

%% Saving results
save_dir = fullfile(pwd, 'results/metrics');
save_file = fullfile(save_dir, sprintf('results_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
save(save_file, 'results');
fprintf('\nResults are saved: %s\n', save_file);
