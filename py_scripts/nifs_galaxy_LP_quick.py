def nifs_galaxy_LP_quick(workdir, caldir, date, flatlist, arclist, ronchilist,
                         telluric, galname, gallist, skylist, skylist_short):

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

    #unlearn the used tasks
    iraf.unlearn(iraf.gemini,iraf.gemtools,iraf.gnirs,iraf.nifs)
    iraf.set(stdimage='imt2048')

    #create a log file and back up the previous one if it already exists
    log = galname+'_'+date+'.log'
    if os.path.exists(log):
        t = time.localtime()
        app = "_"+str(t[0])+str(t[1]).zfill(2)+str(t[2]).zfill(2)+'_'+ \
        str(t[3]).zfill(2)+':'+str(t[4]).zfill(2)+':'+str(t[5]).zfill(2)
        shutil.move(log,log+app)

    #change to the workdir within pyraf
    iraffunctions.chdir(workdir)
        
    #prepare the package for NIFS
    iraf.nsheaders('nifs',logfile=log)

    #set clobber to 'yes' for the script. this still does not make the
    #gemini tasks overwrite files, so you will likely have to remove
    #files if you re-run the script.
    user_clobber=iraf.envget("clobber")
    iraf.reset(clobber='yes')

    #get the file names of the reduced flat, arc, and ronci mask
    calflat=str(open(caldir+flatlist, 'r').readlines()[0]).strip()
    arc=str(open(caldir+arclist, 'r').readlines()[0]).strip()
    ronchiflat=str(open(caldir+ronchilist, 'r').readlines()[0]).strip()

    
    ###########################################################################
    # STEP 2:  Get the Calibrations for the Reduction                         #
    ###########################################################################

    #copy required files and transformation database into the current
    #working directory
    iraf.copy(caldir+'rgn'+ronchiflat+'.fits',output='./')
    iraf.copy(caldir+'wrgn'+arc+'.fits',output='./')
    if not os.path.isdir('./database'):
        os.mkdir('./database/')
    iraf.copy(caldir+'database/*',output='./database/')

    
    ###########################################################################
    # STEP 3:  Reduce the Science Data                                        #
    ###########################################################################

    iraf.nfprepare('@'+gallist, rawpath='', shiftimage=caldir+'s'+calflat,
                    fl_vardq='yes', bpm=caldir+'rgn'+calflat+'_sflat_bpm.pl',
                    logfile=log)

    iraf.nfprepare('@'+skylist_short, rawpath='', shiftimage=caldir+'s'+calflat,
                    fl_vardq='yes', bpm=caldir+'rgn'+calflat+'_sflat_bpm.pl',
                    logfile=log)

    #read in the frame lists (removing '\n' line breaks from the strings)
    galexps=open(gallist, 'r').readlines()
    galexps=[word.strip() for word in galexps]
    skyexps=open(skylist, 'r').readlines()
    skyexps=[word.strip() for word in skyexps]
    for i in range(len(galexps)):
        iraf.gemarith('n'+galexps[i], '-', 'n'+skyexps[i], 'sn'+galexps[i],
                       fl_vardq='yes', logfile=log)

    #flat field and cut the data
    iraf.nsreduce('sn@'+gallist, fl_cut='yes', fl_nsappw='yes', fl_dark='no',
                   fl_sky='no', fl_flat='yes',
                   flatimage=caldir+'rgn'+calflat+'_flat', fl_vardq='yes',
                   logfile=log)

    #interpolate over bad pixels flagged in the DQ plane
    iraf.nffixbad_anil('rsn@'+gallist,logfile=log)

    #derive the 2D to 3D spatial/spectral transformation
    iraf.nsfitcoords('brsn@'+gallist,lamptransf='wrgn'+arc, 
                      sdisttransf='rgn'+ronchiflat, logfile=log,
                      fl_int='no', lxorder=4, syorder=4)

    #apply the transformation determined in the nffitcoords step
    iraf.nstransform('fbrsn@'+gallist, logfile=log)

    #correct the data for telluric absorption features
    iraf.nftelluric_anil('tfbrsn@'+gallist, telluric, fl_flux='no',
                          fl_twea='no', logfile=log)

    
    ###########################################################################
    # Reset to user defaults                                                  #
    ###########################################################################
    if user_clobber == "no":
        iraf.set(clobber='no')

        
###########################################################################
#          End of the Science Data Reduction                              #
#                                                                         #
# The output of this reduction is a set of 3-D data cubes that have been  #
# sky subtracted, flat fielded, cleaned for bad pixels, telluric          #
# corrected and rectified into a cohesive datacube format.  In the case   #
# of this reduction, the final output files are called: catfbrgn+science, #
# or: catfbrgnN20100401S0182.fits                                         #
#     catfbrgnN20100401S0184.fits                                         #
#     catfbrgnN20100401S0186.fits                                         #
#     catfbrgnN20100401S0188.fits                                         #
#                                                                         #
# The meaning of the output prefixes are described below:                 #
#                                                                         #
# g = gemcombined   n=nfprepared  s=skysubtracted   r=nsreduced           #
# b = bad pixel corrected  f= run through nffitcoords                     # 
# t = nftransformed   a = corrected for telluric absorption features      #
# c = rectified to a 3D datacube                                          #
#                                                                         #
# This script is meant to be a guideline as a method of a typical data    #
# reduction for NIFS frames.  Of course, NIFS PIs can add or skip steps   #
# in this reduction as they deem fit in order to reduce their particular  #
# datasets.                                                               #
#                                                                         #
###########################################################################

