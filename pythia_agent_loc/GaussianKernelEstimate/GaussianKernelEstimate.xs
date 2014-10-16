#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

double getKernelEstimate(double x, SV* array_ref, double h, int n)
{
	int i;
	double sum = 0.0;
	AV* array;
	SV* tmpSV = (SV*)SvRV(array_ref); /* deref */
	if (!SvROK(array_ref) || SvTYPE(tmpSV) != SVt_PVAV) 
		croak("expected ARRAY ref");
	array = (AV*) SvRV(array_ref);

	for (i = 0; i <= n /*av_len(array)*/; i++)
	{
		SV** elem = av_fetch(array, i, 0);
		if (elem != NULL)
		{
			double exp = x - SvNV(*elem); exp = exp * exp / (2.0 * h * h);
			sum += pow(2.71828183, -exp);
		}
	}
	sum /= sqrt(2*3.14159265);
	sum /= (n * h);
	return sum;
}


MODULE = GaussianKernelEstimate		PACKAGE = GaussianKernelEstimate		

PROTOTYPES: DISABLE


double
getKernelEstimate (x, array_ref, h, n)
	double	x
	SV *	array_ref
	double	h
	int	n

