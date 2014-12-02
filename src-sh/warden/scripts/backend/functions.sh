#!/bin/sh
# Functions / variables for warden
######################################################################
# DO NOT EDIT 

# Source local functions
. /usr/local/share/pcbsd/scripts/functions.sh

# Installation directory
PROGDIR="/usr/local/share/warden"

# Jail location
JDIR="$(grep ^JDIR: /usr/local/etc/warden.conf | cut -d' ' -f2)"
export JDIR

# Set arch type
REALARCH=`uname -m`
export REALARCH
if [ -z "$ARCH" ] ; then
  ARCH="$REALARCH"
  export ARCH
fi

# Location of pcbsd.conf file
PCBSD_ETCCONF="/usr/local/etc/pcbsd.conf"

# Network interface to use
NIC="$(grep ^NIC: /usr/local/etc/warden.conf | sed 's|NIC: ||g' | sed 's|NIC:||g')"
export NIC

# Tmp directory
WTMP="$(grep ^WTMP: /usr/local/etc/warden.conf | cut -d' ' -f2)"
export WTMP

# Default IP4 Pool of addresses
DEFAULT_IP4POOL="$(grep ^IP4POOL: /usr/local/etc/warden.conf | cut -d' ' -f2)"
if [ -z "$DEFAULT_IP4POOL" ] ; then
   DEFAULT_IP4POOL="192.168.0.220"
fi
export DEFAULT_IP4POOL

# FreeBSD release
FREEBSD_RELEASE="$(grep ^FREEBSD_RELEASE: /usr/local/etc/warden.conf | cut -d' ' -f2)"
if [ -z "${FREEBSD_RELEASE}" ] ; then
  FREEBSD_RELEASE="$(uname -r)"
fi
export UNAME_r="${FREEBSD_RELEASE}"

# Temp file for dialog responses
ATMP="/tmp/.wans"
export ATMP

# Warden Version
WARDENVER="1.4"
export WARDENVER

# Dirs to nullfs mount in X jail
NULLFS_MOUNTS="/tmp /media"
X11_MOUNTS="/usr/local/lib/X11/icons /usr/local/lib/X11/fonts /usr/local/etc/fonts"

# Clone directory
CDIR="${JDIR}/clones"

downloadpluginjail() {
  local _ver="${1}"

  SYSVER=`echo "${_ver}" | sed -E 's|^FreeNAS-(([0-9]+\.){2}[0-9]+).*|\1|'`
  SYSREL=`echo "${_ver}" | sed -E 's|^FreeNAS-([0-9]+\.){2}[0-9]+-([a-zA-Z0-9]+)-.*|\2|'`
  SYSARCH=`echo "${_ver}" | sed -E 's#^(.*)(x86|x64)#\2#'`

  SF="http://downloads.sourceforge.net/project/freenas"
  URL="${SF}/FreeNAS-${SYSVER}/${SYSREL}/${SYSARCH}/plugins"

  PJAIL="FreeNAS-${SYSVER}-${SYSREL}-${SYSARCH}.Plugins_Jail.pbi"
  PJAILSHA256="${PJAIL}.sha256"

  if [ ! -d "${JDIR}" ] ; then mkdir -p "${JDIR}" ; fi
  cd ${JDIR}

  echo "Fetching jail environment. This may take a while..."

  if [ ! -e "${PJAIL}" ] ; then
     echo "Downloading ${URL}/${PJAIL} ..."
     get_file "${URL}/${PJAIL}" "${PJAIL}" 3
     [ $? -ne 0 ] && printerror "Error while downloading the pluginjail."
  fi

  if [ ! -e "${PJAILSHA256}" ] ; then
     echo "Downloading ${URL}/${PJAILSHA256} ..."
     get_file "${URL}/${PJAILSHA256}" "${PJAILSHA256}" 3
     [ $? -ne 0 ] && printerror "Error while downloading the pluginjail sha256."
  fi

  [ "$(sha256 -q ${PJAIL})" != "$(cat ${PJAILSHA256})" ] &&
    printerror "Error in download data, checksum mismatch. Please try again later."

  # Get the dataset of the jails mountpoint
  rDataSet=`mount | grep "on ${JDIR} " | awk '{print $1}'`
  tSubDir=`basename $WORLDCHROOT`
  nDataSet="${rDataSet}/${tSubDir}"

  echo "Creating ZFS ${nDataSet} dataset..."
  isDirZFS "${WORLDCHROOT}" "1"
  if [ $? -ne 0 ] ; then
     zfs create -p ${nDataSet}
     if [ $? -ne 0 ] ; then exit_err "Failed creating ZFS base dataset"; fi
     mkdir -p "${WORLDCHROOT}/.plugins" >/dev/null 2>&1
  fi

  pbi_add -e --no-checksig -p ${WORLDCHROOT} ${PJAIL}
  if [ $? -ne 0 ] ; then exit_err "Failed extracting ZFS chroot environment"; fi

  zfs snapshot ${nDataSet}@clean
  if [ $? -ne 0 ] ; then exit_err "Failed creating clean ZFS base snapshot"; fi
  rm ${PJAIL}
  rm ${PJAILSHA256}
};

