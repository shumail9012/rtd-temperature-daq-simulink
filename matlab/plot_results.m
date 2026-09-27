%% RTD temperature DAQ - plots
% 1) Pt100 resistance vs temperature
% 2) Amplifier output (ADC input) vs temperature
% 3) Calibration curve: measured vs true temperature (10 points)

clear; clc; close all;

Tmin = 30;  Tmax = 119;
Vs = 10;  Rb = 100;
G = 6.079;  offset = -0.6717;      % amplifier design (see design_calculations.m)
Vref = 5;  nbits = 16;

pt100 = @(T) 100 * (1 + 3.9083e-3*T - 5.775e-7*T.^2);
Vb    = @(T) Vs * (pt100(T) ./ (Rb + pt100(T)) - 0.5);
Vout  = @(T) G * Vb(T) + offset;
T = linspace(Tmin, Tmax, 500);

%% 1) Pt100 resistance
figure;
plot(T, pt100(T), 'b', 'LineWidth', 2); grid on;
xlabel('Temperature (\circC)'); ylabel('Resistance (\Omega)');
title('RTD Resistance vs Temperature (Pt100)');

%% 2) Amplifier output
figure;
plot(T, Vout(T), 'b', 'LineWidth', 2); hold on; grid on;
yline(5, 'r--'); yline(1, 'g--');
plot([Tmin Tmax], Vout([Tmin Tmax]), 'ro', 'MarkerFaceColor', 'r');
xlabel('Temperature (\circC)'); ylabel('Amplified Output Voltage (V)');
title('Amplified Voltage vs Temperature for RTD in Wheatstone Bridge');
ylim([0 5.2]);

%% 3) Calibration curve
% The system output is converted back to temperature with a linear two-point
% calibration (30 degC -> Vout(30), 119 degC -> Vout(119)), after 16-bit
% quantization. The bow in the curve comes from the non-linearity of the
% quarter bridge (the RTD sits in one arm), not from the sensor itself.
T_true = linspace(Tmin, Tmax, 10);
lsb = Vref / 2^nbits;
v_meas = round(Vout(T_true) / lsb) * lsb;
T_meas = Tmin + (v_meas - Vout(Tmin)) / (Vout(Tmax) - Vout(Tmin)) * (Tmax - Tmin);

figure;
plot(T_true, T_meas, 'bo-', 'LineWidth', 2, 'MarkerFaceColor', 'b'); hold on; grid on;
plot(T_true, T_true, 'r--', 'LineWidth', 2);
xlabel('True Temperature (\circC)'); ylabel('Measured Temperature (\circC)');
title('Calibration Curve: Measured vs True Temperature');
legend('Measured Temperature', 'Ideal Calibration', 'Location', 'northwest');

fprintf('Max deviation before correction: %.2f degC\n', max(abs(T_meas - T_true)));

% Correcting it: fit a 2nd-order polynomial T = p(Vout) on the calibration points
p = polyfit(v_meas, T_true, 2);
fprintf('Max deviation after 2nd-order correction: %.3f degC\n', ...
    max(abs(polyval(p, v_meas) - T_true)));
