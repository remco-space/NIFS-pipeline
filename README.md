NIFS REDUCTION PIPELINE
=======================

Initial import of the NIFS data reduction pipeline written by Jonelle Walsh, Anil Seth, Richard McDermid, Nora Luetzgendorf & Mariya Lyubenova.

Requirements
============

* Python v2.7.5 
* Gemini package 1.13 or 1.12 (e.g. as part of [Ureka](http://ssb.stsci.edu/ureka/))
* [IDL astrolib]( http://idlastro.gsfc.nasa.gov/)
* [Craig Markwardt's](http://cow.physics.wisc.edu/~craigm/idl/fitting.html) mpfit.pro, mpfitfun.pro, mpfit2dfun.pro, and mpfit2dpeak.pro in your IDL path. 
* [sigfig.pro](http://w.astro.berkeley.edu/~johnjohn/idlprocs/sigfig.pro) in your IDL path 
* [pidly](https://github.com/anthonyjsmith/pIDLy). `pip install pidly`

Installation instructions:
=========================

* Add the idl_scripts to your IDL path:
`!PATH = expand_path('..../NIFS_pipeline/idl_scripts') +':'+ !Path
`
* Add iraf_scripts to your login.cl 
`task nffixbad_anil = home$scripts/nffixbad_anil.cl
task nftelluric_anil = home$scripts/nftelluric_anil.cl`
* Edit `nifs_main_LP_quick.py` and update the path to the `ref_files/` subdirectory

Usage instructions
=================

See [`nifs_pipeline_instructions.PDF`](nifs_pipeline_instructions.pdf) for detailed instructions.



