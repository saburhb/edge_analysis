function [] = vid_corrupt_extended(mu_val)

    %%%%% The programs generates a random number k and drops every kth packet
    %%%%%% in the video. The output of the corrupted video is written in
    %%%%%% output.mp4; 

    %clear all;
    %clc; 
    tic;

    NUM_TS_PKTS = 2031094;
    bytesPerPacket = 188;
    txt_file = 'campus_vid_ext_out.txt';
    fvid = fopen(txt_file,'w+');

    badpackets = zeros(1, NUM_TS_PKTS);
    packet_loss = 0;

    frame_type_list = load('extended_type.txt');
    frame_seq_list = load('extended_map.txt');

    %mu = 20; %%take mu as input
    mu = mu_val;
    pos = 10;

    while (pos < NUM_TS_PKTS)

        pos = pos + ceil(exprnd(mu));
        badpackets(pos) = 1;
        packet_loss = packet_loss + 1;
    end

    delete('extended_vid_copied.ts'); %% Copy a version to corrupt, keeps original video parks.ts unchanged
    copyfile('extended_vid.ts', 'extended_vid_copied.ts', 'f');


    %%%%%%%%%%%%%%%%%%%%% COURRUPT RECVD VIDEO FILE %%%%%%%%%%%%%%%%%%%%%%
    fp = fopen('extended_vid_copied.ts', 'rb+', 'n');

    for index=1:NUM_TS_PKTS
        if (badpackets(1,index) == 1) %It indicates a bad packet offset = (index-1)*bytesPerPacket;
            % READ before overwrite
            offset = (index-1)*bytesPerPacket;
            fseek(fp, offset, 'bof');
            data=fread(fp, bytesPerPacket);
            overwrite=repmat(0,bytesPerPacket,1);
            fseek(fp, offset, 'bof');
            fwrite(fp, data .* overwrite);

        end
    end
    fclose(fp);
    fprintf('\n RCVD FILE CORRUPTION DONE \n');


    srcVid='extended_vid.ts';
    rcvVid='extended_vid_copied.ts';

    ffcmd = 'ffmpeg'; %% change this path as per config

    sExe = sprintf('%s -i %s -i %s -r 25 -filter_complex "psnr" "output_video.mp4" -y 2>&1', ffcmd, rcvVid, srcVid);
    s2Exe = sprintf('%s | grep PSNR | awk ''{print $8}'' | awk -F: ''{print $2}'' ' , sExe);
    [status,cmdout] = system(s2Exe);
    psnrmean = str2num(cmdout);
    display(psnrmean);


    %%%% STATISTICS %%%%
    fprintf(fvid, '%s; %s; %s\n', 'TS packet No.', 'Frame Number', 'Frame_type');
    for index=1:NUM_TS_PKTS
        if (badpackets(1,index) == 1)
            fprintf(fvid, '%d; %d; %d\n',index, frame_seq_list(index), frame_type_list(index));
        end
    end

    %%%% Move results to specific folder with corresponding mu %%%%
    folder_name = sprintf('results_extended_mu_%d', mu);
    if exist(folder_name, 'dir')
        rmdir(folder_name, 's');
        %rehash();
    end
    mkdir(folder_name);

    new_vid = sprintf('%s/extended_corrupted_mu_%d.mp4', folder_name,mu);
    copyfile('output_video.mp4', new_vid, 'f');
    new_data = sprintf('%s/extended_corrupted_mu_%d.csv', folder_name,mu);
    copyfile(txt_file, new_data, 'f');

    fclose(fvid);
    toc;

end
    