%% check_ppg_dalia_structure.m
% Анализ структуры загруженных файлов PPG-DaLiA

clear; clc;

raw_dir = fullfile(pwd, 'data/raw');
mat_files = dir(fullfile(raw_dir, '*.mat'));

if isempty(mat_files)
    fprintf('Нет MAT-файлов в папке: %s\n', raw_dir);
    fprintf('Пожалуйста, поместите файлы в папку data/raw\n');
    return;
end

fprintf('=== АНАЛИЗ СТРУКТУРЫ ФАЙЛОВ PPG-DaLiA ===\n\n');

for k = 1:min(length(mat_files), 3)  % Анализируем первые 3 файла
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    fprintf('Файл %d: %s\n', k, mat_files(k).name);
    fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    data = load(fullfile(raw_dir, mat_files(k).name));
    fields = fieldnames(data);
    
    fprintf('Переменные в файле:\n');
    for i = 1:length(fields)
        var = data.(fields{i});
        if isnumeric(var)
            fprintf('  • %s: размер [%d x %d], тип %s', ...
                fields{i}, size(var,1), size(var,2), class(var));
            if isvector(var)
                fprintf(' (вектор, длина %d)', length(var));
            end
            fprintf('\n');
            
            % Показываем первые несколько значений для векторов
            if isvector(var) && length(var) <= 20
                fprintf('    Значения: [');
                fprintf('%.2f ', var);
                fprintf(']\n');
            elseif isvector(var) && length(var) > 20
                fprintf('    Первые 5 значений: [');
                for j = 1:5
                    fprintf('%.2f ', var(j));
                end
                fprintf('...]\n');
            end
        elseif isstruct(var)
            fprintf('  • %s: структура с полями: ', fields{i});
            subfields = fieldnames(var);
            for j = 1:length(subfields)
                fprintf('%s ', subfields{j});
            end
            fprintf('\n');
        else
            fprintf('  • %s: тип %s\n', fields{i}, class(var));
        end
    end
    fprintf('\n');
end

% Рекомендация
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
fprintf('РЕКОМЕНДАЦИЯ:\n');
fprintf('  Если переменные имеют имена, отличные от "ppg" или "signal",\n');
fprintf('  отредактируйте функцию find_ppg_signal или укажите правильное имя.\n');
fprintf('  Например, если сигнал называется "data", используйте:\n');
fprintf('    ppg_signal = data.data;\n');
fprintf('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');