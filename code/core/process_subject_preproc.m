function obj = process_subject_preproc(obj) 

% Make copies into obj.dir_preproc (in order to not modify the original
% data)
%--------------------------------------------------------------------------
fname = obj.scans{1}{1}.fname;
dir0  = fileparts(fname);
dir0  = strsplit(dir0,filesep);
dir0  = fullfile(obj.dir_preproc,dir0{end - 2});
mkdir(dir0);     

dir_scans = fullfile(dir0,'scans');
mkdir(dir_scans);     

dir_labels = fullfile(dir0,'labels');
mkdir(dir_labels);        

% Copy scans
N = numel(obj.scans);
for n=1:N
    I = numel(obj.scans{n});
    for i=1:I
        fname = obj.scans{n}{i}.fname;
        dir1  = fileparts(fname);
        dir1  = strsplit(dir1,filesep);
        dir1  = fullfile(dir_scans,dir1{end});
        mkdir(dir1);  
        
        copyfile(fname,dir1);
        [~,nam,ext]           = fileparts(fname);
        nfname                = fullfile(dir1,[nam ext]);
        obj.scans{n}{i}.fname = nfname;
    end
end        

if ~isempty(obj.labels)
    % Copy labels        
    copyfile(obj.labels.fname,dir_labels);
    [~,nam,ext]      = fileparts(obj.labels.fname);
    nfname           = fullfile(dir_labels,[nam ext]);
    obj.labels.fname = nfname;
end

% Rigidly realign to MNI space
%--------------------------------------------------------------------------
if obj.preproc.do_realign2mni    
    
    if strcmp(obj.modality,'CT')
        % Reset the origin (only if CT)
        V  = obj.scans{1}{1}; 
        vx = spm_misc('vxsize',V.mat);
        
        spm_impreproc('nm_reorient',V.fname,vx,1,'ro_');    
    
        [pth,nam,ext]   = fileparts(V.fname);
        delete(V.fname);
        nfname          = fullfile(pth,['ro_' nam ext]);
        obj.scans{1}{1} = spm_vol(nfname);
        
        V               = obj.scans{1}{1}; 
        spm_impreproc('reset_origin',V.fname);
        obj.scans{1}{1} = spm_vol(nfname);
        
        if ~isempty(obj.labels)
            V  = obj.labels;
            vx = spm_misc('vxsize',V.mat);
            
            spm_impreproc('nm_reorient',V.fname,vx,1,'ro_');    
    
            [pth,nam,ext] = fileparts(V.fname);
            delete(V.fname);
            nfname        = fullfile(pth,['ro_' nam ext]);
            obj.labels    = spm_vol(nfname);

            V = obj.labels; 
            spm_impreproc('reset_origin',V.fname);
            obj.labels = spm_vol(nfname);            
        end
    end
    
    % Just align the first image  
    V               = obj.scans{1}{1}; 
    M               = spm_impreproc('rigid_align',V.fname);                     
    obj.scans{1}{1} = spm_vol(V.fname);                 
    
    % Then change orientation matrices of the rest accordingly
    for n=1:N
        I = numel(obj.scans{n});
        for i=1:I            
            if n==1 && i==1
                continue;
            end
            
            V = obj.scans{n}{i};
            spm_get_space(V.fname,M\V.mat);  
            obj.scans{n}{i} = spm_vol(V.fname);  
        end
    end    
    
    if ~isempty(obj.labels)
        V = obj.labels;
        spm_get_space(V.fname,M\V.mat); 
        obj.labels = spm_vol(V.fname); 
    end
end               

% Remove image data outside of the head (air..)
%--------------------------------------------------------------------------
if obj.preproc.do_crop
    for n=1:N
        I = numel(obj.scans{n});
        for i=1:I
            V = obj.scans{n}{i};
            
            [~,bb] = spm_impreproc('atlas_crop',V.fname,'cr_',obj.preproc.do_rem_neck); 

            [pth,nam,ext]   = fileparts(V.fname);
            delete(V.fname);
            nfname          = fullfile(pth,['cr_' nam ext]);
            V               = spm_vol(nfname);                                             
            obj.scans{n}{i} = V;
        end
    end    
    
    if ~isempty(obj.labels)
        V = obj.labels;
       
        spm_impreproc('subvol',V,bb,'cr_'); 
       
        [pth,nam,ext] = fileparts(V.fname);
        delete(V.fname);
        nfname        = fullfile(pth,['cr_' nam ext]);
        V             = spm_vol(nfname);                                  
        obj.labels    = V;
    end    
