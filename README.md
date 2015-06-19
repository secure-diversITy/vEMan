####################################################################################
#  NAME:    README
#  PLACE:   ./
#  DESC:    Important hints and requirements
####################################################################################

Known Issues
--------------

	If you encounter issues you can use the GIT repo which may already contain
	fixes for your problem and check docs/TROUBLE for problem hunting.
    
    Keep in mind that it may have good reasons why the code in GIT isn't
    released yet - so don't await that GIT code is stable!
    
	If you still want to use the development/latest available version:
	git clone https://github.com/xdajog/vEMan.git vEMan-git


Requirements
---------------

	Because vEMan is based on VMware and other great tools you need to ensure that
	you have the following installed:

	1) VMware SDK for Perl Toolkit  (*) 
	2) The VMware ovftool   (**)

	Besides the VMware requirements you need to have some standard Linux tools
	installed to get vEMan running:

	netcat, yad (***), a vncviewer (like tightvncviewer or similar), openssl,
	bash, grep, sed, python (v2.5 or higher)

    Recommended versions
    --------------------
    
    Currently recommended and well tested environment is:
    
        - VMware SDK for Perl:  v5.1 (v5.5 is NOT supported atm!)
        - ovftool:              v2.0.1 (or 3.x.x when you do NOT want to deploy)
        - yad:                  v0.23.1
        - python:               v2.7.3
    
    Other versions may work but if you encounter problems try to upgrade/downgrade
    to the above versions first.

Variables
----------------

	Please read the INSTALL file before starting vEMan.
	You can find a variables file included in this package which you may need
	to modify according to your installation (check INSTALL file).

HELP
---------------

	If you struggle somewhere you can get community help at the vEMan project page
    on sourceforge.net!
    Take also a look to the docs/TROUBLE if you encounter a problem!


Footnotes
---------------

	(*) http://www.vmware.com/support/developer/vcli/
        Even if I encountered no problems when using VMware SDK for Perl Toolkit v4.x
        I recommend using v5.1 for vEMan.
        THERE ARE issues with VMware SDK 5.5 !!
        Since v0.9.x vEMan is tested with VMware SDK for Perl v5.1 and higher only. 
        That means NOT that previous Perl Toolkits will NOT work anymore - but it
        means I will not TEST previous SDKs anymore..

   (**) ATTENTION: v2.1.0 doesn't work! Use v2.0 or try any version higher than v2.1.0
		OVFtool v2.0.1 (only one(!) known to work very well) at VMware: 
		https://my.vmware.com/group/vmware/get-download?downloadGroup=OVF-TOOL-2-0-1
        (seems to be thrown away by VMware??!)
		Alternative Google search:
		https://www.google.de/search?q=download+vmware-ovftool-2.0.1*.sh
        Untested ovftool v3.0.1 (install this if you are brave or do not want to
        deploy any VMs but using all the other features):
		https://my.vmware.com/group/vmware/get-download?downloadGroup=OVF-TOOL-3-0-1

  (***) yad is a fork of zenity (Homepage: http://code.google.com/p/yad/
        DEB packages available ;o) 