### Download the chroot
downloadchroot() {
  local CHROOT="${1}"

  # XXX If this is PCBSD, pbreg get /PC-BSD/Version
  SYSVER="$(echo "$(uname -r)" | cut -f1 -d'-')"
  FBSD_TARBALL="fbsd-release.txz"
  FBSD_TARBALL_CKSUM="${FBSD_TARBALL}.md5"

  # Set the mirror URL, may be overridden by setting MIRRORURL environment variable
  if [ -z "${MIRRORURL}" ]; then
    get_mirror
    MIRRORURL="$VAL"
  fi

  if [ ! -d "${JDIR}" ] ; then mkdir -p "${JDIR}" ; fi
  cd ${JDIR}

  echo "Fetching jail environment. This may take a while..."
  echo "Downloading ${MIRRORURL}/${SYSVER}/${ARCH}/netinstall/${FBSD_TARBALL} ..."

  if [ ! -e "$FBSD_TARBALL" ] ; then
     get_file "${MIRRORURL}/${SYSVER}/${ARCH}/netinstall/${FBSD_TARBALL}" "$FBSD_TARBALL" 3
     [ $? -ne 0 ] && printerror "Error while downloading the portsjail."
  fi

  if [ ! -e "$FBSD_TARBALL_CKSUM" ] ; then
     get_file "${MIRRORURL}/${SYSVER}/${ARCH}/netinstall/${FBSD_TARBALL_CKSUM}" "$FBSD_TARBALL_CKSUM" 3
     [ $? -ne 0 ] && printerror "Error while downloading the portsjail."
  fi

  [ "$(md5 -q ${FBSD_TARBALL})" != "$(cat ${FBSD_TARBALL_CKSUM})" ] &&
    printerror "Error in download data, checksum mismatch. Please try again later."

  # Get the dataset of the jails mountpoint
  rDataSet=`mount | grep "on ${JDIR} " | awk '{print $1}'`
  tSubDir=`basename $CHROOT`
  nDataSet="${rDataSet}/${tSubDir}"

  echo "Creating ZFS ${CHROOT} dataset..."
  isDirZFS "${CHROOT}" "1"
  if [ $? -ne 0 ] ; then
     zfs create -p ${nDataSet}
     if [ $? -ne 0 ] ; then exit_err "Failed creating ZFS base dataset"; fi
  fi

  tar xvpf ${FBSD_TARBALL} -C ${CHROOT} 2>/dev/null
  if [ $? -ne 0 ] ; then exit_err "Failed extracting ZFS chroot environment"; fi

  zfs snapshot ${nDataSet}@clean
  if [ $? -ne 0 ] ; then exit_err "Failed creating clean ZFS base snapshot"; fi
  rm ${FBSD_TARBALL}
  rm ${FBSD_TARBALL_CKSUM}
};

# Check if a directory is mounted
isDirMounted() {
  mount | grep -q "on $1 ("
  return $?
}

### Mount all needed filesystems for the jail
mountjailxfs() {

  if [ ! -d "${JDIR}/${1}/" ] ; then
     exit_err "Invalid jail directory: ${JDIR}/${1}"
  fi

  # Update the user files on the portjail
  ETCFILES="resolv.conf passwd master.passwd spwd.db pwd.db group localtime"
  for file in ${ETCFILES}; do
    rm ${JDIR}/${1}/etc/${file} >/dev/null 2>&1
    cp /etc/${file} ${JDIR}/${1}/etc/${file}
  done

  for nullfs_mount in ${NULLFS_MOUNTS}; do
    if [ ! -d "${JDIR}/${1}${nullfs_mount}" ] ; then
      mkdir -p "${JDIR}/${1}${nullfs_mount}"
    fi
    if is_symlinked_mountpoint ${nullfs_mount}; then
      echo "${nullfs_mount} has symlink as parent, not mounting"
      continue
    fi

    # If this is already mounted we can skip for now
    isDirMounted "${JDIR}/${1}${nullfs_mount}" && continue

    echo "Mounting ${JDIR}/${1}${nullfs_mount}"
    mount_nullfs ${nullfs_mount} ${JDIR}/${1}${nullfs_mount}
  done

  # Check and mount /dev
  isDirMounted "${JDIR}/${1}/dev"
  if [ $? -ne 0 ] ; then
    echo "Enabling devfs"
    mount -t devfs devfs ${JDIR}/${1}/dev
  fi

  # Add support for linprocfs for ports that need linprocfs to build/run
  if [  ! -d "${JDIR}/${1}/compat/linux/proc" ]; then
    mkdir -p ${JDIR}/${1}/compat/linux/proc
  fi
  if is_symlinked_mountpoint ${JDIR}/${1}/compat/linux/proc; then
    echo "${JDIR}/${1}/compat/linux/proc has symlink as parent, not mounting"
    return
  fi

  # If this is already mounted we can skip for now
  isDirMounted "${JDIR}/${1}/compat/linux/proc"
  if [ $? -ne 0 ] ; then
    echo "Enabling linprocfs support."
    mount -t linprocfs linprocfs ${JDIR}/${1}/compat/linux/proc
  fi

  # Add support for linsysfs for ports that need linprocfs to build/run
  if [  ! -d "${JDIR}/${1}/compat/linux/sys" ]; then
    mkdir -p ${JDIR}/${1}/compat/linux/sys
  fi
  if is_symlinked_mountpoint ${JDIR}/${1}/compat/linux/sys; then
    echo "${JDIR}/${1}/compat/linux/sys has symlink as parent, not mounting"
    return
  fi

  # If this is already mounted we can skip for now
  isDirMounted "${JDIR}/${1}/compat/linux/sys"
  if [ $? -ne 0 ] ; then
    echo "Enabling linsysfs support."
    mount -t linsysfs linsysfs ${JDIR}/${1}/compat/linux/sys
  fi

  # Lastly we need to mount /usr/home/* directories
  for i in `ls -d /usr/home/*`
  do
    # If this is already mounted we can skip for now
    isDirMounted "${JDIR}/${1}${i}" && continue
    if [ ! -d "${JDIR}/${1}${i}" ] ; then mkdir -p ${JDIR}/${1}${i} ; fi
    echo "Mounting home: ${i}"
    mount_nullfs ${i} ${JDIR}/${1}${i}
  done

}

