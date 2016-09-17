pro setup_writeinfo, rootdir, datadir, dates

;Reads in the raw data files, searches the headers for important info,
;writes that info to a text file (datalist.txt located in
;datadir+dates[i]).


;loop over each night
for i=0, n_elements(dates)-1 do begin

   cd, datadir+dates[i]+'/'
   spawn, 'ls N*.fits > foo.txt'
   
   readcol, 'foo.txt', files, format='A', /silent
   nfiles = n_elements(files)

   openw, 1, 'datalist.txt', width=1000
   printf, 1, '#File Name, Object, Data Type, Obs Class, ExpTime (s), '+$
           'Filter, Central Wave (microns), Aperture, X Offset ("), '+$
           'Y Offset ("), Airmass, PA (deg), Median Img Value, Obs ID, UT', $
           format='(A)'

   for j=0, nfiles-1 do begin
   
      junk = readfits(files[j], head, /silent)
      im = readfits(files[j], ext=1, /silent)

      ;get the object name
      object = strtrim(sxpar(head, 'OBJECT'),2)
      if (object EQ 'Ar,Xe' or object EQ 'Xe,Ar') then object='ArXe'
      object = strjoin(strsplit(object,' ',/extract))

      ;get the type of observation (e.g., Dark, Flat, Object)
      obstype = sxpar(head,'OBSTYPE')

      ;get the observation class (e.g., dayCal, partnerCal, science)
      obsclass = strtrim(sxpar(head,'OBSCLASS'),2)

      ;get the telescope x and y offsets
      xoff = sxpar(head,'XOFFSET')
      yoff = sxpar(head,'YOFFSET')

      ;get the exposure time
      exptime = sxpar(head,'EXPTIME')

      ;get the aperture (e.g., 3.0, ronchi, blocked)
      aperture = (strsplit(sxpar(head,'APERTURE'),'_',/extract))[0]

      ;get the filter
      filter = (strsplit(sxpar(head,'FILTER'),'_',/extract))[0]

      ;get the central wavelength
      centralwave = sxpar(head,'GRATWAVE')

      ;get the observation id (e.g., GN-2013A-Q-1)
      obsid = sxpar(head,'OBSID')

      ;get the airmass
      airmass = sxpar(head,'AIRMASS')
      if (airmass LT 0.0) then airmass=1.0

      ;get the PA
      pa = sxpar(head,'PA')
      
      ;get the UT
      ut = sxpar(head,'UT')

      ;determine the median value of the exposure
      medianim = median(im)

      ;print data info to file
      printf, 1, strmid(files[j],0,14), object, obstype, obsclass, exptime, $
              filter, centralwave, aperture, xoff, yoff, airmass, pa, $
              medianim, obsid, ut, FORMAT='(A14,A20,A15,A15,I7,A10,F7.3,'+$
              'A10,2F10.2,F10.3,F10.2,F10.0,A25,A15)'
   endfor

   spawn,'rm foo.txt'

   close,1
   free_lun,1

endfor

end
