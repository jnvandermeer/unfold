function test_se
%%


EEGsim = simulate_test_case(3,'noise',1,'basis','posneg','srate',50,'datalength',10*60);
%EEGsim.event({EEGsim.event.type} == "stimulusB") = []
EEGsim.data(2,:) = EEGsim.data(1,:);
cfgDesign = [];


cfgDesign.eventtypes = {'stimulusA'};
cfgDesign.codingschema = 'effects'
cfgDesign.formula   = {'y~1+conditionA'};


uf = uf_designmat(EEGsim,cfgDesign);
uf = uf_timeexpandDesignmat(uf,'timelimits',[-.3 5.5]);
uf = uf_glmfit(uf);
%%
% uf = uf_condense(uf)

se = uf_se(uf,'channel',[1,2]);
figure,errorbar(squeeze(uf.unfold.beta_dc(1,:,:)),se)

%%
se_res0 = uf_se(uf,'channel',[1,2],'restrictResidualToModelled',0);
%%
% test the contrast
contrast = zeros(3,size(uf.unfold.beta_dc,2),size(uf.unfold.beta_dc,3));

% #1 Contrast: second beta between 3 & 4 seconds
contrast(1, uf.unfold.times>3 & uf.unfold.times<4,2) = 1;

% #2 Contrast: second beta between -1 & 1 seconds
contrast(2,uf.unfold.times<1 & uf.unfold.times>-1,2) = 1;

% #3 Contrast: sum of first+second beta after 3s
contrast(3,uf.unfold.times>3,1) = 1;
contrast(3,uf.unfold.times>3,2) = 1;

se = uf_se(uf,'channel',[1],'contrast',contrast);


