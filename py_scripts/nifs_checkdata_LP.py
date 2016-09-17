def nifs_checkdata_LP(workdir,filecheck):

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
                                'reduce from scratch (yes/no)? ')

            if response[0:1] == '"' or response[0:1] == "'":
                response = response[1:-1]

            if response == 'yes':

                tmp=subprocess.call(['mkdir',workdir+'holdtmp/'],stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['mv']+glob.glob(os.path.join(workdir,'N*.fits'))+[workdir+'holdtmp/'],\
                                    stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['mv']+glob.glob(os.path.join(workdir,'*list*'))+[workdir+'holdtmp/'],\
                                    stderr=open(os.devnull,'w'))
                if os.path.isdir(workdir+'database/'):
                    tmp=subprocess.call(['rm','-r',workdir+'database/'],stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['rm']+glob.glob(os.path.join(workdir,'*')),stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['mv']+glob.glob(os.path.join(workdir+'holdtmp/','*'))+[workdir],\
                                    stderr=open(os.devnull,'w'))
                tmp=subprocess.call(['rm','-r',workdir+'holdtmp/'],stderr=open(os.devnull,'w'))

            if response == 'no':
                sys.exit('Okay, NOT deleting any files. Modify inputs to the pipeline and run again.')

            if response != 'yes' and response != 'no':
                print 'That is not one of the choices. Enter again.'

