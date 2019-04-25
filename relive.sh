#!/bin/bash

poolold_name='pool-8d4a7ef698eb40159da00c52134b30ef'
poolnew_name='test'
relive_path='/opt/'
logs(){
touch /tmp/relive/
}
for i in $(rbd ls -p ${poolold_name})
do
date >>/tmp/relive.log 2>&1
rbd mv ${poolold_name}/${i} ${poolold_name}/${i}-backup
rbd export ${poolold_name}/${i}-backup ${relive_path}/${i}
rbd import ${relive_path}/${i} ${poolnew_name}/${i}
date
done
