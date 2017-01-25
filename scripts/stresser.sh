#/bin/bash
# stresser.sh, ABr
# Stress a machine based on total memory and processors

# keep on going...
echo "stresser.sh running..."
while true ; do
  proc_count=$(cat /proc/cpuinfo | grep -e '^processor' | wc -l)
  total_mb=$(free -m | grep -e '^Mem:' | awk '{print $2}')
  free_mb=$(free -m | grep -e '^Mem:' | awk '{print $7}')
  min_mb=576
  echo "Current free: ${free_mb}M"
  if [ $free_mb -gt $min_mb ]; then
    echo "Firing off another..."
    l_reference_mb=$(((total_mb - min_mb) / proc_count))

    # count the number of stress processes
    l_stress_procs=$(sudo ps -efa | grep SCREEN | grep stress | grep -v grep | wc -l)
    echo "  Found $l_stress_procs procs running so far..."
    while [ $l_stress_procs -ge $proc_count ]; do
      l_stress_pid=$(sudo ps -efa | grep SCREEN | grep stress | grep -v grep | head -n 1 | awk '{print $2}')
      [ x"$l_stress_pid" != x ] && echo "  Reaping stress PID $l_stress_pid..." && sudo kill $l_stress_pid && sleep 2
      l_stress_procs=$(sudo ps -efa | grep SCREEN | grep stress | grep -v grep | wc -l)
    done

    # recalc memory (in case we reaped any processes above)
    free_mb=$(free -m | grep -e '^Mem:' | awk '{print $7}')
    [ $free_mb -gt $l_reference_mb ] && l_bytes=$l_reference_mb
    [ $free_mb -le $l_reference_mb ] && l_bytes=$((free_mb - min_mb))

    # fire away
    echo "  screen -d -m sudo stress --vm 1 --vm-bytes ${l_bytes}M --vm-keep"
    screen -d -m sudo stress --vm 1 --vm-bytes ${l_bytes}M --vm-keep && sleep 3
  fi  
  sleep 5
done

