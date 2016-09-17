function find_offsets_lp, dir, files, method

;will use the first file as the reference
datacube = readfits(dir+files[0], head, exten_no=1)
img_all = fltarr((size(datacube))[1],(size(datacube))[2],n_elements(files))

;collapse cube
for i = 0, n_elements(files)-1 do begin
   
   datacube = readfits(dir+files[i], head, exten_no=1)

   ;take the median as a way to collapse the cubes
   img = fltarr((size(datacube))[1],(size(datacube))[2])
   for j = 0, (size(datacube))[1]-1 do begin
      for k = 0, (size(datacube))[2]-1 do begin
         img[j,k] = median(datacube[j,k,*],/even)
      endfor 
   endfor

   img_all[*,*,i] = img

endfor

;array that will hold the centers
cen_max_final = fltarr(2, n_elements(files))
cen_gauss_final = fltarr(2, n_elements(files))
cen_crosscorr_final = fltarr(2, n_elements(files))

for i = 0, n_elements(files)-1 do begin

   img_tmp = reform(img_all[*,*,i])

   ;first find the spaxel with the maximum value
   maxval = max(img_tmp, maxindex)
   ncol = (size(img_tmp))[1]
   xmax = maxindex MOD ncol & ymax = maxindex / ncol
   cen_max_final[0,i] = xmax & cen_max_final[1,i] = ymax

   ;now try fitting a 2D Gaussian. trying to fit the entire img, gives
   ;errors, focus near the xmax, ymax.
   yfit = mpfit2dpeak(img_tmp[xmax-15:xmax+15,ymax-15:ymax+15], bestparam, /gaussian)
   xcen_gauss = bestparam[4]+(xmax-15) & ycen_gauss = bestparam[5]+(ymax-15)
   cen_gauss_final[0,i] = xcen_gauss & cen_gauss_final[1,i] = ycen_gauss

end

;calculate the offset relative to the first file
offsets_max_final = fltarr(2, n_elements(files))
offsets_gauss_final = fltarr(2, n_elements(files))
for i = 1, n_elements(files)-1 do begin
   offsets_max_final[0,i] = cen_max_final[0,0] - cen_max_final[0,i]
   offsets_max_final[1,i] = cen_max_final[1,0] - cen_max_final[1,i]
   offsets_gauss_final[0,i] = cen_gauss_final[0,0] - cen_gauss_final[0,i]
   offsets_gauss_final[1,i] = cen_gauss_final[1,0] - cen_gauss_final[1,i]
endfor

;calculate the offsets using a cross-correlation
offsets_crosscorr_final = fltarr(2, n_elements(files))
for i = 1, n_elements(files)-1 do begin
   
   correl_optimize, reform(img_all[*,*,0]), reform(img_all[*,*,i]), $
                    xoffset_optimum, yoffset_optimum, $
                    XOFF_INIT = 0,   $
                    YOFF_INIT = 0,   $
                    /NUMPIX, $
                    MAGNIFICATION = 10., $
                    PLATEAU_TRESH = 0.01
   
   offsets_crosscorr_final[0,i] = xoffset_optimum
   offsets_crosscorr_final[1,i] = yoffset_optimum
   
endfor

;offsets_final = fltarr(3,2,n_elements(files))
;offsets_final[0,*,*] = offsets_max_final
;offsets_final[1,*,*] = offsets_gauss_final
;offsets_final[2,*,*] = offsets_crosscorr_final

if method EQ 'offset_max' then offsets_return = offsets_max_final
if method EQ 'offset_gauss' then offsets_return = offsets_gauss_final
if method EQ 'offset_crosscorr' then offsets_return = offsets_crosscorr_final

return, offsets_return

end
