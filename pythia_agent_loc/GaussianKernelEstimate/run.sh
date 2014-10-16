make clean
perl Makefile.PL
make

cp -f blib/lib/GaussianKernelEstimate.pm ..
cp -f blib/arch/auto/GaussianKernelEstimate/GaussianKernelEstimate.so ..

