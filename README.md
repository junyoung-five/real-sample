# 레이저 초음파(LU) 결함 검출 분석 — MATLAB 파이프라인

LeCroy 오실로스코프에서 추출한 2열 ASCII `.dat` 라인스캔 데이터를
전처리 → 시간/주파수 특징 추출 → B-scan 영상화 → 시편 간 자동 비교
(이상치 = 결함 후보)까지 수행하는 MATLAB 코드 모음입니다.

## 프로젝트 구조
```
real-sample/
├─ data/                 # 원본 .dat 라인스캔 데이터 (C1--<sample>--<NNNNN>.dat)
├─ analysis_matlab/      # MATLAB 분석 파이프라인 (lu_*.m, run_analysis.m)
│  └─ results/           # 분석 결과 (PNG·CSV·MAT)
├─ build_seminar_pptx.py # 세미나 슬라이드 생성 스크립트
└─ ClaudeCode_세미나.pptx
```
> 원본 데이터 경로는 `analysis_matlab/lu_config.m` 의 `cfg.dataDir`(기본값 `<프로젝트 루트>/data`)에서 관리합니다.

## 데이터 사양 (자동 확인됨)
- 형식: 2열 ASCII `시간[s]  진폭[V]`, 파일명 `C1--<sample>--<NNNNN>.dat`
- 샘플당 **1,000,002 포인트**, 시간 **−20 µs ~ +180 µs**
- 샘플링 **Δt = 0.2 ns → fs = 5 GHz**
- **t = 0 = 레이저 여기(트리거) 시점** → t<0 구간은 노이즈(SNR 추정용)
- 시편 2종(`sample1`, `sample2`), 각 **11개 라인스캔 위치**(00000~00010)

## 빠른 시작
```matlab
cd analysis_matlab
edit lu_config.m        % 실험 조건(간격/두께/음속/대역) 조정
run_analysis            % 전체 분석 실행
```
결과는 `analysis_matlab/results/` 에 그림(PNG)·CSV·MAT 로 저장됩니다.
빠른 검증만 원하면 `smoke_test`(2위치×2시편, 다운샘플) 실행.

> 필요 툴박스: **Signal Processing Toolbox**(필수), Wavelet Toolbox(CWT 옵션)

## 파일 구성
| 파일 | 역할 |
|------|------|
| `lu_config.m`        | 모든 파라미터(경로·대역·기하·출력) 중앙 설정 |
| `lu_load_dat.m`      | `.dat` 로더 (+ 선택적 안티앨리어싱 데시메이션) |
| `lu_preprocess.m`    | DC제거·추세제거·**SOS 대역통과(zero-phase)**·SNR 추정 |
| `lu_time_analysis.m` | Hilbert 포락선·**ToF(첫 도달)**·에코 피크·에너지/RMS·깊이 환산 |
| `lu_freq_analysis.m` | FFT 스펙트럼·중심주파수·−6dB 대역폭·STFT·(옵션)CWT |
| `lu_bscan.m`         | 위치별 A-scan 을 쌓아 **B-scan 영상** 구성 |
| `lu_compare.m`       | robust z-score(MAD) 기반 **이상치=결함 후보** 자동 판정 |
| `lu_plots.m`         | A-scan/포락선, FFT, 스펙트로그램, B-scan, 특징곡선 시각화 |
| `run_analysis.m`     | 메인 드라이버 |

## 구현된 결함 검출 방법론
1. **전처리/SNR** — 트리거 이전 구간으로 노이즈 기준선·SNR 산출, SOS
   대역통과(filtfilt, 무위상)로 드리프트·고주파 노이즈 제거.
2. **시간영역(ToF)** — Hilbert 포락선의 *피크 대비 비율(기본 20%)* 첫 교차로
   첫 도달시간 산출. 음속을 알면 깊이로 환산(펄스에코 가정 `d=c·ToF/2`).
   결함은 ToF 지연/에코 추가로 나타남.
3. **주파수영역** — FFT 스펙트럼, 스펙트럼 중심주파수·−6dB 대역폭으로
   결함에 의한 **고주파 감쇠/주파수 하락** 정량화. STFT 로 시간-주파수
   거동(모드변환/분산) 관찰. (옵션 CWT 로 가이드파 분산 분석)
4. **B-scan 영상화** — 라인스캔 위치를 가로축, 시간을 세로축으로 포락선을
   영상화. 결함은 국부적 에코 패턴 변화로 가시화.
5. **자동 비교** — 기준(건전부) 가정 없이, 각 지표(ToF·peakAmp·energy·
   peakFreq·대역폭…)를 위치 분포로 보고 **robust z-score |z|≥3.5**를
   결함 후보로 플래그. 시편 간 평균/표준편차도 요약 비교.

## 실험 조건에 맞춰 조정할 항목 (`lu_config.m`)
- `scanPitch` — 라인스캔 **위치 간격[m]** (현재 1 mm 가정). f-k/속도 분석에 필수.
- `geom.thickness`, `geom.waveSpeed` — 알면 입력 시 **ToF→깊이** 환산 활성화
  (예: 알루미늄 종파 ≈ 6320 m/s, 강 ≈ 5900 m/s).
- `pre.bpLow/bpHigh` — 유효 초음파 **대역**. 현재 데이터는 주성분이
  ~0.5–1 MHz로 낮음. 더 높은 성분을 보려면 `bpHigh`↑ + `pre.decim`↓.
- `pre.decim` — 기본 **10**(5 GHz→500 MHz). 원본 fs 대비 신호대역이 매우
  낮아 데시메이션이 타당하며 수치안정성/속도를 개선. 고주파 관심 시 낮출 것.
- `acqMode` — `'linescan'`(B-scan) / `'average'`(반복측정 평균화).

## 참고 / 주의
- 5 GHz 원본에서 0.5 MHz 컷오프는 정규화 주파수가 극히 낮아 직접형(b,a)
  Butterworth 가 불안정(NaN). 본 코드는 **SOS 설계 + 데시메이션**으로 해결함.
- `scanPitch`·`waveSpeed`·`thickness` 는 실측값으로 교체해야 정량 깊이/속도가
  유효합니다(미입력 시 `depth=NaN`, 위치축은 인덱스 단위).