### Umount all the jail's filesystems
umountjailxfs() {
  status="0"
  # Umount all filesystems that are mounted into the portsjail
  for mountpoint in $(mount | grep ${JDIR}/${1}/ | cut -d" " -f3); do
    if [ "$mountpoint" = "${JDIR}/${1}/dev" ] ; then continue ; fi
    if [ "$mountpoint" = "${JDIR}/${1}/" ] ; then continue ; fi
    if [ "$mountpoint" = "${JDIR}/${1}" ] ; then continue ; fi
    echo "Unmounting $mountpoint"
    umount -f ${mountpoint}
    if [ $? -ne 0 ] ; then status="1" ; fi
  done
  # Now try to umount /dev
  umount -f ${JDIR}/${1}/dev 2>/dev/null >/dev/null
  return $status
}

# Check if PBI scripts are loaded in jail
checkpbiscripts() {
  if [ -z "${1}" ] ; then return ; fi
  if [ ! -e "${1}/usr/local/sbin/pbi_info" ] ; then
    copypbiscripts "${1}"
  elif [ "`ls -l /usr/local/sbin/pbi_info | awk '{print $5}'`" != "`ls -l ${1}/usr/local/sbin/pbi_info | awk '{print $5}'`" ] ; then 
    copypbiscripts "${1}"
  fi
}

# Copy PBI scripts to jail
copypbiscripts() {
  if [ -z "${1}" ] ; then return ; fi
  mkdir -p ${1}/usr/local/sbin >/dev/null 2>/dev/null
  cp /usr/local/sbin/pbi* ${1}/usr/local/sbin/
  chmod 755 ${1}/usr/local/sbin/pbi*

  # Copy rc.d pbid script
  mkdir -p ${1}/usr/local/etc/rc.d >/dev/null 2>/dev/null
  cp /usr/local/etc/rc.d/pbid ${1}/usr/local/etc/rc.d/

  # Copy any PBI manpages
  for man in `find /usr/local/man | grep pbi`
  do
    if [ ! -d "${1}`dirname $man`" ] ; then
      mkdir -p "${1}`dirname $man`"
    fi
    cp "${man}" "${1}${man}"
  done
}

mkportjail() {
  if [ -z "${1}" ] ; then return ; fi
  ETCFILES="resolv.conf passwd master.passwd spwd.db pwd.db group localtime"
  for file in ${ETCFILES}; do
    rm ${1}/etc/${file} >/dev/null 2>&1
    cp /etc/${file} ${1}/etc/${file}
  done
  
  # Need to symlink /home
  chroot ${1} ln -fs /usr/home /home

  # Make sure we remove our cleartmp rc.d script, causes issues
  [ -e "${1}/etc/rc.d/cleartmp" ] && rm ${1}/etc/rc.d/cleartmp

  # Flag this type
  touch ${JMETADIR}/jail-portjail
}

mkpluginjail() {
  if [ -z "${1}" ] ; then return ; fi
  ETCFILES="resolv.conf passwd master.passwd spwd.db pwd.db group localtime"
  for file in ${ETCFILES}; do
    rm ${1}/etc/${file} >/dev/null 2>&1
    cp /etc/${file} ${1}/etc/${file}
  done
  
  # Need to symlink /home
  chroot ${1} ln -fs /usr/home /home

  # Make sure we remove our cleartmp rc.d script, causes issues
  [ -e "${1}/etc/rc.d/cleartmp" ] && rm ${1}/etc/rc.d/cleartmp
  # Flag this type
  touch ${JMETADIR}/jail-pluginjail
}

mkZFSSnap() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi
  tank=`getZFSTank "$1"`
  rp=`getZFSRelativePath "$1"`
  zdate=`date +%Y-%m-%d-%H-%M-%S`
  zfs snapshot $tank${rp}@$zdate
  # Do we have a comment to set?
  if [ -n "$2" ] ; then
      zfs set warden:comment="$2" ${tank}${rp}@${zdate}
  fi
}

listZFSSnap() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi
  tank=`getZFSTank "$1"`
  rp=`getZFSRelativePath "$1"`

  echo "Snapshot				Comment"
  echo "-----------------------------------------------"
  for i in `zfs list -r -t snapshot ${tank}${rp} 2>/dev/null | cut -d '@' -f 2 | awk '{print $1}'`
  do
     comment=`zfs get -o value warden:comment ${tank}${rp}@$i 2>/dev/null| grep -v "VALUE"`
     lcomment=`zfs get -o value lpreserver:comment ${tank}${rp}@$i 2>/dev/null| grep -v "VALUE"`
     if [ -z "$comment" -a -n "$lcomment" ] ; then
       echo "$i		$lcomment"
     else
       echo "$i		$comment"
     fi
  done
}

listZFSClone() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi
  tank=`getZFSTank "$1"`
  cdir=`getZFSRelativePath "${CDIR}"` 
  echo "Clone Directory: ${CDIR}"
  echo "-----------------------------------"
  zfs list | grep -w "^${tank}${cdir}/${2}" | awk '{print $5}' | sed "s|${CDIR}/${2}-||g"
}

rmZFSSnap() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi

  # Get the dataset of the jails mountpoint
  rDataSet=`mount | grep "on ${1} " | awk '{print $1}'`
  zfs destroy ${rDataSet}@$2
}

