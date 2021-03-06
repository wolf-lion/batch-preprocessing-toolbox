function [job,holly] = preproc_default(job,test_level)
if nargin<2, test_level = 0; end

if isstring(job) || ischar(job)
    % Parameters are in a JSON-file
    job = spm_jsonread(job);
end

% General parameters
%----------------------------------------------------------------------    
if ~isfield(job,'S')
    job.S = Inf;
elseif isempty(job.S)
    job.S = Inf;
elseif strcmpi(job.S,'inf')
    job.S = Inf;
end    
if test_level==1
    job.S = min(1,job.S); 
elseif test_level==2
    job.S = min(8,job.S); 
elseif test_level==3
    job.S = min(16,job.S); 
end     
if ~isfield(job,'dir_preproc')
    error('~isfield(pars,''dir_preproc'')')
end    
if ~isfield(job,'write_3d')
    job.write_3d = true;
end
if ~isfield(job,'write_2d')
    job.write_2d = false;
end
if job.write_2d && ~isfield(job,'dir_2d')
    error('~isfield(pars,''dir_2d'')')
elseif ~isfield(job,'dir_2d')
    job.dir_2d = '';
end   
if ~isfield(job,'axis_2d')
    job.axis_2d = 3;
end    
if ~isfield(job,'channel')
    job.channel = {};
end 

% Preprocessing specific
if ~isfield(job,'preproc')
    job.preproc = struct;
end
if ~isfield(job.preproc,'tol_dist')
    job.preproc.tol_dist = 4;
end
if ~isfield(job.preproc,'tol_vx')
    job.preproc.tol_vx = 5;
end
if ~isfield(job.preproc,'reset_origin')
    job.preproc.reset_origin = false;
end
if ~isfield(job.preproc,'do_coreg')
    job.preproc.do_coreg = false;
end
if ~isfield(job.preproc,'do_reslice')
    job.preproc.do_reslice = false;
end    
if ~isfield(job.preproc,'do_ds_inplane')
    job.preproc.do_ds_inplane = false;
end    
if ~isfield(job.preproc,'do_ds_throughplane')
    job.preproc.do_ds_throughplane = false;
end    
if ~isfield(job.preproc,'do_realign2mni')
    job.preproc.do_realign2mni = false;
end
if ~isfield(job.preproc,'do_crop')
    job.preproc.do_crop = false;
end
if ~isfield(job.preproc,'do_rem_neck')
    job.preproc.do_rem_neck = false;
end
if ~isfield(job.preproc,'do_superres')
    job.preproc.do_superres = false;
end    
if ~isfield(job.preproc,'do_denoise')
    job.preproc.do_denoise = false;
end    
if ~isfield(job.preproc,'deg_2d')
    job.preproc.deg_2d = 0;
end
if ~isfield(job.preproc,'do_normalise_intensities')
    job.preproc.do_normalise_intensities = false;
end 
if ~isfield(job.preproc,'do_bf_correct')
    job.preproc.do_bf_correct = false;        
end    
if ~isfield(job.preproc,'do_skull_strip')
    job.preproc.do_skull_strip = false;
end
if ~isfield(job.preproc,'part_labels')
    job.preproc.part_labels = {};
end
if ~isfield(job.preproc,'reslice2channel')
    job.preproc.reslice2channel = '';
end
if ~isfield(job.preproc,'reslice_labels')
    job.preproc.reslice_labels = false;
end
if ~isfield(job.preproc,'mc_denoise')
    job.preproc.mc_denoise = false;
end
if ~isfield(job.preproc,'mc_superres')
    job.preproc.mc_superres = true;
end
if ~isfield(job.preproc,'deg_res')
    job.preproc.deg_res = 1;
end
if ~isfield(job.preproc,'deg_ro')
    job.preproc.deg_ro = 1;
end
if ~isfield(job.preproc,'mtv_workers')
    job.preproc.mtv_workers = 0;
end
if ~isfield(job.preproc,'den_after_vx')
    job.preproc.den_after_vx = false;
end

% Resize
if ~isfield(job.preproc,'resize')
    job.preproc.resize = struct;
end
if ~isfield(job.preproc.resize,'do')
    job.preproc.resize.do = false;
end
if ~isfield(job.preproc.resize,'deg')
    job.preproc.resize.deg = 4;
end
if ~isfield(job.preproc.resize,'vx')
    job.preproc.resize.vx = [];
end
if ~isfield(job.preproc.resize,'keep_neck')
    job.preproc.resize.keep_neck = true;
end
if ~isfield(job.preproc,'vx')
    job.preproc.vx = [];
end

% Labels
if ~isfield(job.preproc,'labels')
    job.preproc.labels = struct;
end
if ~isfield(job.preproc.labels,'part')
    job.preproc.labels.part = [];
end
if ~isfield(job.preproc.labels,'ref')
    job.preproc.labels.ref = '';
end

% Segmentation specific
if ~isfield(job,'segment')
    job.segment = struct;
end
if ~isfield(job.segment,'do')
    job.segment.do = false;
end
if ~isfield(job.segment,'tc')
    job.segment.tc = false(6,4);
end
if ~isfield(job.segment,'df')
    job.segment.df = [false false false];
end
if ~isfield(job.segment,'bf')
    job.segment.bf = [false false];
end
if ~isfield(job.segment,'lkp')
    job.segment.lkp = [1 1 2 2 3 3 4 4 5 5 5 6 6];
end
if ~isfield(job.segment,'reg_def_mult')
    job.segment.reg_def_mult = 0.1;
end
if ~isfield(job.segment,'cleanup')
    job.segment.cleanup = true;
end
if ~isfield(job.segment,'mrf')
    job.segment.mrf = 2;
end
if ~isfield(job.segment,'samp')
    job.segment.samp = 3;
end

if nargout > 1
    % Holly stuff
    %----------------------------------------------------------------------
    if ~isfield(job,'holly')
        holly = struct;
    else
        holly = job.holly;
    end

    if     test_level==1, holly.mode = 'for';
    elseif test_level==2, holly.mode = 'parfor';
    end

    holly = distribute_default(holly);

    if isfield(holly,'translate') && size(holly.translate,1) > 1   
        holly.translate = holly.translate';    
    end
end
%==========================================================================