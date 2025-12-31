%% tb_fir64.m  –  Milestone 1 testbench

clear; clc;

% Parameters
L      = 64;        % number of taps
N      = 10000;     % number of input samples
Q15    = 2^15;      % scaling for Q1.15
Q9     = 2^9;       % scaling for Q7.9

% -- Generate random Q1.15 inputs and coefficients --

% uniform in [-1, 1)
x_real = 2*rand(N,1) - 1;          % double
b_real = 2*rand(L,1) - 1;

% saturate to representable Q1.15 range [-1, 1-2^-15]
clip = @(v) max(min(v, 1 - 1/Q15), -1);

x_q15 = clip(x_real);
b_q15 = clip(b_real);

% store as signed 16-bit integers (Q1.15 format)
x_int = int16(round(x_q15 * Q15));
b_int = int16(round(b_q15 * Q15));

% -- Golden floating-point FIR output (single precision) --

y_fp = fir64_fp(single(double(x_int)/Q15), ...
                single(double(b_int)/Q15));   % use quantized values

% -- Quantize golden output to Q7.9 (what RTL will try to match) --

% design choice: assume y is within roughly [-256, 256)
y_q7_9 = max(min(y_fp, (2^7 - 2^-9)), -2^7);   % range [-128, 128-2^-9]

y_int = int16(round(y_q7_9 * Q9));            % 16-bit signed, Q7.9

% -- Write files for RTL testbench --

% Integers (easiest for Verilog testbench)
writematrix(x_int, 'fir_input_q15.txt', 'FileType','text');     % 16-b signed
writematrix(b_int, 'fir_coeff_q15.txt', 'FileType','text');     % 16-b signed
writematrix(y_int, 'fir_output_q7_9.txt', 'FileType','text');   % 16-b signed

% floating-point golden reference (for NRMSE later)
% writematrix(y_fp,  'fir_output_golden_fp.txt', 'FileType','text');

%% -- Quick sanity check plot--
% Should be just noise for now
figure;
subplot(2,1,1); plot(double(x_int)/Q15); title('Input x[n] (Q1.15)');
subplot(2,1,2); plot(y_fp);             title('Golden output y[n] (float)');
xlabel('n');

%% -- Impulse Response Test --
% should match coefficients
clear; clc;

L = 64;

% a simple low-pass 
b = fir1(L-1, 0.2, 'low');   % normalized coefficients
b = single(b(:));            % change to single precision

N = 128;                      % length of test sequence
x = zeros(N,1,'single');
x(1) = 1;

y = fir64_fp(x, b);

% -- first 64 output samples should match b --
figure;
stem(0:L-1, b, 'filled'); hold on; %use stem for impulses
stem(0:L-1, y(1:L), 'r');
title('Impulse response: b[k] vs y[k]');
xlabel('k'); ylabel('amplitude');
legend('coeff b[k]','output y[k]');
grid on;

%% -- sin wave test
clear; clc;

L  = 64;
Fs = 48000;          % sample rate
Fin = 5500;          % test tone frequency

% -- Low-pass coefficients (same as above or reuse) --
h = fir1(L-1, 0.2, 'low');   % cutoff 0.2*(Fs/2)
h = single(h(:));

N = 1000;
n = (0:N-1).';
x = single(sin(2*pi*Fin/Fs * n));

y = fir64_fp(x, h);

% -- Plot input vs output --
figure;
subplot(2,1,1);
plot(n, x); xlim([0 400]);
title('Input sin x[n]');
xlabel('n');

subplot(2,1,2);
plot(n, y); xlim([0 400]);
title('Filtered output y[n]');
xlabel('n');

%finishing

exit;
