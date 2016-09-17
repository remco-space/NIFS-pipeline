# go to the rootdir (see below), open pyraf, then type:
# ---> pyexecute("/Users/jlwalsh/Data/py_scripts/LP_2016/quick_reduce/nifs_main_LP_quick.py")

########################################################################################################
# EDIT BELOW

#give the location of where IDL lives on your computer
idlpath = '/Applications/exelis/idl85/bin/idl'
#enter the location of the data reduction python scripts
pyscriptspath = '/Users/jlwalsh/Data/py_scripts/LP_2016/quick_reduce/'

#enter the location to the main directory, the directory where the raw
#data is stored, and the directory that will hold the reduced
#data. make sure to include the / at the end of the string. rootdir
#and datadir need to exist beforehand, reducedir will be created if it
#doesn't already exist.
rootdir = '/Users/jlwalsh/Data/LP_2016/nifs_data/2016b/'
datadir = 'raw_data/'
reducedir = 'reduced_data_quick/'
#give the location where HI.dat, atran5000.fits, and anil_ArXe_K.dat
#files are located
refdir = '/Users/jlwalsh/Data/LP_2016/nifs_reduction_info/quick_reduce/files/'
#provide the sets for which you want to reduce data. enter as a string
#and use a yyyymmdd format. a single date or multiple dates can be
#entered. (e.g., dates = ['20121227'] or dates =
#['20121227','20121230'])
dates = ['20121227']
#galaxies observed over ANY of the dates listed above. use full name
#and lower case (e.g., ngc, ugc, pgc, ic, mrk). this will be used to
#name the directoires.
galaxies = ['ngc1277']
#tellurics observed over ANY of the dates listed above. use full name
#and (e.g., hip, hd, hr) lower case. will be used to name the
#directories.
tellurics = ['hip10848']
#sigma threshold for cosmic ray rejection when constructing the final
#galaxy data cube.
sig_thres = 3.
#you can chose to do some parts of the reduction and not others. to do
#the step enter 'yes', to skip the step enter 'no'.
reduce_sortfiles = 'yes'     #create directory structure and sort files
reduce_daycals = 'yes'        #reduce daycals
reduce_tellurics = 'no'     #reduce telluric stars
reduce_galaxies = 'no'      #basic reduction of galaxy exposures
reduce_combine_gal = 'no'   #merge galaxy cubes
#if combining cubes from the same observing block and don't care about
#the vlsr correction, can skip the step below, which takes time (~30
#mins per catfbrsn*.fits file). to complete the step, enter 'yes' to
#skip the step, enter 'no'. note, if entering 'yes' below you must
#also have entered 'yes' for reduce_combine_gal.
alignwave_vlsrcorr_gal = 'no'

# STOP EDITTING
########################################################################################################

#import some useful python utilities
import sys
sys.path.append(pyscriptspath)
import os
import glob
from nifs_basecalib_LP_quick import nifs_basecalib_LP_quick
from nifs_telluric_LP_quick import nifs_telluric_LP_quick
from nifs_galaxy_LP_quick import nifs_galaxy_LP_quick
from nifs_checkdata_LP import nifs_checkdata_LP
from nifs_checkdata_merged_LP import nifs_checkdata_merged_LP
import pidly
idl = pidly.IDL(idlpath)
import pyfits
import numpy as np
import time
import subprocess

########################################################################################################

# Check that the user has selected at least one data reduction task to
# complete
if reduce_sortfiles == 'no' and reduce_daycals == 'no' and \
    reduce_tellurics == 'no' and reduce_galaxies == 'no' and \
    reduce_combine_gal == 'no':
    sys.exit('You need to set one of the reduction steps to "yes".')


# Run the IDL tasks to write important info to text files, create
# directory structure, and sort files.
if reduce_sortfiles == 'yes':

    print ''
    print 'Gathering info...'
    print ''
    idl.pro('setup_writeinfo', rootdir, rootdir+datadir, dates)
    print ''
    print 'Setting up directories...'
    print ''
    idl.pro('setup_makedirectories', rootdir, rootdir+datadir, rootdir+reducedir,
            dates, galaxies, tellurics)

#########################################################################################################