rmZFSSnapDate() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi
  tank=`getZFSTank "$1"`
  rp=`getZFSRelativePath "$1"`

  snap_rm_date=`echo "$2" | sed 's/-//g'`

  if [ ! `date -j "$snap_rm_date"0000 "+%Y%m%d" 2>/dev/null` ]; then
    printerror "$2 is not a valid date."
  fi

  echo "Removing snapshots older than $2."
  echo "-----------------------------------"

  for i in `zfs list -r -H -S creation -o name -t snapshot ${tank}${rp} 2>/dev/null`
  do
    snap_creation_date=`zfs get -H -o value creation $i 2>/dev/null`
		# Format output to numbered month. zfs get ouput: "Wed Oct  1 17:30 2014"
    snap_creation_date=`echo $snap_creation_date | sed 's/ Jan / 01 /;s/ Feb / 02 /;s/ Mar / 03 /;s/ Apr / 04 /;s/ May / 05 /;s/ Jun / 06 /;s/ Jul / 07 /;s/ Aug / 08 /;s/ Sep / 09 /;s/ Oct / 10 /;s/ Nov / 11 /;s/ Dec / 12 /'`
		# Format day output to two digit number. zfs get ouput: "Wed Oct  1 17:30 2014"
    snap_creation_date=`echo $snap_creation_date | sed 's/ 1 / 01 /;s/ 2 / 02 /;s/ 3 / 03 /;s/ 4 / 04 /;s/ 5 / 05 /;s/ 6 / 06 /;s/ 7 / 07 /;s/ 8 / 08 /;s/ 9 / 09 /' | awk '{ print $5 $2 $3 }'`
    if [ "$snap_creation_date" -lt "$snap_rm_date" ]; then
      snapshot=`echo $i | cut -d '@' -f 2 | awk '{ print $1 }'`
      zfs destroy $i
      if [ $? -ne 0 ]; then printerror "Something went wrong with removal of $snapshot. Aborting."; fi
      echo "Removed snapshot $snapshot"
    fi
  done

}

revertZFSSnap() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi
  tank=`getZFSTank "$1"`
  rp=`getZFSRelativePath "$1"`

  # Make sure this is a valid snapshot
  zfs list -t snapshot | grep -w "^${tank}${rp}" | cut -d '@' -f 2 | awk '{print $1}' | grep -q ${2}
  if [ $? -ne 0 ] ; then printerror "Invalid ZFS snapshot!" ; fi

  # Check if the jail is running first
  ${PROGDIR}/scripts/backend/checkstatus.sh "${3}"
  if [ "$?" = "0" ]; then
    restartJail="YES"
    # Make sure the jail is stopped
    ${PROGDIR}/scripts/backend/stopjail.sh "${3}"
    ${PROGDIR}/scripts/backend/checkstatus.sh "${3}"
    if [ "$?" = "0" ]; then
      printerror "Could not stop jail... Halting..."
    fi
  fi

  # Rollback the snapshot
  zfs rollback -R -f ${tank}${rp}@$2

  # If it was started, restart the jail now
  if [ "$restartJail" = "YES" ]; then
    ${PROGDIR}/scripts/backend/startjail.sh "${3}"
  fi
  
}

cloneZFSDir() {
  isDirZFS "${1}" "1"
  if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${1}" ; fi

  # Get the dataset of the jails mountpoint
  rDataSet=`mount | grep "on ${JDIR} " | awk '{print $1}'`
  oSubDir=`basename $1`
  oDataSet="${rDataSet}/${oSubDir}"
  nSubDir=`basename $2`
  nDataSet="${rDataSet}/${nSubDir}"

  zdate=`date +%Y-%m-%d-%H-%M-%S`
  snapName="preClone-$zdate"

  # Create a temp snapshot we can clone
  zfs snapshot ${oDataSet}@${snapName}
  if [ $? -ne 0 ] ; then printerror "Failed creating snapshot!" ; fi

  # Clone the snapshot
  zfs clone -p ${oDataSet}@${snapName} ${nDataSet}
  if [ $? -ne 0 ] ; then printerror "Failed cloning snapshot!" ; fi

  return 0
}

set_warden_metadir()
{
   JMETADIR="${JDIR}/.${JAILNAME}.meta"
   export JMETADIR
}

get_ip_and_netmask()
{
   JIP=`echo "${1}" | cut -f1 -d'/'`
   JMASK=`echo "${1}" | cut -f2 -d'/' -s`
}

get_interface_addresses()
{
   ifconfig ${1} | grep -w inet | awk '{ print $2 }'
}

get_interface_ipv4_addresses()
{
   ifconfig ${1} | grep -w inet | awk '{ print $2 }'
}

get_interface_ipv6_addresses()
{
   ifconfig ${1} | grep -w inet6 | awk '{ print $2 }'
}

get_interface_address()
{
   ifconfig ${1} | grep -w inet | head -1 | awk '{ print $2 }'
}

get_interface_ipv4_address()
{
   ifconfig ${1} | grep -w inet | head -1 | awk '{ print $2 }'
}

get_interface_ipv6_address()
{
   ifconfig ${1} | grep -w inet6 | head -1 | awk '{ print $2 }'
}

get_interface_aliases()
{
   local _count

   _count=`ifconfig ${1} | grep -w inet | wc -l`
   _count="$(echo "${_count} - 1" | bc)"

   ifconfig ${1} | grep -w inet | tail -${_count} | awk '{ print $2 }'
}

get_interface_ipv4_aliases()
{
   local _count

   _count=`ifconfig ${1} | grep -w inet | wc -l`
   _count="$(echo "${_count} - 1" | bc)"

   ifconfig ${1} | grep -w inet | tail -${_count} | awk '{ print $2 }'
}

