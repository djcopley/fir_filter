 #!python3
import numpy
from numpy import sin, pi, absolute, arange
from pylab import figure, clf, plot, xlabel, ylabel, xlim, ylim, title, grid, axes, show
from scipy.signal import kaiserord, lfilter, firwin, freqz

sample_rate = 100e6
nsamples = 1000
t = arange(nsamples) / sample_rate
x = sin(2 * pi * 10e6 * t) + sin(2 * pi * 40e6 * t)

nyq_rate = sample_rate / 2.0
width = 20e6 / nyq_rate
ripple_db = 60.0
N, beta = kaiserord(ripple_db, width)
cutoff_hz = 35e6
taps = firwin(N, cutoff_hz / nyq_rate, window=('kaiser', beta))

# Write data to files
norm_scale_taps = numpy.round(((2 ** 16) - 1) * (taps / max(taps)))
with open("./taps.data", "w") as f:
    for i in norm_scale_taps:
        f.write(str(int(i)) + "\n")

norm_scale_sig = numpy.round(((2 ** 23) - 1) * (x / max(x)))
with open("./sig.data", "w") as f:
    for i in norm_scale_sig:
        f.write(str(int(i)) + "\n")

filtered_x = lfilter(taps, 1.0, x)

figure(1)
plot(taps, 'bo-', linewidth=2)
title('Filter Coefficients (%d taps)' % N)
grid(True)

figure(2)
clf()
w, h = freqz(taps, worN=8000)
plot((w / pi) * nyq_rate, absolute(h), linewidth=2)
xlabel('Frequency (Hz)')
ylabel('Gain')
title('Frequency Response')
ylim(-0.05, 1.05)
grid(True)

ax1 = axes([0.42, 0.6, .45, .25])
plot((w / pi) * nyq_rate, absolute(h), linewidth=2)
xlim(0, 8.0)
ylim(0.9985, 1.001)
grid(True)

ax2 = axes([0.42, 0.25, .45, .25])
plot((w / pi) * nyq_rate, absolute(h), linewidth=2)
xlim(12.0, 20.0)
ylim(0.0, 0.0025)
grid(True)

delay = 0.5 * (N - 1) / sample_rate

figure(3)
plot(t, x)
plot(t - delay, filtered_x, 'r-')
plot(t[N - 1:] - delay, filtered_x[N - 1:], 'g', linewidth=4)

xlabel('t')
grid(True)

show()
