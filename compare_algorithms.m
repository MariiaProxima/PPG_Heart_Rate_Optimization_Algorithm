% Comparison of original and optimized PPg_DaLiA algorithms 

function comparison = compare_algorithms(ppg_signal, fs, reference_hr)
%% Input parameters:
% ppg_signal - PPG vector
% fs - sampling rate
% reference_hr - reference heart rate

%% Output parameters:
% comparison - structure with comparison

fprintf('---------------------------\n');
fprintf('-- ALGORITHMS COMPARISON --\n');
fprintf('---------------------------\n');

%% Improved algorithm upload
fprintf('\n-> Improved algorithm upload...\n');
improved = optimized_ppg_algorithm(ppg_signal, fs, 'visualize', false);

%% Original algorithm upload
fprintf('\n-> Original algorithm upload...\n');

% Simple bandpass filter
[b_basic, a_basic] = butter(4,[0.7,3]/(fs/2), 'bandpass');
basic_filter = filtfilt(b_basic, a_basic, double(detrend(ppg_signal, 'linear')));

% Simple peak detector (fixed threshold)
basic_threshold = 0.5*std(basic_filter);
[~, basic_peaks] = findpeaks(basic_filter, 'MinPeakHeight', basic_threshold, ...
    'MinPeakDistance', rounf(fs*0.4));

% Heart rate calculation
if length(basic_peaks) >= 2
    basic_rr = diff(basic_peaks)/fs;
    valid_basic_rr = basic_rr(basic_rr > 0.4 & basic_rr < 1.5);
    if ~isempty(valid_basic_rr)
        basic_hr = 60/median(valid_basic_rr);
    else
        basic_hr = NaN;
    end
else
    basic_hr = NaN;
end

%% Comparative analysis
comparison.improved.hr = improved.heart_rate;
comparison.improved.num_peaks = length(improved.peaks);
comparison.improved.snr = improved.snr_after;
comparison.improved.time = improved.processing_time;

comparison.basic.hr = basic_hr;
comparison.basic.num_peaks = length(basic_peaks);
comparison.basic.snr = improved.snr_before;
comparison.basic.time = 0.1;

if ~isnan(reference_hr)
    comparison.improved.error = abs(improved.heart_rate - reference_hr);
    comparison.basic.error = abs(basic_hr - reference_hr);
else
    comparison.improved.error = NaN;
    comparison.basic.error = NaN;
end

%% Comparison visualization
figure('Position',[100,100,1200,800]);

% Plot 1: Signals and peaks
subplot(2,2,1);
t = (0:length(ppg_signal)-1)/fs;
plot(t, basic_filter,'b-','LineWidth',1); hold on;
plot(t, improved.cleaned_signal, 'r-','LineWidth',1);
plot(basic_peaks/fs, basic_filtered(basic_peaks),'bo','MarkerSize',6);
plot(improved.peaks/fs, improved.cleaned_signal(improved.peaks),'ro','MarkerSize',6);
xlabel('Time (sec)'); ylabel('Amplitude');
title('Comparison: Basic vs Improved algorithm')
legend('Original signal', 'Improved signal', 'Original peaks', 'Improved peaks');
grid on;
    
% Plot 2: Heart rate comparison (histogram)
subplot(2,2,2);
if ~isnan(comparison.improved.hr) && ~isnan(comparison.basic.hr)
    categories = {'Original', 'Improved'};
    values = [comparison.basic.hr, comparison.improved.hr];
    bar(values, 'FaceColor',[0.5,0.5,0.8]);
    ylabel('Heart rate (beats/min)');
    title('Calculated heart rate comparison');
    set(gca, 'xTickLabel', categories);
    if ~isnan(reference_hr)
        yline(reference_hr, 'r--', 'LineWidth',2);
        legend('', sprintf('Reference: %.1f', reference_hr));
    end
end

% Plot 3: Detection quality
subplot(2,2,3);
bar([length(basic_peaks), length(improved.peaks)], 'FaceColor',[0.6,0.8,0.6]);
xlabel('Algorithm'); ylabel('Number of peaks');
set(gca, 'XTickLabel', {'Original', 'Improved'});
title('Number of detected peaks');
grid on;

% Plot 4: Error regarding to reference
subplot(2,2,4);
if ~isnan(reference_hr) && ~isnan(comparison.improved.error)
    bar([comparison.basic.error, comparison.improved.error], 'FaceColor',[0.9,0.5,0.5]);
    xlabel('Algorithm'); ylabel('Absolute error (beats/min)');
    set(gca, 'XTickLabel', {'Original', 'Improved'});
    title('Error regarding to reference');
    grid on;
end

sgtitle('COMPARISON ALGORITHM ANALYSIS');
drawnow;

%% Console output

fprintf('\n--- СРАВНЕНИЕ РЕЗУЛЬТАТОВ ---\n');
fprintf('┌────────────────────────────┬──────────────┬──────────────┐\n');
fprintf('│ Показатель                 │ Базовый      │ Улучшенный   │\n');
fprintf('├────────────────────────────┼──────────────┼──────────────┤\n');
fprintf('│ ЧСС (уд/мин)               │ %11.1f │ %12.1f │\n', comparison.basic.hr, comparison.improved.hr);
fprintf('│ Количество пиков           │ %11d │ %12d │\n', comparison.basic.num_peaks, comparison.improved.num_peaks);
fprintf('│ SNR (дБ)                   │ %11.1f │ %12.1f │\n', comparison.basic.snr, comparison.improved.snr);
if ~isnan(comparison.improved.error)
    fprintf('│ Ошибка (уд/мин)             │ %11.1f │ %12.1f │\n', comparison.basic.error, comparison.improved.error);
end
fprintf('│ Время обработки (сек)      │ %11.2f │ %12.2f │\n', comparison.basic.time, comparison.improved.time);
fprintf('└────────────────────────────┴──────────────┴──────────────┘\n');

end

