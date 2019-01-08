Elastic 6.5 has built-in management of Beats agents. However, you must be a paying customer, which I'm not
I've written this script to help me manage my winLogBeat agents

You must create a winLogBeat folder where this script lives and place all winLogbeat files that you downloaded from Elastic there

You must also create winLogbeat.XX.yml files, one for each type of server you collect info from. For example:
  - winLogBeat.DC.yml for Domain Controllers (included as example)
  - winLogBeat.Print.yml for Print Servers
Adjust the $TYPE parameter to meet your needs

The script will check the time stamp of winlogbeat.exe and winlogbeat.yml. Based on that information it will:
  - Install winLogBeat if winLogBeat.exe isn't found on the remote computer
  - Upgrade winLogBeat if the local version of the EXE is newer
  - Update winLogBeat configuration (yml file) if the local version of the YML is newer