get_interface_ipv6_aliases()
{
   local _count

   _count=`ifconfig ${1} | grep -w inet | wc -l`
   _count="$(echo "${_count} - 1" | bc)"

   ifconfig ${1} | grep -w inet6 | tail -${_count} | awk '{ print $2 }'
}

get_default_route()
{
   netstat -f inet -nr | grep '^default' | awk '{ print $2 }'
}

get_default_interface()
{
   local iface
   iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $7 }'`
   if [ -z "$iface" ] ; then
     # For 10.1 and later
     iface=`netstat -f inet -nrW | grep '^default' | awk '{ print $6 }'`
   fi
   echo $iface
}

get_bridge_interfaces()
{
   ifconfig -a | grep -E '^bridge[0-9]+' | cut -f1 -d:
}

get_bridge_members()
{
   ifconfig ${1} | grep -w member | awk '{ print $2 }'
}

get_bridge_interface_by_ipv4_network()
{
   local network="${1}"
   local bridges="$(get_bridge_interfaces)"

   if [ -z "${network}" ]
   then
      return 1
   fi

   for _bridge in ${bridges}
   do
      local ips="$(get_interface_ipv4_aliases "${_bridge}")"
      for _ip in ${ips}
      do
         if in_ipv4_network "${_ip}" "${network}"
         then
            echo "${_bridge}"
            return 0
         fi
      done
   done

   return 1
}

get_bridge_interface_by_ipv6_network()
{
   local network="${1}"
   local bridges="$(get_bridge_interfaces)"

   if [ -z "${network}" ]
   then
      return 1
   fi

   for _bridge in ${bridges}
   do
      local ips="$(get_interface_ipv6_aliases "${_bridge}")"
      for _ip in ${ips}
      do
         if in_ipv6_network "${_ip}" "${network}"
         then
            echo "${_bridge}"
            return 0
         fi
      done
   done

   return 1
}

is_bridge_member()
{
   local _bridge="${1}"
   local _iface="${2}"

   for _member in `get_bridge_members ${_bridge}`
   do
      if [ "${_member}" = "${_iface}" ] ; then
         return 0
      fi
   done

   return 1
}

jail_interfaces_down()
{
   local _jid="${1}"
   local _bridgeif
   local _epaira
   local _epairb

   _epairb=`jexec ${_jid} ifconfig -a | grep '^epair' | cut -f1 -d:`
   if [ -n "${_epairb}" ] ; then
      _epaira=`echo ${_epairb} | sed -E 's|b$|a|'`
      _bridgeif=

      for _bridge in `ifconfig -a | grep -E '^bridge[0-9]+' | cut -f1 -d:`
      do
         for _member in `ifconfig ${_bridge} | grep member | awk '{ print $2 }'`
         do
            if [ "${_member}" = "${_epaira}" ] ; then
               _bridgeif="${_bridge}"
                break
            fi
         done
         if [ -n "${_bridgeif}" ] ; then
            break
         fi
      done

      jexec ${_jid} ifconfig ${_epairb} down
      ifconfig ${_epaira} down
      ifconfig ${_epaira} destroy
      _count=`ifconfig ${_bridgeif} | grep member | awk '{ print $2 }' | wc -l`
      if [ "${_count}" -lt "1" ] ; then
         ifconfig ${_bridgeif} destroy
      fi
   fi
}

enable_cron()
{
   cronscript="${PROGDIR}/scripts/backend/cronsnap.sh"
   grep -q "${cronscript}" /etc/crontab
   if [ $? -eq 0 ] ; then return 0 ; fi
   echo "2     *        *       *       *        root    ${cronscript}" >> /etc/crontab
   # Restart cron
   /etc/rc.d/cron restart >/dev/null 2>/dev/null
}

fix_old_meta()
{
   for i in `ls -d ${JDIR}/.*.meta 2>/dev/null`
   do
      if [ -e "${i}/xjail" ] ; then
         touch ${i}/jail-portjail 2>/dev/null
      fi
      if [ -e "${i}/linuxjail" ] ; then
         touch ${i}/jail-linux 2>/dev/null
      fi
   done
}

is_ipv4()
{
   local addr="${1}"
   local res=1

   local ipv4="$(/usr/local/bin/sipcalc "${addr}"|head -1|cut -f2 -d'['|awk '{ print $1 }')"
   if [ "${ipv4}" = "ipv4" ]
   then
      res=0
   fi

   return ${res}
}

is_ipv6()
{
   local addr="${1}"
   local res=1

   local ipv6="$(/usr/local/bin/sipcalc "${addr}"|head -1|cut -f2 -d'['|awk '{ print $1 }')"
   if [ "${ipv6}" = "ipv6" ]
   then
      res=0
   fi

   return ${res}
}

in_ipv4_network()
{
   local addr="${1}"
   local network="${2}"
   local res=1

   local start="$(/usr/local/bin/sipcalc "${network}"|awk '/^Usable/ { print $4 }')"
   local end="$(/usr/local/bin/sipcalc "${network}"|awk '/^Usable/ { print $6 }')"

   local iaddr="$(/usr/local/bin/sipcalc "${addr}"|awk '/(decimal)/ { print $5 }')"
   local istart="$(/usr/local/bin/sipcalc "${start}"|awk '/(decimal)/ { print $5 }')"
   local iend="$(/usr/local/bin/sipcalc "${end}"|awk '/(decimal)/ { print $5 }')"

   if [ "${iaddr}" -ge "${istart}" -a "${iaddr}" -le "${iend}" ]
   then
      res=0
   fi

   return ${res}
}

