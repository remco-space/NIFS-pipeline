pro nifcube_anil, workdir, infile
  
;a replacement for nifcube that will hopefully have less horrible
;effects on the noise properties of the images.

outfile='c'+infile

nslice=29
sciexts=indgen(29)*3+1
varexts=indgen(29)*3+2
dqexts=indgen(29)*3+3

zeroext=readfits(workdir+infile,zerohead,ext=0,/silent)
example=readfits(workdir+infile,exhead,ext=sciexts[0],/silent)
slicesize=size(example,/dim)
allslice=fltarr(slicesize[0],slicesize[1],nslice)
allvar=fltarr(slicesize[0],slicesize[1],nslice)
alldq=fltarr(slicesize[0],slicesize[1],nslice)
slicera=fltarr(nslice)
allhead=strarr(nslice,n_elements(exhead))

;read in all data
for i=0,nslice-1 do begin
   slice=readfits(workdir+infile,head,ext=sciexts[i],/silent)
   var=readfits(workdir+infile,ext=varexts[i],/silent)
   dq=readfits(workdir+infile,ext=dqexts[i],/silent)
   allhead[i,*]=head
   slicera[i]=sxpar(head,'CRVAL3')
   allslice[*,*,i]=slice
   allvar[*,*,i]=var
   alldq[*,*,i]=float(dq)
endfor

;Here is the process
;1) Rebin existing data into a (very) subsampled image
;2) Resample this data by averaging data in new pixelsizes
subpixsize=0.001
xinpixsize=abs(slicera[1]-slicera[0])
yinpixsize=sxpar(exhead,'CD2_2')
yinpixsize=fix(yinpixsize/subpixsize+0.5)*subpixsize
nxinpix=fix(float(nslice)*(xinpixsize/subpixsize)+0.5)
nyinpix=fix(float(slicesize[1])*(yinpixsize/subpixsize)+0.5)
outpixsize=0.05
nxoutpix=fix((float(nxinpix)*subpixsize)/outpixsize)+1
nyoutpix=fix((float(nyinpix)*subpixsize)/outpixsize)+1
nxbigpix=fix(float(nxoutpix)/(subpixsize/outpixsize)+0.5)
nybigpix=fix(float(nyoutpix)/(subpixsize/outpixsize)+0.5)
relarea=outpixsize^2/(xinpixsize*yinpixsize)

;setup output arrays
outcube=fltarr(nxoutpix,nyoutpix,slicesize[0])
outvarcube=fltarr(nxoutpix,nyoutpix,slicesize[0])
outdqcube=fltarr(nxoutpix,nyoutpix,slicesize[0])
;loop over wavelengths first
for i=0,slicesize[0]-1 do begin
   
   ;may need to reverse this to get right X direction?
   onepane=rotate(reform(allslice[i,*,*]),1) ;4 would give me X going other way
   bigpane=rebin(onepane,nxinpix,nyinpix,/sample)
   outbigpane=fltarr(nxbigpix,nybigpix)
   outbigpane[0:nxinpix-1,0:nyinpix-1]=bigpane
   outbigpane[nxinpix:*,nyinpix:*]=!VALUES.F_NAN
   ;this REBIN command is just an average
   outpane=(rebin(outbigpane,nxoutpix,nyoutpix));*relarea
   outcube[*,*,i]=outpane

   ;variance spectrum seems like it has been arbitrarily scaled by a
   ;larger number in the atfbrgn* files. Seems more appropriately
   ;scaled in the tfbrgn* files. Try tracking this down!
   onevar=rotate(reform(allvar[i,*,*]),1) ;4 would give me X going other way
   bigvar=rebin(onevar,nxinpix,nyinpix,/SAMPLE)
   outbigvar=fltarr(nxbigpix,nybigpix)
   outbigvar[0:nxinpix-1,0:nyinpix-1]=bigvar
   outbigvar[nxinpix:*,nyinpix:*]=!VALUES.F_NAN
   outvar=(rebin(outbigvar,nxoutpix,nyoutpix))*relarea
   outvarcube[*,*,i]=outvar
   
   ;dq image will be helpful for separating CRs from bad pixels
   onedq=rotate(reform(alldq[i,*,*]),1) ;4 would give me X going other way
   bigdq=rebin(onedq,nxinpix,nyinpix,/SAMPLE)
   outbigdq=fltarr(nxbigpix,nybigpix)
   outbigdq[0:nxinpix-1,0:nyinpix-1]=bigdq
   outbigdq[nxinpix:*,nyinpix:*]=!VALUES.F_NAN
   outdq=(rebin(outbigdq,nxoutpix,nyoutpix))
   outdqcube[*,*,i]=outdq

endfor

;prepare header for 1st extension
outhead=exhead
sxaddpar,outhead,'CTYPE1',SXPAR(zerohead,'CTYPE1')
sxaddpar,outhead,'CRVAL1',SXPAR(zerohead,'RA')-SXPAR(zerohead,'RAOFFSET')/3600.
sxaddpar,outhead,'CRPIX1',nxoutpix/2.
sxaddpar,outhead,'CD1_1',-outpixsize/3600.
sxaddpar,outhead,'CD1_2',0.0
sxaddpar,outhead,'CTYPE2',SXPAR(zerohead,'CTYPE2')
sxaddpar,outhead,'CRVAL2',SXPAR(zerohead,'DEC')-SXPAR(zerohead,'DECOFFSE')/3600.
sxaddpar,outhead,'CRPIX2',nyoutpix/2.
sxaddpar,outhead,'CD2_1',0.0
sxaddpar,outhead,'CD2_2',outpixsize/3600.
sxaddpar,outhead,'CTYPE3','LINEAR'
sxaddpar,outhead,'CRUNIT3','Angstrom'
sxaddpar,outhead,'CRVAL3',SXPAR(exhead,'CRVAL1')
sxaddpar,outhead,'CD3_3',SXPAR(exhead,'CD1_1')
sxaddpar,outhead,'DISPAXIS',3
sxdelpar,outhead,'WAXMAP01'
sxdelpar,outhead,'WAT1_001'
sxdelpar,outhead,'WAT2_001'
sxdelpar,outhead,'WAT3_001'
sxdelpar,outhead,'NSCUTSEC'
sxdelpar,outhead,'NSCUTSPC'
sxdelpar,outhead,'FIXPIX'
sxdelpar,outhead,'WCSDIM'
sxdelpar,outhead,'DCLOG1'


fits_write,workdir+outfile,zeroext,zerohead
fits_open,workdir+outfile,fcbout,/update
fits_write,fcbout,outcube,outhead,extname='SCI'
fits_write,fcbout,outvarcube,outhead,extname='VAR'
fits_write,fcbout,outdqcube,outhead,extname='DQ'
fits_close,fcbout

end

;===================================================================

pro run_nifcube_anil, workdir, listfile

readcol,workdir+listfile,infile,format='A'
nfile=n_elements(infile)
for i=0,nfile-1 do begin
   nifcube_anil,workdir,infile[i]
endfor

end
