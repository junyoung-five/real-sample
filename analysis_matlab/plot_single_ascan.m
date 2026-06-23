function plot_single_ascan()
%PLOT_SINGLE_ASCAN  단일 .dat 라인스캔 파일을 적절한 figure 세팅으로 시각화.
%   C1--sample1--00000.dat 를 로드하여
%     (a) 전체 A-scan(원시 파형)
%     (b) 트리거(t=0) 이후 신호 구간 확대 + Hilbert 포락선
%     (c) 진폭 스펙트럼(FFT, 단측)
%   3-패널 figure 로 그리고 results/ 에 PNG 로 저장한다.

    here     = fileparts(mfilename('fullpath'));
    dataFile = fullfile(here, '..', 'data', 'C1--sample1--00000.dat');
    outDir   = fullfile(here, 'results');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    % ---- 로드 ---------------------------------------------------------
    M = readmatrix(dataFile, 'FileType', 'text');
    t = M(:,1);          % [s]
    v = M(:,2);          % [V]

    dt = median(diff(t));
    fs = 1/dt;
    fprintf('points=%d  dt=%.3g s  fs=%.3g Hz  t=[%.2f, %.2f] us\n', ...
            numel(t), dt, fs, t(1)*1e6, t(end)*1e6);

    % DC 제거(트리거 이전 노이즈 구간 평균 기준)
    pre = t < 0;
    v0  = v - mean(v(pre));

    % Hilbert 포락선(신호 구간만; t>=0)
    sigIdx = t >= 0;
    ts     = t(sigIdx);
    vs     = v0(sigIdx);
    env    = abs(hilbert(vs));

    % ---- figure -------------------------------------------------------
    f = figure('Color', 'w', 'Position', [100 100 1000 900]);
    try, theme(f, 'light'); end   % R2025a+ 다크 기본테마 방지 -> 밝은 배경 강제
    tl = tiledlayout(f, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(tl, 'C1--sample1--00000  (Laser Ultrasonic A-scan)', ...
          'FontWeight', 'bold', 'Interpreter', 'none');

    % (a) 전체 파형
    ax1 = nexttile;
    plot(ax1, t*1e6, v0, 'Color', [0 0.45 0.74], 'LineWidth', 0.4);
    xline(ax1, 0, '--r', 't_0 (laser)', 'LineWidth', 1, ...
          'LabelVerticalAlignment', 'bottom');
    grid(ax1, 'on'); box(ax1, 'on');
    xlabel(ax1, 'Time [\mus]'); ylabel(ax1, 'Amplitude [V]');
    title(ax1, '(a) Full A-scan (DC-removed)');
    xlim(ax1, [t(1) t(end)]*1e6);

    % (b) 신호 구간 확대 + 포락선
    ax2 = nexttile;
    plot(ax2, ts*1e6, vs, 'Color', [0.5 0.5 0.5], 'LineWidth', 0.4); hold(ax2, 'on');
    plot(ax2, ts*1e6, env, 'r', 'LineWidth', 1.2);
    [pkv, pki] = max(env);
    plot(ax2, ts(pki)*1e6, pkv, 'r^', 'MarkerFaceColor', 'r');
    text(ax2, ts(pki)*1e6, pkv, sprintf('  peak @ %.2f \\mus', ts(pki)*1e6), ...
         'VerticalAlignment', 'bottom');
    grid(ax2, 'on'); box(ax2, 'on');
    legend(ax2, {'signal', 'Hilbert envelope'}, 'Location', 'northeast');
    xlabel(ax2, 'Time [\mus]'); ylabel(ax2, 'Amplitude [V]');
    title(ax2, '(b) Signal window (t \geq 0) with envelope');
    xlim(ax2, [0 ts(end)]*1e6);

    % (c) 진폭 스펙트럼
    ax3 = nexttile;
    N  = numel(vs);
    Y  = fft(vs .* hann(N));
    P  = abs(Y(1:floor(N/2)+1)) / N;
    P(2:end-1) = 2*P(2:end-1);
    fax = (0:floor(N/2))' * fs / N;
    plot(ax3, fax/1e6, P, 'Color', [0.85 0.33 0.10], 'LineWidth', 1);
    grid(ax3, 'on'); box(ax3, 'on');
    xlabel(ax3, 'Frequency [MHz]'); ylabel(ax3, '|Amplitude|');
    title(ax3, '(c) Single-sided amplitude spectrum');
    xlim(ax3, [0 10]);   % 주성분이 저주파(~1MHz)이므로 0-10MHz 확대

    % ---- 저장 ---------------------------------------------------------
    outPng = fullfile(outDir, 'single_ascan_sample1_00000.png');
    exportgraphics(f, outPng, 'Resolution', 150);
    fprintf('saved: %s\n', outPng);
end
