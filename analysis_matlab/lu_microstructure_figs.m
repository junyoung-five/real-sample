function lu_microstructure_figs()
%LU_MICROSTRUCTURE_FIGS  미세조직(결정립) 분석용 발표 figure 생성.
%   pump-probe 레이저 초음파로 취득한 표면파(Rayleigh) 신호를
%   시편(sample1, sample2) 간 비교하여 결정립 크기와의 연관성을
%   살펴보기 위한 발표용 그림 4종을 생성한다.
%
%   생성물 (results/):
%     ms_fig1_surfacewave.png  표면파 대표 A-scan 비교 (0-3 us)
%     ms_fig2_waterfall.png    위치별 신호 적층(재현성/안정성)
%     ms_fig3_spectrum.png     평균 진폭 스펙트럼 비교 (감쇠/주파수)
%     ms_fig4_features.png     핵심 특징 막대 비교 (mean +/- std)

    here    = fileparts(mfilename('fullpath'));
    dataDir = fullfile(here, '..', 'data');
    outDir  = fullfile(here, 'results');
    if ~exist(outDir,'dir'); mkdir(outDir); end

    samples = {'sample1','sample2'};
    idx     = 0:10;
    SWIN    = [0 3e-6];          % 표면파 관심 윈도우 [s]
    BAND    = [0.1e6 5e6];       % 표면파 유효 신호대역 [Hz] (centroid 산정 범위)
    C = struct('blue',[0 0.45 0.74],'red',[0.85 0.33 0.10], ...
               'g1',[0.20 0.55 0.85],'g2',[0.90 0.40 0.15]);
    sampCol = {C.g1, C.g2};
    sampLbl = {'sample1  (결정립 64.4 \mum)','sample2  (결정립 482 \mum)'};

    % ---- 로드 + 윈도우 트림 -----------------------------------------
    D = struct();
    for si = 1:numel(samples)
        sig = {}; t0 = [];
        for k = idx
            fn = fullfile(dataDir, sprintf('C1--%s--%05d.dat', samples{si}, k));
            if ~exist(fn,'file'); continue; end
            M = readmatrix(fn,'FileType','text');
            t = M(:,1); v = M(:,2);
            v = v - mean(v(t<0));                 % DC 제거(트리거 이전 기준)
            sel = t>=SWIN(1) & t<=SWIN(2);
            sig{end+1} = v(sel); %#ok<AGROW>
            if isempty(t0); t0 = t(sel); end
        end
        L = min(cellfun(@numel,sig));
        Mx = cell2mat(cellfun(@(x)x(1:L)', sig, 'uni',0)');  % [nPos x L]
        D(si).t = t0(1:L); D(si).X = Mx;
        D(si).fs = 1/median(diff(t0));
    end

    % ===== Figure 1 : 표면파 대표 A-scan 비교 =========================
    f1 = figure('Color','w','Position',[80 80 1000 560]); trytheme(f1);
    tl = tiledlayout(f1,2,1,'TileSpacing','compact','Padding','compact');
    title(tl,'표면파(Rayleigh) 신호 — 시편 간 비교  (pump-probe 3 mm, 0–3 \mus)', ...
          'FontWeight','bold');
    for si = 1:2
        ax = nexttile;
        t = D(si).t*1e6; X = D(si).X;
        mu = mean(X,1); env = abs(hilbert(mu));
        % 개별 위치(옅게) + 평균 + 포락선
        plot(ax, t, X', 'Color',[0.8 0.8 0.8 0.5],'LineWidth',0.3); hold(ax,'on');
        plot(ax, t, mu,'Color',sampCol{si},'LineWidth',1.4);
        plot(ax, t, env,'Color',C.red,'LineWidth',1.2);
        [pk,pi]=max(env);
        plot(ax,t(pi),pk,'r^','MarkerFaceColor','r');
        text(ax,t(pi),pk,sprintf('  표면파 도달 \\approx %.2f \\mus',t(pi)),...
             'VerticalAlignment','bottom','FontWeight','bold');
        grid(ax,'on'); box(ax,'on'); xlim(ax,[0 3]);
        ylabel(ax,'Amplitude [V]');
        title(ax,sampLbl{si});
        if si==2; xlabel(ax,'Time [\mus]'); end
        legend(ax,{'개별 위치','평균','포락선'},'Location','northeast','FontSize',8);
    end
    save_fig(f1, fullfile(outDir,'ms_fig1_surfacewave.png'));

    % ===== Figure 2 : 위치별 waterfall(재현성/안정성) ================
    f2 = figure('Color','w','Position',[80 80 1000 560]); trytheme(f2);
    tl = tiledlayout(f2,1,2,'TileSpacing','compact','Padding','compact');
    title(tl,'위치별 표면파 신호 적층 — 스캔 재현성/안정성','FontWeight','bold');
    for si = 1:2
        ax = nexttile; t = D(si).t*1e6; X = D(si).X;
        off = 0.06;                       % 위치별 수직 오프셋
        for p = 1:size(X,1)
            plot(ax, t, X(p,:) + (p-1)*off, 'Color',sampCol{si},'LineWidth',0.5);
            hold(ax,'on');
        end
        grid(ax,'on'); box(ax,'on'); xlim(ax,[0 3]);
        yticks(ax,(0:size(X,1)-1)*off); yticklabels(ax,string(0:size(X,1)-1));
        xlabel(ax,'Time [\mus]');
        if si==1; ylabel(ax,'스캔 위치 인덱스 (아래→위)'); end
        title(ax,sampLbl{si});
    end
    save_fig(f2, fullfile(outDir,'ms_fig2_waterfall.png'));

    % ===== Figure 3 : 평균 진폭 스펙트럼 비교 =========================
    f3 = figure('Color','w','Position',[80 80 980 520]); trytheme(f3);
    ax = axes(f3); hold(ax,'on'); cent = zeros(1,2);
    for si = 1:2
        X = D(si).X; fs = D(si).fs; N = size(X,2);
        w = hann(N)';
        P = mean(abs(fft(X.*w,[],2)),1); P = P(1:floor(N/2)+1)/N; P(2:end-1)=2*P(2:end-1);
        fax = (0:floor(N/2))*fs/N;
        plot(ax, fax/1e6, P, 'Color',sampCol{si},'LineWidth',1.6);
        bsel = fax>=BAND(1) & fax<=BAND(2);            % 유효대역 내에서만 centroid
        cent(si) = sum(fax(bsel).*P(bsel))/sum(P(bsel));
    end
    for si=1:2
        xline(ax,cent(si)/1e6,'--','Color',sampCol{si},'LineWidth',1,...
            'Label',sprintf('centroid %.2f MHz',cent(si)/1e6));
    end
    grid(ax,'on'); box(ax,'on'); xlim(ax,[0 5]);
    xlabel(ax,'Frequency [MHz]'); ylabel(ax,'|Amplitude| (평균)');
    title(ax,'평균 진폭 스펙트럼 비교 — 결정립↑ ⇒ 고주파 감쇠/중심주파수 하락 기대',...
          'FontWeight','bold');
    legend(ax,sampLbl,'Location','northeast');
    save_fig(f3, fullfile(outDir,'ms_fig3_spectrum.png'));

    % ===== Figure 4 : 핵심 특징 막대 비교 =============================
    feats = struct('name',{},'val',{},'err',{},'unit',{});
    for si=1:2
        X=D(si).X; t=D(si).t; fs=D(si).fs;
        env = abs(hilbert(X')');
        pkAmp = max(env,[],2);                          % 표면파 피크진폭
        [~,pii]= max(env,[],2); tof = t(pii)*1e6;       % 도달시간 us
        en  = sum(X.^2,2)/fs;                           % 에너지
        N=size(X,2); w=hann(N)'; P=abs(fft(X.*w,[],2)); P=P(:,1:floor(N/2)+1);
        fax=(0:floor(N/2))*fs/N; bsel=fax>=BAND(1)&fax<=BAND(2);   % 유효대역 한정
        ctr=(P(:,bsel)*fax(bsel)')./sum(P(:,bsel),2)/1e6;         % centroid MHz
        agg=@(x)[mean(x) std(x)];
        S(si).pk=agg(pkAmp); S(si).tof=agg(tof); S(si).en=agg(en*1e9); S(si).ctr=agg(ctr); %#ok<AGROW>
    end
    metrics = {'표면파 피크진폭 [V]','pk'; '표면파 도달시간 [\mus]','tof';
               '신호 에너지 [nV^2\cdots]','en'; '중심주파수 [MHz]','ctr'};
    f4 = figure('Color','w','Position',[80 80 1000 620]); trytheme(f4);
    tl=tiledlayout(f4,2,2,'TileSpacing','compact','Padding','compact');
    title(tl,'시편 간 표면파 특징 비교  (평균 \pm 표준편차, 11위치)','FontWeight','bold');
    for m=1:4
        ax=nexttile; fld=metrics{m,2};
        mu=[S(1).(fld)(1) S(2).(fld)(1)]; er=[S(1).(fld)(2) S(2).(fld)(2)];
        b=bar(ax,mu,'FaceColor','flat'); b.CData=[sampCol{1};sampCol{2}];
        hold(ax,'on'); errorbar(ax,1:2,mu,er,'k','LineStyle','none','LineWidth',1);
        xticks(ax,1:2); xticklabels(ax,{'sample1','sample2'});
        title(ax,metrics{m,1}); grid(ax,'on'); box(ax,'on');
    end
    save_fig(f4, fullfile(outDir,'ms_fig4_features.png'));

    fprintf('미세조직 분석 figure 4종 저장 완료 -> %s\n', outDir);
end

function trytheme(f)
    try, theme(f,'light'); end
end
function save_fig(f, p)
    exportgraphics(f, p, 'Resolution',150);
    fprintf('saved: %s\n', p);
end