ipv6_to_binary()
{
   echo ${1}|awk '{
      split($1, octets, ":");
      olen = length(octets);
		
      bnum = "";
      for (i = 1;i <= olen;i++) {
         tbnum = "";
         dnum = int(sprintf("0x%s", octets[i]));
         for (;;) {
            rem = int(dnum % 2);
            if (rem == 0) 
               tbnum = sprintf("0%s", tbnum);
            else		
               tbnum = sprintf("1%s", tbnum);
            dnum /= 2;
            if (dnum < 1)
               break;
         }
         bnum = sprintf("%s%016s", bnum, tbnum);
      }
      printf("%s", bnum);
   }'
}

in_ipv6_network()
{
   local addr="${1}"
   local network="${2}"
   local mask="$(echo "${network}"|cut -f2 -d'/' -s)"
   local res=1

   local addr="$(/usr/local/bin/sipcalc "${addr}"|awk \
      '/^Expanded/ { print $4}')"
   local start="$(/usr/local/bin/sipcalc "${network}"|egrep \
      '^Network range'|awk '{ print $4 }')"

   local baddr="$(ipv6_to_binary "${addr}")"
   local bstart="$(ipv6_to_binary "${start}")"

   local baddrnet="$(echo "${baddr}"|awk -v mask="${mask}" \
      '{ s = substr($0, 1, mask); printf("%s", s); }')"
   local bstartnet="$(echo "${bstart}"|awk -v mask="${mask}" \
      '{ s = substr($0, 1, mask); printf("%s", s); }')"

   if [ "${baddrnet}" = "${bstartnet}" ]
   then
      res=0
   fi

   return ${res}
}

install_pc_extractoverlay()
{
  if [ -z "${1}" ] ; then
    return 1 
  fi 

  mkdir -p ${1}/usr/local/bin
  mkdir -p ${1}/usr/local/share/pcbsd/conf
  mkdir -p ${1}/usr/local/share/pcbsd/distfiles

  cp /usr/local/bin/pc-extractoverlay ${1}/usr/local/bin/
  chmod 755 ${1}/usr/local/bin/pc-extractoverlay

  cp /usr/local/share/pcbsd/conf/server-excludes \
    ${1}/usr/local/share/pcbsd/conf
  cp /usr/local/share/pcbsd/distfiles/server-overlay.txz \
    ${1}/usr/local/share/pcbsd/distfiles

  return 0
}

make_bootstrap_pkgng_file_standard()
{
  local jaildir="${1}"
  local outfile="${2}"

  if [ ! -e "${jaildir}/bin/freebsd-version" ] ; then
     echo "Missing /bin/freebsd-version in jail.."
     echo "PKG bootstrap can only be done on 10.0 and higher, skipping..."
     return 1
  fi

  # Setup the repo to use the XX.0-RELEASE pkgng branch
  local release="`${jaildir}/bin/freebsd-version | cut -d '-' -f 1 |  cut -d '.' -f 1`.0-RELEASE"
  local arch="$(uname -m)"

cat<<__EOF__>"${outfile}"
#!/bin/sh
tar xvf pkg.txz --exclude +MANIFEST --exclude +MTREE_DIRS 2>/dev/null
pkg add pkg.txz
rm pkg.txz

# Create the pkg.conf file
echo "PKG_CACHEDIR: /usr/local/tmp
REPOS_DIR: [
                \"/usr/local/etc/pkg/repos\"
           ]" > /usr/local/etc/pkg.conf

# Create the repo dirs
mkdir -p /usr/local/etc/pkg/repos 2>/dev/null
mkdir -p /usr/local/etc/pkg/fingerprints/pcbsd/trusted 2>/dev/null
mkdir -p /usr/local/etc/pkg/fingerprints/pcbsd/revoked 2>/dev/null

# Save the repo configuration file
echo "pcbsd-major: {
               url: \"http://pkg.cdn.pcbsd.org/${release}/${arch}\",
               signature_type: \"fingerprints\",
               fingerprints: \"/usr/local/etc/pkg/fingerprints/pcbsd\",
               enabled: true
              }" > /usr/local/etc/pkg/repos/pcbsd.conf

# Create the repo.dist file
echo "pcbsd: {
               url: \"http://pkg.cdn.pcbsd.org/VERSION/ARCH\",
               signature_type: \"fingerprints\",
               fingerprints: \"/usr/local/etc/pkg/fingerprints/pcbsd\",
               enabled: true
              }" > /usr/local/etc/pkg/repos/pcbsd.conf.dist

# Save the fingerprint file
echo "function: sha256
fingerprint: b2b9e037f938cf20ba68aa85ac88c15889c729a7f6b70c25069774308e760a03" > /usr/local/etc/pkg/fingerprints/pcbsd/trusted/pkg.cdn.pcbsd.org.20131209

pkg update -f

exit 0
__EOF__

}

