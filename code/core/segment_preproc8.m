function segment_preproc8(V,write_tc,write_bf,write_df,dir_out,modality,opt)
N = numel(V);

obj          = struct;
obj.bb       = NaN(2,3);
obj.vox      = NaN;
obj.affreg   = 'mni';
obj.reg      = [0 0.001 0.5 0.05 0.2]*opt.reg_def_mult;
obj.fwhm     = 1;
obj.samp     = opt.samp;
obj.biasfwhm = 60*ones(1,N);
obj.mrf      = opt.mrf;    
obj.cleanup  = opt.cleanup;

if strcmpi(modality,'CT')
    obj.biasreg  = 10; 
elseif strcmpi(modality,'MRI')
    obj.biasreg  = 1e-3*(1/5)*ones(1,N);    
end

tpmname   = fullfile(spm('dir'),'tpm','TPM.nii');
obj.lkp   = opt.lkp;
obj.tpm   = spm_load_priors8(tpmname);
obj.image = V;

M                       = obj.image(1).mat;
c                       = (obj.image(1).dim+1)/2;
obj.image(1).mat(1:3,4) = -M(1:3,1:3)*c(:);
[Affine1,ll1]           = spm_maff8(obj.image(1),8,(0+1)*16,obj.tpm,[],obj.affreg); % Closer to rigid
Affine1                 = Affine1*(obj.image(1).mat/M);

% Run using the origin from the header
obj.image(1).mat = M;
[Affine2,ll2]    = spm_maff8(obj.image(1),8,(0+1)*16,obj.tpm,[],obj.affreg); % Closer to rigid

% Pick the result with the best fit
if ll1>ll2, obj.Affine  = Affine1; else obj.Affine  = Affine2; end

% Initial affine registration.
obj.Affine = spm_maff8(obj.image(1),4,(obj.fwhm+1)*16,obj.tpm, obj.Affine, obj.affreg); % Closer to rigid
obj.Affine = spm_maff8(obj.image(1),3, obj.fwhm,      obj.tpm, obj.Affine, obj.affreg);    

% Run the actual segmentation
res = spm_preproc8(obj);

% Final iteration, so write out the required data.
spm_preproc_write8(res,write_tc,repmat(write_bf,N,1),write_df,obj.mrf,obj.cleanup,obj.bb,obj.vox,dir_out);
