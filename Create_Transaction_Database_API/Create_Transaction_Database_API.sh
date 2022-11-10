#!/bin/bash
input_customer="${1}"
input_lob="${2}"
input_modes="${3}"
input_interface="${4}"
echo "=============== Starting Shell Script ===================="
CDDB_IP="10.100.16.51"
CDDB_PORT="3400"
CDDB_USERNAME="relusr"
CDDB_PASSWORD="relusr*1"
CDDB_NAME="provisioningdb"
CDDB_DB_CONNECTIONS_TABLE="HOST"
space_thrs='80'
ram_thrs='20'
rand_port=`shuf -i 3000-4000 -n 1`

group_name="DB_Server"

output_json=/opt/ProvisioningAPI_2022/Create_Transaction_Database_API/output.json
destn_invent=/opt/ProvisioningAPI_2022/Create_Transaction_Database_API/inventory.txt

connection_mode="ssh"

select_ip(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
echo '"IP":"'$results'",' >> $output_json
}


select_hostname(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST_NAME FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
echo '"HOSTNAME":"'$results'",' >> $output_json

}

fileclr()
{

>$output_json
>$destn_invent

}

extracting_json(){
host=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}'`
count=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | wc --word`
i=1
until [ $i -gt $count ]
do
  #echo i: $i
ip=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g' | awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
#echo "IP is:" $ip
hostnme=`cat $output_json | grep -iw 'HOSTNAME' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
#echo "HOSTNAME is:" $hostnme
resource_check $ip
create_inventory $ip $hostnme
free_port_check $ip
#echo "Host $i is:-"   $(host_$i)"
  ((i=i+1))
done

}

create_inventory(){

echo "================= Inside Create Inventory Funtion !!! ==================="
#echo "IP =" $1
#echo "Username =" $2
#echo "Password =" $3
#echo "Connecion_Mode =" $connection_mode
echo "$2 ansible_host=$1" >> $destn_invent
}

resource_check()
{
#echo "IP =" $1
#echo "Username =" $2
#echo "Password =" $3

space=`ssh $1 df -h /home | awk 'NR==2 {print $5+0}'`
ram=`ssh $1 free -g | awk 'NR==2 {print $4}'`
echo "FOR VM::$1 SPACE::$space and RAM::$ram"
if [ $space -le $space_thrs ] && [ $ram -le $ram_thrs ];
then
echo "Available space is less than the threshold, So we can use this VM"
else
echo "Available space exceeds the threshold, so proceeding to create new VM"
#call VM creation playbook
exit 1
fi
}

free_port_check()
{

check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
free_port_num=$rand_port
echo "Free port on $1 is: $free_port_num"
else
while [[ ! -z $check_port ]]
do
echo "$rand_port is already in use. So finding another port."
rand_port=`shuf -i 3000-4000 -n 1`
check_port=`ssh $1 sudo netstat -ltnp | grep -w $rand_port`
if [[ -z $check_port ]]
then
free_port_num=$rand_port
echo "Free port on $1 is: $free_port_num"
else
break
fi
done
fi

}

calling_playbook()
{
echo "=============== CALLING THE MAIN PLAYBOOK ==============="
ansible-playbook /opt/ProvisioningAPI_2022/Create_Transaction_Database_API/Create_Transaction_Database_API.yml -i $destn_invent --extra-vars="port_num=$free_port_num customer_name=$input_customer lob_name=$input_lob modes_needed=$input_modes master_host=Transaction_Master slave_host=Transaction_Slave"
if [[ $? != 0 ]]
then
echo "TransactionDB Playbook execution got failed"
exit 1
fi
if [[ $input_interface == 'Y' ]]
then
ansible-playbook /opt/ProvisioningAPI_2022/Create_Transaction_Database_API/Create_Interface_Database_API.yml -i $destn_invent --extra-vars="port_num=$free_port_num customer_name=$input_customer lob_name=$input_lob modes_needed=$input_modes master_host=Transaction_Slave slave_host=Interface_Master"
if [[ $? != 0 ]]
then
echo "InterfaceDB Playbook execution got failed"
exit 1
fi
else
echo "InterfaceDB not requested"
fi
echo "=============== END OF PLAY ============================="
}

fileclr
select_ip
select_hostname
echo "["$group_name"]" >> $destn_invent
extracting_json
calling_playbook
