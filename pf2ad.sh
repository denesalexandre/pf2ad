#!/bin/sh

VERSION='20160414007'

if [ -f "/etc/samba3.patch.version" ]; then
	if [ "$(cat /etc/samba3.patch.version)" = "$VERSION" ]; then
		echo "ERROR: Changes have been applied!"
		exit 2
	fi
fi

# Verifica versao pfSense
if [ "$(cat /etc/version)" != "2.3-RELEASE" ]; then
	echo "ERROR: You need the pfSense version 2.3 to apply this script"
	exit 2
fi

arch="`uname -p`"

ASSUME_ALWAYS_YES=YES
export ASSUME_ALWAYS_YES

/usr/sbin/pkg bootstrap
/usr/sbin/pkg update

# Lock packages necessary
/usr/sbin/pkg lock pfSense-2.3
/usr/sbin/pkg lock dnsmasq-devel

mkdir -p /usr/local/etc/pkg/repos

cat <<EOF > /usr/local/etc/pkg/repos/pf2ad.conf
pf2ad: {
    url: "http://projetos.mundounix.com.br/pfsense/2.3/packages/${arch}",
    mirror_type: "http",
    enabled: yes
}
EOF

/usr/sbin/pkg update -r pf2ad
/usr/sbin/pkg install -r pf2ad net/samba36 2> /dev/null

echo 'samba_enable="YES"' > /etc/rc.conf.d/samba
echo 'winbindd_enable="YES"' > /etc/rc.conf.d/winbindd

cd /usr/local/etc/rc.d/
if [ ! -f "samba.sh" ]; then
	ln -s samba samba.sh
fi

mkdir -p /var/db/samba/winbindd_privileged
chown -R :proxy /var/db/samba/winbindd_privileged
chmod -R 0750 /var/db/samba/winbindd_privileged

fetch -o /usr/local/pkg -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/samba3.inc
fetch -o /usr/local/pkg -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/samba3.xml
fetch -o /usr/local/www/javascript -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/jquery-1.9.1.min.js

cd /usr/local/www
awk '/gettext\("SNMP"\)/{print "$services_menu[] = array(\"Samba (AD)\", \"/pkg_edit.php?xml=samba3.xml&id=0\");"}1' head.inc > /tmp/head.inc.tmp
mv /tmp/head.inc.tmp head.inc


if [ ! "$(/usr/local/sbin/pfSsh.php playback listpkg | grep 'squid')" ]; then
	/usr/local/sbin/pfSsh.php playback installpkg "squid"
fi

cd /usr/local/pkg
if [ "$(md5 -q squid.inc)" != "55e6a04e9d3867a46443e7a336fce7d0" ]; then
	fetch -o squid.inc -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/squid.inc
fi
if [ "$(md5 -q squid_js.inc)" != "4fb3d0a63fce3ee291e69f9791a77189" ]; then
	fetch -o squid_js.inc -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/squid_js.inc
fi
if [ "$(md5 -q squid_auth.xml)" != "f16ba584bc86093e00b38a86b8a309ef" ]; then
	fetch -o squid_auth.xml -q http://projetos.mundounix.com.br/pfsense/2.3/samba3/squid_auth.xml
fi

if [ ! -f "/usr/local/etc/smb.conf" ]; then
	touch /usr/local/etc/smb.conf
fi
cp -f /usr/local/bin/ntlm_auth /usr/local/libexec/squid/ntlm_auth

/etc/rc.d/ldconfig restart

echo "$VERSION" > /etc/samba3.patch.version