make_bootstrap_pkgng_file_pluginjail()
{

  local jaildir="${1}"
  local outfile="${2}"

  if [ ! -e "${jaildir}/bin/freebsd-version" ] ; then
     echo "Missing /bin/freebsd-version in jail.."
     echo "PKG bootstrap can only be done on 10.0 and higher, skipping..."
     return 0
  fi

  # Setup the repo to use the XX.0-RELEASE pkgng branch
  local release="`${jaildir}/bin/freebsd-version | cut -d '-' -f 1 |  cut -d '.' -f 1`.0-RELEASE"
  local arch="$(uname -m)"

  get_mirror
  local mirror="${VAL}"

  cp /usr/local/share/warden/pluginjail-packages "${jaildir}/pluginjail-packages"

cat<<__EOF__>"${outfile}"
#!/bin/sh
tar xvf pkg.txz --exclude +MANIFEST --exclude +MTREE_DIRS 2>/dev/null
pkg add pkg.txz
rm pkg.txz

mount -t devfs devfs /dev

# Create the pkg.conf file
echo "PKG_CACHEDIR: /usr/local/tmp
REPOS_DIR: [
                \"/usr/local/etc/pkg/repos\"
           ]" > /usr/local/etc/pkg.conf

# Create the repo dirs
mkdir -p /usr/local/etc/pkg/repos 2>/dev/null
mkdir -p /usr/local/etc/pkg/fingerprints/pcbsd/trusted 2>/dev/null
mkdir -p /usr/local/etc/pkg/fingerprints/pcbsd/revoked 2>/dev/null

# Save the repo configuration file
echo "pcbsd-major: {
               url: \"http://pkg.cdn.pcbsd.org/${release}/${arch}\",
               signature_type: \"fingerprints\",
               fingerprints: \"/usr/local/etc/pkg/fingerprints/pcbsd\",
               enabled: true
              }" > /usr/local/etc/pkg/repos/pcbsd.conf

# Create the repo.dist file
echo "pcbsd: {
               url: \"http://pkg.cdn.pcbsd.org/VERSION/ARCH\",
               signature_type: \"fingerprints\",
               fingerprints: \"/usr/local/etc/pkg/fingerprints/pcbsd\",
               enabled: true
              }" > /usr/local/etc/pkg/repos/pcbsd.conf.dist

# Save the fingerprint file
echo "function: sha256
fingerprint: b2b9e037f938cf20ba68aa85ac88c15889c729a7f6b70c25069774308e760a03" > /usr/local/etc/pkg/fingerprints/pcbsd/trusted/pkg.cdn.pcbsd.org.20131209

pkg update -f

__EOF__

echo '
i=0
count=`wc -l /pluginjail-packages| awk "{ print $1 }"`
for p in `cat /pluginjail-packages`
do
  pkg install -y ${p}
  : $(( i += 1 ))
done

umount devfs
exit $?
' >> "${outfile}"
}


bootstrap_pkgng()
{
  local jaildir="${1}"
  local jailtype="${2}"
  if [ -z "${jailtype}" ] ; then
    jailtype="standard"
  fi

  if [ ! -e "${jaildir}/bin/freebsd-version" ] ; then
     echo "Missing /bin/freebsd-version in jail.."
     echo "PKG bootstrap can only be done on 10.0 and higher, skipping..."
     return 1
  fi

  local release="`${jaildir}/bin/freebsd-version | cut -d '-' -f 1 |  cut -d '.' -f 1`.0-RELEASE"
  local arch="$(uname -m)"

  local ffunc="make_bootstrap_pkgng_file_standard"
  if [ "${jailtype}" = "pluginjail" ] ; then
    ffunc="make_bootstrap_pkgng_file_pluginjail"
  fi

  cd ${jaildir} 
  echo "Boot-strapping pkgng"

  mkdir -p ${jaildir}/usr/local/etc


  ${ffunc} "${jaildir}" "${jaildir}/bootstrap-pkgng"
  chmod 755 "${jaildir}/bootstrap-pkgng"

  if [ -e "pkg.txz" ] ; then rm pkg.txz ; fi
  get_file_from_mirrors "/${release}/${arch}/Latest/pkg.txz" "pkg.txz" "pkg"
  if [ $? -eq 0 ] ; then
    chroot ${jaildir} /bootstrap-pkgng
    if [ $? -eq 0 ] ; then
      rm -f "${jaildir}/bootstrap-pkgng"
      rm -f "${jaildir}/pluginjail-packages"
      chroot ${jaildir} pc-extractoverlay server --sysinit
      return 0
    fi
  fi

  echo "Failed boot-strapping PKGNG, most likely cause is internet connection failure."
  rm -f "${jaildir}/bootstrap-pkgng"
  rm -f "${jaildir}/pluginjail-packages"
  return 1
}

ipv4_configured()
{
   local iface="${1}"
   local jid="${2}"
   local jexec=

   if [ -n "${jid}" ] ; then
      jexec="jexec ${jid}"
   fi

   ${jexec} ifconfig "${iface}" | grep -qw inet 2>/dev/null
   return $?
}

ipv4_address_configured()
{
   local iface="${1}"
   local addr="${2}"
   local jid="${3}"
   local jexec= 

   addr="$(echo ${addr}|cut -f1 -d'/')"

   if [ -n "${jid}" ] ; then
      jexec="jexec ${jid}"
   fi

   ${jexec} ifconfig "${iface}" | \
      grep -w inet | \
      awk '{ print $2 }' | \
      grep -Ew "^${addr}" >/dev/null 2>&1
   return $?
}

ipv6_configured()
{
   local iface="${1}"
   local jid="${2}"
   local jexec=

   if [ -n "${jid}" ] ; then
      jexec="jexec ${jid}"
   fi

   ${jexec} ifconfig "${iface}" | grep -qw inet6 2>/dev/null
   return $?
}

ipv6_address_configured()
{
   local iface="${1}"
   local addr="${2}"
   local jid="${3}"
   local jexec= 

   addr="$(echo ${addr}|cut -f1 -d'/')"

   if [ -n "${jid}" ] ; then
      jexec="jexec ${jid}"
   fi

   ${jexec} ifconfig "${iface}" | \
      grep -w inet6 | \
      awk '{ print $2 }' | \
      grep -Ew "^${addr}" >/dev/null 2>&1
   return $?
}

