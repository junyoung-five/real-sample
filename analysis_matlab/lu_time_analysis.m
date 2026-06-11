function feat = lu_time_analysis(t, vp, cfg)
%LU_TIME_ANALYSIS  시간영역 특징 추출 (포락선 / ToF / 에너지).
%   레이저 초음파 결함검출의 핵심 지표인 도달시간(Time-of-Flight),
%   신호 에너지, 포락선 피크 등을 계산한다.
%
%   feat = lu_time_analysis(t, vp, cfg)
%
%   반환 feat:
%     env        : Hilbert 포락선
%     tofFirst   : 첫 도달 시간 [s] (임계 초과 시점)
%     peakTime   : 최대 포락선 피크 시간 [s]
%     peakAmp    : 최대 포락선 진폭
%     echoTimes  : 포락선 다중 피크(에코) 시간들 [s]
%     energy     : 신호구간 에너지 (sum v^2 * dt)
%     rms        : 신호구간 RMS
%     depth      : (속도/두께 알면) ToF -> 추정 깊이 [m]

    dt = median(diff(t));
    feat = struct();

    % --- 포락선 (해석 신호 크기) ---
    env = abs(hilbert(vp));
    feat.env = env;

    sigIdx = t >= cfg.tof.searchAfter;
    tt = t(sigIdx);
    ee = env(sigIdx);
    vv = vp(sigIdx);

    % --- 노이즈 기준 임계 (트리거 이전 구간) ---
    preIdx   = t < cfg.triggerTime;
    if nnz(preIdx) < 50, preIdx = t < t(1) + 0.05*(t(end)-t(1)); end
    noiseRMS = rms(env(preIdx));

    % --- 최대 피크 (검색 구간 내) ---
    [pkAmp, kPk] = max(ee);

    % --- 첫 도달 시간 ---
    %   주 기준: 최대 포락선의 일정 비율(peakFrac)을 처음 넘어서는 시점.
    %   보조(하한): 노이즈 env RMS * threshFactor (둘 중 큰 값).
    %   => 명확한 피크가 있으면 항상 도달을 잡고, 노이즈만 있으면 NaN.
    thr = max(cfg.tof.peakFrac * pkAmp, cfg.tof.threshFactor * noiseRMS);
    if pkAmp <= cfg.tof.threshFactor * noiseRMS
        feat.tofFirst = NaN;          % 신호가 노이즈 수준 -> 도달 없음
    else
        k = find(ee >= thr, 1, 'first');
        if isempty(k); feat.tofFirst = NaN; else; feat.tofFirst = tt(k); end
    end
    feat.peakAmp  = pkAmp;
    feat.peakTime = tt(kPk);

    % --- 다중 에코(피크) 검출: 후속 반사(back-wall echo, 결함 에코) ---
    envN = ee / max(ee + eps);
    try
        [~, locs] = findpeaks(envN, ...
            'MinPeakProminence', cfg.tof.minPeakProm, ...
            'MinPeakDistance',  max(1, round(1e-6/dt)));   % 최소 1us 간격
        feat.echoTimes = tt(locs);
        feat.echoAmps  = ee(locs);
    catch
        feat.echoTimes = feat.peakTime;
        feat.echoAmps  = pkAmp;
    end

    % --- 에너지 / RMS (신호 구간) ---
    feat.energy = sum(vv.^2) * dt;
    feat.rms    = rms(vv);
    feat.noiseRMS = noiseRMS;

    % --- ToF -> 결함 깊이 추정 (속도와 두께 정보가 있을 때) ---
    feat.depth = NaN;
    if ~isnan(cfg.geom.waveSpeed) && ~isnan(feat.tofFirst)
        % 펄스에코 가정: 왕복거리 = c * ToF, 깊이 = c*ToF/2
        feat.depth = cfg.geom.waveSpeed * (feat.tofFirst - cfg.triggerTime) / 2;
    end
end
