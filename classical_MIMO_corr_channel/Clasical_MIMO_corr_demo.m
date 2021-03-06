%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This program performs testing for the DeepHOTML and HOTML in the following paper
% ``Binary MIMO Detection via Homotopy Optimization and Its Deep Adaptation'' by Mingjie Shao and Wing-Kin Ma
% The demo is for classical MIMO detection with correlated Gaussian channels.
% The demo loads the parameters of successfully trained DeepHOTML network.
% If you have any questions, please contact mjshao@link.cuhk.edu.hk
% Nov. 27, 2020
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
clc

Ntrials=1e2; % no. of Monte Carlo trials
T=100; % no. of symbols per channel use

% MIMO system setting:
% N is the number of transmit antennas, M is the number of receive antennas
% Both N and M are complex-valued dimension. 
% For each case, we load the parameters of DeepHOTML

LayerNo = 20;  % no. of layers of DeepHOTML

setting='80by80';
switch setting
    
    case '40by40'
        N=40;
        M=40;
        % load the parameters from DeepHOTML
        load ('./DeepHOTML_para/DeepHOTML_40by40SNR27_32Layer2038.mat')
        
    case '80by80'
        N=80;
        M=80;
        % load the parameters from DeepHOTML
        load ('./DeepHOTML_para/DeepHOTML_80by80SNR28_34Layer2014.mat')
        
end

% QPSK constellation is used
scenario='QPSK';
switch scenario
    case 'QPSK'
        modulation_order=2;
        P_per=1;
end

q=2^modulation_order;
theta=pi/q;

% SNR range
SNR = 20:2:40;
sigma_snr = sqrt(2*M* N*10 .^ ( - (SNR) / 10 ) );

BER_DeepHOTML=zeros(length(SNR),1);
BER_LB=zeros(length(SNR),1);
BER_HOTML=zeros(length(SNR),1);
BER_ZF=zeros(length(SNR),1);
BER_MMSE=zeros(length(SNR),1);

%% ----------------- Monte Carlo Testing----------------------------
wb=waitbar(0,'plez wait');

% channel coherence matrices
r=0.2;
Rr=zeros(M); % receive channel coherence matrix
for i=1:M
    for j=1:M
        Rr(i,j)=r^(abs(i-j));
    end
end
Rr_sqrt = sqrtm(Rr);

Rt=zeros(N); % transmit channel coherence matrix
for i=1:N
    for j=1:N
        Rt(i,j)=r^(abs(i-j));
    end
end
Rt_sqrt = sqrtm(Rt);

