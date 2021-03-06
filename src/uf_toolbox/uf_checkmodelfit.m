function r2 = uf_checkmodelfit(EEG,varargin)
% Function to get R2, and partialR2 (in the future possibly AIC/BIC, but
% normally assumption is wrong! Better to use CrossValR2 I guess)
%
% Important: RESIDUALS ARE ONLY CALCULATED WHERE THERE ARE ENTRIES IN
% EEG.UNFOLD.XDC. thus _not_ in pauses/breaks/inbetween trials etc.
%
%Input: EEG should the EEG either before or after uf_glmfit.
%
%Arguments:
% cfg.method (string):   default 'R2'. 
%                       R2: calculates coefficient of determination
%                       partialR2: calculates partial R2
%                           (model_with-model_without predictor) for all
%                           predictors (or if specified in cfg.variablename)
%                       crossValR2: R2 in crossvalidated, folded by
%                                   cfg.fold_event
%                       crossValpartialR2: same as partialR2 with
%                                          CrossValidation
% cfg.fold_event (cell/string):  The field that we can cut the data into
%                       folds without risking any overlap. E.g. this can be
%                       breaks, or if there is no overlap, trials. 
%
% cfg.variablename (cell of strings): Specify the variablename 
%                   (taken from EEG.unfold.variablenames) on which the
%                   partialR2 method should be applied to. 
%
% cfg.channel       : On which channel should the function be run?
%
% DESCRIPTION
cfg = finputcheck(varargin,...
    {'method', 'string',{'R2','partialR2','crossValR2','crossValpartialR2'}, 'R2';
    'fold_event','','',{}; %can be string or cell
    'channel','integer','',[];
    },'mode','ignore');
if(ischar(cfg)); error(cfg);end

if isempty(cfg.channel)
    cfg.channel = 1:size(EEG.data,1);
end
assert(ndims(EEG.data)==2,'EEG.data has to be continuous, i.e. 2 dimensions')
assert(isfield(EEG,'unfold'))
assert(isfield(EEG.unfold,'Xdc'))

% cfg.method = 'crossValR2'
% cfg.method = 'r2'
% cfg.fold_event = 'pause';


switch cfg.method
    case {'crossValR2','crossValpartialR2'}
        
        [train,test]=uf_cv_getFolds(EEG,'fold_event',cfg.fold_event);
        r2 = []; % in case of crossValpartialR2 this is necessary
        
        % for each fold
        for fold = 1:length(train)
            fprintf('Running fold %i',fold)
            % select test & train time-ix
            
            % refit model
            EEGfold = EEG;
            EEGfold.unfold.Xdc = train(fold).Xdc;
            EEGfold = uf_glmfit(EEGfold);
            
            
            switch cfg.method
                case 'crossValpartialR2'
                    % potentially one could implement here a selection of
                    % only some variables. %% enhancement %%
                    
                    r2_fold=  partialR2(EEGfold,EEG.data(:,test(fold).ix),test(fold).Xdc(test(fold).ix,:),varargin);
                    r2_fold.fold = repmat(fold,size(r2_fold,1),1);
                    r2 = [r2;r2_fold];
                    
                    
                case 'crossValR2'
                    r2(:,fold) = calc_r2(EEG.data(cfg.channel,test(fold).ix),test(fold).Xdc(test(fold).ix,:),EEGfold.unfold.beta_dc(cfg.channel,:,:));
                    
                    %  calculate R2
                    
            end
            
        end
        
    case 'partialR2'
        r2 = partialR2(EEG,EEG.data(cfg.channel,:),EEG.unfold.Xdc,varargin);
    case 'R2'
        assert(isfield(EEG.unfold,'beta_dc'),'Please run uf_glmfit first manually to get non-crossvalidated R2')
        
        r2 = calc_r2(EEG.data(cfg.channel,:),EEG.unfold.Xdc,EEG.unfold.beta_dc(cfg.channel,:,:));
    otherwise
        error('not implemented method')
end



% Specify / find Events that can be used for folding
% select one as a test-part
% temporarly blank the test-part of Xdc
% refit the model
% calculate R2
end
function partial_r2_table = partialR2(EEG,testData,testXdc,input)
    cfg = finputcheck(input,...
    {'variablename','cell','',{}; % cell of variablename names {'varnameA','varnameB'}
     'channel','integer',[],1:size(EEG.data,1);
    },'mode','ignore');
if ischar(cfg); error(cfg);end
   

   % r2partial = r2_total - r2_without
    r2_total    = calc_r2(testData,testXdc,      EEG.unfold.beta_dc(cfg.channel,:,:));
    
    % go over each variable in the model
    Xdc_terms2variablenames = EEG.unfold.cols2variablenames(EEG.unfold.Xdc_terms2cols); %which Xdc columns belong to which variables
    varNames = [];partial_r2 = [];
    for k = sort(unique(Xdc_terms2variablenames),'ascend')
        % in case we prespecified which ones to run, check if it is in the
        % list, else skip
        if ~isempty(cfg.variablename)
            current_var = EEG.unfold.variablenames{k};

            if ~any(strcmp(current_var,cfg.variablename))
                fprintf('Skipping partialR2 for variablename:%s\n',current_var)
                continue
            end
            fprintf('Calculating partialR2 for variablename:%s\n',current_var)
        end
        
        EEG_ca = EEG;
        % banish these columns from the design matrix
        % Enhancement: One could try permuting them similar to Mussal [et al]...
        % & Churchland 2019. s
        ix_k = Xdc_terms2variablenames == k;
        EEG_ca.unfold.Xdc(:,ix_k) = [];
        EEG_ca.unfold.Xdc_terms2cols(ix_k) = [];
        %     EEG_ca.unfold.eventtypes(k) = [];
        EEG_ca.unfold.variablenames(k) = [];
        EEG_ca.unfold.cols2eventtypes(k) = [];
        EEG_ca.unfold.cols2variablenames(k) = [];

        EEG_ca = uf_glmfit(EEG_ca,'channel',cfg.channel);

        
        % crossvalidated R2
        testXdc_ca = testXdc;
        testXdc_ca(:,ix_k) = [];
        r2_ca = calc_r2(testData(cfg.channel,:,:),testXdc_ca,EEG_ca.unfold.beta_dc(cfg.channel,:,:));
        
        partial_r2(:,end+1) = r2_total-r2_ca;
        varNames{end+1} = EEG.unfold.variablenames{k};

    end
    partial_r2_table = [];
    for ch = 1:size(partial_r2,1)
    partial_r2_t = table(repmat(ch,size(partial_r2(ch,:)))',varNames',partial_r2(ch,:)','VariableNames',{'channel','variablenames','r2_ca'});
    partial_r2_t.r2_total = repmat(r2_total(ch),size(partial_r2_t,1),1);

     partial_r2_table = [partial_r2_table; partial_r2_t];
    end
end

% What has been modeled at all?
function r2 = calc_r2(data,Xdc,beta)
model_ix = any(Xdc,2);
residuals = (data' - Xdc*beta(:,:)')';

residSS = sum(residuals(:,model_ix).^2,2);
totSS = (sum(model_ix)-1) * var(data(:,model_ix),[],2);
r2 = 1-residSS./totSS;
end