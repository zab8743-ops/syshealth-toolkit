#!/usr/bin/env bash

#==================================================

#syshealth.sh -System Health & Log Analysis Toolkit

#Lab 1 - Data Collector

#Author: Zoheb Bamban

#Date: $(date +%Y-%m-%d)

#--Threshholds: Maximum values of variables that will not trigger any alerts--

CPU_THRESHOLD=75

MEM_THRESHOLD=85

DISK_THRESHOLD=85

#--Setting variables like this makes it easier to configure and edit these values later as per needs.--

#--Adding a color coded status, whether if the systems nominal or has an issue to be alerted about.--

print_status(){
	local status="$1"
	local message="$2"
	if [ "$status" = "OK" ]; then
		echo -e "\e[32m OK: $message\e[0m"
	else
		echo -e "\e[31m ALERT: $message\e[0m"
	fi
}

#Here we make use of local variables since it does not exist outside of the function, making a cleaner global variable space.
#==================================================
#------Variables and quoting demonstration------
HOSTNAME=$(hostname)
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

#IMPORTANT: Quoting demo (Python/Java students read this!)
#Without quotes -> word-splitting bug (try it!)
#With double quotes -> safe (Best practice for bash)

echo "Hostname without quotes: $HOSTNAME" #works now, dangerous later
echo "Hostname with quotes: \"$HOSTNAME\"" #always do this
cat << EOF
#Difference between double and single quotes in Java and Python compared to Bash:-
#In python/Java varaiables keep their full values as one piece.
#However in bash, the variables are seperated and split into their arguments whereever there are spaces.
#This can be prevented by using double quotes, since anything inside them will be treated as a whole.
EOF

#----System metrics collection----

UPTIME=$(uptime -p)
DISK_USAGE=$(df -h / | tail -1)
MEMORY_USAGE=$(free -h | awk '/Mem:/ {print $3 "/" $2}')
PROCESS_COUNT=$(ps -e | wc -l)
#These varaibles hold the following details;
#Uptime -> Gets how long the system has been running for.
#Disk usage -> Storage usage for the root partition.
#Memory usage -> Format used vs total RAM.
#Process count -> counts the total number of processes.

#--Making the system statistics into readable integers to compare them--
# Getting the root drive usage, stripping the % that comes with it.
DISK_PCT=$(df / | tail -1 | awk '{gsub("%",""); print $5}')

#Getting the current total RAM usage and rouding it to a integer
MEM_PCT=$(free | awk '/Mem:/ {printf "%.0f", $3/$2*100}')

#Get the CPU Usage:
#This method uses top for getting the CPU usage reading.
CPU_PCT=$(top -bn1 | grep '^%Cpu' | awk '{print 100 - $8}' | cut -d. -f1)

#--System Health Check--
#-Uses a variable to check if the system is healthy-
#-Uses conditionals to check on the variable and gives an output with respective color coding.
print_status "CHECK" "Running system health analysis..."
HEALTH_STATUS=0
#-This will be our variable to which we will run our conditions for.-
#-We set the default to 0, this will raise no alerts.-
#-However, if the condition returns to be true, we change the value to 1 which raises an alert.
#-Conditional statements:
#- 1: Checking the Disk -
if ((DISK_PCT > DISK_THRESHOLD )); then
	print_status "ALERT" "Disk usage on / is ${DISK_PCT}% (threshold ${DISK_THRESHOLD}%)"
	HEALTH_STATUS=1
else 
	print_status "OK" "Disk usage on / is ${DISK_PCT}%"
fi

# -- Iterating through  additional storage mount points -- 
# - First we verify if the target path is an active storage mount -
# - We then grab the data and strip away the %. -
# - Compare and test it with our existing threshold. - 
# - or we skip the checking entirely if the path is not recognized mount point on this server. -
for mount in / /home /var; do
	if mountpoint -q "$mount" 2>/dev/null || [ "$mount" = "/" ] ; then
		PCT=$(df "$mount" | tail -1 | awk '{gsub("%",""); print $5}')
		if ((PCT> DISK_THRESHOLD )); then
			print_status "ALERT" "Disk usage on $mount is ${PCT}% (threshold ${DISK_THRESHOLD}%)"
			HEALTH_STATUS=1
		else
			print_status "OK" "Disk usage on $mount is ${PCT}%"
		fi
	else
		print_status "OK" "Mount point $mount does not exist or it not a mountpoint on this system"
	fi
done

# - The Mountpoint checks if the directory is an active filesystem mountpoint before checking its space while
#   also supressing errors -
#- 2: Checking Memory -

if ((MEM_PCT > MEM_THRESHOLD )); then
	print_status "ALERT" "Memory usage is ${MEM_PCT}% (threshold ${MEM_THRESHOLD}%)"
	HEALTH_STATUS=1
else
	print_status "OK" "Memory Usage is ${MEM_PCT}%"
fi

#- 3: Checking CPU -
if ((CPU_PCT > CPU_THRESHOLD )); then
	print_status "ALERT" "CPU Usage is ${CPU_PCT}% (threshold ${CPU_THRESHOLD}%)"
	HEALTH_STATUS=1
else
	print_status "OK" "CPU Usage is ${CPU_PCT}%"
fi

#----Output Handling----
OUTPUT_FILE="${1:-}" #if $1 is given, use it ; else print it to screen.
print_report(){
printf "=============================================\n"
printf "System Health Report - %s\n" "$CURRENT_DATE"
printf "Hostname         : %s\n" "$HOSTNAME"
printf "Uptime           : %s\n" "$UPTIME"
printf "Disk  /          : %s\n" "$DISK_USAGE"
printf "Memory used      : %s\n" "$MEMORY_USAGE"
printf "Total processes  : %s\n" "$PROCESS_COUNT"
printf "Health status    : %s\n" "$([ "$HEALTH_STATUS" -eq 0 ] && echo 'HEALTHY' || echo 'UNHEALTHY - see alerts above')"
printf "=============================================\n"
}
if [ -n "$OUTPUT_FILE" ]; then
	print_report > "$OUTPUT_FILE"
	echo "Report written to $OUTPUT_FILE (alerts were printed to terminal)"
else
	print_report
fi

#Return 0 if the system in normal state, 1 if any alerts were raised.
exit "${HEALTH_STATUS: -0}"

