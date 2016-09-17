pro cube_combine_lp, dir, files, offsetlist, sig_thres, outfile

readcol, dir+offsetlist, xoff, yoff, format='F,F', comment='#', /silent

zeroext=readfits(dir+files[0], zerohead, ext=0, /silent)
im=readfits(dir+files[0], head, ext=1, /silent)
outhead=head
imsize=size(im,/DIM)
nim=n_elements(files)

;determine the spatial size of the mosaiced cube
maxx = max(xoff)  &  maxy = max(yoff)  &  minx = min(xoff)  &  miny = min(yoff)
max_x_shift = round(maxx)  &  max_y_shift = round(maxy)  &  min_x_shift = round(minx)  &  min_y_shift = round(miny)
nn1 = imsize[0]+max_x_shift-min_x_shift
nn2 = imsize[1]+max_y_shift-min_y_shift

outimsize=[nn1,nn2,imsize[2]]
imstack=dblarr([nim,outimsize])
varstack=dblarr([nim,outimsize])
dqstack=dblarr([nim,outimsize])
pixelstack=intarr([nim,outimsize])
;loop over the cubes
for i=0, nim-1 do begin
   
   im=readfits(dir+files[i], ext=1, /silent)
   var=readfits(dir+files[i], ext=2, /silent)
   dq=readfits(dir+files[i], ext=3, /silent)

   ;dx = xoff[i] - round(xoff[i])
   ;dy = yoff[i] - round(yoff[i])
   ix = abs(min_x_shift) + round(xoff[i])
   iy = abs(min_y_shift) + round(yoff[i])

   imstack[i, ix : ix + imsize[0]-1, iy : iy + imsize[1]-1, *] = im
   varstack[i, ix : ix + imsize[0]-1, iy : iy + imsize[1]-1, *] = var
   dqstack[i, ix : ix + imsize[0]-1, iy : iy + imsize[1]-1, *] = dq
   pixelstack[i, ix : ix + imsize[0]-1, iy : iy + imsize[1]-1, *] = 1
   
endfor

outim=dblarr(outimsize)
varim=dblarr(outimsize)
dqim=dblarr(outimsize)
npixim=dblarr(outimsize)
sigmaim=dblarr(outimsize)
flagim=dblarr(outimsize)
varim=dblarr(outimsize)

for i=1,outimsize[0]-2 do begin
   for j=1,outimsize[1]-2 do begin
      for k=0,outimsize[2]-1 do begin
         ;base cosmic ray rejection on neighboring x-pixels
         allval=imstack[*,i-1:i+1,j-1:j+1,k]
         allpix=pixelstack[*,i-1:i+1,j-1:j+1,k]
         allind=where(allpix EQ 1 AND FINITE(allval) EQ 1, nallind)
         if (nallind GT 1) then begin
            meanclip,allval[allind],av,sigma,clipsig=sig_thres
            sigma=sigma > 0.1
            val=imstack[*,i,j,k]
            var=varstack[*,i,j,k]
            dq=dqstack[*,i,j,k]
            pix=pixelstack[*,i,j,k]
            if (abs(median(val)-av) GT sigma) then flagim[i,j,k]=1
            ind=where(pix EQ 1 AND abs(val-av) LT sig_thres*sigma, nind)
            ;ind=where(pix EQ 1 AND abs(val-av) LT sig_thres*sigma AND dq LT 0.2, nind)
            ;adding a variance clip causes problem on the red end in
            ;the center
            if (nind GE 2) then begin
               outim[i,j,k]=mean(val[ind])
               varim[i,j,k]=total(var[ind])/(float(nind))^2
               dqim[i,j,k]=mean(dq[ind])
               npixim[i,j,k]=nind
               sigmaim[i,j,k]=sigma
            endif else begin
               if (nind EQ 1) then begin
                  outim[i,j,k]=val[ind]
                  varim[i,j,k]=var[ind]
                  dqim[i,j,k]=dq[ind]
                  npixim[i,j,k]=nind
                  sigmaim[i,j,k]=sigma
               endif
            endelse
         endif
      endfor
   endfor
endfor

fits_write,dir+outfile,zeroext,zerohead
fits_open,dir+outfile,fcbout,/update
fits_write,fcbout,outim,outhead,extname='SCI'
fits_write,fcbout,varim,outhead,extname='VAR'
fits_write,fcbout,dqim,outhead,extname='DQ'
fits_write,fcbout,npixim,outhead,extname='NPIX'
fits_write,fcbout,sigmaim,outhead,extname='SIG'
fits_write,fcbout,flagim,outhead,extname='FLAG'

fits_close,fcbout

end
