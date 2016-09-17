def nifs_checkdata_merged_LP(workdir,filecheck):
    
    import sys
    import os
    import glob
    import subprocess

    if len(glob.glob(workdir+filecheck)) > 0:

        print ''
        print 'There are outputs from a previous reduction already.'

        response = ''
        while not response == 'yes' or response == 'no':
            
            response = raw_input('Do you want to delete these files and '\
                                 'combine the cubes from scratch (yes/no)? ')

            if response[0:1] == '"' or response[0:1] == "'":
                response = response[1:-1]

            if response == 'yes':

                tmp=subprocess.call(['rm']+glob.glob(os.path.join(workdir,'*_shift.fits')),\
                                    stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['rm']+glob.glob(os.path.join(workdir,'*combine*')),\
                                    stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['rm']+glob.glob(os.path.join(workdir,'*list*')),\
                                    stderr=open(os.devnull,'w'))

            if response == 'no':
                sys.exit('Okay, NOT deleting any files. Modify inputs to the pipeline and run again.')

            if response != 'yes' and response != 'no':
                print 'That is not one of the choices. Enter again.'
