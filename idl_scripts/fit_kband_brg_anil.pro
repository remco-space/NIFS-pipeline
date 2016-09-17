function cnb_voigt, x, sigma, gamma
  
; PURPOSE:
; This function computes centered Voigt profiles. It is a wrapper to the
; builtin IDL VOIGT routine, which uses a somewhat confusing variable
; convention. The Voigt function implemented here is a stright
; convolution of a Gaussian with a Lorentzian.
;
; INPUTS:
; x: The abcissa values. The profile will be centered on x=0. Scalar
; or vector.
; sigma: The width of the Gaussian part of the profile. Scalar or
; vector
; gamma: The width of the Lorentzian part of the profile. Scalar or
; vector
;
; OUTPUTS:
; The voigt profile with the specified sigma, gamma, evaluated at x.
;
; MODIFIATION HISTORY:
; October 2010: Written by Chris Beaumont
;-

compile_opt idl2
on_error, 2

;- check inputs
if n_params() NE 3 then begin
print, 'calling sequence'
print, 'result = cnb_voigt(x, sigma, gamma)'
endif

;- inputs are scalars or arrays of the same size
nx = n_elements(x) & ng = n_elements(gamma) & ns = n_elements(sigma)
num = (nx > ng > ns)
if (nx NE 1 && nx NE num) || (ng NE 1 && ng NE num) || $
(ns NE 1 && ns NE num) then $
message, 'x, gamma, and sigma have incompatible sizes'

;- change of varialbes into IDL's voigt convention
delta = sqrt(2) * sigma
u = x / delta
a = gamma / delta
result = 1 / (sqrt(!pi) * delta) * voigt(a, u)

;- the above approach doesn't work when sigma=0.
;- this is just the lorentz profile in this case
TINY = 1e-7
bad = where(sigma LT TINY, ct)
if ct NE 0 && ns EQ 1 then result = gamma / (!pi * (x^2 + gamma^2))
if ct NE 0 && ns GT 1 then begin
   g = ng EQ 1 ? replicate(gamma, ct) : gamma[bad]
   subx = nx EQ 1 ? replicate(x, ct) : x[bad]
   result[bad] = g / (!pi * (subx^2 + g^2))
endif

return, result

end

;===================================================================

function fit_brackett,lambda,p
; p[0] = velocity
; p[1] = gaussian sigma
; p[2] = lorentzian gamma
; p[3] = flux of each line
; p[4-7] = polynomial fit parameters (nuisance)

COMMON brackett, brlambda

brvcor=brlambda*(1+p[0]/2.99792D5)
nbr=n_elements(brvcor)
spec=replicate(1.0,n_elements(lambda))
vlambda=findgen(1000.D)-500.D
vflux=cnb_voigt(vlambda,p[1],p[2])
for i=0,nbr-1 do begin
   templambda=vlambda+brvcor[i]
   lineflux=p[i+3]*interpol(vflux,templambda,lambda)
   spec=spec-lineflux
endfor
npoly=n_elements(p)-4
polyweights=p[4:*]/10^(4.*findgen(npoly))
spec=spec*poly(lambda,polyweights)

return,spec

end

;===================================================================

function kband_brackett, lambda, brlambda, brflux

vel=50.D
sigma=5.D
gamma=20.D
spec=replicate(1.0,n_elements(lambda))
brlambda=brlambda*(1+vel/2.99D5)
nbr=n_elements(brlambda)
brflux=findgen(nbr)+2.D
vlambda=findgen(1000.D)-500.D
vflux=cnb_voigt(vlambda,sigma,gamma)
plot,vlambda,vflux
for i=0,nbr-1 do begin
   templambda=vlambda+brlambda[i]
   lineflux=brflux[i]*interpol(vflux,templambda,lambda)
   spec=spec-lineflux
endfor
   
return, spec

end

;===================================================================

pro fit_kband_brg_anil, indir, infile, refdir

COMMON brackett, brlambda

outfile='c'+infile

readcol,refdir+'HI.dat',brlambda
telmodel=MRDFITS(refdir+'atran5000.fits')

fits_open,indir+infile,fcbin
fits_read,fcbin,ex0,header,exten_no=0
fits_read,fcbin,sci1,hex1,exten_no=1
fits_read,fcbin,err1,hex2,exten_no=2
fits_read,fcbin,dq1,hex3,exten_no=3
fits_close,fcbin
flux=sci1
fluxe=err1
lambda0=sxpar(hex1,'CRVAL1') & dlambda=SXPAR(hex1,'CD1_1')
lambda=findgen(n_elements(flux))*dlambda+lambda0
telmodelinterp=interpol(telmodel[*,1],telmodel[*,0]*10000.,lambda)

;prep Brackett line
brlambda=brlambda*1.D4
ind=where(brlambda GT MIN(lambda) and brlambda LT MAX(lambda),nind)
brlambda=brlambda[ind]

minfit=2.15D4
maxfit=2.185D4
fitind=where(lambda GT minfit and lambda LT maxfit)

tcorflux=flux/(telmodelinterp)
tcorflux=double(tcorflux/median(tcorflux))

brflux=[10.]
nparam=8
initguess=[-38.,5.,20.,brflux,1.02,-3.,7.,-2]
parinfo = replicate({value:0.D, fixed:0,limited:[0.D,0.D],$
                     limits:[0.D,0.D],mpmaxstep:0.D,relstep:0.D},nparam)
parinfo[*].value=initguess
parinfo[*].limited[*]=1
parinfo[0].limits=[-200.,200.]
parinfo[1].limits=[3.,100.]
parinfo[2].limits=[0.1,200.]
parinfo[3].limits=[0.01,1000.]
parinfo[4].limits=[0.001,10000.0]
parinfo[5:7].limits=[-1000,1000]
weights=1/fluxe^2
plot,lambda,tcorflux,xrange=[minfit,maxfit],xtitle='Wavelength (Angstroms)',$
     ytitle='Flux',psym=10
test=fit_brackett(lambda,initguess)
oplot,lambda,test,color=1,thick=3
fit=mpfitfun('fit_brackett', lambda[fitind], tcorflux[fitind], $
             weights=weights[fitind],perror=err, xtol=1.D-15, ftol=1d-20,$
             maxiter=100, status=status, parinfo=parinfo, bestnorm=bestnorm)

oplot,lambda[fitind],fit_brackett(lambda[fitind],fit),color=1,thick=3
oplot,lambda[fitind],poly(lambda[fitind],fit[4:7]),color=1, thick=3
wait, 2
plot,lambda[fitind],flux[fitind]/fit_brackett(lambda[fitind],fit)

fitflat=fit
fitflat[4]=1. & fitflat[5:*]=0.0

outspec=flux/fit_brackett(lambda,fitflat)
ind=where(outspec LT 0.2*median(outspec))
outspec[ind]=median(outspec)*0.5

plot,lambda,flux,xtitle='Wavelength (Angstroms)',ytitle='Flux',psym=10
loadct,13,/si
oplot,lambda,outspec,color=240,psym=10
loadct,0,/si

fits_write,indir+outfile,ex0,fcbin.hmain
fits_open,indir+outfile,fcbout,/update
fits_write,fcbout,outspec,hex1,extname=fcbin.extname[1],extver=fcbin.extver[1]
fits_write,fcbout,err1,hex2,extname=fcbin.extname[2],extver=fcbin.extver[2]
fits_write,fcbout,dq1,hex3,extname=fcbin.extname[3],extver=fcbin.extver[3]
fits_close,fcbout

end