for i_H=1:Ntrials
    fprintf('\n')
    display(['ntrials:' int2str(i_H)]);
    waitbar(i_H/Ntrials,wb);
    
    % generate channels
    H_c =Rr_sqrt* (randn(M,N)+1i*randn(M,N))/sqrt(2)*Rt_sqrt;
    H = [real(H_c) -imag(H_c);
        imag(H_c) real(H_c)];
    HTH = H'*H;
    HHinv=inv(HTH);
    L_f = 2* norm(HTH);
    
    % for each channel, we evaluate T times symbol transmission.
    for t=1:T
        
        n_c=(randn(M,1)+1i*randn(M,1))/sqrt(2);
        % generating symbols
        Databits=round(rand(modulation_order,N));
        symbol_index=bin2dec(char(Databits+48)');
        s_tr=sqrt(2)* pskmod(symbol_index,2^modulation_order,theta);
        l_bit=symbol_decode(s_tr,modulation_order,theta,'BER');
        s_r=[real(s_tr);imag(s_tr)];
        
        %% ---- Testing different SNR ----------
        for snr_index = 1 : length(SNR)
            
            y_c = H_c*s_tr + (sigma_snr(snr_index))*n_c;
            y=[real(y_c);imag(y_c)];
            Hy = H'*y;
            %% -----  DeepHOTML --------------------
            
            tic
            x_DeepHOTML = DeepHOTML(HTH,Hy,y,W1,b1,N,M,LayerNo,beta,omega,gamma,alpha)';
            x_DeepHOTMLcom=x_DeepHOTML(1:N,:)+1i*x_DeepHOTML(N+1:2*N,:);
            T_DeepHOTML=toc;
            %             display(['DeepHOTML time:' num2str(T_DeepHOTML)]);
            %------------- Count BER -----------------------
            Bit_DeepHOTML=symbol_decode(double(x_DeepHOTMLcom),modulation_order,theta,'BER');
            BER_DeepHOTML(snr_index)=BER_DeepHOTML(snr_index)+length(find(Bit_DeepHOTML-l_bit));
            
            %% ----------- HOTML Lagrangian Duality Relaxation  ----------------
            
            x_InHOTML=pinv(H)*y;
            x_InHOTML=max(-P_per,min(P_per,x_InHOTML));
            lambda=0.001;
            tic
            x_HOTML=HOTML(x_InHOTML,HTH,Hy,L_f,P_per,lambda);
            T_HOTML=toc;
            %             display(['HOTML time:' num2str(T_HOTML)]);
            x_HOTMLcom=x_HOTML(1:N,:)+1i*x_HOTML(N+1:2*N,:);
            %------------- Count BER -----------------------
            Bit_HOTML=symbol_decode(x_HOTMLcom,modulation_order,theta,'BER');
            BER_HOTML(snr_index)=BER_HOTML(snr_index)+length(find(Bit_HOTML-l_bit));
            
            %%  ----- ZF -----------------
            x_zf= H\y;
            x_zfcom=x_zf(1:N,:)+1i*x_zf(N+1:2*N,:);
            %------------- Count BER -----------------------
            Bit_zf=symbol_decode(x_zfcom,modulation_order,theta,'BER');
            BER_ZF(snr_index)=BER_ZF(snr_index)+length(find(Bit_zf-l_bit));
            
            %% ------  MMSE--------------
            x_MMSE= (H'*H+ (sigma_snr(snr_index).^2)*eye(2*N)/2)\(H'*y);
            x_MMSEcom=x_MMSE(1:N,:)+1i*x_MMSE(N+1:2*N,:);
            %------------- Count BER -----------------------
            Bit_MMSE=symbol_decode(x_MMSEcom,modulation_order,theta,'BER');
            BER_MMSE(snr_index)=BER_MMSE(snr_index)+length(find(Bit_MMSE-l_bit));
            
            %% ----- No-inteference lower bound----
            x_LB= NoInterference(H_c,s_tr,(sigma_snr(snr_index))*n_c);
            %------------- Count BER -----------------------
            Bit_LB=symbol_decode(x_LB,modulation_order,theta,'BER');
            BER_LB(snr_index)=BER_LB(snr_index)+length(find(Bit_LB-l_bit));
            
        end
    end
    
end
close(wb)

%% show BER results

%----  DeepHOTML-----------
BER_DeepHOTML=BER_DeepHOTML/(T*Ntrials*N*modulation_order);
%---- HOTML  ----------
BER_HOTML=BER_HOTML/(T*Ntrials*N*modulation_order);
%---- no interference lower bound -------
BER_LB=BER_LB/(T*Ntrials*N*modulation_order);
%---- ZF ----------
BER_ZF=BER_ZF/(T*Ntrials*N*modulation_order);
%---- MMSE ----------
BER_MMSE=BER_MMSE/(T*Ntrials*N*modulation_order);

%--------- plot BER curve ----------------

H1 = figure;
semilogy(SNR,BER_HOTML,'-^b', 'Linewidth',1.5,'markers',8);hold on;
semilogy(SNR,BER_DeepHOTML,'-ok', 'Linewidth',1.5,'markers',8);hold on;
semilogy(SNR,BER_ZF,'--g', 'Linewidth',1.5,'markers',8);hold on;
semilogy(SNR,BER_MMSE,'--m', 'Linewidth',1.5,'markers',8);hold on;
semilogy(SNR,BER_LB,'-r', 'Linewidth',1.5,'markers',8);hold on;

legend( '\fontsize{12}HOTML', '\fontsize{12}DeepHOTML','\fontsize{12}ZF','\fontsize{12}MMSE','\fontsize{12}lower bound' )
xlabel('SNR / (dB)')
ylabel('Bit Error Rate (BER)')
axis([20,40,1e-5,1])
hold on
grid on

