% Optimizes algorithm of processing PPG with expanded parameters
% Using open database PPG-DaLiA
function [results] = optimized_ppg_algorithm(ppg_signal, fs, varargin)
%% Input parameters:
% ppg_signal - vector of PPG signal
% fs - sampling rate (частота дискретизации)
% varargin - extra options (structure)
%% Output parameters (results structure):
% .heart_rate - final heart rate (beats/min)
% .heart_rate_history - heart rate array by windows
% .cleaned_signal - processed signal
% .peaks - indexes of detected peaks
% .peak_qualities - quality of each peak (0-1)
% .snr - signal/noise ratio before/after processing
% .processing_time - processing time (sec)
% .parameters - used parameters
%% Parsing used parameters
p = inputParser;
% Duration of window (sec)
addParameter(p, 'window_duration', 8, @isnumeric);
% Overlapping of windows (0-1)
addParameter(p, 'overlap', 0.5, @isnumeric); 
% The lower limit of the low-pass filter (Hz)
addParameter(p, 'low_cut', 0.5, @isnumeric); 
% The upper limit of the high-pass filter (Hz)
addParameter(p, 'high_cut', 4.0, @isnumeric); 
% Filter order
addParameter(p, 'filter_order', 5, @isnumeric);
addParameter(p, 'use_median_filter', true, @islogical);
% Median window (sec)
addParameter(p, 'median_window', 0.5, @isnumeric); 
addParameter(p, 'visualize', false, @islogical);
parse(p, varargin{:});
params = p.Results;
window_samples = round(params.window_duration * fs);
overlap_samples = round(params.overlap * window_samples);
tic; % Run the timer
%% Step 1: Preprocessing (improved)
fprintf('-> Signal preprocessing...\n');
% Removing a linear trend (slow drift)
ppg_detrended = detrend(ppg_signal, 'linear');
% Bandpass filter with zero latency - Полосовая фильтрация с нулевой
% задержкой
[b, a] = butter(params.filter_order, [params.low_cut, params.high_cut]/(fs/2),'bandpass');
ppg_filtered = filtfilt(b,a,double(ppg_detrended));
% Median filter for suppression of pulse noise
if params.use_median_filter
    median_window_samples = round(params.median_window * fs);
    if mod(median_window_samples, 2) == 0
        median_window_samples = median_window_samples + 1;
    end
    cleaned_signal = medfilt1(ppg_filtered, median_window_samples);
else
    cleaned_signal = ppg_filtered;
end
% Estimation SNR before and after processing - Signal-to-noise ration
snr_before = 10 * log10(var(ppg_signal)/var(ppg_signal - ppg_filtered));
snr_after = 10 * log10(var(cleaned_signal)/var(cleaned_signal - ppg_filtered));
%% Step 2: Adaptive peak detector
fprintf('->Detection of heart rate...\n');
% Adaptive threshold based on the standart deviation coefficient of the
% signal - СКО (Стандартный коэффициент отклонения)
peak_height_threshold = 0.4 * std(cleaned_signal);
% Minimal distance between peaks (physiology limits)
min_peak_distance = round(fs * 0.4); % max 150 beats/min
% Search fo peaks with quality verification
[peak_amplitudes, peaks_idx] = findpeaks(cleaned_signal, ...
    'MinPeakHeight', peak_height_threshold, 'MinPeakDistance', min_peak_distance);
% Quality estimation of each peak
% Creates an array to store the quality of each peak
peak_qualities = zeros(size(peaks_idx));
for i = 1:length(peaks_idx)
    % Checks whether the peak is too close to signal edges or not 
    if peaks_idx(i) > 2 && peaks_idx(i) < length(cleaned_signal) - 2
        % Quality criteria:
        % 1. Amplitude relatively threshold
        % Checks how higher than adaptive threshold the peak is
        amp_quality = min(1, peak_amplitudes(i)/(2*peak_height_threshold));
        
        % 2. The slope of the leading front (derivative)
        % Checks how fast the signal rises to the peak
        % 2/fs - time betwen two counts in seconds
        slope = (cleaned_signal(peaks_idx(i)) - cleaned_signal(peaks_idx(i)-2))/(2/fs);
        slope_quality = min(1,slope/10); % Empirical threshold
        % 3. Peak symmetry
        % Checks how similar the left and right valleys are
        left_valley = min(cleaned_signal(max(1,peaks_idx(i)-round(fs*0.2)):peaks_idx(i)));
        right_valley = min(cleaned_signal(peaks_idx(i):min(length(cleaned_signal),peaks_idx(i)+round(fs*0.2))));
        symmetry = 1 - abs(left_valley - right_valley)/max(abs(left_valley), abs(right_valley));
        % Average three criteria to obtain overall quality assessment 
        peak_qualities(i) = (amp_quality + slope_quality + symmetry)/3;
    end
