#!/bin/zsh

#####################################################################################################
appName="ScriptName"
appVer="1.0"
appAuthor="Jeff Grisso"
appDepartment="Company Nane"
appDate="[CREATIONDATE]"
appUpDate="[MODIFICATION DATE]"
templateLastModified="20211014"

####################################################################################################
# Date Version Description
#--------------------------------------------------------------------------------------------------
#   [date] - [version] - [comment]
# 

####################################################################################################
#Debug code
####################################################################################################
#bash -x ./[script_name.sh] for detailed script output
#bash -n ./[script_name.sh] for syntax checking

# Bash strict mode settings
#set -u # References to any variable you haven't previously defined (except $* and $@) is an error, and causes the program to immediately exit.
#set -e # instructs bash to immediately exit if any command has a non-zero exit status.
#set -o pipefail # This setting prevents errors in a pipeline from being masked
#set -euo pipefail # sets all strict settings at once. 
# Debug trap to process script line by line
#set -x
#trap read debug


####################################################################################################
#Traps
####################################################################################################

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
  echo "CTL+C was caught."
  exitfunction
}

####################################################################################################
#Script logging
####################################################################################################

/bin/mkdir -p "/Library/Logs/${appDepartment}"
logFile="/Library/Logs/${appDepartment}/com.jamfPro.${appName}.log"

# sends all standard output and standard error to log file.
exec >> ${logFile}

# Sends all standard output and standard error to log file and standard output. Script results will display in JamfPro policy results.
# Redirect stdout ( > ) into a named pipe ( >() ) running "tee"
# exec > >(tee -ia "${logFile}")

# Send standard error to standard output
exec 2>&1
#echo "LOG REDIRECTION DISABLED BECAUSE INTERACTION IS REQUIRED"
#echo "LOG REDIRECTION DISABLED"

####################################################################################################
#Uncommon Binaries
####################################################################################################

#plistbuddy='/usr/libexec/plistbuddy'
#lsregister='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
#bypass='/System/Library/Extensions/TMSafetyNet.kext/Contents/MacOS/bypass' #TimeMachine safety bypass binary
#createmobileaccount='/System/Library/CoreServices/ManagedClient.app/Contents/Resources/createmobileaccount'

####################################################################################################
#Variables
####################################################################################################

oldifs="${IFS}"
# lazy way: 
# unset IFS
IFS=$(echo -en "\n\b")
error="0"
count="0"
AppDir="$(dirname "$0")"
clientUDID="$(ioreg -d 2 -c IOPlatformExpertDevice | sed -n 's/.*IOPlatformUUID.*"\(.*\)"/\1/p')"
clintSerialNumber="$(ioreg -d 2 -c IOPlatformExpertDevice | sed -n 's/.*IOPlatformSerialNumber.*"\(.*\)"/\1/p')"
macMac="$(ifconfig en0 ether | sed -n 's/.*ether \(.*\) /\1/pg' | sed 's/://g')"
UserName="$(stat -f %Su /dev/console)"
UserPID="$(stat -f %u /dev/console)"
LoginWindowPID="$(pgrep -u ${UserName} loginwindow)"
UserHomeDirectory="$(dscl . read /Users/"${UserName}" NFSHomeDirectory | sed 's/NFSHomeDirectory: //g')"
autoComputerName="AP$(tr '[:lower:]' '[:upper:]' <<< ${clintSerialNumber: -6}${macMac: -6})"

# more "official" way to get logged in user. solves multi-user problem. see https://scriptingosx.com/2018/04/demystifying-root-on-macos-part-3-root-and-scripting/ 
# do not use once Apple removes python from macOS. 
# loggedInUser="$(/usr/bin/python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");')"
# loggedInUserID="$(id -u "$loggedInUser")"

# other methods
# stat -f%Su /dev/console
# bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'
# defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName
# scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' 

# updated way that should work post-python removal. 
loggedInUser="$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ && ! /loginwindow/ { print $3 }' )"
loggedInUserID="$(id -u "$loggedInUser")"

#code template for running as user example:
#launchctl asuser "${UserPID}" /usr/bin/open /Applications/application.app
#launchctl asuser "${loggedInUserID}" /usr/bin/open /Applications/application.app

# reminder for jamf end user inform:
# jamf recon -endUserName $3

####################################################################################################
#Functions
####################################################################################################

appLog() {
    printf "$appName $(date "+%m/%d/%Y %H:%M:%S %Z"): ${1} \n"
}

exitfunction() {
  IFS=${oldifs}
  exit ${error}
}

getWorkingDIR()
{
    path="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
    echo "current working directory: $path"
}

quickDate() {
    quickdate="$(date "+%Y%m%d_%H%M%S")"
}

quickDateSQL() {
    quickdatesql="$(date "+%Y-%m-%d %H:%M:%S")"
}


waitForNetwork(){
    ipconfig waitall
}

osa() {
	/usr/bin/osascript \
		-e "with timeout of (${2:-1800}) seconds" \
		-e "set myReply to ${3:-button} returned of (display dialog ${1})" \
		-e "end timeout" ${4:-}
}
# example use: myName=`osa '"Please enter the name of the logged in account:" default answer "" with hidden answer buttons{"OK"} default button 1' '' text`


urlEncode() {
	echo "$1" | sed  -e 's:%:%25:g' -e 's:+:%2B:g' -e 's: :%20:g' -e 's:<:%3C:g' -e 's:>:%3E:g' -e 's:#:%23:g' -e 's:{:%7B:g' -e 's:}:%7D:g' -e 's:|:%7C:g' -e 's:\\:%5C:g' -e 's:\^:%5E:g' -e 's:~:%7E:g' -e 's:\[:%5B:g' -e 's:\]:%5D:g' -e 's:`:%60:g' -e 's:;:%3B:g' -e 's:/:%2F:g' -e 's:?:%3F:g' -e 's^:^%3A^g' -e 's:@:%40:g' -e 's:=:%3D:g' -e 's:&:%26:g' -e 's:\$:%24:g' -e 's:\!:%21:g' -e 's:\*:%2A:g'
}

counter(){
    count=$((count+1))
    echo "$count"
}

benchmarkStart(){
    SECONDS=0
}

benchmarkEnd(){
    duration=$SECONDS
    echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."
}

# Include DecryptString() with your script to decrypt the password sent by the JSS
# The 'Salt' and 'Passphrase' values would be present in the script
# source: https://github.com/jamf/Encrypted-Script-Parameters
function DecryptString() {
    # Usage: ~$ DecryptString "Encrypted String" "Salt" "Passphrase"
    echo "${1}" | /usr/bin/openssl enc -aes256 -d -a -A -S "${2}" -k "${3}"
}


####################################################################################################
#Script
####################################################################################################
appLog "\n--------------------------------------------------------------------------------
Discovered Console username: ${UserName}
Found login window PID: ${LoginWindowPID}
Application path is ${AppDir}
--------------------------------------------------------------------------------
Start: $(date "+%m/%d/%Y %H:%M:%S %Z")
Program name: ${appName}
Program version: ${appVer}
Author: ${appAuthor}
Development department: ${appDepartment}
Program creation date: ${appDate}
Program modification date: ${appUpDate}
Client serial number: ${clintSerialNumber}
Client name: $(hostname)
Client byHost/UUID/UDID: ${clientUDID}
--------------------------------------------------------------------------------"
####################################################################################################

# Script goes here

####################################################################################################
appLog "The script has completed. Exit code is: ${error}"
exitfunction
#catch-all exit
appLog "ERROR: catch-all exit was reached! You may have an open quote in your code."
exit 1