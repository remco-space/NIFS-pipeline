# Copyright(c) 2006 Association of Universities for Research in Astronomy, Inc.

procedure nffixbad_anil(inimages)

# Fix bad pixels in a NIFS dispersed image with one image in 
# each SCI, VAR, and DQ extension.
#
# Version September 19, 2005  PJM  v1.0 release
#
# History: 19-SEP-05  PJM - Creation based on nfcrcej.cl.
#          15-NOV-05  KL  - Incorporate into Gemini's NIFS package.  bpmfile
#                           parameter removed for now.
#
# Still to do:
#
# - 

char    inimages    {prompt="Input NIFS images"}
char    outimages   {"",       prompt="Output images"}
char    outpref     {"b",      prompt="Prefix for output images"}
char    sci_ext     {"SCI",    prompt="Name of science extension"}
char    var_ext     {"VAR",    prompt="Name of variance extension"}
char    dq_ext      {"DQ",     prompt="Name of data quality extension\n"}

char    logfile     {"",       prompt="Logfile"}
bool    verbose     {yes,      prompt="Verbose output?"}
int     status      {0,        prompt="Exit status (0=good)"}
struct  *scanfile   {"",       prompt="Internal use only"}

begin

    # Define local variables.
    char    l_inimages = ""
    char    l_outimages = ""
    char    l_outpref = ""
    char    l_logfile = ""
    char    l_sci_ext = ""
    char    l_var_ext = ""
    char    l_dq_ext = ""
    bool    l_verbose

    # Define run time variables.
    bool    debug
    int     nver, version, nimages, i, nmissing, noutimages, junk
    char    tmpsci, tmpvar, tmpdq, sec, scisec, varsec, dqsec
    char    tmpfile, tmpinimg, tmpoutimg
    char    keyfound, errmsg, filename, outputstr, astring
    char    in[200], out[200]
    int     maximages = 200
    real    defvar = 99999.
    struct  sdate, line

    # Set local variable values.
    junk = fscan (inimages, l_inimages)
    junk = fscan (outimages, l_outimages)
    junk = fscan (outpref, l_outpref)
    junk = fscan (sci_ext, l_sci_ext)
    junk = fscan (var_ext, l_var_ext)
    junk = fscan (dq_ext, l_dq_ext)
    junk = fscan (logfile, l_logfile)
    l_verbose     = verbose

    # Make temporary files.
    tmpsci        = ""      # dummy, TBD later
    tmpvar        = ""      # dummy, TBD later
    tmpdq         = ""      # dummy, TBD later
    tmpfile       = mktemp ("tmpfile")
    tmpinimg      = mktemp ("tmpinimg")
    tmpoutimg     = mktemp ("tmpoutimg")

     # Initialize variables.
    status      = 0
    debug       = no

    # Keep task parameters from changing from the outside.
    cache ("gimverify", "gemdate", "gemextn")

    # Test the logfile.
    if (l_logfile == "") {
        l_logfile = nifs.logfile
        if (l_logfile == "") {
            l_logfile = "nifs.log"
            printlog("WARNING - NFFIXBAD: Both nffixbad.logfile and \
                nifs.logfile are empty.", l_logfile, l_verbose)
            printlog ("                    Using default file nifs.log.",
                l_logfile, l_verbose)
        }
    }

    # Start logging.
    date | scan(sdate)
    printlog ("--------------------------------------------------------------\
        --------------", l_logfile, l_verbose)
    printlog ("NFFIXBAD -- "//sdate, l_logfile, l_verbose)
    printlog ("", l_logfile, l_verbose)

    # Logs the parameters:
    printlog ("Input images         = "//l_inimages, l_logfile, l_verbose)
    printlog ("Output images        = "//l_outimages, l_logfile, l_verbose)
    printlog ("Output prefix        = "//l_outpref, l_logfile, l_verbose)
    printlog ("sci_ext              = "//l_sci_ext, l_logfile, l_verbose)
    printlog ("var_ext              = "//l_var_ext, l_logfile, l_verbose)
    printlog ("dq_ext               = "//l_dq_ext, l_logfile, l_verbose)
    printlog ("logfile              = "//l_logfile, l_logfile, l_verbose)
    printlog ("verbose              = "//l_verbose, l_logfile, l_verbose)
    printlog ("", l_logfile, l_verbose)

    # Test the SCI extension name.
    if (l_sci_ext == "") {
        printlog ("ERROR - NFFIXBAD: Science extension name SCI_EXT is not \
            defined.", l_logfile, yes)
        status = 121
    }

    # Test the VAR extension name.
    if (l_var_ext == "") {
        printlog ("ERROR - NFFIXBAD: Variance extension name VAR_EXT is not \
            defined.", l_logfile, yes)
        status = 121
    }

    # Test the DQ extension name.
    if (l_dq_ext == "") {
        printlog("ERROR - NFFIXBAD: Data quality extension name DQ_EXT is \
            not defined.", l_logfile, yes)
        status = 121
    }               

    # Exit if error above
    if (status != 0)
        goto clean

    # Load up the array of input file names
    gemextn (l_inimages, check="", process="none", index="", extname="",
        extversion="", ikparams="", omit="extension", replace="",
        outfile=tmpfile, logfile=l_logfile, verbose=l_verbose)
    gemextn ("@"//tmpfile, check="exist,mef", process="none", index="",
        extname="", extversion="", ikparams="", omit="", replace="",
        outfile=tmpinimg, logfile=l_logfile, verbose=l_verbose)
    nimages = gemextn.count
    delete (tmpfile, ver-, >& "dev$null")
    
    if ((gemextn.fail_count > 0) || (nimages == 0) || \
        (nimages > maximages)) {
        
        if (gemextn.fail_count > 0) {
            errmsg = gemextn.fail_count//" images were not found."
            status = 101
        } else if (nimages == 0) {
            errmsg = "No input images defined."
            status = 121
        } else if (nimages > maximages) {
            errmsg = "Maximum number of input images ("//str(maximages)//") \
                has been exceeded."
            status = 121
        }
        
        printlog ("ERROR - NFFIXBAD: "//errmsg, l_logfile, verbose+)
        goto clean
    } else {
        scanfile = tmpinimg
        i = 0
        while (fscan(scanfile, filename) != EOF) {
            i += 1
            in[i] = filename
        }
        scanfile = ""
        if (i != nimages) {
            status = 99
            printlog ("ERROR - NFFIXBAD: Error while counting the input \
                images.", l_logfile, verbose+)
            goto clean
        }
    }
    
    # Input images must have VAR and DQ planes
    gemextn ("@"//tmpinimg, process="append", extname=l_var_ext, 
        check="ext=exists", index="", extversion="", ikparams="", omit="",
        replace="", outfile="dev$null", logfile=l_logfile, glogpars="",
        verbose=l_verbose)
    nmissing = gemextn.fail_count
    gemextn ("@"//tmpinimg, process="append", extname=l_dq_ext,
        check="ext=exists", index="", extversion="", ikparams="", omit="",
        replace="", outfile="dev$null", logfile=l_logfile, glogpars="",
        verbose=l_verbose)
    nmissing += gemextn.fail_count
    if (nmissing > 0) {
        status = 123
        printlog ("ERROR - NFFIXBAD: Not all images have variance and data \
            quality planes.", l_logfile, verbose+)
        goto clean
    }


    # Load up the array of output file names
    if (l_outimages != "")
        outputstr = l_outimages
    else if (l_outpref != "") {
        gemextn ("@"//tmpinimg, check="", process="none", index="", extname="",
            extversion="", ikparams="", omit="path", replace="",
            outfile=tmpoutimg, logfile=l_logfile, glogpars="",
            verbose=l_verbose)
        outputstr = l_outpref//"@"//tmpoutimg
    } else {
        status = 121
        printlog ("ERROR - NFFIXBAD: Neither output image name nor output \
            prefix are defined.", l_logfile, verbose+)
        goto clean
    }
    
    gemextn (outputstr, check="", process="none", index="", extname="",
        extversion="", ikparams="", omit="extension", replace="",
        outfile=tmpfile, logfile=l_logfile, glogpars="", verbose=l_verbose)
    delete (tmpoutimg, ver-, >& "dev$null")
    gemextn ("@"//tmpfile, check="absent", process="none", index="",
        extname="", extversion="", ikparams="", omit="", replace="",
        outfile=tmpoutimg, logfile=l_logfile, glogpars="", verbose=l_verbose)
    noutimages = gemextn.count
    delete (tmpfile, ver-, >& "dev$null")
    
    if ((gemextn.fail_count > 0) || (noutimages == 0) || \
        (noutimages != nimages)) {
        
        if (gemextn.fail_count > 0) {
            errmsg = gemextn.fail_count//" images(s) already exist(s)."
            status = 102
        } else if (noutimages == 0) {
            errmsg = "No output images defined."
            status = 121
        } else if (noutimages != nimages) {
            errmsg = "Different number of input images ("//nimages//") and \
                output images ("//noutimages//")."
            status = 121
        }
        
        printlog ("ERROR - NFFIXBAD: "//errmsg, l_logfile, verbose+)
        goto clean
    } else {
        scanfile = tmpoutimg
        i = 0
        while (fscan (scanfile, filename) != EOF) {
            i += 1
            out[i] = filename//".fits"
        }
        scanfile = ""
        if (i != noutimages) {
            status = 99
            printlog ("ERROR - NFFIXBAD: Error while counting the output \
                images.", l_logfile, verbose+)
            goto clean
        }
    }
    delete (tmpinimg, ver-, >& "dev$null")
    delete (tmpoutimg, ver-, >& "dev$null")

    # Do the work, one image at a time
    for (i=1; i<=nimages; i+=1) {
    
        # This is so slow, let the user know something is going on
        printlog ("Working on image "//in[i], l_logfile, l_verbose)
        
        # Get the number of science extensions in input image.
        gemextn (in[i], check="exists", process="expand", index="", \
            extname=l_sci_ext, extversion="1-", ikparams="", omit="", \
            replace="", outfile="dev$null", logfile="", glogpars="",
            verbose-)
        if (0 != gemextn.fail_count || 0 == gemextn.count) {
            printlog ("ERROR - NFFIXBAD: Bad science data in " // in[i] // ".",
                l_logfile, verbose+)
            status = 123
            goto clean
        }
        nver = gemextn.count

        if (debug) print ("Image "//i//" has "//nver//" extensions.") 

        # Copy the input to the output file.
        fxcopy (in[i], out[i], groups="", new_file+, ver-)
    
        # Clean each SCI extension using the corresponding DQ extension.
        
        for (version = 1; version <= nver; version = version+1) {
            # Create tmp names to be used for images within this for-loop
            tmpsci = mktemp ("tmpsci")
            tmpvar = mktemp ("tmpvar")
            tmpdq = mktemp ("tmpdq")

            if (debug) print ("processing extension ", version)

            scisec = "[" // l_sci_ext // "," // version // "]"
            varsec = "[" // l_var_ext // "," // version // "]"
            dqsec = "[" // l_dq_ext // "," // version // "]"

            if (debug) print ("copying image SCI extension...")

            # Copy the image SCI extension to a temporary file.
            imcopy (out[i]//scisec, tmpsci, verbose-)

            if (debug) print ("copying image DQ extension...")

            # Copy the image DQ extension to a temporary file.
            imcopy (out[i]//dqsec, tmpdq, verbose-)

            if (debug) print ("running FIXPIX...")

            # Run FIXPIX to interpolate over bad pixels in narrowest direction.
            proto.fixpix (tmpsci, tmpdq, linterp="INDEF", cinterp="INDEF",
                verbose=no, pixels=no)

            if (debug) print ("copying result...")
            
            # Put the image back in the SCI extension.
            sec = "[" // l_sci_ext // "," // version // ",overwrite]"
            imcopy (tmpsci, out[i]//sec, verbose-)
            
            # Set variance of 'fixed' pixels to default, high value
#            imexpr ("(b == 0) ? a : "//str(defvar), tmpvar, out[i]//varsec, 
#                tmpdq, dims="auto", intype="auto", outtype="auto",
#                refim="auto", bwidth=0, btype="nearest", bpixval=0.,
#                rangech+, verbose-, exprdb="none", lastout="")
            #  Added to get rid of high values for variance image, 
            #    just interpolate: ACS 12/08
            # Copy the image var extension to a temporary file.
            imcopy (out[i]//varsec, tmpvar, verbose-)
	    proto.fixpix (tmpvar, tmpdq, linterp="INDEF", cinterp="INDEF",
                verbose=no, pixels=no)
	    ###The above lines I added, ACS 12/08####
            sec = "[" // l_var_ext // "," // version // ",overwrite]"
            imcopy (tmpvar, out[i]//sec, verbose-)

            imdelete (tmpsci, verify-, >& "dev$null")
            imdelete (tmpvar, verify-, >& "dev$null")
            imdelete (tmpdq, verify-, >& "dev$null")
            
        }

        # Update headers.
        gemdate ()
        nhedit (out[i]//"[0]", "NFFIXBAD", gemdate.outdate, 
            "UT Time stamp for NFFIXBAD", comfile="NULL", after="", before="",
            update+, add+, addonly-, delete-, verify-, show-)
        nhedit (out[i]//"[0]", "GEM-TLM", gemdate.outdate,
            "UT Last modification with GEMINI", comfile="NULL", after="",
            before="", update+, add+, addonly-, delete-, verify-, show-)
            
    }   # end for-loop through input images


clean:
    # Clean up and exit.
    delete (tmpfile, verify-, >& "dev$null")
    delete (tmpinimg, verify-, >& "dev$null")
    delete (tmpoutimg, verify-, >& "dev$null")
    imdelete (tmpsci, verify-, >& "dev$null")
    imdelete (tmpdq, verify-, >& "dev$null")

    printlog ("", l_logfile, l_verbose)
    if (status == 0) {
        printlog ("NFFIXBAD exit status:  good.", l_logfile, l_verbose)
    } else {
        printlog ("NFFIXBAD exit status:  error.", l_logfile, l_verbose)
    }
    printlog ("----------------------------------------------------------\
        ------------------", l_logfile, l_verbose)

end
