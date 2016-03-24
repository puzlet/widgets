{input, result, plot} = $blab.ui

f = input()
result f

x = linspace(0, 1, 1000)  #;
y = x*x * sin(2*pi*f*x)  #;

plot x, y
