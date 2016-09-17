def nifs_basecalib_LP_quick(workdir, date, flatlist, flatdarklist, arclist,
                            arcdarklist, ronchilist, refdir):

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
    from pyraf import iraffunctions
    import pyfits

    #unlearn the used tasks
    iraf.unlearn(iraf.gemini,iraf.gemtools,iraf.gnirs,iraf.nifs)
    iraf.set(stdimage='imt2048')
    
    #create a log file and back up the previous one if it already
    #exists
    log = 'basecalib_'+date+'.log'
    if os.path.exists(log):
        t = time.localtime()
        app = '_'+str(t[0])+str(t[1]).zfill(2)+str(t[2]).zfill(2)+'_'+ \
        str(t[3]).zfill(2)+':'+str(t[4]).zfill(2)+':'+str(t[5]).zfill(2)
        shutil.move(log,log+app)

    #change to the workdir within pyraf
    iraffunctions.chdir(workdir)

    #prepare the package for NIFS
    iraf.nsheaders('nifs',logfile=log)

    #set clobber to 'yes' for the script. this still does not make the
    #gemini tasks overwrite files, so you will likely have to remove
    #files if you re-run the script.
    user_clobber=iraf.envget('clobber')
    iraf.reset(clobber='yes')

    #set the file names for the main calibration outputs. just use the
    #first name in the list of relevant files, which we get from the
    #file lists
    calflat=str(open(flatlist, 'r').readlines()[0]).strip()
    flatdark=str(open(flatdarklist, 'r').readlines()[0]).strip()
    arcobj=str(open(arclist, 'r').readlines()[0]).strip()
    arcdark=str(open(arcdarklist, 'r').readlines()[0]).strip()
    ronchiflat=str(open(ronchilist, 'r').readlines()[0]).strip()

    ###########################################################################
    #  STEP 2: Determine the shift to the MDF file  		                  #
    ###########################################################################

    iraf.nfprepare(calflat, rawpath='', outpref='s', shiftx='INDEF',
                   shifty='INDEF', fl_vardq='no', fl_corr='no', fl_nonl='no',
                   logfile=log)

    
    ###########################################################################
    #  STEP 3: Make the Flat Field and BPM  		                          #
    ###########################################################################
        
    iraf.nfprepare('@'+flatlist, rawpath='', shiftim='s'+calflat,
                    fl_vardq='yes', fl_inter='yes', fl_corr='no',
                    fl_nonl='no', logfile=log)
                   
    iraf.nfprepare('@'+flatdarklist, rawpath='', shiftim='s'+calflat,
                    fl_vardq='yes', fl_inter='yes', fl_corr='no',
                    fl_nonl='no', logfile=log)

    iraf.gemcombine('n//@'+flatlist, output='gn'+calflat, fl_dqpr='yes',
                    fl_vardq='yes', masktype='none', logfile=log)
    iraf.gemcombine('n//@'+flatdarklist, output='gn'+flatdark, fl_dqpr='yes',
                    fl_vardq='yes', masktype='none', logfile=log)

    iraf.nsreduce('gn'+calflat, fl_cut='yes', fl_nsappw='yes', fl_vardq='yes',
                   fl_sky='no', fl_dark='no', fl_flat='no', logfile=log)
    iraf.nsreduce('gn'+flatdark, fl_cut='yes', fl_nsappw='yes', fl_vardq='yes',
                   fl_sky='no', fl_dark='no', fl_flat='no', logfile=log)

    #creating flat image, final name = rgnN....._sflat.fits
    iraf.nsflat('rgn'+calflat, darks='rgn'+flatdark,
                 flatfile='rgn'+calflat+'_sflat', darkfile='rgn'+flatdark+'_dark',
                 fl_save_dark='yes', process='fit', thr_flo=0.15, thr_fup=1.55,
                 fl_vardq='yes', logfile=log)

    #rectify the flat for slit function differences - make the final flat
    iraf.nsslitfunction('rgn'+calflat, 'rgn'+calflat+'_flat',
                         flat='rgn'+calflat+'_sflat',
                         dark='rgn'+flatdark+'_dark', combine='median', order=3,
                         fl_vary='no', logfile=log)

    
    ###########################################################################
    # STEP 4: Reduce the Arcs and determine the wavelength solution           #
    ###########################################################################

    iraf.nfprepare('@'+arclist, rawpath='', shiftimage='s'+calflat,
                    bpm='rgn'+calflat+'_sflat_bpm.pl', fl_vardq='yes',
                    fl_corr='no', fl_nonl='no', logfile=log)

    iraf.nfprepare('@'+arcdarklist, rawpath='', shiftimage='s'+calflat,
                    bpm='rgn'+calflat+'_sflat_bpm.pl', fl_vardq='yes',
                    fl_corr='no', fl_nonl='no', logfile=log)

    #determine the number of input arcs and arc darks so that the routine runs
    #automatically for single or multiple files.

    nfiles = len(open(arclist).readlines())
    if nfiles > 1:
        iraf.gemcombine('n//@'+arclist, output='gn'+arcobj,
                         fl_dqpr='yes', fl_vardq='yes', masktype='none',
                         logfile=log)
    else:
        iraf.copy('n'+arcobj+'.fits','gn'+arcobj+'.fits')
    
    nfiles = len(open(arcdarklist).readlines())
    if nfiles > 1:
        iraf.gemcombine('n//@'+arcdarklist, output='gn'+arcdark,
                         fl_dqpr='yes', fl_vardq='yes', masktype='none',
                         logfile=log)
    else:
        iraf.copy('n'+arcdark+'.fits','gn'+arcdark+'.fits')

    iraf.nsreduce('gn'+arcobj, outpr='r', darki='gn'+arcdark,
                   flati='rgn'+calflat+'_flat', fl_vardq='no', fl_cut='yes',
                   fl_nsappw='yes', fl_sky='no', fl_dark='yes',fl_flat='yes',
                   logfile=log)

    #determine the wavelength of the observation and set the arc
    #coordinate file. if the user wishes to change the coordinate file
    #to a different one, they need only to change the "clist" variable
    #to their line list in the coordli= parameter in the nswavelength
    #call.

    hdulistobj = pyfits.open('rgn'+arcobj+'.fits')
    bandobj = hdulistobj[0].header['GRATING'][0:1]

    if bandobj == "Z":
        clistobj="nifs$data/ArXe_Z.dat"
        my_threshobj=100.0
    elif bandobj == "K":
        clistobj=refdir+'anil_ArXe_K.dat'  #"nifs$data/ArXe_K.dat"
        my_threshobj=50.0
    else:
        clistobj="gnirs$data/argon.dat"
        my_threshobj=100.0    
        
    #for this quick reduction will turn off interactive mode for the wavelength
    #calibration!
    iraf.nswavelength('rgn'+arcobj, coordli=clistobj, nsum=10,
                       thresho=my_threshobj, trace='yes', fwidth=2.0, match=-6,
                       cradius=8.0, fl_inter='no', nfound=10, nlost=10,
                       logfile=log)

    
    ##############################################################################
    # STEP 5: Trace the spatial curvature/spectral distortion in the Ronchi flat #
    ##############################################################################

    iraf.nfprepare('@'+ronchilist, rawpath='', shiftimage='s'+calflat,
                    bpm='rgn'+calflat+'_sflat_bpm.pl', fl_vardq='yes',
                    fl_corr='no', fl_nonl='no', logfile=log)

    #determine the number of input Ronchi calibration mask files and
    #Ronchi dark files so that the routine runs automatically for
    #single or multiple files.
    nfiles = len(open(ronchilist).readlines())
    if nfiles > 1:
        iraf.gemcombine('n//@'+ronchilist, output='gn'+ronchiflat,
                         fl_dqpr='yes', masktype='none', fl_vardq='yes',
                         logfile=log)
    else:
        iraf.copy('n'+ronchiflat+'.fits','gn'+ronchiflat+'.fits')

    iraf.nsreduce('gn'+ronchiflat, outpref='r', dark='rgn'+flatdark+'_dark',
                   flatimage='rgn'+calflat+'_flat', fl_cut='yes',
                   fl_nsappw='yes', fl_flat='yes', fl_sky='no', fl_dark='yes',
                   fl_vardq='no', logfile=log)

    iraf.nfsdist('rgn'+ronchiflat, fwidth=6.0, cradius=8.0, glshift=2.8,
                  minsep=6.5, thresh=2000.0, nlost=3, fl_inter='yes',
                  logfile=log)

                  
    ###########################################################################
    # Reset to user defaults                                                  #
    ###########################################################################
    if user_clobber == "no":
        iraf.set(clobber='no')


