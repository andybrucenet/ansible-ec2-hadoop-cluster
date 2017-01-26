#!/bin/bash
# setup-vncserver.sh, ABr
# Setup vnc server on a system
#set -x

# pass in user and VNC password
i_user="$1"; shift
i_password="$1"; shift

# account for problems within tty
l_workname="/tmp/$$-work.sh"
l_response_file="/tmp/$$.response"
l_rc_file="/tmp/$$.rc"
l_complete_file="/tmp/$$.complete"
touch "$l_response_file"
touch "$l_rc_file"
touch "$l_complete_file"
sudo chmod 666 "$l_response_file" "$l_rc_file" "$l_complete_file"
cat > "$l_workname" << EOF
#!/bin/bash

# result
l_rc=0

# create directory if necessary
[ ! -d .vnc ] && mkdir -p .vnc && chmod 755 .vnc
if [ ! -d .vnc ]; then
  echo "Unable to create .vnc" >> '$l_response_file'
  l_rc=1
else
  # create password
  if [ ! -s .vnc/passwd ]; then
    echo '$i_password' > .vnc/passwd
    chmod 600 .vnc/passwd
  fi
  if [ ! -s .vnc/passwd ]; then
    echo "Unable to create .vnc/passwd" >> '$l_response_file'
    l_rc=1
  fi
fi

# start vnc
if [ \$l_rc -eq 0 ]; then
  l_vncs=\$(ps -efa | grep -v grep | grep -e '$i_user' | grep -e Xvnc)
  if [ x"\$l_vncs" != x ]; then
    #echo "'\$l_vncs'" >> '$l_response_file'
    echo "vnc already running" >> '$l_response_file'
  else
    echo "Starting vnc..." >> '$l_response_file'
    vncserver >> '$l_response_file' 2>&1
    l_rc=\$?
  fi
fi

# command result
echo \$l_rc >> '$l_rc_file'

# indicate command is complete
echo '1' >> '$l_complete_file'
EOF
sudo chmod 755 "$l_workname"
#sudo cat "$l_workname"

# spawn in background
sudo su - $i_user -c "screen -md bash '$l_workname'"

# wait for job to finish completely
echo -n 'Waiting:'
sleep 2
if [ ! -s "$l_complete_file" ]; then
  echo ' '
  while [ ! -s "$l_complete_file" ]; do
    echo -n '.'
    sleep 2
  done
fi
echo ' Complete'

# quiesce, get return code, show response
sleep 1
l_rc=$(cat "$l_rc_file" | head -n 1)
echo -n "Response: "
cat "$l_response_file"

# cleanup
sudo rm -f "$l_response_file" "$l_rc_file" "$l_complete_file"

# return to caller
exit $l_rc

