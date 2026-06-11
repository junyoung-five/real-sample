%% RUN_ANALYSIS  레이저 초음파(LU) 결함 검출 메인 분석 스크립트
%
%   LeCroy 오실로스코프에서 추출한 2열 ASCII(.dat) 라인스캔 데이터를
%   읽어 전처리 -> 시간/주파수 특징 추출 -> B-scan 영상화 -> 시편 간
%   자동 비교(이상치=결함 후보) 까지 수행한다.
%
%   사용법:
%     1) lu_config.m 에서 실험 조건(간격, 두께, 음속, 대역 등) 조정
%     2) 본 스크립트 실행 (analysis_matlab 폴더에서)
%
%   필요 툴박스: Signal Processing Toolbox (필수), Wavelet Toolbox (CWT 옵션)
%
%   작성: LU NDT 분석 파이프라인
% ------------------------------------------------------------------------

clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
cfg = lu_config();

if ~exist(cfg.out.dir, 'dir'); mkdir(cfg.out.dir); end
fprintf('데이터 폴더: %s\n', cfg.dataDir);

%% 1) 로드 + 전처리 + 특징 추출 -------------------------------------------
allSamples = struct();      % allSamples.(sample)(pos) = per-A-scan data
rows = {};                  % feature table rows

for si = 1:numel(cfg.samples)
    sname = cfg.samples{si};
    fprintf('\n=== 시편: %s ===\n', sname);
    posData = struct('t', {}, 'vp', {}, 'env', {});

    for k = 1:numel(cfg.indexRange)
        idx   = cfg.indexRange(k);
        fname = sprintf('%s--%s--%05d.dat', cfg.channelPrefix, sname, idx);
        fpath = fullfile(cfg.dataDir, fname);
        if ~isfile(fpath)
            warning('파일 없음, 건너뜀: %s', fname); continue;
        end
        fprintf('  [%2d/%2d] %s ', k, numel(cfg.indexRange), fname);

        % --- 로드 ---
        [t, v, info] = lu_load_dat(fpath, cfg);
        if isnan(cfg.fs); cfg.fs = info.fs; cfg.dt = info.dt; end

        % --- 전처리 ---
        [vp, pp] = lu_preprocess(t, v, cfg);

        % --- 시간영역 특징 ---
        ft = lu_time_analysis(t, vp, cfg);

        % --- 주파수영역 특징 ---
        fr = lu_freq_analysis(t, vp, cfg);

        fprintf('| SNR=%.1f dB, ToF=%.2f us, fpk=%.1f MHz\n', ...
            pp.snr_dB, 1e6*ft.tofFirst, 1e-6*fr.peakFreq);

        % --- 위치 데이터 저장 (B-scan 용) ---
        posData(end+1) = struct('t', t, 'vp', vp, 'env', ft.env); %#ok<SAGROW>

        % --- 특징 테이블 행 ---
        rows(end+1, :) = { sname, idx, idx*cfg.scanPitch, ...
            ft.tofFirst, ft.peakAmp, ft.energy, ft.rms, pp.snr_dB, ...
            fr.peakFreq, fr.centroid, fr.bw, ft.depth }; %#ok<SAGROW>
    end
    allSamples.(sname) = posData;
end

featTable = cell2table(rows, 'VariableNames', ...
    {'sample','index','pos','tofFirst','peakAmp','energy','rms', ...
     'snr_dB','peakFreq','centroid','bw','depth'});

disp(' '); disp('=== 특징 테이블 ==='); disp(featTable);

%% 2) 시편 간 자동 비교 (이상치 = 결함 후보) ------------------------------
cmp = lu_compare(featTable, cfg);
disp('=== 시편별 요약 ==='); disp(cmp.summary);
anom = cmp.table(cmp.table.anomaly, {'sample','index','pos'});
if isempty(anom)
    fprintf('이상치(결함 후보) 검출 없음 (|robust z| < 3.5).\n');
else
    fprintf('결함 후보 위치(이상치):\n'); disp(anom);
end

%% 3) B-scan 영상 구성 ----------------------------------------------------
bscan = struct();
for si = 1:numel(cfg.samples)
    sname = cfg.samples{si};
    if isfield(allSamples, sname) && ~isempty(allSamples.(sname))
        bscan.(sname) = lu_bscan(allSamples.(sname), cfg);
    end
end

%% 4) 시각화 ---------------------------------------------------------------
lu_plots(allSamples, bscan, featTable, cmp, cfg);

%% 5) 결과 저장 -----------------------------------------------------------
if cfg.out.saveMat
    save(fullfile(cfg.out.dir, 'lu_results.mat'), ...
        'featTable', 'cmp', 'bscan', 'cfg', '-v7.3');
    writetable(featTable, fullfile(cfg.out.dir, 'features.csv'));
    writetable(cmp.table,  fullfile(cfg.out.dir, 'features_with_zscore.csv'));
    writetable(cmp.summary,fullfile(cfg.out.dir, 'sample_summary.csv'));
    fprintf('\n결과 저장 완료: %s\n', cfg.out.dir);
end
