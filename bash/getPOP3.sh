#!/bin/bash
#
# Perform email service availability check. ( 4 minutes maximum delay )
# File name: getPOP3.sh
# run cron job locally on external for the organisation email server
#  */5 * * * * /home/path-to/getPOP3.sh >/dev/null 2>&1
#
# Send mail from organisation email server 
# 1-59/5 * * * * /home/path-to/sendme.sh > /dev/null 2>&1
#
# Send email one-line script: sendme.sh
# #!/bin/bash
# swaks -ha -s smtp.internal.com:25 -t "mail@external.com" -f mail@internal.com --header "Subject: heartbeat" --body "heartbeat"

mailbox="mail@external.com"
password="P@ssw0rd"
alarmTO="alarm@external.com"
alarmText="no email $(date)"
alarmSubject="email service not working"


#READ WRITE to pop3
exec 3<> /dev/tcp/localhost/pop3
read ok line line2<&3
echo $line $line2

#Login
echo USER $mailbox  >&3
read ok<&3
echo aft userid entered:$ok
echo PASS $password >&3
read ok line <&3
echo password entered:$ok $line

#Read number of emails
echo STAT >&3
read ok num num1 <&3
echo $num
if [ $num -eq 0 ]; then
  mail -s $alarmSubject $alarmTO <<< $alarmText
  echo $alarmText
fi

#Delete all emails
while [ $num -gt 0 ] 
do
  echo "too much $num"
  echo DELE $num >&3
  read ok <&3
  echo STAT >&3
  read ok num num1 <&3
  echo $num
done
echo QUIT >&3
