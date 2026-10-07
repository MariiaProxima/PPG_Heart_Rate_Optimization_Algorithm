% Full experiment: loading, processing, comparison, saving results
clear, clc, close all;
fprintf('\n\n');
fprintf('╔════════════════════════════════════╗\n');
fprintf('      PPG ALGORITHM OPTIMIZATION\n');
fprintf('  PPG-DaLiA open database processing\n');
fprintf('╚════════════════════════════════════╝\n\n');

%% Step 1: Environment set up
fprintf('[1/6] Environment set up...\n');
setup_ppg;

%% Step 2: Files search
fprintf('\n[2/6] PPG-DaLiA files search...\n');
raw_dir = fullfile(pwd, 'data/raw');
mat_files = dir(fullfile(raw_dir, '*.mat'));
if length(mat_files) < 6
    fprintf('Not enough files are found. PPG-DaLiA contains 8 files.\n');
end

%% Step 3: Each file processing
fprintf('\n[3/6] Starting processing of all records...\n');
all_results = {};
default_fs = 32;
successful_files = {};
failed_files = {};
empty_results_files = {};

for file_idx = 1:length(mat_files)
    fprintf('\nFile "%d/%d: %s" processing...\n', file_idx, length(mat_files), mat_files(file_idx).name);
    
    data = load(fullfile(raw_dir, mat_files(file_idx).name));
    
    ppg_signal = [];
    fs = default_fs;
    
    if isfield(data, 'data') && isstruct(data.data)
        fprintf('  data.data size: %s\n', mat2str(size(data.data)));
        
        all_ppg = [];
        all_fs = [];
        
        for i = 1:length(data.data)
            % Extract PPG signal from data.data(i).ppg.v
            if isfield(data.data(i), 'ppg')
                ppg_struct = data.data(i).ppg;
                
                if isstruct(ppg_struct) && isfield(ppg_struct, 'v')
                    sig = ppg_struct.v;
                    if isnumeric(sig) && ~isempty(sig)
                        all_ppg = [all_ppg; sig(:)];
                        fprintf('  Entry %d: PPG v = %d samples\n', i, length(sig));
                    end
                end
                
                if isfield(ppg_struct, 'fs')
                    all_fs(end+1) = ppg_struct.fs;
                end
            end
            
            % Fallback: extract ECG from data.data(i).ecg.v
            if isempty(all_ppg) && isfield(data.data(i), 'ecg')
                ecg_struct = data.data(i).ecg;
                
                if isstruct(ecg_struct) && isfield(ecg_struct, 'v')
                    sig = ecg_struct.v;
                    if isnumeric(sig) && ~isempty(sig)
                        all_ppg = [all_ppg; sig(:)];
                        fprintf('  Entry %d: Using ECG v = %d samples\n', i, length(sig));
                    end
                end
                
                if isfield(ecg_struct, 'fs')
                    all_fs(end+1) = ecg_struct.fs;
                end
            end
        end
        
        if ~isempty(all_ppg)
            ppg_signal = double(all_ppg);
            fprintf('  ✓ Total PPG signal: %d samples\n', length(ppg_signal));
        else
            fprintf('  ERROR: No PPG or ECG signal found\n');
            failed_files{end+1} = mat_files(file_idx).name;
            continue;
        end
        
        % Get sampling rate
        if ~isempty(all_fs)
            fs = all_fs(1);
            fprintf('  Sampling rate: %.1f Hz\n', fs);
        else
            fprintf('  Using default: %.1f Hz\n', default_fs);
        end
    else
        fprintf('  ERROR: Unexpected format\n');
        failed_files{end+1} = mat_files(file_idx).name;
        continue;
    end
    
    % Quality check
    if max(abs(ppg_signal)) == 0 || isempty(ppg_signal)
        fprintf('  ERROR: Zero/empty signal\n');
        failed_files{end+1} = mat_files(file_idx).name;
        continue;
    end
    
    fprintf('  Signal OK: range=[%.3f, %.3f], mean=%.3f\n', ...
        min(ppg_signal), max(ppg_signal), mean(ppg_signal));
    
    % Normalization
    ppg_signal = ppg_signal - mean(ppg_signal);
    ppg_signal = ppg_signal / max(abs(ppg_signal));
    
    % Processing
    try
        results = optimized_ppg_algorithm(ppg_signal, fs, 'visualize', false);
        results.filename = mat_files(file_idx).name;
        
        if isnan(results.heart_rate) || results.heart_rate < 30 || results.heart_rate > 200
            fprintf('  WARNING: Unusual HR: %.1f BPM\n', results.heart_rate);
            empty_results_files{end+1} = mat_files(file_idx).name;
        else
            all_results{end+1} = results;
            successful_files{end+1} = mat_files(file_idx).name;
            fprintf('  ✓ HR: %.1f BPM, Peaks: %d, SNR: +%.1f dB, Time: %.3f s\n', ...
                results.heart_rate, length(results.peaks), ...
                results.snr_after - results.snr_before, results.processing_time);
        end
    catch ME
        fprintf('  ERROR: %s\n', ME.message);
        failed_files{end+1} = mat_files(file_idx).name;
    end
