/*
 * This file was generated automatically by xsubpp version 1.9508 from the
 * contents of GaussianKernelEstimate.xs. Do not edit this file, edit GaussianKernelEstimate.xs instead.
 *
 *	ANY CHANGES MADE HERE WILL BE LOST!
 *
 */

#line 1 "GaussianKernelEstimate.xs"
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


#line 42 "GaussianKernelEstimate.c"

XS(XS_GaussianKernelEstimate_getKernelEstimate); /* prototype to pass -Wmissing-prototypes */
XS(XS_GaussianKernelEstimate_getKernelEstimate)
{
    dXSARGS;
    if (items != 4)
	Perl_croak(aTHX_ "Usage: GaussianKernelEstimate::getKernelEstimate(x, array_ref, h, n)");
    {
	double	x = (double)SvNV(ST(0));
	SV *	array_ref = ST(1);
	double	h = (double)SvNV(ST(2));
	int	n = (int)SvIV(ST(3));
	double	RETVAL;
	dXSTARG;

	RETVAL = getKernelEstimate(x, array_ref, h, n);
	XSprePUSH; PUSHn((double)RETVAL);
    }
    XSRETURN(1);
}

#ifdef __cplusplus
extern "C"
#endif
XS(boot_GaussianKernelEstimate); /* prototype to pass -Wmissing-prototypes */
XS(boot_GaussianKernelEstimate)
{
    dXSARGS;
    char* file = __FILE__;

    XS_VERSION_BOOTCHECK ;

        newXS("GaussianKernelEstimate::getKernelEstimate", XS_GaussianKernelEstimate_getKernelEstimate, file);
    XSRETURN_YES;
}
