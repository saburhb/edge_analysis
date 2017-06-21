clear; clc;

NUM_PKTS=21416;
NUM_FRAMES=372;
B=20; %Average length of successive error
%e=0.01; %probability of error 
e = 0.3;
fileID = fopen('exp.txt','w+');
%fip = fopen('input.txt','w+');

%%%%%%%% Load Frame Seq and type%%%%%%%%
frame_type_list = load('campus_frame_type.txt');
frame_seq_list = load('campus_frame_seq.txt');

%%%%%%%% Each Frame contains how many packets %%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
frame_to_packets=zeros(1,NUM_FRAMES);
prv=0;
cur=0;
for i=1:1:NUM_PKTS
    cur=frame_seq_list(i);
    if(cur==0)
        continue;
    end
    if(cur > prv)
        if(cur > 1)
            frame_to_packets(prv) = pkt_cnt;
        end
        prv = cur;
        pkt_cnt = 1;
        
    else
        pkt_cnt = pkt_cnt + 1;
    end
end
frame_to_packets(cur) = pkt_cnt;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%while (e <= 0.1)

    num_repeat=100;
    max_mserr_list=zeros(1,num_repeat);
    avg_mserr_list=zeros(1,num_repeat);
    avg_score_per_frame=zeros(1,NUM_FRAMES);
    frames_data=zeros(1,NUM_FRAMES);
    avg_mean_vid_score = 0;

    %%%%% Repeat exp for a fixed B and e %%%%%%%%%%% 
    k=1;    
    
    while k <= num_repeat
        bad_iteration=0;
        try
            %%%%%%%%%%%%%%%%%
            filename='input_test';
            fn=sprintf('%s_%d.txt',filename, k);
            fip=fopen(fn, 'w');
            trans_mat=zeros(2);
            packet_states=zeros(1,NUM_PKTS);
            bad_pkt_index=zeros(1,NUM_PKTS);
            
            single_pkt_trace=zeros(7,NUM_FRAMES);
            score_per_frame=zeros(1,NUM_FRAMES);
            mean_vid_score = 0;

            %Define transition Probabilty Matrix
            trans_mat(1,1) = (B -(B*e)-e)/(B - (B*e)) ; 
            trans_mat(1,2) = e/(B - (B*e)) ;
            trans_mat(2,1) = 1/B;
            trans_mat(2,2) = (B-1)/B;

            display(trans_mat);

            p00=trans_mat(1,1);
            p01=trans_mat(1,2);
            p10=trans_mat(2,1);
            p11=trans_mat(2,2);

            % Define Initial state based on the steady state probability of error
            r=rand();
            if(r < e)
                new_state=1;
            else
                new_state=0;
            end
            packet_states(1,4) = new_state;
            old_state=new_state;

            prob_err=0;
            
            prev_frame = 1;
            curr_frame = 1;
            pkt_pos_in_curr_frame = 0;
            
            %%%%%%%%% Run the Markov Chain %%%%%%%%%%
            for i=5:NUM_PKTS    
                r=rand();

                if(old_state == 0)
                    if(r < p01)
                        new_state=1;
                    else
                        new_state=0;
                    end
                else
                    if(r < p10)
                        new_state=0;
                    else
                        new_state=1;
                    end
                end

                packet_states(1,i) = new_state;
                old_state = new_state;
                
                curr_frame = frame_seq_list(i);
                num_pkts_curr_frame = frame_to_packets(curr_frame);
                
                if(curr_frame == prev_frame)
                    pkt_pos_in_curr_frame = pkt_pos_in_curr_frame + 1;                 
                else
                    pkt_pos_in_curr_frame = 1;
                    prev_frame = curr_frame;
                end
                
                if(new_state == 1)
                    t=curr_frame;
                    if((pkt_pos_in_curr_frame/num_pkts_curr_frame) < 0.2)
                        single_pkt_trace(1,t) = single_pkt_trace(1,t) + 1;
                    elseif((pkt_pos_in_curr_frame/num_pkts_curr_frame) < 0.4)
                        single_pkt_trace(2,t) = single_pkt_trace(2,t) + 1;
                    elseif((pkt_pos_in_curr_frame/num_pkts_curr_frame) < 0.6)
                        single_pkt_trace(3,t) = single_pkt_trace(3,t) + 1;
                    elseif((pkt_pos_in_curr_frame/num_pkts_curr_frame) < 0.8)
                        single_pkt_trace(4,t) = single_pkt_trace(4,t) + 1;
                    else
                        single_pkt_trace(5,t) = single_pkt_trace(5,t) + 1;
                    end
                end
                
            end

            %display(packet_states);
            
            %%%%%%%%%%%%% Write input file for packet trace %%%%%%%%%
            for j=1:1:NUM_FRAMES
                frame_type = frame_type_list(j);
                total_loss = 0;
                str1 = '1.2';
                for p=1:1:5
                    total_loss = total_loss + single_pkt_trace(p,j);
                    if(single_pkt_trace(p,j) > 0)
                       % if(length(str1)==0)
                           % str2 = sprintf('%d:%d',p-1,single_pkt_trace(p,j));
                        %else
                            str2 = sprintf(' %d:%d',p-1,single_pkt_trace(p,j));
                        %end
                        str1 = strcat(str1, str2);
                    end
                end
                str3 = sprintf('%d:%d',5,frame_type);
                str4 = sprintf('%d:%d',6,total_loss);
                if(total_loss == 0)
                    if(j>=4)
                        fprintf(fip, '%s %s\n', str1, str3);
                    end
                else
                    if(j>=4)
                        fprintf(fip, '%s %s %s\n', str1, str3, str4);
                    end
                end
            end
            
            fclose(fip);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %%%% Feed the bad packets list to corrupt packets in stream %%%%%

            bytesPerPacket=188;
            
            %{
            delete('campus_copied.ts'); %% Copy a version to corrupt, keeps original video parks.ts unchanged
            copyfile('uci_campus1.ts', 'campus_copied.ts', 'f');
            
            %%%%%%%%%%%%%%%%%%%%% COURRUPT RECVD VIDEO FILE %%%%%%%%%%%%%%%%%%%%%%
            fp = fopen('campus_copied.ts', 'rb+', 'n');

            for index=1:NUM_PKTS
                if (packet_states(1,index) == 1) %It indicates a bad packet offset = (index-1)*bytesPerPacket;
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
    %}
            
            
            %%%%%%% Feed input to SVM for scoring frame by frame %%%%%%%%
            predict='/home/sbaidya/libsvm/svm-predict';
            in_file=fn;
            model='/home/sbaidya/libsvm/input.txt.model';
            out_file='out.txt';
            sExe=sprintf('%s %s %s %s', predict, in_file, model, out_file);
            
            [status,cmdout] = system(sExe);
            score_per_frame=load(out_file);
            mean_vid_score=mean(score_per_frame);
                       
            %%%%%% Update cumulative average %%%%%%%%
            for q=1:1:(NUM_FRAMES-3)
               avg_score_per_frame(q) = ((k-1)*avg_score_per_frame(q) + score_per_frame(q))/k;
               frames_data(q) = q;
            end
            avg_mean_vid_score = ((k-1)*avg_mean_vid_score + mean_vid_score)/k;
            

            k=k+1;
        catch err
            bad_iteration=k;
            warning('Something happened');
            fprintf('\n Bad Iteration : %d \n', bad_iteration);
            msgString = getReport(err, 'extended');
            fprintf('\n Exception Message: %s \n ', msgString);
        end

         %save('avg_score_frames.mat', avg_score_per_frame);
        
        %%%%%%%Plot for a fixed epsilon %%%%%%%%%%%
        %plot(frames_data, avg_score_per_frame);
        
        
    end %%% end while repeat k times for a given B

    %display(cumulative_mserr);
    save('avg_score_frames.mat', 'avg_score_per_frame');
    
    fout_perframe=fopen('out_per_frame.txt', 'w');
    fout_vid=fopen('out_vid.txt', 'w');
    
    for m=1:1:NUM_FRAMES-3
        fprintf(fout_perframe, '%d\n',avg_score_per_frame(m));
    end
    fprintf(fout_vid, '%d\n', avg_mean_vid_score');
    fclose(fout_perframe);
    fclose(fout_vid);
    
    e = e + 0.01;
    
%end %% for different e

fclose(fileID);