end  

% Co-register images
%--------------------------------------------------------------------------
if obj.preproc.do_coreg && N>1
    cnt = 1;
    for n=1:N
        I = numel(obj.scans{n});
        for i=1:I
            V(cnt) = obj.scans{n}{i};            
            cnt    = cnt + 1;
        end
    end  
    
    V = spm_impreproc('coreg',V);
    
    cnt = 1;
    for n=1:N
        I = numel(obj.scans{n});
        for i=1:I
            obj.scans{n}{i} = V(cnt);            
            cnt             = cnt + 1;
        end
    end  
end

% Denoise images
%--------------------------------------------------------------------------
if obj.preproc.do_denoise
    obj = spm_denoise(obj);
end

% Create equally sized images by super-resolution
%--------------------------------------------------------------------------
if obj.preproc.do_superres    
    obj = spm_superres(obj);
end                  

% Reslice to size of image with largest FOV
%--------------------------------------------------------------------------
if obj.preproc.do_reslice && N>1        
    for n=1:N
        V(n) = obj.scans{n}{1};   
    end  
    
    V = spm_impreproc('reslice',V);    
    
    for n=1:N
        obj.scans{n}{1} = V(n);
    end  
end

% Change voxel size of image(s)
%--------------------------------------------------------------------------
if ~isempty(obj.preproc.vx)
    for n=1:N
        V = obj.scans{n}{1};   
    
        spm_impreproc('nm_reorient',V.fname,obj.preproc.vx,1,'vx_');    
    
        [pth,nam,ext]   = fileparts(V.fname);
        delete(V.fname);
        nfname          = fullfile(pth,['vx_' nam ext]);
        obj.scans{n}{1} = spm_vol(nfname);
    end  
    
    if ~isempty(obj.labels)
        V = obj.labels;
       
        spm_impreproc('nm_reorient',V.fname,obj.preproc.vx,0,'vx_');    
    
        [pth,nam,ext]   = fileparts(V.fname);
        delete(V.fname);
        nfname          = fullfile(pth,['vx_' nam ext]);
        obj.labels      = spm_vol(nfname);
    end    
end

% Simple normalisation of image intensities
%--------------------------------------------------------------------------
if obj.preproc.normalise_intensities    
    for n=1:N
        V         = obj.scans{n}{1};   
        Nii       = nifti(V.fname);
        img       = single(Nii.dat(:,:,:));
        msk       = spm_misc('msk_modality',img,obj.modality);        
        
        sint = sum(reshape(img(msk),[],1));
        nm   = nnz(msk);        
        scl  = (1024/(sint/nm));
        
        [pth,nam,ext] = fileparts(V.fname);
        nfname        = fullfile(pth,['ni_' nam ext]);

        Nii         = nifti;
        Nii.dat     = file_array(nfname,V.dim,V.dt,0,1,0);
        Nii.mat     = V.mat;
        Nii.mat0    = V.mat;
        Nii.descrip = 'norm-int';
        create(Nii);
                   
        Nii.dat(:,:,:) = scl*img;

        obj.scans{n}{1} = spm_vol(nfname);
        delete(V.fname)
    end      
end                  

