function cfg = lu_config()
%LU_CONFIG  레이저 초음파(LU) 결함 검출 분석 파라미터 설정.
%   모든 분석 스크립트가 공유하는 설정값을 한 곳에서 관리한다.
%   실험 조건이 바뀌면 이 파일만 수정하면 된다.
%
%   반환: cfg (struct)

    cfg = struct();

    % ------------------------------------------------------------------
    % 1) 데이터 위치 / 파일 명명 규칙
    % ------------------------------------------------------------------
    % LeCroy 오실로스코프 파일명 형식:  C1--<sample>--<NNNNN>.dat
    %   - 채널접두어 = 'C1'
    %   - 시편(sample) = 'sample1', 'sample2'
    %   - 인덱스 NNNNN = 라인 스캔 위치(00000~00010)
    projectRoot       = fileparts(fileparts(mfilename('fullpath'))); % 프로젝트 최상위 폴더
    cfg.dataDir       = fullfile(projectRoot, 'data');               % .dat 들이 모여 있는 data 폴더
    cfg.channelPrefix = 'C1';
    cfg.samples       = {'sample1', 'sample2'};   % 비교할 시편 목록
    cfg.indexRange    = 0:10;                      % 라인 스캔 위치 인덱스

    % ------------------------------------------------------------------
    % 2) 획득(Acquisition) 성격
    %   'linescan'  : 인덱스 = 공간 위치  -> B-scan 이미지 생성
    %   'average'   : 동일 지점 반복 측정 -> coherent averaging
    % ------------------------------------------------------------------
    cfg.acqMode = 'linescan';

    % 라인 스캔 위치 간격 [m]. (실측값으로 교체할 것. 모르면 1 으로 두면
    %  결과 축이 '인덱스' 단위가 된다.) f-k 분석 시 반드시 필요.
    cfg.scanPitch = 1e-3;   % 예: 1 mm 간격

    % ------------------------------------------------------------------
    % 3) 신호 시간축 / 트리거
    % ------------------------------------------------------------------
    % fs, dt 는 데이터에서 자동 계산되므로 비워둔다(아래 NaN).
    cfg.fs = NaN;           % [Hz] 샘플링 주파수 (자동)
    cfg.dt = NaN;           % [s]  샘플 간격     (자동)
    cfg.triggerTime = 0;    % [s]  레이저 여기 시점(=초음파 발생 t0)

    % ------------------------------------------------------------------
    % 4) 전처리(Preprocessing)
    % ------------------------------------------------------------------
    cfg.pre.removeDC     = true;    % DC offset 제거(트리거 이전 구간 기준)
    cfg.pre.detrend      = true;    % 선형 추세 제거
    cfg.pre.bandpass     = true;    % 대역통과 필터 적용 여부
    cfg.pre.bpLow        = 0.5e6;   % [Hz] 하한 (저주파 드리프트 제거)
    cfg.pre.bpHigh       = 50e6;    % [Hz] 상한 (레이저초음파 유효대역)
    cfg.pre.bpOrder      = 4;       % Butterworth 차수(zero-phase filtfilt)
    cfg.pre.gateNoise    = true;    % t<triggerTime(노이즈 구간)으로 SNR 추정

    % 대용량(1M points @ 5GHz) 처리를 위한 다운샘플.
    %  원본 fs=5GHz 인데 레이저초음파 유효신호는 ~수십 MHz 이하이므로
    %  데시메이션이 물리적으로 타당하고(대역손실 없음) 속도/수치안정성을
    %  크게 개선한다. decim=10 -> fs=500MHz(Nyquist 250MHz, 해석대역 50MHz).
    %  더 높은 주파수 성분을 보려면 decim 을 낮추고 bpHigh 를 올린다.
    cfg.pre.decim        = 10;

    % ------------------------------------------------------------------
    % 5) 시간영역 분석 (ToF / 포락선)
    % ------------------------------------------------------------------
    cfg.tof.envMethod    = 'hilbert';  % 포락선 방법: 'hilbert'
    cfg.tof.threshFactor = 4;          % 노이즈 기반 임계 = 노이즈env RMS * factor (하한)
    cfg.tof.peakFrac     = 0.2;        % 주 임계 = 최대포락선 * 이 비율(20%) 첫 교차
    cfg.tof.minPeakProm  = 0.05;       % 포락선 피크 최소 prominence(정규화)
    cfg.tof.searchAfter  = 0;          % [s] 이 시점 이후에서만 도달 탐색

    % 두께/속도 (ToF -> 결함 깊이 환산용; 알면 입력, 모르면 NaN)
    cfg.geom.thickness   = NaN;        % [m] 시편 두께
    cfg.geom.waveSpeed   = NaN;        % [m/s] 종파 음속(예: 알루미늄 ~6320)

    % ------------------------------------------------------------------
    % 6) 주파수 / 시간-주파수 분석
    % ------------------------------------------------------------------
    cfg.freq.doFFT       = true;
    cfg.freq.doSTFT      = true;    % 스펙트로그램
    cfg.freq.stftWin     = 1024;    % STFT 윈도우 길이(샘플)
    cfg.freq.stftOverlap = 0.75;    % 오버랩 비율
    cfg.freq.doCWT       = false;   % 연속 웨이블릿(분산성 가이드파). Wavelet Toolbox 필요
    cfg.freq.fAxisMax    = 60e6;    % [Hz] 그림 표시 상한

    % 분석 관심 윈도우(t0 이후 신호 구간). [start end] 초, 비우면 전체.
    cfg.freq.analysisWin = [];      % 예: [0 60e-6]

    % ------------------------------------------------------------------
    % 7) 출력
    % ------------------------------------------------------------------
    cfg.out.dir          = fullfile(projectRoot, 'analysis_matlab', 'results');
    cfg.out.savePlots    = true;
    cfg.out.saveMat      = true;
    cfg.out.plotFormat   = 'png';
end