get_ipfw_nat_instance()
{
   local iface="${1}"
   local res=1

   if [ -z "${iface}" ] ; then
      local instance="`ipfw list|egrep '[0-9]+ nat'|awk '{ print $3 }'|tail -1`"
      if [ -z "${instance}" ] ; then
         instance="100"
      else		  
         : $(( instance += 100 )) 
      fi
      echo "${instance}"
      return 0
   fi

   for ni in `ipfw list|egrep '[0-9]+ nat'|awk '{ print $3 }'`
   do
      ipfw nat "${ni}" show config|egrep -qw "${iface}"
      if [ "$?" = "0" ] ; then
         echo "${ni}"
         res=0
         break
      fi
   done

   return ${res}
}

get_ipfw_nat_priority()
{
   local iface="${1}"
   local res=1

   if [ -z "${iface}" ] ; then
      local priority="`ipfw list|egrep '[0-9]+ nat'|awk '{ print $1 }'|tail -1`"
      if [ -z "${priority}" ] ; then
         priority=2000
      fi
      printf "%05d\n" "${priority}"
      return 0
   fi

   local IFS='
'
   for rule in `ipfw list|egrep '[0-9]+ nat'`
   do
      local priority="`echo "${rule}"|awk '{ print $1 }'`"
      local ni="`echo "${rule}"|awk '{ print $3 }'`"

      ipfw nat "${ni}" show config|egrep -qw "${iface}"
      if [ "$?" = "0" ] ; then
         echo "${priority}"
         res=0
         break
      fi
   done

   return ${res}
}

list_templates()
{
   echo "Jail Templates:"
   echo "------------------------------" 
   for i in `ls -d ${JDIR}/.warden-template* 2>/dev/null`
   do 
     if [ ! -e "$i/bin/sh" ] ; then continue ; fi
     NICK=`echo "$i" | sed "s|${JDIR}/.warden-template-||g"`
     file "$i/bin/sh" 2>/dev/null | grep -q "64-bit"
     if [ $? -eq 0 ] ; then
        ARCH="amd64"
     else
        ARCH="i386"
     fi
     VER=`file "$i/bin/sh" | cut -d ',' -f 5 | awk '{print $3}'`
     if [ -e "$i/etc/rc.conf.pcbsd" ] ; then
        TYPE="TrueOS"
     else
        TYPE="FreeBSD"
     fi
     echo -e "${NICK} - $TYPE $VER ($ARCH)"
  done
  exit 0
}

delete_template()
{
   tDir="${JDIR}/.warden-template-${1}"
   isDirZFS "${tDir}" "1"
   if [ $? -ne 0 ] ; then printerror "Not a ZFS volume: ${tDir}" ; fi

   # Get the dataset of the jails mountpoint
   rDataSet=`mount | grep "on ${tDir} " | awk '{print $1}'`

   zfs destroy -r ${rDataSet}
   if [ $? -ne 0 ] ; then
     exit_err "Could not remove template, perhaps you have jails still using it?"
   fi
   rmdir ${tDir}
   echo "DONE"

   exit 0
}

get_ip_host_flags()
{
         IP4="OFF"
         IP6="OFF"
         HOST="OFF"
         for i in "$@"
         do
           # Check if we have a new IPv4 address for this import
           echo "${i}" | grep '\-\-ipv4=' >/dev/null 2>/dev/null
           if [ "$?" = "0" ]; then
              tmp="`echo ${i} | cut -d '=' -f 2`"
              IP4="`echo ${tmp} | cut -d '/' -f 1 -s`"
              MASK4="`echo ${tmp} | cut -d '/' -f 2 -s`"

              #Sanity check on the IP
              if ! is_ipv4 "${IP4}" ; then
                 exit_err "Invalid IPv4 address: $IP4"
              fi

              for i in `ls -d ${JDIR}/.*.meta 2>/dev/null`
              do
                if [ "`cat ${i}/ipv4 2>/dev/null`" = "${IP4}/${MASK4}" ] ; then
                  exit_err "A jail with this IPv4 address already exists!"
                fi
              done
           fi

           # Check if we have a new IPv6 address for this import
           echo "${i}" | grep '\-\-ipv6=' >/dev/null 2>/dev/null
           if [ "$?" = "0" ]; then
              tmp="`echo ${i} | cut -d '=' -f 2`"
              IP6="`echo ${tmp} | cut -d '/' -f 1 -s`"
              MASK6="`echo ${tmp} | cut -d '/' -f 2 -s`"

              #Sanity check on the IP
              if ! is_ipv6 "${IP6}" ; then
                 exit_err "Invalid IPv6 address!"
              fi

              for i in `ls -d ${JDIR}/.*.meta 2>/dev/null`
              do
                _ipv6=`cat ${i}/ipv6 2>/dev/null | tr a-z A-Z`
                _nipv6="`echo ${IP6}|tr a-z A-Z`/${MASK6}"

                if [ "${_ipv6}" = "${_nipv6}" ] ; then
                  exit_err "A jail with this IPv6 address already exists!"
                fi
              done
           fi

           # Check if we have a new hostname for this jail
           echo ${i} | grep '\-\-host=' >/dev/null 2>/dev/null
           if [ "$?" = "0" ]; then
              HOST="`echo ${i} | cut -d '=' -f 2`"
           fi

         done

}

zfs_prog_check() {

   local testDataSet=`mount | grep "on ${JDIR} " | awk '{print $1}'`
   if [ -z "$testDataSet" ] ; then
      echo "WARNING: JDIR is NOT set to a ZFS managed dataset.."
      echo "Please change JDIR in /usr/local/etc/warden.conf to a valid, mounted ZFS dataset!"
      exit 1
   fi

}