###########################################################################
# End of the Baseline Calibration reduction                               #
###########################################################################
#	                                                                      #
#  The final output files created from this script for later science      #
#  reduction have prefixes and file names of:                             #
#     1. Shift reference file:  "s"+calflat                               #
#     2. Flat field:  "rn"+calflat+"_flat"                                #
#     3. Flat BPM (for DQ plane generation):  "rn"+calflat+"_flat_bpm.pl" #
#     4. Wavelength referenced Arc:  "wrgn"+arc                           #
#     5. Spatially referenced Ronchi Flat:  "rgn"+ronchiflat              #
#     For this reduction,                                                 #
#        Shift ref. file =   sN20100410S0362.fits                         #
#        Flat field      =  rgnN20100410S0362_flat.fits                   #
#        Flat BPM        =  rgnN20100410S0362_sflat_bpm.pl                #
#        Arc frame       =  wrgnN20100401S0181.fits                       #
#        Ronchi flat     =  rgnN20100410S0375.fits                        #
#	                                                                      #
#  NOTE:  Other important information for reducing the science data is    #
#    included in the "database" directory that is created and edited      #
#    within the above "nswavelength" and "nfsdist" IRAF calls. For a      #
#    proper science reduction to work (particularly the "nsfitcoords"     #
#    step), the science data must either be reduced in the same directory #
#    as the calibrations, or the whole "database" directory created by    #
#    this script must be copied into the working science reduction        #
#    directory.                                                           #
#                                                                         #
###########################################################################