#loop over each night to reduce the daycals and the tellurics
for a in range(len(dates)):

    os.chdir(rootdir+reducedir+'daycals/'+dates[a])
    obs_setups = glob.glob('*')

    for b in range(len(obs_setups)):

        #work on the baseline calibrations
        workdir = rootdir+reducedir+'daycals/'+dates[a]+'/'+obs_setups[b]+'/'
        
        #the names of the daycal lists
        flatlist = 'flatlist'
        flatdarklist = 'flatdarklist'
        arclist = 'arclist'
        arcdarklist = 'arcdarklist'
        ronchilist = 'ronchilist'

        if reduce_daycals == 'yes':

            print ''
            print 'Starting the baseline calibrations for '+dates[a]+' and '+ obs_setups[b]
            print ''

            #check to see if outputs of data reduction already
            #exist. if so, ask the user whether to proceed. if the
            #user does want to proceed, delete the previous outputs
            #and start over.
            nifs_checkdata_LP(workdir,'basecalib*log*')
        
            #reduce the baseline calibrations
            nifs_basecalib_LP_quick(workdir, dates[a], flatlist, flatdarklist, arclist,
                                    arcdarklist, ronchilist, refdir)


        if reduce_tellurics == 'yes':
            
            os.chdir(rootdir+reducedir+'tellurics/'+dates[a]+'/'+obs_setups[b]+'/')
            telluric_stars = glob.glob('*')
        
            for c in range(len(telluric_stars)):
        
                workdir = rootdir+reducedir+'tellurics/'+dates[a]+'/'+obs_setups[b]+'/'+\
                  telluric_stars[c]+'/'
                caldir = rootdir+reducedir+'daycals/'+dates[a]+'/'+obs_setups[b]+'/'

                print ''
                print 'Starting the telluric '+telluric_stars[c]+' for '+dates[a]+\
                  ' and '+ obs_setups[b]
                print ''

                #check to see if outputs of data reduction already
                #exist. if so, ask the user whether to proceed. if the
                #user does want to proceed, delete the previous
                #outputs and start over.
                nifs_checkdata_LP(workdir,'telluric*log*')

                telluriclist = 'telluriclist'
                skylist = 'skylist'
                skylist_short = 'skylist_short'

                telluric=open(workdir+telluriclist, 'r').readlines()
                telluric=[word.strip() for word in telluric]
                sky=open(workdir+skylist, 'r').readlines()
                sky=[word.strip() for word in sky]
                skyshort=open(workdir+skylist_short, 'r').readlines()
                skyshort=[word.strip() for word in skyshort]

                while len(telluric) != len(sky) or len(sky) == len(skyshort):
                    
                    print ''
                    print '***********************************************************'
                    print 'Please modify telluriclist, skylist, skylist_short in:'
                    print workdir
                    print ''
                    print 'Sky file #1 will be subtracted from telluric file #1, so '\
                          'the number of telluric and sky exposures needs to be the '\
                          'same. It is okay to duplicate sky file names in skylist. '\
                          'However, skylist_short should contain only unique sky file '\
                          'names.'
                    print ''
                    print 'See datalist.txt (e.g., median img value) for help '\
                          'identifying the telluric vs. sky exposures located in: '
                    print rootdir+datadir+dates[a]
                    print ''
                    print 'Also, open a DS9 window if you have not yet done so!'
                    print ''
                    pause = raw_input('When you are done, and ready to proceed, hit return. ')
                    print '***********************************************************'
                    print ''
                    
                    telluric=open(workdir+telluriclist, 'r').readlines()
                    telluric=[word.strip() for word in telluric]
                    sky=open(workdir+skylist, 'r').readlines()
                    sky=[word.strip() for word in sky]
                    skyshort=open(workdir+skylist_short, 'r').readlines()
                    skyshort=[word.strip() for word in skyshort]
                    
                    if len(telluric) != len(sky) or len(sky) <= len(skyshort):
                        print ''
                        print 'TRY AGAIN!'
                        print 'The number of exposures in the telluric list needs to '\
                              'equal the number of exposures in the sky list.'
                        print 'also...'
                        print 'The sky list should contain all the sky exposures (repeated '\
                              'if necessary) while short sky list should contain only '\
                              'unique sky file names.'
                
                
                #reduce the telluric stars
                nifs_telluric_LP_quick(workdir, caldir, dates[a], flatlist, arclist, ronchilist,
                                       telluriclist, skylist, skylist_short)

                #remove the Br-gamma absorption line
                telluric = str(open(workdir+telluriclist, 'r').readlines()[0]).strip()
                infile_telluric = 'gxtfbrsn'+telluric+'.fits'
                idl.pro('fit_kband_brg_anil', workdir, infile_telluric, refdir)

                #divide by blackbody (assumes A0V star) and write the final
                #telluric file
                telluric_noline = pyfits.open(workdir+'cgxtfbrsn'+telluric+'.fits')
                bb = pyfits.open(workdir+'blackbody.fits')
                telluric_noline[1].data = telluric_noline[1].data/bb[0].data
                telluric_noline.writeto(workdir+'cgxtfbrsn'+telluric+'_final.fits', \
                                            output_verify='ignore')
                telluric_noline.close()
                bb.close()


