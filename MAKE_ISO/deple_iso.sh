#!/bin/bash

sou_iso="CentOS-7-x86_64-Minimal-1810.iso"
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

stat_code=$(ksvalidator ks.cfg |wc -l)
if [[ $stat_code != '0' ]];then 
  ksvalidator ks.cfg
  exit 1
fi

umount -l bootiso/ &>/dev/null
rm -rf ./xs_boot.iso ./bootiso ./bootisoks
mkdir -p bootiso
mount -o loop CentOS-7-x86_64-Minimal-1810.iso bootiso/
mkdir -p bootisoks
cp -r bootiso/* bootisoks/
cd bootisoks/isolinux/
#sed -i  '62s/menu label.*/menu label ^Install XS_4.1.000.0 in XE2000/; 64s/append initrd=.*64 quiet/append initrd=initrd.img ks=cdrom:\/ks.cfg/' isolinux.cfg
sed -i  '64s/append initrd=.*64 quiet/append initrd=initrd.img ks=cdrom:\/ks.cfg/' isolinux.cfg
cp ../../ks.cfg ./
cd ..
createrepo Packages
mkisofs -o ../xs_boot.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "XSKY XSCALER 4.1" -R -J -v -T isolinux/. .
cd ..
implantisomd5 xs_boot.iso
checkisomd5 xs_boot.iso
