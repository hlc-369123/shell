#!/bin/bash

begin() {
  title=${1-"test"}
  cat << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<workload name="$title" description="sample benchmark for s3">
  <workflow>
    <workstage name="main">    

EOF
}

end() {
cat << EOF
    </workstage>
  </workflow>
</workload>
EOF
}

main() {

access_key="9085OIIQK5OK7WB4TKFZ"
secret_key="3ESLNFoF3qyDisoBc82DY1EXNoWDv7wtfe31wD2r"

hosts="
10.252.1.27:8001
10.252.1.28:8001
10.252.1.29:8001"
idx=1

buckets=$1  #桶数
works=$2    #每个gateway的work数
workers=$3  #每个work的worker数，类似numjobs,write时为1，read时可以增加
op_type=$4  #read or write
cprefix=$5  #桶前缀
oprefix=$6  #对象前缀
size=$7     #对象大小
oid=$8    #对象起始值
step=$9   #对象计数步长

for i in `seq $buckets`;
do
for ip in $hosts;
do
for j in `seq $works`;
do
obj_start=$oid
obj_end=`expr $step + $oid - 1`
cat << EOF
      <work name="w$idx" workers="$workers" totalOps="$step" >
        <operation type="$op_type" ratio="100" config="cprefix=$cprefix;oprefix=$oprefix-;containers=c($i);objects=s($obj_start,$obj_end);sizes=$size" />
        <storage type="s3" config="path_style_access=true;accesskey=$access_key;secretkey=$secret_key;proxyhost=;proxyport=;endpoint=http://$ip" />
      </work>
EOF
let oid=$oid+$step
let idx=$idx+1
done
done
done
}

begin "put_4m_test"
main $1 $2 $3 $4 $5 $6 $7 $8 $9
end
#./singlebucket140.sh 20 2 2 write feng- 001 'c(97)KB' 1 100000 > 50.xml
