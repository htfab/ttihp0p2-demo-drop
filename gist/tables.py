import numpy as np

#   float envA = exp(-10.*t120_);
#   float envB = exp(-20.*t120_);
#   float envC = exp(-20.*t480_);

exp5 = np.exp(np.linspace(0,1,60) * -5.0) * 255.
exp10 = np.exp(np.linspace(0,1,60) * -10.0) * 255.
exp20 = np.exp(np.linspace(0,1,60) * -20.0) * 255.

print("exp -5.0",  exp5[1]/exp5[0],   "\n", exp5.astype(int),  "\n", exp5.astype(int)[0:29])
print("exp -10.0", exp10[1]/exp10[0], "\n", exp10.astype(int), "\n", exp10.astype(int)[0:29])
print("exp -20.0", exp20[1]/exp20[0], "\n", exp20.astype(int), "\n", exp20.astype(int)[0:14])

#   tx = floor(tx*60.*4.)/(60.*4.);
#   float tseq = mod(tx * 16.0, 16.0);
#   float dr = 0.26;
#   float amp = exp((tnote-dr) * -10.0)*.5;
#   float amp2 = exp((tnote-dr) * -1.0);
#   float amp3 = exp(tnote * -0.25)*.1;
#   // float amps = exp((tnote-.1) * -2.0)*3.;
#   float amps = (amp+amp2+amp3) * 2.;

len_in_sec = 4
time = np.linspace(0, len_in_sec, len_in_sec*60)
tseq = np.mod(time * 4.0, 16.0)
tnote = np.modf(tseq)[0]
# print(time, tseq, tnote)
dr = np.array([0.26]*len(tnote))
amp = np.exp((tnote-dr) * -10.0)*.5
amp2 = np.exp((tnote-dr) * -1.0)
amp3 = np.exp(tnote * -0.25)*.1
amps = (amp+amp2+amp3) * .33
amps = (amps * 255.).astype(int)
print("amp", "\n", amps[0:60], "\n", np.minimum(amps[0:14], 255))


#   float seqn = fract(floor(.5+.5*(1.-tseq)) * 0.18972);  
#   // float seqn = fract(floor(tseq) * 19871.8972);
#   float n = 20.0 + floor(seqn * 38.0);  //50.0 + floor(time * 2.0);
#   // n += sin(tseq*100.)*.0025;
#   float base = 440.0 * pow(2.0, (n - 69.0) / 12.0); // ntof
#   float h = 4.;
#   float v = sin(pi2 * t * base * h) < 0.0 ? -.2 : .2;

seqn = np.modf(1.+np.floor(.5+.5*(1.-tseq)) * 0.18972)[0]
n = 20.0 + np.floor(seqn * 38.0)
base = 440.0 * np.power(2.0, (n - 69.0) / 12.0) # ntof
h = 4.
print("notes", seqn, base*h)