end

%% Step 4: Aggregation
fprintf('\n[4/6] Results aggregation...\n');
valid_hr = []; valid_snr_improvement = []; valid_num_peaks = []; valid_processing_time = [];

for i = 1:length(all_results)
    if ~isnan(all_results{i}.heart_rate)
        valid_hr(end+1) = all_results{i}.heart_rate;
        valid_snr_improvement(end+1) = all_results{i}.snr_after - all_results{i}.snr_before;
        valid_num_peaks(end+1) = length(all_results{i}.peaks);
        valid_processing_time(end+1) = all_results{i}.processing_time;
    end
end

aggregated.num_processed = length(all_results);
aggregated.num_valid = length(valid_hr);

if ~isempty(valid_hr)
    aggregated.mean_hr = mean(valid_hr); aggregated.std_hr = std(valid_hr);
    aggregated.median_hr = median(valid_hr); aggregated.min_hr = min(valid_hr); aggregated.max_hr = max(valid_hr);
else
    aggregated.mean_hr = NaN; aggregated.std_hr = NaN; aggregated.median_hr = NaN;
    aggregated.min_hr = NaN; aggregated.max_hr = NaN;
end

if ~isempty(valid_snr_improvement)
    aggregated.mean_snr_improvement = mean(valid_snr_improvement);
    aggregated.std_snr_improvement = std(valid_snr_improvement);
else
    aggregated.mean_snr_improvement = NaN; aggregated.std_snr_improvement = NaN;
end

if ~isempty(valid_num_peaks)
    aggregated.mean_num_peaks = mean(valid_num_peaks);
    aggregated.std_num_peaks = std(valid_num_peaks);
else
    aggregated.mean_num_peaks = NaN; aggregated.std_num_peaks = NaN;
end

if ~isempty(valid_processing_time)
    aggregated.mean_processing_time = mean(valid_processing_time);
    aggregated.std_processing_time = std(valid_processing_time);
else
    aggregated.mean_processing_time = NaN; aggregated.std_processing_time = NaN;
end

fprintf('  Processed: %d, Valid: %d\n', aggregated.num_processed, aggregated.num_valid);

%% Step 5: Visualization
fprintf('\n[5/6] Plots generation...\n');
figure('Position',[100,100,1400,900]);

subplot(2,2,1);
if length(valid_hr) > 1
    histogram(valid_hr, min(15,length(valid_hr)),'FaceColor',[0.3,0.6,0.9],'EdgeColor','k');
    hold on; xline(aggregated.mean_hr,'r-','LineWidth',2); xline(aggregated.median_hr,'g--','LineWidth',2);
    xlabel('Heart Rate (BPM)'); ylabel('Frequency');
    title(sprintf('Heart Rate Distribution (n=%d)',length(valid_hr))); grid on;
    legend('Distribution',sprintf('Mean: %.1f BPM',aggregated.mean_hr),'Location','best');
elseif ~isempty(valid_hr)
    bar(valid_hr,'FaceColor',[0.3,0.6,0.9]); xlabel('HR (BPM)'); ylabel('Value');
    title(sprintf('HR: %.1f BPM',valid_hr)); grid on;
else
    text(0.5,0.5,'No data','HorizontalAlignment','center','VerticalAlignment','middle'); title('HR Distribution'); axis off;
end

