#!/bin/bash

sou_iso="CentOS-7.6-x86_64-DVD-1810.iso"
new_ios="XOS-7.6-x86_64-1810.iso"
ks_cfg="ks.cfg"
RPMcheck=$(rpm -qa|egrep 'genisoimage|createrepo|isomd5sum|pykickstart'|wc -l)

if [[ ! -f ./$sou_iso || ! -f ./$ks_cfg ]];then
echo "Unfound $sou_iso Or $ks_cfg "
exit 1
fi
if [[ $RPMcheck -lt 4 ]];then
echo "Please Check Is Istall 'genisoimage createrepo isomd5sum pykickstart'"
exit 1
fi

stat_code=$(ksvalidator ${ks_cfg} |wc -l)
if [[ $stat_code != '0' ]];then
ksvalidator ks.cfg
exit 1
fi

umount -l bootiso/ &>/dev/null
if [[ -f "${new_ios}" ]];then
  rm -rf ./${new_ios}
fi
rm -rf ./bootiso ./bootisoks
mkdir -p bootiso
mount -o loop ${sou_iso} bootiso/
mkdir -p bootisoks
cp -r bootiso/* bootisoks/
cd bootisoks/isolinux/
#sed -i '62s/menu label.*/menu label ^Install XS_4.1.000.0 in XE2000/; 64s/append initrd=.*64 quiet/append initrd=initrd.img ks=cdrom:\/ks.cfg/' isolinux.cfg
sed -i '64s/append initrd=.*64 quiet/append initrd=initrd.img ks=cdrom:\/ks.cfg/' isolinux.cfg
cp ../../ks.cfg ./
cd ..
#createrepo Packages
mkisofs -o ../${new_ios} -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "CentOS 7.6-x86_64 1810" -R -J -v -T isolinux/. .
cd ..
implantisomd5 ${new_ios}
checkisomd5 ${new_ios}

sync
echo 3 >/proc/sys/vm/drop_caches
