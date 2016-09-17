function resample_spectra_anil, inspectra, inlambda, outlambda, $
                                OVERSAMPLE=oversample, NPOINTS=npoints
  
;this program takes an input spectrum and wavelength array, and
;outputs a spectra with the desired output wavelength array.  This is
;done first with oversampling, and then binning down to the desired
;spectra.  Note that wavelength accuracy will be determined by the
;oversampling factor.  Currently assumes that outlambda (the output
;wavelength array) is evenly binned in wavelength.
;NOTE that oversampling is of the OUTPUT wavelength array

if not KEYWORD_SET(oversample) then oversample=10

minlambda=MIN(outlambda)
maxlambda=MAX(outlambda)
difflambda=outlambda-outlambda[1:*]
mediandiff=ABS(MEDIAN(difflambda))
inmediandiff=ABS(MEDIAN(inlambda-inlambda[1:*]))
if (mediandiff/float(oversample) GT inmediandiff/2.) then begin 
   print,'Warning: oversampling of output array still undersamples input array'
   print,'Out/oversample,in/2',mediandiff/float(oversample),inmediandiff/2.
endif 

nlambda=long(n_elements(outlambda))
noversample=nlambda*long(oversample)
intlambda=minlambda+findgen(noversample)*(mediandiff/oversample)-(mediandiff*0.5)
intspec=interpol(inspectra,inlambda,intlambda,/spline)
outspectra=fltarr(nlambda)
npoints=intarr(nlambda)
for i=0l,nlambda-1 do begin
   ind=where(intlambda GE outlambda[i]-mediandiff/2.0 AND intlambda LT outlambda[i]+mediandiff/2.0,nind)
   outspectra[i]=total(intspec[ind])/float(nind)
   npoints[i]=nind
endfor

return, outspectra

end

;===================================================================

pro shift_cube_anil, workdir, incubestem, lambdaref

;to align the wavelengths of cubes to a reference wavelength grid
; Written by Anil Seth

incubefile=workdir+incubestem+'.fits'
outcubefile=workdir+incubestem+'_shift.fits'
ext0 = mrdfits(incubefile,0,h0,/silent)
cube = mrdfits(incubefile,1,h1,/silent)
var = mrdfits(incubefile,2,h2,/silent)
dq = mrdfits(incubefile,3,h3,/silent)

imsize=size(cube,/dim)
nlambda=imsize[2]
lambda0=sxpar(h1,'CRVAL3')
dlambda=sxpar(h1,'CD3_3')
lambda=findgen(imsize[2])*dlambda+lambda0

outcube=cube
outvar=var
outdq=dq
for i=0,imsize[0]-1 do begin
   for j=0,imsize[1]-1 do begin
      outcube[i,j,*]=resample_spectra_anil(cube[i,j,*],lambda,lambdaref,oversample=10,npoints=npoints)
      outvar[i,j,*]=resample_spectra_anil(var[i,j,*],lambda,lambdaref,oversample=10,npoints=npoints)
      outdq[i,j,*]=resample_spectra_anil(dq[i,j,*],lambda,lambdaref,oversample=10,npoints=npoints)
    
   endfor 
endfor

sxaddpar,h1,'CRVAL3',lambdaref[0]
mwrfits,ext0,outcubefile,h0,/create,/silent
mwrfits,outcube,outcubefile,h1,/silent
mwrfits,var,outcubefile,h2,/silent
mwrfits,dq,outcubefile,h3,/silent

end

;===================================================================

pro run_shift_anil, workdir, corfiles, vlsr_corr

;set the reference wavelength.
cube = mrdfits(workdir+corfiles[0]+'.fits',1,h1,/silent)
imsize=size(cube,/dim)
nlambda=imsize[2]
lambda0=sxpar(h1,'CRVAL3')
dlambda=sxpar(h1,'CD3_3')
lambda=findgen(imsize[2])*dlambda+lambda0
;make the vlsr correction
lambda=lambda*(1.D + (vlsr_corr/2.99792458D5))

;shift the cubes to the same wavelength array
for i=0,n_elements(corfiles)-1 do shift_cube_anil, workdir, corfiles[i],$
   lambda

end

