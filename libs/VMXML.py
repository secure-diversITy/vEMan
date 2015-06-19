#!/usr/bin/env python
#################################################################
#
# This is part of vEMan (http://vEMan.nethna.de)
# Parsing VM XML files and write a flexible output depending on
# the mode / type you need.
#
#################################################################

import sys, getopt
try:
    import cElementTree as ET
except ImportError:
  try:
    # Python 2.5 need to import a different module
    import xml.etree.cElementTree as ET
  except ImportError:
    exit_err("Failed to import cElementTree from any known place")      

#def _read_text(element): 
#    return eval("%s('%s')" % ('', element.text))

def load_dict(xml,mode,tag): 
    ''' 
    parsing given XML file and return output depending on mode selected 
    args: filename, mode
    '''
    d = {} 
    dict_valid_vmedit = ('Name', 'noCPU', 'memorySize')
    xmltree = ET.parse(xml) 
    tag_dict = xmltree.getroot() 

    #print  "".join(d)
#        sys.stdout.write(element.text)
#        sys.stdout.write('\" ')
        #,element.tag)

#    for element in tag_dict.findall("./VM/*"):
    for element in tag_dict.findall("./*/*"):
        d[element.tag] = element.text

    if mode == 'keys':
        for key,value in d.items():
            #sys.stdout.write('--field=')
            sys.stdout.write('"')
            sys.stdout.write(key)
            #sys.stdout.write('" ')
            #print '\' '
            print '\" '
    elif mode == 'values':
        for key,value in d.items():
            sys.stdout.write('"')
            sys.stdout.write(value)
            print '" '
            #print '\' \ '
    elif mode == 'yadlist':
        for key,value in d.items():
            print(key)
            print(value)
    elif mode == 'keyvalue':
        for key,value in d.items():
            sys.stdout.write(key)
            sys.stdout.write(':')
            print(value)
    elif mode == 'vmedit':
        for key,value in d.items():
          if key in dict_valid_vmedit:
            sys.stdout.write('--field=')
            sys.stdout.write(key)
            sys.stdout.write(' ')
            sys.stdout.write(value)
            sys.stdout.write(' ')
    elif mode == 'xmltag':
        tagout = 'unref'
        for key,value in d.items():
          if key == tag:
            #print(key)
            tagout = value
        if tagout != 'unref':
          print(tagout)
        else:
          print 'ERROR: XML tag <',tag,'> is not available'
          return 2
    else:
        print "ERROR: unknown mode <",mode,"> selected"
        helpusage()

def helpusage():
    print
    print 'USAGE:'
    print
    print 'This tool can do both: '
    print 'a) parsing and convert the output to given modes'
    print 'b) and also write a VMware compatible XML file on given input'
    print
    print 'Option 1) Read, parse and convert to readable output:'
    print sys.argv[0],' --readxml -x <XML-file> -m <mode> [-t tag]'
    print
    print '  mode can be one of: '
    print '         <keys> for keys only output'
    print '         <values> for values only output '
    print '         <yadlist> for a yad --list compatible output'
    print '         <keyvalue> for a simple to parse key-value output'
    print '         <vmedit> for a valid list of editable VM settings'
    print '         <xmltag> for fetch 1 specific XML tag only - requires <-t|--tag>'
    print ' <-t|--tag> <XMLfield>: required for <xmltag> mode only. e.g. to findout noCPU only.'
    print '                      it returns the value only and if the tag is not found there will be no error.'
    print
    print 'Option 2) Take input and convert it to a VMware compatible XML: '
    print sys.argv[0],'--writexml -i <comma separated list of key-values> -x <XML input-file> -o <XML output-file>'
    print
    print '   for <-i> we need ALL of those:'
    print '       prka:<value> ("previously known as", because the VM name can change!!)'
    print '       name:<value> (the new VM name - can be identical with prka if not changed)'
    print '       noCPU:<value> (number of CPUs between 1 and 999)'
    print '       memorySize:<value> (RAM in Megabyte must be higher than 8)'
    print '       e.g.: -i "name:moo,noCPU:8,memorySize:4096" -o moo.xml'
    print '    <-x> You need to specify the current / old XML file of the VM. We could also'
    print '         fetch that from ESX/vSphere but that is not necessary and can produce more faults.'
    print

def main(argv):
   ''' 
   Meaning: Will parse and check given args.
   Args: all available args are required
   '''
   xmlfile = ''
   mode = ''
   operation = ''
   inputdata = ''
   outputfile = ''
   tag = ''
   try:
      opts, args = getopt.getopt(argv,"hx:m:rwi:o:t:",["help","xmlfile=","mode=","readxml","writexml","inputfile=","outputfile=","xmltag="])
   except getopt.GetoptError:
      print 'Problem with your argument(s). Please check help.'
      helpusage()
      sys.exit(2)
   for opt, arg in opts:
      if opt in ("-h", "--help"):
        helpusage()
        sys.exit()
      elif opt in ("-x", "--xmlfile"):
         xmlfile = arg
      elif opt in ("-m", "--mode"):
         mode = arg
      elif opt in ("-r", "--readxml"):
          operation = 'readxml'
      elif opt in ("-w", "--writexml"):
          operation = 'writexml'
      elif opt in ("-i", "--inputdata"):
          inputdata = arg
      elif opt in ("-o", "--outputfile"):
          outputfile = arg
      elif opt in ("-t", "--xmltag"):
          tag = arg
   if operation == 'readxml':
      if xmlfile and mode:
        if mode != 'xmltag':
          tag = 'unused'
        elif tag == '':
          print 'Missing tag name!'
          helpusage()
          sys.exit()
        load_dict(xmlfile,mode,tag)
      else:
        print 'Missing or wrong argument(s) for read mode!'
        helpusage()
        sys.exit()
   elif operation == 'writexml':
      if inputdata and outputfile and xmlfile:
        save_dict(xmlfile, inputdata, outputfile)
      else:
        print 'Missing or wrong argument(s) for write mode!'
        helpusage()
        sys.exit()
   else:
        print 'Missing argument!'
        helpusage()
        sys.exit()
if __name__ == "__main__":
   main(sys.argv[1:])
   
