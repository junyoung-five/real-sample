function [t, v, info] = lu_load_dat(filePath, cfg)
%LU_LOAD_DAT  LeCroy 오실로스코프 2열 ASCII(.dat) 파일 로더.
%   파일은 "time amplitude" 두 열(공백 구분, CRLF)로 구성된다.
%
%   [t, v, info] = lu_load_dat(filePath, cfg)
%     filePath : .dat 파일 전체 경로
%     cfg      : lu_config() 구조체 (옵션; 다운샘플/검증에 사용)
%
%   반환:
%     t    : 시간 벡터 [s]  (열벡터)
%     v    : 진폭 벡터 [V]  (열벡터)
%     info : struct(fs, dt, N, tStart, tEnd, file)

    if nargin < 2, cfg = struct('pre', struct('decim', 1)); end

    if ~isfile(filePath)
        error('lu_load_dat:fileNotFound', '파일을 찾을 수 없습니다: %s', filePath);
    end

    % readmatrix 가 가장 빠르고 견고함(공백/CRLF 자동 처리).
    M = readmatrix(filePath, 'FileType', 'text');

    % 혹시 NaN 행(빈 줄 등) 제거
    M = M(all(~isnan(M), 2), :);
    if size(M, 2) < 2
        error('lu_load_dat:badFormat', ...
              '2열 데이터가 아닙니다 (열 개수 = %d): %s', size(M,2), filePath);
    end

    t = M(:, 1);
    v = M(:, 2);

    % 샘플 간격 / 샘플링 주파수 추정 (중앙값으로 견고하게)
    dt = median(diff(t));
    fs = 1 / dt;

    % 선택적 다운샘플(해석 대역이 Nyquist 보다 훨씬 낮을 때 메모리/속도 개선)
    decim = 1;
    if isfield(cfg, 'pre') && isfield(cfg.pre, 'decim')
        decim = max(1, round(cfg.pre.decim));
    end
    if decim > 1
        % 앤티앨리어싱 포함 다운샘플
        v = decimate(v, decim);
        t = t(1:decim:end);
        t = t(1:numel(v));
        dt = dt * decim;
        fs = fs / decim;
    end

    info = struct();
    info.fs     = fs;
    info.dt     = dt;
    info.N      = numel(v);
    info.tStart = t(1);
    info.tEnd   = t(end);
    [~, name, ext] = fileparts(filePath);
    info.file   = [name ext];
end
