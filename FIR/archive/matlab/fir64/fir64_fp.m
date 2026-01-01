function y = fir64_fp(x, b)
% x : column or row vector of input samples
% b : 64-tap coefficient vector (length 64)
% y : same length as x

    x = single(x(:));          % use 32-bit float for Matlab
    b = single(b(:));          % coefficient
    L = numel(b);              % 64
    N = numel(x);
    y = zeros(N, 1, 'single'); % output

    % delay line
    d = zeros(L, 1, 'single');

    for n = 1:N
        % shift registers
        d(2:end) = d(1:end-1); %for each N index
        d(1)     = x(n);

        % MAC
        acc = single(0); % sum
        for k = 1:L
            acc = acc + b(k) * d(k);
        end
        y(n) = acc;
    end
end
