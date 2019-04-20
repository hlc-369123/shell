#!/bin/bash
# mail:863604721@qq.com

DIR=`pwd`
DIR="${DIR}/"
PGNUM=$( echo "scale=1; $(ceph osd pool get volumes pg_num|awk '{print $2}') * $(ceph osd pool get volumes size|awk '{print $2}')" | bc )
TOTAL_SIZE=0
ceph osd df|grep -v "TOTAL\|WEIGHT\|MIN"|awk '$8>0 {print $0}'|awk '{print $4}'|sort -u|sed 's/G//g'  > "${DIR}osd_size.txt"
> "${DIR}osd_size_num.txt"
while read osd_size
do
    num=`ceph osd df|grep -v "TOTAL\|WEIGHT\|MIN"|awk '$8>0 {print $0}'|awk '{print $4}'|grep ${osd_size}|wc -l`
    echo "${osd_size}    ${num}"  >> ${DIR}osd_size_num.txt
    let "TOTAL_SIZE+=${osd_size}*$num"
    #echo "${TOTAL_SIZE}"
done < "${DIR}osd_size.txt"
run_weight=`ceph osd crush dump|grep -A 5 '"type_name": "root"'|awk -F  '"weight":' '{print $2}'|grep [0-9]|sed 's/,//g'`
weight=`echo "scale=3;${run_weight} / 65535" |bc`
function_a=`echo "scale=6;${TOTAL_SIZE} / 1024" |bc`
function=`echo "scale=3;${weight} / ${function_a}" |bc`
function_b=`echo "scale=3;1 / ${function} * 102.4" |bc`
RATIO=`echo "scale=4;${PGNUM} / ${TOTAL_SIZE}" |bc`
STANDARDS=`echo "scale=6;${RATIO} * ${function_b} * 1"|bc` #变大此值可增加精度，默认为1
SET_STANDARD=`echo "scale=6;0.1 / ${STANDARDS}"|bc`
#echo "${SET_STANDARD}"
getpg(){
ceph pg dump | awk '
 /^pg_stat/ { col=1; while($col!="up") {col++}; col++ }
 /^[0-9a-f]+\.[0-9a-f]+/ { match($0,/^[0-9a-f]+/); pool=substr($0, RSTART, RLENGTH); poollist[pool]=0;
 up=$col; i=0; RSTART=0; RLENGTH=0; delete osds; while(match(up,/[0-9]+/)>0) { osds[++i]=substr(up,RSTART,RLENGTH); up = substr(up, RSTART+RLENGTH) }
 for(i in osds) {array[osds[i],pool]++; osdlist[osds[i]];}
}
END {
 printf("\n");
 printf("pool :\t"); for (i in poollist) printf("%s\t",i); printf("| SUM \n");
 for (i in poollist) printf("--------"); printf("----------------\n");
 for (i in osdlist) { printf("osd.%i\t", i); sum=0;
 for (j in poollist) { printf("%i\t", array[i,j]); sum+=array[i,j]; poollist[j]+=array[i,j] }; printf("| %i\n",sum) }
 for (i in poollist) printf("--------"); printf("----------------\n");
 printf("SUM :\t"); for (i in poollist) printf("%s\t",poollist[i]); printf("|\n");
}'
}
ceph osd getcrushmap -o "${DIR}crushmap" > /dev/null 2>&1
run_num=`echo "$(ceph osd ls|wc -l) / 2" |bc` #调整osd的所占比，默认为2
echo $run_num
for i in $(seq 1 ${run_num}) #通过改变此值可以修改调整osd的数量,默认为1
do
    echo $i
    getpg |grep osd|awk '{print $1" "$2}' > "${DIR}"pg_table.txt
    while read osd_size
    do
        PG_NUM=`echo "$osd_size * $RATIO" | bc`
        ceph osd df|grep -v "TOTAL\|WEIGHT\|MIN"|awk '$8>0 {print $0}'|awk '{print $1"\t"$2"\t"$4"\t"$7}'|grep "${osd_size}" > "${DIR}""${osd_size}.txt"
        sed -i "s/^/osd./g"  "${DIR}""${osd_size}.txt"
        sed -i "s/$/\t${PG_NUM}/"  "${DIR}""${osd_size}.txt"
        while read osd_id pg_num
        do
            sed -i "/\<${osd_id}\>/ s/$/\t${pg_num}/"  "${DIR}""${osd_size}.txt"
        done < "${DIR}"pg_table.txt
    done < "${DIR}"osd_size.txt
    while read osd_size
    do
        osd_nu=`cat ${DIR}${osd_size}.txt |sort -n -k 6|head -n1|awk '{print $1}'`
        alter_price=`cat ${DIR}${osd_size}.txt |sort -n -k 6|head -n1|awk \
        '{mean_pg = $5;run_pg = $6;SET_STANDARD = '${SET_STANDARD}';RUN_WEIGHT = $2;} END {average = mean_pg-run_pg;average0 = average * SET_STANDARD;print average1 = average0+RUN_WEIGHT }'`
        cat ${DIR}${osd_size}.txt|grep -w "${osd_nu}"|awk '{print $1"\t"$2"\t"$5"\t"$6}'
        echo 'ceph osd crush reweight' "${osd_nu}" "${alter_price}"
        ceph osd crush reweight "${osd_nu}" "${alter_price}"
        sleep 8
        getpg |grep -w "${osd_nu}"|awk '{print $1"\t"$2}'
        osd_nu_h=`cat ${DIR}${osd_size}.txt |sort -n -k 6|tail -n1|awk '{print $1}'`
        alter_price_h=`cat ${DIR}${osd_size}.txt |sort -n -k 6|tail -n1|awk \
        '{mean_pg = $5;run_pg = $6;SET_STANDARD = '${SET_STANDARD}';RUN_WEIGHT = $2;} END {average = mean_pg-run_pg;average0 = average * SET_STANDARD;print average1 = average0+RUN_WEIGHT }'`
        cat "${DIR}${osd_size}.txt"|grep -w "${osd_nu_h}"|awk '{print $1"\t"$2"\t"$5"\t"$6}'
        echo 'ceph osd crush reweight' "${osd_nu_h}" "${alter_price_h}"
        ceph osd crush reweight "${osd_nu_h}" "${alter_price_h}"
        sleep 8
        getpg |grep -w "${osd_nu_h}"|awk '{print $1"\t"$2}'
	done < "${DIR}osd_size.txt"
done
