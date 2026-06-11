function cmp = lu_compare(featTable, cfg)
%LU_COMPARE  두 시편(및 위치별)의 특징을 자동 비교해 이상(결함) 후보를 도출.
%   기준(건전부) 가정 없이, 각 지표를 위치에 대해 분포로 보고 통계적
%   이상치(robust z-score)를 결함 후보로 표시한다. 시편 간 평균 차이도 보고.
%
%   cmp = lu_compare(featTable, cfg)
%     featTable : table. 열 = {sample, index, pos, tofFirst, peakAmp,
%                 energy, rms, snr_dB, peakFreq, centroid, bw, ...}
%
%   반환 cmp:
%     table     : 입력 + 지표별 robust z-score + 이상 플래그
%     summary   : 시편별 지표 평균/표준편차 비교 table
%     metrics   : 사용된 지표 이름 목록

    T = featTable;
    metrics = {'tofFirst','peakAmp','energy','rms','snr_dB', ...
               'peakFreq','centroid','bw'};
    metrics = metrics(ismember(metrics, T.Properties.VariableNames));

    % --- 시편 내 위치별 robust z-score (MAD 기반) ---
    samples = unique(T.sample, 'stable');
    anomalyFlag = false(height(T), 1);
    for m = 1:numel(metrics)
        z = nan(height(T), 1);
        for s = 1:numel(samples)
            rows = strcmp(T.sample, samples{s});
            x = T.(metrics{m})(rows);
            med = median(x, 'omitnan');
            madv = 1.4826 * median(abs(x - med), 'omitnan');  % 정규분포 환산 MAD
            if madv > 0
                z(rows) = (x - med) / madv;
            else
                z(rows) = 0;
            end
        end
        T.(['z_' metrics{m}]) = z;
        anomalyFlag = anomalyFlag | (abs(z) >= 3.5);  % |z|>=3.5 -> 이상치
    end
    T.anomaly = anomalyFlag;

    % --- 시편 간 요약 비교 ---
    rows = cell(0,1); c = 0;
    Smean = []; Sstd = [];
    for m = 1:numel(metrics)
        for s = 1:numel(samples)
            sel = strcmp(T.sample, samples{s});
            Smean(s, m) = mean(T.(metrics{m})(sel), 'omitnan'); %#ok<AGROW>
            Sstd(s, m)  = std(T.(metrics{m})(sel),  'omitnan'); %#ok<AGROW>
        end
    end
    summary = table();
    summary.sample = samples(:);
    for m = 1:numel(metrics)
        summary.(['mean_' metrics{m}]) = Smean(:, m);
        summary.(['std_'  metrics{m}]) = Sstd(:, m);
    end

    cmp = struct();
    cmp.table   = T;
    cmp.summary = summary;
    cmp.metrics = metrics;
end