subplot(2,2,2);
if ~isempty(valid_snr_improvement)
    bar(valid_snr_improvement,'FaceColor',[0.3,0.8,0.3]); hold on;
    yline(aggregated.mean_snr_improvement,'r--','LineWidth',2);
    xlabel('File'); ylabel('SNR (dB)');
    title(sprintf('SNR Improvement (Mean: +%.1f dB)',aggregated.mean_snr_improvement)); grid on;
    legend('SNR',sprintf('Mean: +%.1f dB',aggregated.mean_snr_improvement),'Location','best');
else
    text(0.5,0.5,'No data','HorizontalAlignment','center','VerticalAlignment','middle'); title('SNR'); axis off;
end

subplot(2,2,3);
if ~isempty(valid_processing_time)
    bar(valid_processing_time*1000,'FaceColor',[0.8,0.5,0.3]); hold on;
    yline(aggregated.mean_processing_time*1000,'r--','LineWidth',2);
    xlabel('File'); ylabel('Time (ms)');
    title(sprintf('Processing Time (Mean: %.1f ms)',aggregated.mean_processing_time*1000)); grid on;
    legend('Time',sprintf('Mean: %.1f ms',aggregated.mean_processing_time*1000),'Location','best');
else
    text(0.5,0.5,'No data','HorizontalAlignment','center','VerticalAlignment','middle'); title('Time'); axis off;
end

subplot(2,2,4);
if ~isempty(valid_hr)
    bar(1:3,[aggregated.mean_hr, aggregated.mean_snr_improvement, aggregated.mean_processing_time*1000],'FaceColor',[0.5,0.6,0.8]);
    hold on; errorbar(1:3,[aggregated.mean_hr,aggregated.mean_snr_improvement,aggregated.mean_processing_time*1000],...
        [aggregated.std_hr,aggregated.std_snr_improvement,aggregated.std_processing_time*1000],'k.','LineWidth',2,'MarkerSize',15);
    set(gca,'XTick',1:3,'XTickLabel',{'HR (BPM)';'SNR (dB)';'Time (ms)'});
    ylabel('Value'); title('Summary'); grid on; xlim([0.5,3.5]);
else
    text(0.5,0.5,'No data','HorizontalAlignment','center','VerticalAlignment','middle'); title('Summary'); axis off;
end

sgtitle(sprintf('PPG-DaLiA | Processed: %d, Valid: %d',aggregated.num_processed,aggregated.num_valid));

save_dir = fullfile(pwd,'results/figures');
if ~exist(save_dir,'dir'), mkdir(save_dir); end
saveas(gcf,fullfile(save_dir,'experiment_summary.png'));
fprintf('  ✓ Saved: %s\n',fullfile(save_dir,'experiment_summary.png'));

%% Step 6: Saving
fprintf('\n[6/6] Saving results...\n');
results_dir = fullfile(pwd,'results');
if ~exist(results_dir,'dir'), mkdir(results_dir); end

save(fullfile(results_dir,'aggregated_results.mat'),'aggregated');
save(fullfile(results_dir,'all_results.mat'),'all_results');

if ~isempty(all_results)
    T = table();
    for i = 1:length(all_results)
        T.filename{i} = all_results{i}.filename;
        T.heart_rate(i) = all_results{i}.heart_rate;
        T.num_peaks(i) = length(all_results{i}.peaks);
        T.snr_improvement(i) = all_results{i}.snr_after - all_results{i}.snr_before;
        T.processing_time(i) = all_results{i}.processing_time;
    end
    writetable(T,fullfile(results_dir,'summary.csv'));
    fprintf('  ✓ Summary: %s\n',fullfile(results_dir,'summary.csv'));
end

save(fullfile(results_dir,'file_status.mat'),'successful_files','failed_files','empty_results_files');
fprintf('  ✓ Status: %s\n',fullfile(results_dir,'file_status.mat'));

fprintf('\n===========================================\n');
fprintf('         EXPERIMENT COMPLETED\n');
fprintf('===========================================\n');
fprintf('  Processed: %d | Valid: %d | Success: %d | Failed: %d\n',...
    aggregated.num_processed, aggregated.num_valid, length(successful_files), length(failed_files));
fprintf('\n  Results: %s\n', results_dir);
fprintf('  Figures: %s\n', save_dir);