%% RTD temperature DAQ - design calculations
% Computes every value in the signal chain, from temperature to ADC code:
% Pt100 resistance -> Wheatstone bridge voltage -> amplifier output -> ADC.
% Values match the Simulink model in ../model/rtd_temperature_daq.slx.

clear; clc;

%% Parameters
Tmin = 30;  Tmax = 119;          % measurement range (degC)
Vs   = 10;                        % bridge supply (V)
Rb   = 100;                       % fixed bridge resistors R1 = R2 = R3 (Ohm)
Vout_min = 1;  Vout_max = 5;      % target amplifier output range (V)
Vref = 5;                         % ADC reference (V)

%% 1) Pt100 resistance (IEC 60751, Callendar-Van Dusen for T >= 0 degC)
Rmin = pt100(Tmin);
Rmax = pt100(Tmax);
fprintf('R(%d degC)  = %.2f Ohm\n', Tmin, Rmin);
fprintf('R(%d degC) = %.2f Ohm\n\n', Tmax, Rmax);

%% 2) Wheatstone bridge output
Vb = @(R) Vs * (R ./ (Rb + R) - 0.5);
Vb_min = Vb(Rmin);
Vb_max = Vb(Rmax);
fprintf('Bridge output: %.4f V -> %.4f V (span %.4f V)\n\n', Vb_min, Vb_max, Vb_max - Vb_min);

%% 3) Amplifier gain and offset from y = m*x + c
G      = (Vout_max - Vout_min) / (Vb_max - Vb_min);
offset = Vout_min - G * Vb_min;
fprintf('Required gain   G = %.3f\n', G);
fprintf('Required offset c = %.4f V\n', offset);

% Values implemented in the Simulink model (from bridge voltages rounded to
% 0.275 V / 0.933 V in the hand calculation). They keep the output just under 5 V.
G      = 6.079;
offset = -0.6717;

% Difference amplifier: G = Rf / Rin
Rin = 10e3;
Rf  = G * Rin;
fprintf('Implemented: G = %.3f, offset = %.4f V\n', G, offset);
fprintf('Difference amplifier: Rin = %.0f kOhm, Rf = %.2f kOhm\n\n', Rin/1e3, Rf/1e3);

%% 4) Output range and sensitivity
Vout = @(T) G * Vb(pt100(T)) + offset;
S = (Vout(Tmax) - Vout(Tmin)) / (Tmax - Tmin);   % V/degC (average)
fprintf('Vout(%d degC) = %.3f V, Vout(%d degC) = %.3f V\n', Tmin, Vout(Tmin), Tmax, Vout(Tmax));
fprintf('Average sensitivity = %.2f mV/degC\n\n', S * 1e3);

%% 5) ADC resolution and quantization error
configs = [16 5; 10 5; 10 3.3];   % [bits, Vref]
fprintf('%-16s %-14s %-14s %-14s\n', 'ADC', 'LSB', 'Resolution', 'Max q. error');
for k = 1:size(configs, 1)
    n = configs(k, 1);  vr = configs(k, 2);
    lsb = vr / 2^n;
    fprintf('%2d-bit, %.1f V   %-14s %-14s %-14s\n', n, vr, ...
        sprintf('%.2f uV', lsb * 1e6), ...
        sprintf('%.5f degC', lsb / S), ...
        sprintf('%.5f degC', lsb / S / 2));
end
fprintf('\nNote: with a 3.3 V ADC the amplifier gain must be reduced so Vout stays below 3.3 V.\n\n');

%% 6) Full chain example at 50 degC
T = 50;
R = pt100(T);  vb = Vb(R);  vo = Vout(T);
code = floor(vo / (Vref / 2^16));
fprintf('Example, T = %d degC: R = %.2f Ohm, Vb = %.4f V, Vout = %.4f V, 16-bit code = %d\n', ...
    T, R, vb, vo, code);

%% Sampling
% Temperature is a slow signal limited by thermal inertia. Nyquist requires
% fs >= 2*fmax; allowing for fast process changes (up to ~5 degC/s) and a
% safety factor, 20 Hz is used.

function R = pt100(T)
    R0 = 100;  A = 3.9083e-3;  B = -5.775e-7;
    R = R0 * (1 + A*T + B*T.^2);
end
