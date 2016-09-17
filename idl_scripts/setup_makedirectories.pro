pro setup_makedirectories, rootdir, datadir, workdir, dates, $
                           galaxies, tellurics

;Program to create directory structure, sort files into the correct
;directories, create the daycal file lists (i.e., flatlist,
;flatdarklist).


;make main directory structure
;------------------------------

;for workdir
if (file_test(workdir,/dir) EQ 0) then spawn, 'mkdir '+workdir

;for daycals
if (file_test(workdir+'daycals',/dir) EQ 0) then $
   spawn, 'mkdir '+workdir+'daycals'

;for tellurics
if (file_test(workdir+'tellurics',/dir) EQ 0) then $
   spawn, 'mkdir '+workdir+'tellurics'

;for object exposures
for i = 0, n_elements(galaxies)-1 do begin
   if (file_test(workdir+'/'+galaxies[i],/dir) EQ 0) then $
      spawn, 'mkdir '+workdir+'/'+galaxies[i]
   if (file_test(workdir+'/'+galaxies[i]+'/merged',/dir) EQ 0) then $
      spawn, 'mkdir '+workdir+'/'+galaxies[i]+'/merged'
endfor

;-----------------------

;loop over each night
for i=0, n_elements(dates)-1 do begin

   cd, datadir+dates[i]+'/'

   readcol,'datalist.txt', filestem, object, obstype, obsclass, exptime, $
           filter, centralwave, aperture, xoff, yoff, airmass, pa, medianim,$
           obsid, ut, FORMAT='A,A,A,A,I,A,F,A,F,F,F,F,F,A,A', /silent

   ;make the dated subdirectories
   ;------------------------------
   
   ;for the daycals
   if (file_test(workdir+'daycals/'+dates[i],/dir) EQ 0) then $
      spawn, 'mkdir '+workdir+'daycals/'+dates[i]

   ;for the tellurics
   if (file_test(workdir+'tellurics/'+dates[i],/dir) EQ 0) then $
      spawn, 'mkdir '+workdir+'tellurics/'+dates[i]

   ;for the objects
   scifiles = where(obsclass EQ 'science', nscifiles)
   if nscifiles EQ 0 then begin
      print, 'No science files found.'
      stop
   endif
   uniqobject = object[scifiles[uniq(object[scifiles])]]
   
   for j = 0, n_elements(galaxies)-1 do begin
      
      catalog_firstletter = strmid(galaxies[j],0,1)

      case catalog_firstletter of
         'n': galaxies_number = strsplit(galaxies[j],'ngc',/extract)
         'u': galaxies_number = strsplit(galaxies[j],'ugc',/extract)
         'm': galaxies_number = strsplit(galaxies[j],'mrk',/extract)
         'p': galaxies_number = strsplit(galaxies[j],'pgc',/extract)
         'i': galaxies_number = strsplit(galaxies[j],'ic',/extract)
         else: stop
      endcase

      for k = 0, n_elements(uniqobject)-1 do begin
         
         test = strmatch(uniqobject[k], '*'+galaxies_number+'*')
         if test EQ 1 then begin
            if (file_test(workdir+'/'+galaxies[j]+'/'+dates[i],/dir) EQ 0) then $
               spawn, 'mkdir '+workdir+'/'+galaxies[j]+'/'+dates[i]
         endif
      endfor
   endfor

   ;------------------------------

   
    ;all observations are assumed to be done in K, but could have
   ;different central wavelengths. loop over different central
   ;wavelengths
   uniqcentralwave = centralwave[uniq(centralwave)]
   nuniqcentralwave = n_elements(uniqcentralwave)

   for j=0, nuniqcentralwave-1 do begin

      index = where(centralwave EQ uniqcentralwave[j],nindex)
      if nindex EQ 0 then begin
         print, 'Problem finding files with the same central wavelength.'
         stop
      endif
      filestem_tmp = filestem[index]
      object_tmp = object[index]
      obstype_tmp = obstype[index]
      obsclass_tmp = obsclass[index]
      exptime_tmp = exptime[index]
      filter_tmp = filter[index]
      centralwave_tmp = centralwave[index]
      aperture_tmp = aperture[index]
      xoff_tmp = xoff[index]
      yoff_tmp = yoff[index]
      airmass_tmp = airmass[index]
      pa_tmp = pa[index]
      medianim_tmp = medianim[index]
      obsid_tmp = obsid[index]
      ut_tmp = ut[index]


      ;make the observational setup subdirectories and for the the
      ;tellurics and galaxies, sort files into the subdirectories
      ;----------------------------------------------------------

      setup = 'hk_'+strcompress(sigfig(uniqcentralwave[j],3),/remove_all)

      ;for the daycals      
      if (file_test(workdir+'daycals/'+dates[i]+'/'+setup,/dir) EQ 0) then $
         spawn, 'mkdir '+workdir+'daycals/'+dates[i]+'/'+setup

      
      ;for the tellurics. also make subdirectories with star name and
      ;sort raw files into the correct directory
      if (file_test(workdir+'tellurics/'+dates[i]+'/'+setup,/dir) EQ 0) then $
         spawn, 'mkdir '+workdir+'tellurics/'+dates[i]+'/'+setup
      telfiles = where(obsclass_tmp EQ 'partnerCal', ntelfiles)
      if ntelfiles EQ 0 then begin
         print, 'No telluric files with this central wavelength found.'
         stop
      endif
      uniqobject = object_tmp[telfiles[uniq(object_tmp[telfiles])]]

      for k = 0, n_elements(tellurics)-1 do begin

         catalog_first2letters = strmid(tellurics[k],0,2)

         case catalog_first2letters of
            'hi': tellurics_number = strsplit(tellurics[k],'hip',/extract)
            'hd': tellurics_number = strsplit(tellurics[k],'hd',/extract)
            'hr': tellurics_number = strsplit(tellurics[k],'hr',/extract)
            else: stop
         endcase

         for l = 0, n_elements(uniqobject)-1 do begin
         
            test = strmatch(uniqobject[l], '*'+tellurics_number+'*')
            if test EQ 1 then begin
               if (file_test(workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k],/dir) EQ 0) then $
                  spawn, 'mkdir '+workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]
               tel_indices = where(uniqobject[l] EQ object_tmp AND $
                                   obsclass_tmp EQ 'partnerCal', ntel_indices)
               openw, lun, workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]+$
                      '/telluriclist', /get_lun
               for m = 0, ntel_indices-1 do begin
                  spawn, 'cp '+filestem_tmp[tel_indices[m]]+'.fits '+workdir+'/tellurics/'+$
                         dates[i]+'/'+setup+'/'+tellurics[k]+'/'
                  printf, lun, filestem_tmp[tel_indices[m]], format='(A)'
               endfor
               close, lun
               free_lun, lun
               spawn, 'cp '+workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]+$
                      '/telluriclist '+workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]+$
                      '/skylist'
               spawn, 'cp '+workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]+$
                      '/telluriclist '+workdir+'/tellurics/'+dates[i]+'/'+setup+'/'+tellurics[k]+$
                      '/skylist_short'
            endif
         endfor
      endfor
      
      ;for the objects. also sort raw files into the correct directory
      scifiles = where(obsclass_tmp EQ 'science', nscifiles)
      if nscifiles EQ 0 then begin
         print, 'No science files with this central wavelength found.'
         stop
      endif
      uniqobject = object_tmp[scifiles[uniq(object_tmp[scifiles])]]
   
      for k = 0, n_elements(galaxies)-1 do begin
      
         catalog_firstletter = strmid(galaxies[k],0,1)

         case catalog_firstletter of
            'n': galaxies_number = strsplit(galaxies[k],'ngc',/extract)
            'u': galaxies_number = strsplit(galaxies[k],'ugc',/extract)
            'm': galaxies_number = strsplit(galaxies[k],'mrk',/extract)
            'p': galaxies_number = strsplit(galaxies[k],'pgc',/extract)
            'i': galaxies_number = strsplit(galaxies[k],'ic',/extract)
            else: stop
         endcase

         for l = 0, n_elements(uniqobject)-1 do begin
         
            test = strmatch(uniqobject[l], '*'+galaxies_number+'*')
            if test EQ 1 then begin
               if (file_test(workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup,/dir) EQ 0) then $
                  spawn, 'mkdir '+workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup
               if (file_test(workdir+'/'+galaxies[k]+'/merged/'+setup,/dir) EQ 0) then $
                  spawn, 'mkdir '+workdir+'/'+galaxies[k]+'/merged/'+setup
               sci_indices = where(uniqobject[l] EQ object_tmp AND $
                                   obsclass_tmp EQ 'science', nsci_indices)
               openw, lun, workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup+'/gallist', /get_lun
               for m = 0, nsci_indices-1 do begin
                  spawn, 'cp '+filestem_tmp[sci_indices[m]]+'.fits '+workdir+'/'+galaxies[k]+$
                         '/'+dates[i]+'/'+setup+'/'
                  printf, lun, filestem_tmp[sci_indices[m]], format='(A)'
               endfor
               close, lun
               free_lun, lun
               spawn, 'cp '+workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup+'/gallist '+$
                      workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup+'/skylist'
               spawn, 'cp '+workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup+'/gallist '+$
                      workdir+'/'+galaxies[k]+'/'+dates[i]+'/'+setup+'/skylist_short'
            endif
         endfor
      endfor

      ;sort calibration data files and make lists (e.g., flatlist,
      ;flatdarklist)
      ;-------------------------------------------------------------

      ;for the flats
      flats_index = where(obstype_tmp EQ 'FLAT' AND aperture_tmp EQ '3.0' AND $
                          medianim_tmp GT 200., nflats)
      if nflats EQ 0 then begin
         print, 'Cannot find flats.'
         stop
      endif
      openw, lun, workdir+'daycals/'+dates[i]+'/'+setup+'/flatlist', /get_lun
      for k=0, nflats-1 do begin
         spawn, 'cp '+filestem_tmp[flats_index[k]]+'.fits '+workdir+'daycals/'+$
                dates[i]+'/'+setup+'/'
         printf, lun, filestem_tmp[flats_index[k]], format='(A)'
      endfor
      close, lun
      free_lun, lun

      
      ;for the flat darks
      flatdarks_index = where(obstype_tmp EQ 'FLAT' AND $
                              aperture_tmp EQ '3.0' AND $
                              medianim_tmp LT 200., nflatdarks)
      if nflatdarks EQ 0 then begin
         print, 'Cannot find flat darks.'
         stop
      endif
      openw, lun, workdir+'daycals/'+dates[i]+'/'+setup+'/flatdarklist', /get_lun
      for k=0, nflatdarks-1 do begin
         spawn, 'cp '+filestem_tmp[flatdarks_index[k]]+'.fits '+workdir+$
                'daycals/'+dates[i]+'/'+setup+'/'
         printf, lun, filestem_tmp[flatdarks_index[k]], format='(A)'
      endfor
      close, lun
      free_lun, lun

      
      ;for the ronchi mask
      ronchi_index = where(obstype_tmp EQ 'FLAT' AND $
                           aperture_tmp EQ 'Ronchi' AND $
                           medianim_tmp GT 200.,nronchi)
      if nronchi EQ 0 then begin
         print, 'Cannot find ronchi mask.'
         stop
      endif
      openw, lun, workdir+'daycals/'+dates[i]+'/'+setup+'/ronchilist', /get_lun
      for k=0, nronchi-1 do begin
         spawn, 'cp '+filestem_tmp[ronchi_index[k]]+'.fits '+workdir+$
                'daycals/'+dates[i]+'/'+setup+'/'
         printf, lun, filestem_tmp[ronchi_index[k]], format='(A)'
      endfor
      close, lun
      free_lun, lun


      ;for the arcs. for now, just combine all arcs from the night
      ;together.
      arcs_index = where(obstype_tmp EQ 'ARC', narcs)
      if narcs EQ 0 then begin
         print, 'Cannot find arcs.'
         stop
      endif
      openw, lun, workdir+'daycals/'+dates[i]+'/'+setup+'/arclist', /get_lun
      for k=0, narcs-1 do begin
         spawn, 'cp '+filestem_tmp[arcs_index[k]]+'.fits '+workdir+'daycals/'+$
                dates[i]+'/'+setup+'/'
         printf, lun, filestem_tmp[arcs_index[k]], format='(A)'
      endfor
      close, lun
      free_lun, lun

      
      ;for the arc darks
      arcdarks_index = where(obstype_tmp EQ 'DARK' AND $
                             aperture_tmp EQ 'Blocked' AND $
                             exptime_tmp LT 60., narcdarks)
      if narcdarks EQ 0 then begin
         print, 'Cannot find arc darks.'
      endif
      openw, lun, workdir+'daycals/'+dates[i]+'/'+setup+$
             '/arcdarklist', /get_lun
      for k=0, narcdarks-1 do begin
         spawn, 'cp '+filestem_tmp[arcdarks_index[k]]+'.fits '+workdir+$
                'daycals/'+dates[i]+'/'+setup+'/'
         printf, lun, filestem_tmp[arcdarks_index[k]], format='(A)'
      endfor
      close, lun
      free_lun, lun

   endfor

endfor

end
