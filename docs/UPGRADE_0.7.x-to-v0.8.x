Upgrading vEMan is easy ;-)
-----------------------------------

v0.8.x was a big change so unfortunately it isn't possible to keep the previous uservars_vEMan.cfg file.
If you're upgrading from 0.7.1 or lower version I recommend to do it that way:

1) Rename your current vEMan folder
2) Create a new empty folder
3) Download the new vEMan version
3) unpack it to the created dir in 2)
4) chmod -R +x vEMan ./libs/ ./vmapps
5) change the values in uservars_vEMan.cfg to match your installation (do NOT copy the old cfg file!)
6) If you have enabled console with vEMan before v0.8.0 it is highly recommended to disable and enable console once again
7) If the new vEMan version works as expected you can delete the folder you renamed in 1) otherwise you can easily switch back to the previous one. 
