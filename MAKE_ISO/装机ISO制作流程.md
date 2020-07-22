# 装机ISO制作流程

## 基本思路

​	装机ISO镜像基于centos7.6制作，基本思路是使用官方的镜像，先解包，然后再其中加入需要安装的软件包，利用kickstart定义自动化安装流程，最后重新封装成ISO镜像，并写入md5校验码。

## 概念解释

​	kickstart:kickstart是一种ISO安装方式，根据kickstart的语法定义好安装流程，做到自动化装机，免去了装机过程中的人机交互	
kickstart语法参考：

https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/installation_guide/sect-kickstart-syntax

# ISO制作流程

## 开发环境

操作系统：Linux（CentOS）

使用工具：createrepo、genisoimage、isomd5sum，pykickstart ；用yum安装

```bash
yum -y install createrepo genisoimage isomd5sum pykickstart
```

**一般情况下只需要安装以上包即可**

system-config-kickstart-2.9.7-1.el7.noarch 为生成ks.cfg图形化工具，需要先安装图形桌面的rpm包组

```bash
yum -y groupinstall "GNOME Desktop" "Graphical Administration Tools"
systemctl get-default #获取当前系统运行形式，会显示multi-user.target（命令行终端），或者：graphical.target
systemctl set-default graphical.target #设置默认启动为图形界面，reboot后界面会自动是图形窗口了。
systemctl set-default multi-user.target #换回命令界面启动

yum -y install system-config-kickstart
shutdown -r 0 #重启后默认进入图形界面
```

## 流程

下载官方ISO镜像，我用的是CentOS-7.6-x86_64-DVD-1810.iso

挂载ISO镜像

```bash
mkdir -p bootiso``mount -o loop CentOS-7-x86_64-Minimal-1810.iso bootiso/
```

Copy镜像内容到自己的文件夹

```bash
mkdir -p bootisoks``cp -r bootiso/* bootisoks/
```

生成root密码加密字符串

```bash
# grub-crypt --sha-512
或
# echo 'import crypt,getpass; print crypt.crypt(getpass.getpass(), "$6$16_CHARACTER_SALT_HERE")' | python -
输出：
$6$16_CHARACTER_SAL$dvFZEFR66m38M3u3K4os2Yi4j88oTRaF9Q7XkKK4VFlMlwS9l17oTjXI043rfpNxDkB8/1ntrOiAFQGeYgwEZ.
```

编辑kickstart文件ks.cfg，将其copy到自己的目录的isolinux/下，ks.cfg内容如下

```bash
install #表示是安装，而不是升级
cdrom #安装方式，如果是网络安装的话可以写成 url ––url ftp://192.168.1.254/dir 或者 nfs --server=192.168.0.241 --dir=/centosinstall 
text #文本方式安装 
keyboard us #键盘样式
lang en_US.UTF-8 #系统默认编码
rootpw --iscrypted $6$16_CHARACTER_SAL$dvFZEFR66m38M3u3K4os2Yi4j88oTRaF9Q7XkKK4VFlMlwS9l17oTjXI043rfpNxDkB8/1ntrOiAFQGeYgwEZ. #root密码
auth --useshadow --passalgo=sha512 #系统认证方式
# firewall配置防火墙，可以--port=xx,xx指定打开的端口，本文档中暂时关闭
firewall --disabled
selinux --disabled
# network配置网络，一体机定制机型千兆卡有4口，其中前两个口做bond，第三个口设置固定IP：192.168.254.1
network --device=bond1 --bondslaves=enfs1f0,ens1f1
network --onboot=yes --devces=ens1f2 --ip=192.168.254.1 --netmask=255.255.255.0
skipx #如果存在，则在已安装的系统上配置
#reboot指定装机完成后需要重启
reboot
timezone Asia/Shanghai #时区
bootloader --location=mbr --driveorder=sda #引导程序相关参数 
zerombr #清空磁盘的mbr
clearpart --all --initlabel #初始化磁盘
# part配置分区
part /boot --fstype="xfs" --ondisk=sda --size=1024
part / --fstype="xfs" --ondisk=sda --size=1 --grow
 
%pre
# 可以在这里添加脚本，脚本将在Kickstart文件被解析后，安装开始之前执行，比如根据硬盘大小写出不同的分区方案
%end
 
%post
#!/bin/bash
# 这里的脚本是在安装之后执行，例如将xs_4.1.0.xxx.tar.gz拷贝到指定目录
%end
```

修改isolinux.cfg定制boot menu，并将kickstart文件添加label的option

```bash
label linux
  menu label ^Install XS_4.1.000.0 in XE2000
  kernel vmlinuz
  append initrd=initrd.img ks=cdrom:/ks.cfg
cd bootisoks/isolinux/
sed -i  '62s/menu label.*/menu label ^Install XS_4.1.000.0 in XE2000/; 64s/append initrd=.*64 quiet/append initrd=initrd.img ks=cdrom:\/ks.cfg/' isolinux.cfg
```

将需要安装的rpm包copy到Packages，并重新生成包索引和元数据。

```bash
cd bootisoks/
createrepo Packages
```

重新打包ISO

```bash
cd bootisoks/
mkisofs -o ../xs_boot.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "XSKY XSCALER 4.1" -R -J -v -T isolinux/. .
```

MD5验证码并写入到ISO包

```bash
cd bootisoks/..
implantisomd5 xs_boot.iso  //md5写入iso
checkisomd5 xs_boot.iso    //验证iso
```

## **自动镜像打包脚本**

将相关的镜像上传到指定的位置

```bash
ls CentOS-7-x86_64-Minimal-1810.iso ks.cfg
CentOS-7-x86_64-Minimal-1810.iso ks.cfg
```

自动打包脚本

```bash
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
```

 

 