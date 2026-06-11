% 스모크 테스트: 파이프라인 함수들이 오류 없이 도는지 빠르게 검증
% (2개 위치 × 2 시편, 다운샘플로 속도 ↑)
addpath(fileparts(mfilename('fullpath')));
cfg = lu_config();
cfg.indexRange = 0:1;      % 위치 2개만
cfg.pre.decim  = 5;        % 1MS -> 200k 로 축소
cfg.freq.doSTFT = true;
cfg.out.savePlots = false; cfg.out.saveMat = false;

rows = {};
for si = 1:numel(cfg.samples)
    sname = cfg.samples{si};
    for k = 1:numel(cfg.indexRange)
        idx = cfg.indexRange(k);
        fpath = fullfile(cfg.dataDir, sprintf('%s--%s--%05d.dat', cfg.channelPrefix, sname, idx));
        [t,v,info] = lu_load_dat(fpath, cfg);
        [vp,pp] = lu_preprocess(t,v,cfg);
        ft = lu_time_analysis(t,vp,cfg);
        fr = lu_freq_analysis(t,vp,cfg);
        fprintf('%s pos%d: fs=%.3gGHz N=%d SNR=%.1fdB ToF=%.2fus fpk=%.1fMHz energy=%.3g\n',...
            sname, idx, info.fs/1e9, info.N, pp.snr_dB, 1e6*ft.tofFirst, 1e-6*fr.peakFreq, ft.energy);
        rows(end+1,:) = {sname, idx, idx*cfg.scanPitch, ft.tofFirst, ft.peakAmp, ...
            ft.energy, ft.rms, pp.snr_dB, fr.peakFreq, fr.centroid, fr.bw, ft.depth};
    end
end
featTable = cell2table(rows,'VariableNames',{'sample','index','pos','tofFirst',...
    'peakAmp','energy','rms','snr_dB','peakFreq','centroid','bw','depth'});
cmp = lu_compare(featTable, cfg);
disp(cmp.summary);
fprintf('SMOKE TEST OK\n');