#loop over each galaxy to reduce the galaxy exposures
for a in range(len(galaxies)):
    
    for b in range(len(dates)):

        #dates contains all the days data are to be reduced, but this
        #galaxy may not have been observed on this date. check here.
        if os.path.isdir(rootdir+reducedir+galaxies[a]+'/'+dates[b]):

            #there will only be 1 setup for a galaxy, but find out what that is
            os.chdir(rootdir+reducedir+galaxies[a]+'/'+dates[b])
            obs_setups = glob.glob('hk*')

            if len(obs_setups) != 1:
                sys.exit('More than 1 observation setup found for '+galaxies[a]+'. '\
                            'Cannot handle this yet.')

            workdir = rootdir+reducedir+galaxies[a]+'/'+dates[b]+'/'+obs_setups[0]+'/'
            caldir = rootdir+reducedir+'daycals/'+dates[b]+'/'+obs_setups[0]+'/'

            #the names of the daycal lists
            flatlist = 'flatlist'
            arclist = 'arclist'
            ronchilist = 'ronchilist'

            if reduce_galaxies == 'yes':

                print ''
                print 'Starting the galaxy '+galaxies[a]+' for '+dates[b]+\
                ' and '+ obs_setups[0]
                print ''

                #check to see if outputs of data reduction already
                #exist. if so, ask the user whether to proceed. if the
                #user does want to proceed, delete the previous
                #outputs and start over.
                nifs_checkdata_LP(workdir,galaxies[a]+'*log*')

                gallist = 'gallist'
                skylist = 'skylist'
                skylist_short = 'skylist_short'

                gal=open(workdir+gallist, 'r').readlines()
                gal=[word.strip() for word in gal]
                sky=open(workdir+skylist, 'r').readlines()
                sky=[word.strip() for word in sky]
                skyshort=open(workdir+skylist_short, 'r').readlines()
                skyshort=[word.strip() for word in skyshort]

                while len(gal) != len(sky) or len(sky) == len(skyshort):

                    print ''
                    print '***********************************************************'
                    print 'Please modify gallist, skylist, skylist_short in:'
                    print workdir
                    print ''
                    print 'Sky file #1 will be subtracted from galaxy file #1, so the '\
                          'number of galaxy and sky exposures needs to be the same. It '\
                          'is okay to duplicate sky file names in skylist. However, '\
                          'skylist_short should contain only unique sky file names.'
                    print ''
                    print 'See datalist.txt (e.g., median img value, x/y offsets) for '\
                          'help identifying the galaxy vs. sky exposures located in: '
                    print rootdir+datadir+dates[b]
                    print ''
                    print 'Also, open a DS9 window if you have not yet done so!'
                    print ''
                    pause = raw_input('When you are done, and ready to proceed, hit return. ')
                    print '***********************************************************'
                    print ''
        
                    gal=open(workdir+gallist, 'r').readlines()
                    gal=[word.strip() for word in gal]
                    sky=open(workdir+skylist, 'r').readlines()
                    sky=[word.strip() for word in sky]
                    skyshort=open(workdir+skylist_short, 'r').readlines()
                    skyshort=[word.strip() for word in skyshort]
                    
                    if len(gal) != len(sky) or len(sky) <= len(skyshort):
                        print ''
                        print 'TRY AGAIN!'
                        print 'The number of exposures in the galaxy list needs to '\
                              'equal the number of exposures in the sky list.'
                        print 'also...'
                        print 'The sky list should contain all the sky exposures (repeated '\
                              'if necessary) while short sky list should contain only '\
                              'unique sky file names.'

                
                #get the full path and name of final 1D telluric spectrum
                telluric = ''
                while not os.path.isfile(telluric):
                    telluric = raw_input('Enter the full path and name for the reduced '\
                                            '1D telluric (e.g., cgxtfbrsn*_final.fits): ')
                    if telluric[0:1] == '"' or telluric[0:1] == "'":
                        telluric = telluric[1:-1]
                    if not os.path.isfile(telluric):
                        print 'Cannot find file. Did you enter the full path and '\
                        'name correctly?'
        
        
                #reduce the galaxy exposures
                nifs_galaxy_LP_quick(workdir, caldir, dates[b], flatlist, arclist,
                                     ronchilist, telluric, galaxies[a], gallist, skylist,
                                     skylist_short)

            
                #create the 3D cube. use anil's version of nifcube
                os.chdir(workdir)
                atlistfile = 'atlist'
                tmp=subprocess.call(['ls -1 atfbrsn*.fits > '+atlistfile],\
                                        stderr=open(os.devnull,'w'),shell=True)
                timenow = time.localtime()
                print ''
                print 'This step will take a while, please be patient! (Each atfbrsn*.fits file'\
                ' takes ~8 mins.) The time right now is '+str(timenow[3])+':'+str(timenow[4])
                print ''
                idl.pro('run_nifcube_anil', workdir, atlistfile)

        
                #copy the cubes to the merged directory
                gal_cubes = glob.glob('catfbrsn*.fits')
                for c in range(len(gal_cubes)):
                    tmp=subprocess.call(['cp',workdir+gal_cubes[c],rootdir+reducedir+galaxies[a]+\
                                         '/merged/'+obs_setups[0]+'/'],stderr=open(os.devnull,'w'))


    if reduce_combine_gal == 'yes':

        workdir = rootdir+reducedir+galaxies[a]+'/merged/'+obs_setups[0]+'/'
        
        #may have a combined cube from another night, but now have an
        #additional night and want to combine everything. remove any
        #files that are not 'catfbrsn*.fits' and start the process
        #over, but check with the user first.
        nifs_checkdata_merged_LP(workdir,'*_shift.fits')
        
        os.chdir(workdir)
        gal_cubes = glob.glob('catfbrsn*.fits')

        if len(gal_cubes) <= 1:
            sys.exit('Cannot find more than 1 cube to combine. There needs to be at '+\
                     'least 2 catfbrsn*.fits files in '+workdir+'.')
    
        #determine the barycentric correction for a reference galaxy
        #cube in the merged directory (just taking the first cube).
            
        galheader = pyfits.open(workdir+gal_cubes[0])
        ra = (galheader[0].header['RA'])/15.
        dec = galheader[0].header['DEC']
        dateobs = galheader[0].header['DATE-OBS']
        dateobs_yr = dateobs[0:4]
        dateobs_month = dateobs[5:7]
        dateobs_day = dateobs[8:10]
        ut = galheader[0].header['UT']
        ut_hrs = ut[0:2]
        ut_mins = ut[3:5]
        ut_sec = ut[6:10]
            
        vlsr_corr = idl.func('vlsr_anil', ra, dec,  dateobs_yr, dateobs_month,
                                 dateobs_day, ut_hrs, ut_mins, ut_sec)
            
        galheader.close()

        
        #put all the galaxy cubes on the same wavelength scale. use
        #the first file as the reference image and make the vlsr
        #correction for the date/time of the reference file. the
        #reference file is the first cube.

        #corfiles shouldn't have the .fits at the end
        corfiles = gal_cubes
        for b in range(len(corfiles)):
            tmp = corfiles[b]
            corfiles[b] = str(tmp[0:len(tmp)-5])

        if alignwave_vlsrcorr_gal == 'yes':
        
            timenow = time.localtime()
            print ''
            print 'This step will take a while, please be patient! (Each catfbrsn*.fits file'\
            ' will take ~30 mins.) The time right now is '+str(timenow[3])+':'+str(timenow[4])
            print ''
            idl.pro('run_shift_anil', workdir, corfiles, vlsr_corr)

        if alignwave_vlsrcorr_gal == 'no':
            for b in range(len(corfiles)):
                tmp=subprocess.call(['cp',workdir+corfiles[b]+'.fits',workdir+corfiles[b]+\
                                     '_shift.fits'],stderr=open(os.devnull,'w'))

    
        #collpase the data cubes and determine the spatial integer offsets
        #relative to the first file
        offset_cubes = glob.glob('*_shift.fits')
        offsets = idl.func('find_offsets_lp', workdir, offset_cubes, 'offset_gauss')
      
        #print to an output file
        offsetlist = open(workdir+'offset.list','w')
        offsetlist.write('%s\n' % '#x, y offsets (pixels) needed to match first entry')
        offsetlist.write('%s\n' % '#using center from 2D Gaussian fit.')
        for b in range(len(offset_cubes)):
            outstr = '%8.2f %8.2f\n' % (offsets[b][0], offsets[b][1])
            offsetlist.write(outstr)
        offsetlist.close()
    
    
        #align cubes spatially and combine with a cosmic ray rejection
        outcubefile = galaxies[a]+'_combined.fits'
        offsetlist = 'offset.list'
        timenow = time.localtime()
        print ''
        print 'This step is working, please be patient! (Generating the combined fits file '\
        'will take ~5 mins.) The time right now is '+str(timenow[3])+':'+str(timenow[4])
        print ''
        idl.pro('cube_combine_lp', workdir, offset_cubes, offsetlist, sig_thres, outcubefile)
