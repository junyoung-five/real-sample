function fr = lu_freq_analysis(t, vp, cfg)
%LU_FREQ_ANALYSIS  주파수 / 시간-주파수 영역 분석.
%   FFT 스펙트럼, STFT 스펙트로그램, (옵션) CWT 를 계산한다.
%   결함은 종종 주파수 성분 감쇠/이동, 모드변환으로 나타난다.
%
%   fr = lu_freq_analysis(t, vp, cfg)
%
%   반환 fr:
%     f, P        : 단측 진폭 스펙트럼 (주파수[Hz], 크기)
%     centroid    : 스펙트럼 무게중심 주파수 [Hz]
%     bw          : -6dB 대역폭 [Hz]
%     peakFreq    : 최대 성분 주파수 [Hz]
%     stft        : struct(S, fS, tS) 스펙트로그램(옵션)
%     cwt         : struct(coefs, fC, tC) (옵션)

    fs = 1 / median(diff(t));
    fr = struct();

    % 분석 윈도우(트리거 이후 신호 구간) 선택
    if ~isempty(cfg.freq.analysisWin)
        idx = t >= cfg.freq.analysisWin(1) & t <= cfg.freq.analysisWin(2);
    else
        idx = t >= cfg.triggerTime;
    end
    x = vp(idx);
    x = x - mean(x);
    N = numel(x);

    % --- FFT 단측 스펙트럼 ---
    if cfg.freq.doFFT
        w  = hann(N);
        X  = fft(x .* w);
        P  = abs(X(1:floor(N/2)+1)) / N;
        P(2:end-1) = 2 * P(2:end-1);
        f  = (0:floor(N/2))' * fs / N;

        fr.f = f;
        fr.P = P;

        % 표시 대역 내 지표
        bandIdx = f <= cfg.freq.fAxisMax;
        fb = f(bandIdx); Pb = P(bandIdx);
        [pk, kp] = max(Pb);
        fr.peakFreq = fb(kp);
        fr.centroid = sum(fb .* Pb) / sum(Pb + eps);

        % -6 dB 대역폭
        half = pk / 2;          % -6 dB = 1/2 진폭
        above = fb(Pb >= half);
        if numel(above) >= 2
            fr.bw = above(end) - above(1);
        else
            fr.bw = NaN;
        end
    end

    % --- STFT 스펙트로그램 ---
    if cfg.freq.doSTFT
        win = min(cfg.freq.stftWin, floor(N/4));
        win = max(win, 64);
        nov = round(cfg.freq.stftOverlap * win);
        nfft = 2^nextpow2(win);
        try
            [S, fS, tS] = spectrogram(x, hann(win), nov, nfft, fs);
            fr.stft = struct('S', abs(S), 'fS', fS, 'tS', tS + t(find(idx,1)));
        catch ME
            warning('lu_freq_analysis:stft', 'STFT 실패: %s', ME.message);
        end
    end

    % --- CWT (분산성 가이드파 분석; Wavelet Toolbox 필요) ---
    if cfg.freq.doCWT && exist('cwt', 'file') == 2
        try
            % 1M 포인트 전체는 과도하므로 신호 구간으로 제한
            [coefs, fC] = cwt(x, fs);
            fr.cwt = struct('coefs', abs(coefs), 'fC', fC, ...
                            'tC', t(idx));
        catch ME
            warning('lu_freq_analysis:cwt', 'CWT 실패: %s', ME.message);
        end
    end
end
