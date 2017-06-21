clear all;
clc; 
tic;

ERR_SCALE = 10; % inverse of % of packet loss
NUM_TS_PKTS = 5444;
fvid = fopen('vid_out.txt','w+');

%factor = 1;
%for loop on factor 
NUM_ITER = 1; %10;
psnr_factor = zeros(1,NUM_ITER);
obj_det_factor = zeros(1, NUM_ITER);
burst_factor = zeros(1, NUM_ITER);
mu_factor = zeros(1, NUM_ITER);
for num = 1:1:NUM_ITER
    factor = num;
    rep = 1; %20;
    avg_psnr = zeros(1,rep);
    mean_det_prob = zeros(1,rep);

    for i=1:1:rep
        chunkSize = 0;
        burstSize = 0;
        maxChunk = ERR_SCALE*factor;
        maxBurst = 1*factor;
        mu = num+5;
        pivot = 0;
        
        try

            count_I_frames = 0;
            count_BP_frames = 0;
            num_lines = 0;
            badpackets = zeros(1, NUM_TS_PKTS);
            packet_loss = 0;
            pos = ceil(exprnd(mu));
            %display(pos);
            
            fp = fopen('parks_tsframes.txt', 'r+');
            tline = fgetl(fp);

            while (ischar(tline)) 
                num_lines = num_lines + 1;   
                %fprintf('..... Processing packet : %d\n ', num_lines);

                c = strsplit(tline, ',');
                k = str2num(char(c(1))); 
                frame_type = str2num(char(c(2)));
    
                
                fprintf('..... Processing packet : %d ; k =%d ; pivot+pos = %d\n ', num_lines, k, pivot+pos);
                %display(pivot+pos);
                %display(k);
                
                if (k == (pivot+pos))
                    
                    if((frame_type ~= 0) && (frame_type ~= 1))
                        badpackets(k) = 1;
                        packet_loss = packet_loss + 1;
                        fprintf('P packet damaged at TS packet #%d , when mu = %d \n', k,mu);
                    end
                    pivot = pivot+pos;
                    pos = ceil(exprnd(mu));
                    display(pos);
                    tline = fgetl(fp);
                else
                    tline = fgetl(fp);
                end
                
            end

            fclose(fp);

            %%%%%%%%%%%%%% CALCULATE PSNR %%%%%%%%%%%%%%%
            [m_psnr] = parks_psnr(badpackets);

            fprintf(fvid, '\n PSNR for Packet loss (%): %.3f = %.3f \n ', packet_loss/NUM_TS_PKTS, m_psnr);
            avg_psnr(i) = m_psnr;
            
            %%%%%%%%%%% CALCULATE OBJECT DETECTION PROBABILITY %%%%%%%%%%%
            [detection_prob, detTotProb] = detect_object_feature();
            mean_det_prob(i) = detection_prob;
        
            fprintf(fvid, '\t Avg. object detection probability for Packet loss (%): %.3f = %.3f  \n', packet_loss/NUM_TS_PKTS, detection_prob);
            fprintf(fvid, '\t Total object detection probability for Packet loss (%): %.3f = %.3f  \n', packet_loss/NUM_TS_PKTS, detTotProb);


        catch err
            fprintf('\n BAD ITERATION ....... RETRY \n ');
            fprintf(fvid, '\n BAD ITERATION ....... RETRY \n ');
            %exception = MException.last;
            msgString = getReport(err, 'extended');
            fprintf('\n Exception Message: %s \n ', msgString);
            fprintf(fvid, '\n Exception Message: %s \n ', msgString);
        end


        fprintf('\n\n PSNR for Packet loss (%): %.3f = %.3f \n\n ', packet_loss/NUM_TS_PKTS, avg_psnr(i));
        %display(offset);

    end
    
    %fprintf(fvid, '\n PSNR for burstsize %d , for loss percentage = %.3f in several iterations: >>>\n', factor, (1/ERR_SCALE));
    fprintf(fvid, '%d\t', avg_psnr);
    fprintf(fvid, '\n');
    
    psnr_factor(num) = mean(avg_psnr);
    obj_det_factor(num) = mean(mean_det_prob);
    burst_factor(num) = num;
end

%{
fprintf(fvid, '\n **************** END OF ITERATIONS FOR PACKET LOSS PERCENT: %.3f ***************\n', (1/ERR_SCALE));
fprintf(fvid, '\n Avg. PSNR for different exponential distribution for loss percentage = %.3f >>>\n', (1/ERR_SCALE));
fprintf(fvid, '%d\t', mu_factor);
fprintf(fvid, '\n');
fprintf(fvid, '%d\t', psnr_factor);
fprintf(fvid, '\n\n');
fprintf(fvid, '\n Avg. Detection Probability for different exponential distribution for loss percentage = %.3f >>>\n', (1/ERR_SCALE));
fprintf(fvid, '%d\t', mu_factor);
fprintf(fvid, '\n');
fprintf(fvid, '%d\t', obj_det_factor);
fprintf(fvid, '\n');
 %}


figure(1);
hold on;
plot(mu_factor,psnr_factor);
xlabel('mu')
ylabel('Video PSNR');


figure(2);
hold on;
plot(mu, obj_det_factor);
xlabel('mu')
ylabel('Object Detection Probability');

fclose(fvid);


toc;

    