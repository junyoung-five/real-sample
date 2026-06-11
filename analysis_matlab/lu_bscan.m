function B = lu_bscan(sampleData, cfg)
%LU_BSCAN  라인 스캔 A-scan 들을 쌓아 B-scan 이미지를 구성한다.
%   각 스캔 위치의 1D 시간신호(A-scan)를 세로로 정렬해 2D 영상으로 만든다.
%   가로축 = 스캔 위치, 세로축 = 시간(또는 깊이). 결함은 에코 패턴의
%   국부적 변화로 나타난다.
%
%   B = lu_bscan(sampleData, cfg)
%     sampleData : 1xP 구조체 배열(위치별), 각 원소에 .t .vp .env 필드
%     cfg        : lu_config()
%
%   반환 B:
%     img      : [Nt x P] 진폭 이미지 (필터된 신호)
%     imgEnv   : [Nt x P] 포락선 이미지
%     t        : 시간축 [s]
%     pos      : 위치축 [m] (scanPitch 기반)

    P = numel(sampleData);

    % 위치마다 길이가 미세하게 다를 수 있으므로 공통 최소 길이로 정렬
    Nt = min(arrayfun(@(s) numel(s.vp), sampleData));

    img    = zeros(Nt, P);
    imgEnv = zeros(Nt, P);
    for p = 1:P
        img(:, p)    = sampleData(p).vp(1:Nt);
        imgEnv(:, p) = sampleData(p).env(1:Nt);
    end

    B = struct();
    B.img    = img;
    B.imgEnv = imgEnv;
    B.t      = sampleData(1).t(1:Nt);
    B.pos    = (0:P-1) * cfg.scanPitch;
end