% Segment and/or bias-field correct and/or skull-strip
%--------------------------------------------------------------------------
if any(any(obj.preproc.write_tc==true) == true) || obj.preproc.do_skull_strip || obj.preproc.do_bf_correct    
    dir_seg = fullfile(dir0,'segmentations');
    mkdir(dir_seg);      
    
    for n=1:N
        V(n) = obj.scans{n}{1};   
    end  
    
    write_tc = obj.preproc.write_tc;
    write_bf = obj.preproc.write_bf;
    write_df = obj.preproc.write_df;
    
    if obj.preproc.do_bf_correct
        write_bf(1,2) = true;
    end
    
    if obj.preproc.do_skull_strip
        write_tc(1:3,1) = true;
    end
    
    segment_subject(V,write_tc,write_bf,write_df,dir_seg,obj.modality);
       
    if obj.preproc.do_bf_correct
        % Replace data with bias-corrected versions
        files = spm_select('FPList',dir_seg,'^m.*\.nii$'); % Get bias-field corrected images
        for n=1:N          
            fname   = obj.scans{n}{1}.fname;                        
            [~,nam] = fileparts(fname);
            for n1=1:N
                [~,nam_bf] = fileparts(files(n1,:));
                if strcmp(nam,nam_bf(2:end))
                    fname_bf = files(n1,:);
                    V_bf     = spm_vol(fname_bf);
                    
                    [pth,nam,ext] = fileparts(fname);
                    nfname        = fullfile(pth,['bf_' nam ext]);

                    Nii         = nifti;
                    Nii.dat     = file_array(nfname,V_bf.dim,V_bf.dt,0,1,0);
                    Nii.mat     = V_bf.mat;
                    Nii.mat0    = V_bf.mat;
                    Nii.descrip = 'bf-corrected';
                    create(Nii);

                    Nii1           = nifti(fname_bf);
                    img            = single(Nii1.dat(:,:,:));                    
                    Nii.dat(:,:,:) = img;
                    
                    obj.scans{n}{1} = spm_vol(nfname);
                    delete(fname)
                end
            end  
        end
    end
    
    if obj.preproc.do_skull_strip
        % Overwrite image data with skull-stripped versions
        files = spm_select('FPList',dir_seg,'^c[1,2,3].*\.nii$');
        V0    = spm_vol(files);
        K     = numel(V0);
        msk   = zeros(V0(1).dim,'single');
        for k=1:K
            Nii  = nifti(V0(k).fname);
            resp = single(Nii.dat(:,:,:)); 
            msk  = msk + resp;
        end
        clear resp
                                               
        for z=1:V0(1).dim(3) % loop over slices
            msk(:,:,z) = imgaussfilt(msk(:,:,z),1);    % Smooth
            msk(:,:,z) = msk(:,:,z)>0.5;               % Threshold
            msk(:,:,z) = imfill(msk(:,:,z),4,'holes'); % Fill holes
        end

        % Mask out voxels based on SPM TPM size
        pth_tpm = fullfile(spm('dir'),'tpm','TPM.nii,');
        V1      = spm_vol(pth_tpm);

        M0  = V0(1).mat;      
        dm0 = V0(1).dim; 
        M1  = V1(1).mat;  
        dm1 = V1(1).dim;

        T = M1\M0; % Get the mapping from M0 to M1

        % Use ndgrid to give an array of voxel indices
        [x0,y0,z0] = ndgrid(single(1:dm0(1)),...
                            single(1:dm0(2)),...
                            single(1:dm0(3)));

        % Transform these indices to the indices that they point to in the reference image
        D = cat(4,T(1,1)*x0 + T(1,2)*y0 + T(1,3)*z0 + T(1,4), ...
                  T(2,1)*x0 + T(2,2)*y0 + T(2,3)*z0 + T(2,4), ...
                  T(3,1)*x0 + T(3,2)*y0 + T(3,3)*z0 + T(3,4));
        clear x0 y0 z0
        
        % Mask according to whether these are < 1 or > than the dimensions of the reference image.        
        msk1 = cell(1,3);
        ix   = [1 1 20];
        for i=1:3
            msk1{i} = D(:,:,:,i) >= ix(i) & D(:,:,:,i) <= dm1(i);
        end
        clear D
        
        % Generate masked image
        for i=1:3
            msk = msk1{i}.*msk;
        end
        clear msk1
        
        if 0
            % For testing skull-stripping
            split = 4;
            dm0   = V0(1).dim;
            nfigs = floor(dm0(3)/split);
            
            F1 = floor(sqrt(nfigs));
            F2 = ceil(nfigs/F1);      
            figure(666); 
            for f=1:nfigs
                subplot(F1,F2,f);            
                imagesc(msk(:,:,split*f)'); colormap(gray); axis off xy image;
            end
            
            figure(667);            
            msk1 = permute(msk,[2 3 1]);
            slice = msk1(:,:,floor(size(msk1,3)/2) + 1);
            subplot(121); imagesc(slice'); colormap(gray); axis off xy;
            
            msk1 = permute(obj.scans{1}{1}.private.dat(:,:,:),[2 3 1]);
            slice = msk1(:,:,floor(size(msk1,3)/2) + 1);
            subplot(122); imagesc(slice',[0 100]); colormap(gray); axis off xy;
        end
        
        for n=1:N
            fname         = obj.scans{n}{1}.fname;  
            [pth,nam,ext] = fileparts(fname);
            nfname        = fullfile(pth,['ss_' nam ext]);

            Nii         = nifti;
            Nii.dat     = file_array(nfname,obj.scans{n}{1}.dim,[16 0],0,1,0);
            Nii.mat     = obj.scans{n}{1}.mat;
            Nii.mat0    = obj.scans{n}{1}.mat;
            Nii.descrip = 'skull-stripped';
            create(Nii);

            Nii1           = nifti(fname);
            img            = single(Nii1.dat(:,:,:));
            img(~msk)      = NaN;  
            Nii.dat(:,:,:) = img;
            
            obj.scans{n}{1} = spm_vol(nfname);
            delete(fname);
        end
    end  
    
    if obj.preproc.make_ml_labels && isempty(obj.labels)
        % Write maximum-likelihoods labels (only if labels are not available)                
        files = spm_select('FPList',dir_seg,'^c.*\.nii$');
        
        if ~isempty(files)
            V0    = spm_vol(files);
            K     = numel(V0);
            img   = zeros([V0(1).dim K],'single');
            for k=1:K
                Nii          = nifti(V0(k).fname);
                img(:,:,:,k) = single(Nii.dat(:,:,:));
            end

            if K<6
                % Less than the default SPM template number of classes requested
                % -> correct ML labels
                img1 = ones(V0(1).dim,'single');
                img1 = img1 - sum(img,4);
                img  = cat(4,img,img1);
                clear img1
            end

            [~,ml_labels] = max(img,[],4);        
            clear img

            fname       = obj.scans{1}{1}.fname;  
            [~,nam,ext] = fileparts(fname);
            nfname      = fullfile(dir_labels,['ml_' nam ext]);

            Nii      = nifti;
            Nii.dat  = file_array(nfname,size(ml_labels),'uint8',0,1/K,0);
            Nii.mat  = V0(1).mat;
            Nii.mat0 = V0(1).mat;
            Nii.descrip = 'ML-labels';
            create(Nii);

            Nii.dat(:,:,:) = ml_labels;
            clear ml_labels

            obj.labels = spm_vol(nfname);
        end
    end
    
    % Clean-up
    if ~any(any(obj.preproc.write_tc==true) == true)
        rmdir(dir_seg,'s');
    end
end         

% Create 2D versions
%--------------------------------------------------------------------------
if obj.preproc.write_2d
    fname = obj.scans{1}{1}.fname;
    dir0  = fileparts(fname);
    dir0  = strsplit(dir0,filesep);
    dir0  = fullfile(obj.dir_preproc_2d,dir0{end - 2});
    mkdir(dir0);     

    dir_scans = fullfile(dir0,'scans');
    mkdir(dir_scans);     

    dir_labels = fullfile(dir0,'labels');
    mkdir(dir_labels);        

    % Of scans    
    N = numel(obj.scans);
    for n=1:N
        I = numel(obj.scans{n});
        for i=1:I
            fname = obj.scans{n}{i}.fname;
            dir1  = fileparts(fname);
            dir1  = strsplit(dir1,filesep);
            dir1  = fullfile(dir_scans,dir1{end});
            mkdir(dir1);  

            copyfile(fname,dir1);
            [~,nam,ext] = fileparts(fname);
            nfname      = fullfile(dir1,[nam ext]);
            
            create_2d_slice(nfname,obj.preproc.axis_2d);
        end
    end        

    if ~isempty(obj.labels)
        % Of labels        
        copyfile(obj.labels.fname,dir_labels);
        [~,nam,ext] = fileparts(obj.labels.fname);
        nfname      = fullfile(dir_labels,[nam ext]);

        create_2d_slice(nfname,obj.preproc.axis_2d);     
    end
    
    if any(any(obj.preproc.write_tc==true) == true)                
        % Of segmentations                 
        dir_seg1 = fullfile(dir0,'segmentations');
        mkdir(dir_seg1);                                   
        
        prefix = {'c','wc','mwc'};
        for i=1:numel(prefix)
            files = spm_select('FPList',dir_seg,['^' prefix{i} '.*\.nii$']);
            
            for i1=1:size(files,1)
                copyfile(files(i1,:),dir_seg1);
                [~,nam,ext] = fileparts(files(i1,:));
                nfname      = fullfile(dir_seg1,[nam ext]);

                create_2d_slice(nfname,obj.preproc.axis_2d);            
            end
        end
    end
end      
%==========================================================================
