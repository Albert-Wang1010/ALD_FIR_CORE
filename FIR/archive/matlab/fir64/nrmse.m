function y = nrmse(y_fp, y_q)
% y_fp : golden MATLAB result (float)
% y_q  : quantized RTL result (same length, real-valued)

    y_fp = y_fp(:);
    y_q  = y_q(:);
    assert(numel(y_fp) == numel(y_q), 'Vectors must be same length');

    rmse  = sqrt(mean((y_fp - y_q).^2));
    ymax  = max(y_fp);
    ymin  = min(y_fp);
    y = rmse / (ymax - ymin);
end
