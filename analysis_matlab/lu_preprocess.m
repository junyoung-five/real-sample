function [vp, pp] = lu_preprocess(t, v, cfg)
%LU_PREPROCESS  레이저 초음파 A-scan 신호 전처리.
%   DC 제거 -> 추세 제거 -> 대역통과(zero-phase) 순으로 정제하고,
%   트리거 이전 구간으로 노이즈 통계/SNR 을 추정한다.
%
%   [vp, pp] = lu_preprocess(t, v, cfg)
%     t, v : 시간/진폭 벡터
%     cfg  : lu_config()
%
%   반환:
%     vp : 전처리된 진폭 벡터
%     pp : struct(noiseRMS, snr_dB, dcOffset, ...) 전처리 메타정보

    fs = 1 / median(diff(t));
    pp = struct();

    vp = double(v(:));

    % 트리거 이전(노이즈) 구간 인덱스
    preIdx = t < cfg.triggerTime;
    if nnz(preIdx) < 50
        % 트리거 이전 샘플이 거의 없으면 앞쪽 1% 를 노이즈로 사용
        n = max(50, round(0.01 * numel(vp)));
        preIdx = false(size(vp)); preIdx(1:n) = true;
    end

    % 1) DC offset 제거 (노이즈 구간 평균 기준 -> 신호 왜곡 최소화)
    if cfg.pre.removeDC
        dc = mean(vp(preIdx));
        vp = vp - dc;
        pp.dcOffset = dc;
    end

    % 2) 선형 추세 제거(저주파 드리프트)
    if cfg.pre.detrend
        vp = detrend(vp, 'linear');
    end

    % 3) 대역통과 필터 (Butterworth, zero-phase filtfilt -> 위상왜곡 없음)
    %    수치 안정성을 위해 반드시 SOS(2차 섹션) 형태로 설계한다.
    %    (b,a 직접형은 정규화 컷오프가 매우 낮을 때 NaN/Inf 를 유발함)
    if cfg.pre.bandpass
        nyq = fs / 2;
        lo  = cfg.pre.bpLow  / nyq;
        hi  = min(cfg.pre.bpHigh / nyq, 0.99);
        lo  = max(lo, 1e-4);
        if lo < 1e-3
            warning('lu_preprocess:lowWn', ...
                ['정규화 하한 컷오프가 매우 낮습니다(%.1e). 데시메이션' ...
                 '(cfg.pre.decim)을 권장합니다.'], lo);
        end
        if lo < hi
            [z, p, k] = butter(cfg.pre.bpOrder, [lo hi], 'bandpass');
            [sos, g]  = zp2sos(z, p, k);
            vp = filtfilt(sos, g, vp);
        else
            warning('lu_preprocess:badBand', '대역 설정이 유효하지 않아 필터를 건너뜁니다.');
        end
    end

    % 4) 노이즈 RMS / SNR 추정
    noiseRMS = rms(vp(preIdx));
    sigIdx   = t >= cfg.triggerTime;
    sigPeak  = max(abs(vp(sigIdx)));
    pp.noiseRMS = noiseRMS;
    pp.sigPeak  = sigPeak;
    pp.snr_dB   = 20 * log10(sigPeak / max(noiseRMS, eps));
    pp.fs       = fs;
end