end
%% Step 3: Heart rate calculation by sliding windows
fprintf('-> Heart rate calculation...\n');
% For reliable calculation we need more than 3 peaks because 4 peaks give 3
% RR-intervals
if length(peaks_idx) >= 4
    % RR-intervals calculation
    rr_samples = diff(peaks_idx); % in counts
    rr_seconds = rr_samples/fs; % in seconds
    % Physiologically impossible intervals filter
    valid_rr_mask = (rr_seconds >= 0.4) & (rr_seconds <= 1.5); % 40-150 beats/min
    valid_rr = rr_seconds(valid_rr_mask);
    valid_qualities = peak_qualities(2:end);
    valid_qualities = valid_qualities(valid_rr_mask);
    if ~isempty(valid_rr)
        % Weighted median of intervals
        [sorted_rr, sort_idx] = sort(valid_rr);
        sorted_weights = valid_qualities(sort_idx);
        % Cumulative sum - accumulation
        cum_weights = cumsum(sorted_weights)/sum(sorted_weights);
        median_idx = find(cum_weights >= 0.5,1);
        median_rr = sorted_rr(median_idx);
        % Final heart rate
        heart_rate = 60/median_rr;
        % Heart rate calculation by sliding windows (for trend)
        hr_window = [];
        hr_time = [];
        num_windows = floor((length(ppg_signal) - window_samples)/overlap_samples)+1;
        for w = 1:num_windows
            start_idx = (w-1)*overlap_samples +1;
            end_idx = min(start_idx + window_samples - 1, length(ppg_signal));
            if end_idx - start_idx > window_samples/2
                window_peaks = peaks_idx(peaks_idx >= start_idx & peaks_idx <= end_idx);
                if length(window_peaks) >= 2
                    window_rr = diff(window_peaks)/fs;
                    valid_window_rr = window_rr(window_rr >= 0.4 & window_rr <= 1.5);
                    if ~isempty(valid_window_rr)
                        hr_window(end+1) = 60/median(valid_window_rr);
                        hr_time(end+1) = (start_idx + end_idx)/(2*fs);
                    end
                end
            end
        end
        heart_rate_history.hr = hr_window;
        heart_rate_history.time = hr_time;
    else
        heart_rate = NaN;
        heart_rate_history = [];
        warning('Valid RR-intervals were not found\n');
    end
else
    heart_rate = NaN;
    heart_rate_history = [];
    warning('Not enough peaks were found (%d, minimum quantity is 4)', length(peaks_idx));
end
%% Step 4: Collecting results
processing_time = toc;
results.heart_rate = heart_rate;
results.heart_rate_history = heart_rate_history;
results.cleaned_signal = cleaned_signal;
results.peaks = peaks_idx;
results.peak_amplitudes = peak_amplitudes;
results.peak_qualities = peak_qualities;
results.snr_before = snr_before;
results.snr_after = snr_after;
results.processing_time = processing_time;
results.parameters = params;
results.fs = fs;
%% Step 5: Visualization (optionally)
if params.visualize
    figure('Position',[100,100,1400,900]);
    % Plot 1: Original vs processed signal
    subplot(2,2,1);
    t = (0:length(ppg_signal)-1)/fs;
    plot(t, ppg_signal,'b-','LineWidth',0.5); hold on;
    plot(t, cleaned_signal, 'r-','LineWidth',1);
    plot(peaks_idx/fs, peak_amplitudes,'go','MarkerSize',8,'MarkerFaceColor','g');
    title(sprintf('PPG signal preprocessing (Heart rate = %.1f beats/min)', heart_rate));
    xlabel('Time (sec)'); ylabel('Amplitude');
    legend('Original signal', 'Preprocessed signal', 'Detected peaks');
    grid on;
    % Plot 2: Spectral analysis
    subplot(2,2,2);
    [pxx_orig, f_orig] = pwelch(ppg_signal, [], [], [], fs);
    [pxx_clean, f_clean] = pwelch(cleaned_signal, [], [], [], fs);
    plot(f_orig, 10*log10(pxx_orig),'b-','LineWidth',1.5); hold on;
    plot(f_clean, 10*log10(pxx_clean),'r-','LineWidth',1.5); 
    xlim([0,10]);
    xlabel('Frequency (Hz)'); ylabel('Spectral Power (dB)');
    title('Spectral power density');
    legend('Original signal', 'Preprocessed signal');
    grid on;
    % Plot 3: Peak detection quality
    subplot(2,2,3);
    bar(peak_qualities, 'FaceColor',[0.3,0.6,0.9]);
    xlabel('Peak number'); ylabel('Quality (0-1)');
    title('Each detected peak quality estimation');
    ylim([0,1.1]);
    grid on;
    % Plot 4: Heart rate dynamics by windows
    subplot(2,2,4);
    if ~isempty(heart_rate_history.hr)
        plot(heart_rate_history.time, heart_rate_history.hr, 'b-o','LineWidth',1.5);
        yline(heart_rate, 'r--', 'LineWidth',1.5);
        xlabel('Time (sec)'); ylabel('Heart rate (beats/min)');
        title('Heart rate dynamics');
        legend('Local heart rate', 'Average heart rate');
        ylim([40,150]);
    else
        text(0.5,0.5,'Not enough data for dynamics calculation', ...
            'HorizontalAlignment','center','FontSize',12);
    end
    grid on;
    sgtitle(sprintf('PPG-DaLiA: Subject signal analysis | SNR +%.1f dB', snr_after - snr_before));
    drawnow;
end
end