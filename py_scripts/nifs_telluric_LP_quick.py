def nifs_telluric_LP_quick(workdir, caldir, date, flatlist, arclist, ronchilist,
                           telluriclist, skylist, skylist_short):

    ###########################################################################
    #  STEP 1: Prepare IRAF  		                                          #
    ###########################################################################

    #import some useful python utilities
    import sys
    import getopt
    import os
    import time
    import shutil
    #import the pyraf module and relevant packages
    from pyraf import iraf
    iraf.gemini(_doprint=0)
    iraf.nifs(_doprint=0)
    iraf.gnirs(_doprint=0)
    iraf.gemtools(_doprint=0)
    iraf.onedspec(_doprint=0)
    from pyraf import iraffunctions
    import pyfits
    import numpy as np

    #unlearn the used tasks
    iraf.unlearn(iraf.gemini,iraf.gemtools,iraf.gnirs,iraf.nifs)
    iraf.set(stdimage='imt2048')

    #create a log file and back up the previous one if it already exists
    log = 'telluric_'+date+'.log'
    if os.path.exists(log):
        t = time.localtime()
        app = '_'+str(t[0])+str(t[1]).zfill(2)+str(t[2]).zfill(2)+'_'+ \
        str(t[3]).zfill(2)+':'+str(t[4]).zfill(2)+':'+str(t[5]).zfill(2)
        shutil.move(log,log+app)

    #change to the workdir within pyraf
    iraffunctions.chdir(workdir)
        
    #prepare the package for NIFS
    iraf.nsheaders('nifs',logfile=log)

    #set clobber to 'yes' for the script. this still does not make the gemini
    #tasks overwrite files, so you will likely have to remove files if you
    #re-run the script.
    user_clobber=iraf.envget("clobber")
    iraf.reset(clobber='yes')

    #get the file names of the reduced flat, arc, and ronci mask
    calflat=str(open(caldir+flatlist, 'r').readlines()[0]).strip()
    arc=str(open(caldir+arclist, 'r').readlines()[0]).strip()
    ronchiflat=str(open(caldir+ronchilist, 'r').readlines()[0]).strip()
    #use the first telluric frame as the base name for the combined telluric
    #spectrum
    telluric=str(open(telluriclist, 'r').readlines()[0]).strip()

    
    ############################################################################
    # STEP 2:  Get the Calibrations for the Reduction                          #
    ############################################################################

    #copy required files and transformation database into the current
    #working directory
    iraf.copy(caldir+'rgn'+ronchiflat+'.fits',output='./')
    iraf.copy(caldir+'wrgn'+arc+'.fits',output='./')
    if not os.path.isdir('./database'):
        os.mkdir('./database/')
    iraf.copy(caldir+'database/*',output='./database/')


    ###########################################################################
    # STEP 3:  Reduce the Telluric Standard                                   #
    ###########################################################################

    #prepare the data
    iraf.nfprepare('@'+telluriclist, rawpath='', shiftim=caldir+'s'+calflat,
                    bpm=caldir+'rgn'+calflat+'_sflat_bpm.pl', fl_vardq='yes',
                    fl_int='yes', fl_corr='no', fl_nonl='no', logfile=log)

    iraf.nfprepare('@'+skylist_short, rawpath='', shiftim=caldir+'s'+calflat,
                    bpm=caldir+'rgn'+calflat+'_sflat_bpm.pl', fl_vardq='yes',
                    fl_int='yes', fl_corr='no', fl_nonl='no', logfile=log)

    #do the sky subtraction on all the individual frames. read the
    #list and get rid of '\n' character returns first.
    telluricexps=open(telluriclist, 'r').readlines()
    telluricexps=[word.strip() for word in telluricexps]
    skyexps=open(skylist, 'r').readlines()
    skyexps=[word.strip() for word in skyexps]
    for i in range(len(telluricexps)):
        iraf.gemarith('n'+telluricexps[i], '-', 'n'+skyexps[i],
                    'sn'+telluricexps[i], fl_vardq='yes', logfile=log)

    #reduce and flat field the data
    iraf.nsreduce('sn@'+telluriclist, outpref='r',
                   flatim=caldir+'rgn'+calflat+'_flat', fl_cut='yes',
                   fl_nsappw='no', fl_vardq='yes', fl_sky='no', fl_dark='no',
                   fl_flat='yes', logfile=log)

    #fix bad pixels from the DQ plane
    iraf.nffixbad('rsn@'+telluriclist, outpref='b', logfile=log)

    #derive the 2D to 3D spatial/spectral transformation
    iraf.nsfitcoords('brsn@'+telluriclist, outpref='f', fl_int='no',
                      lamptr='wrgn'+arc, sdisttr='rgn'+ronchiflat,
                      logfile=log, lxorder=4, syorder=4)

    #apply the transformation determined in the nffitcoords step
    iraf.nstransform('fbrsn@'+telluriclist, outpref='t', logfile=log)

    #extract 1D spectra from the 2D data
    iraf.nfextract('tfbrsn@'+telluriclist, outpref='x', diameter=0.5,
                    fl_int='yes', logfile=log)

    #combine all the 1D spectra to one final output file
    iraf.gemcombine('xtfbrsn//@'+telluriclist, output='gxtfbrsn'+telluric,
                     statsec='[*]', combine='median', logfile=log,
                     masktype='none', fl_vardq='yes')

    #make a blackbody spectrum for temp=9480 (A0V star is assumed)
    telheader = pyfits.open('gxtfbrsn'+telluric+'.fits')
    telwave = np.zeros(telheader[1].header['NAXIS1'])
    wstart = telheader[1].header['CRVAL1']
    wdelt = telheader[1].header['CD1_1']
    for i in range(len(telwave)):
        telwave[i] = wstart+(i*wdelt)
    telheader.close()
    iraf.mkspec('blackbody', 'Blacbody', ncols=len(telwave), nlines=1, func=3,
        start_wave=telwave[0], end_wave=telwave[len(telwave)-1], temp=9480)

    
    ###########################################################################
    # Reset to user defaults                                                  #
    ###########################################################################
    if user_clobber == "no":
        iraf.set(clobber='no')

###########################################################################
#          End of the Telluric Calibration Data Reduction                 #
#                                                                         #
#  The output of this reduction script is a 1-D spectrum used for         #
# telluric calibration of NIFS science data.  For this particular         #
# reduction the output file name is "gxtfbrsn"+telluric, or:              #
# gxtfbrsnN20100401S0138. The file prefixes are described below.          #
#                                                                         #
# g = gemcombined/gemarithed   n=nfprepared  s=skysubtracted              #
# r=nsreduced  b = bad pixel corrected  f= run through nffitcoords        # 
# t = nftransformed   x = extracted to a 1D spectrum                      #
#                                                                         #
# This script is meant to be a guideline as a method of a typical data    #
# reduction for NIFS frames.  Of course, NIFS PIs can add or skip steps   #
# in this reduction as they deem fit in order to reduce their particular  #
# datasets.                                                               #
#                                                                         #
###########################################################################
