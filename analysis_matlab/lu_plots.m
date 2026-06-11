function lu_plots(allSamples, bscan, featTable, cmp, cfg)
%LU_PLOTS  분석 결과 시각화.
%   (1) 대표 A-scan + 포락선  (2) FFT 스펙트럼 비교
%   (3) STFT 스펙트로그램      (4) B-scan 영상(시편별)
%   (5) 위치별 특징 곡선 + 이상치 표시
%
%   lu_plots(allSamples, bscan, featTable, cmp, cfg)

    samples = cfg.samples;
    saveFig = @(fig, name) localSave(fig, name, cfg);

    %% (1) 대표 A-scan + 포락선 -------------------------------------------
    f1 = figure('Name','A-scan & Envelope','Color','w','Position',[80 80 1000 600]);
    for si = 1:numel(samples)
        sname = samples{si};
        if ~isfield(allSamples, sname) || isempty(allSamples.(sname)), continue; end
        d = allSamples.(sname)(1);   % 첫 위치
        subplot(numel(samples),1,si);
        plot(d.t*1e6, d.vp, 'Color',[0.2 0.4 0.8]); hold on;
        plot(d.t*1e6, d.env, 'r', 'LineWidth',1.0);
        xline(cfg.triggerTime*1e6, '--k', 'trigger');
        xlabel('time [\mus]'); ylabel('amp [V]');
        title(sprintf('%s — pos #0 A-scan (filtered) + Hilbert envelope', sname),...
              'Interpreter','none');
        legend({'filtered','envelope'},'Location','northeast'); grid on;
        xlim([min(d.t) max(d.t)]*1e6);
    end
    saveFig(f1, 'fig1_ascan_envelope');

    %% (2) FFT 스펙트럼 비교 (위치 0 기준) --------------------------------
    f2 = figure('Name','FFT Spectrum','Color','w','Position',[100 100 900 500]);
    hold on; leg = {};
    for si = 1:numel(samples)
        sname = samples{si};
        if ~isfield(allSamples, sname) || isempty(allSamples.(sname)), continue; end
        d  = allSamples.(sname)(1);
        fr = lu_freq_analysis(d.t, d.vp, cfg);
        plot(fr.f*1e-6, fr.P, 'LineWidth',1.2);
        leg{end+1} = sname; %#ok<AGROW>
    end
    xlabel('frequency [MHz]'); ylabel('|amplitude|');
    title('Single-sided FFT spectrum (pos #0)'); grid on;
    xlim([0 cfg.freq.fAxisMax*1e-6]); legend(leg,'Interpreter','none');
    saveFig(f2, 'fig2_fft_spectrum');

    %% (3) STFT 스펙트로그램 (시편별 pos 0) -------------------------------
    f3 = figure('Name','Spectrogram','Color','w','Position',[120 120 1100 500]);
    for si = 1:numel(samples)
        sname = samples{si};
        if ~isfield(allSamples, sname) || isempty(allSamples.(sname)), continue; end
        d  = allSamples.(sname)(1);
        fr = lu_freq_analysis(d.t, d.vp, cfg);
        if isfield(fr,'stft')
            subplot(1,numel(samples),si);
            S = 20*log10(fr.stft.S + eps);
            imagesc(fr.stft.tS*1e6, fr.stft.fS*1e-6, S);
            axis xy; ylim([0 cfg.freq.fAxisMax*1e-6]);
            xlabel('time [\mus]'); ylabel('freq [MHz]');
            title(sprintf('%s STFT [dB]', sname),'Interpreter','none');
            colorbar; colormap(gca, 'turbo');
        end
    end
    saveFig(f3, 'fig3_spectrogram');

    %% (4) B-scan 영상 ----------------------------------------------------
    f4 = figure('Name','B-scan','Color','w','Position',[140 140 1100 600]);
    for si = 1:numel(samples)
        sname = samples{si};
        if ~isfield(bscan, sname), continue; end
        B = bscan.(sname);
        subplot(1,numel(samples),si);
        % 포락선 B-scan (결함 에코 가시성↑). 위치축은 인덱스로 그려도 됨.
        imagesc(0:numel(B.pos)-1, B.t*1e6, B.imgEnv);
        axis xy; xlabel('scan position index'); ylabel('time [\mus]');
        title(sprintf('%s B-scan (envelope)', sname),'Interpreter','none');
        colorbar; colormap(gca, 'hot');
    end
    saveFig(f4, 'fig4_bscan');

    %% (5) 위치별 특징 곡선 + 이상치 --------------------------------------
    metricsToPlot = {'peakAmp','energy','tofFirst','peakFreq'};
    metricsToPlot = metricsToPlot(ismember(metricsToPlot, featTable.Properties.VariableNames));
    f5 = figure('Name','Feature vs position','Color','w','Position',[160 160 1100 700]);
    T = cmp.table;
    for mi = 1:numel(metricsToPlot)
        subplot(2,2,mi); hold on;
        for si = 1:numel(samples)
            sel = strcmp(T.sample, samples{si});
            x = T.index(sel); y = T.(metricsToPlot{mi})(sel);
            plot(x, y, '-o', 'LineWidth',1.2, 'DisplayName', samples{si});
            % 이상치 강조
            an = sel & T.anomaly;
            if any(an)
                plot(T.index(an), T.(metricsToPlot{mi})(an), 'r*', ...
                     'MarkerSize',12, 'HandleVisibility','off');
            end
        end
        xlabel('scan position index'); ylabel(metricsToPlot{mi},'Interpreter','none');
        title([metricsToPlot{mi} '  (red * = anomaly)'],'Interpreter','none');
        grid on; legend('Interpreter','none','Location','best');
    end
    saveFig(f5, 'fig5_features');
end

function localSave(fig, name, cfg)
    if cfg.out.savePlots
        try
            exportgraphics(fig, fullfile(cfg.out.dir, [name '.' cfg.out.plotFormat]), ...
                           'Resolution', 150);
        catch
            saveas(fig, fullfile(cfg.out.dir, [name '.' cfg.out.plotFormat]));
        end
    end
end
