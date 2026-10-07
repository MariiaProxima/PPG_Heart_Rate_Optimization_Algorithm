clear;
clc;
close all;

fprintf('--------------------------------\n');
fprintf('-- PPG ALGORITHM OPTIMIZATION --\n');
fprintf('--------------------------------\n');

% 1. Creating a structure of project folders
project_root = pwd;
folders = {'data/raw', 'data/processed', 'results/figures', 'results/metrics', 'functions'};

for i = 1:length(folders)
    folder_path = fullfile(project_root, folders{i});
    if ~exist(folder_path, 'dir')
        mkdir(folder_path); % Creating folder with a specified path
        fprintf('The folder "%s" is created\n ', folders{i});
    end
end

% Checking the download
raw_dir = fullfile(project_root, 'data/raw');
mat_files = dir(fullfile(raw_dir, '*.mat'));

if isempty(mat_files)
    warning('Files are not found. Add .mat files to "data\raw"');
else 
    fprintf('\n%d files are found:\n', length(mat_files));
end

% 4. Adding functions to the path
addpath(genpath(project_root));
fprintf('---------------------\n');
fprintf('-- PATHS ARE ADDED --\n');
fprintf('---------------------\n');


