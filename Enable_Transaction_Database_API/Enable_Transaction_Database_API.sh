#!/bin/bash
input_customer="${1}"
input_lob="${2}"
echo "=============== Starting Shell Script ===================="
CDDB_IP="10.100.16.51"
CDDB_PORT="3400"
CDDB_USERNAME="relusr"
CDDB_PASSWORD="relusr*1"
CDDB_NAME="provisioningdb"
CDDB_DB_CONNECTIONS_TABLE="HOST"
CDDB_DB_LOG_TABLE="LOG_DB_DETAIL"

group_name="DB_Server"

output_json=/opt/ProvisioningAPI_2022/Enable_Transaction_Database_API/output.json
destn_invent=/opt/ProvisioningAPI_2022/Enable_Transaction_Database_API/inventory.txt

select_ip(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND HOST_NAME IN (SELECT DISTINCT DB_TYPE FROM $CDDB_DB_LOG_TABLE WHERE CUSTOMER='$input_customer' AND LOB='$input_lob') AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
echo '"IP":"'$results'",' >> $output_json
}


select_hostname(){
results=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT HOST_NAME FROM $CDDB_DB_CONNECTIONS_TABLE WHERE GROUP_NAME = '$group_name' AND HOST_NAME IN (SELECT DISTINCT DB_TYPE FROM $CDDB_DB_LOG_TABLE WHERE CUSTOMER='$input_customer' AND LOB='$input_lob') AND ACTIVE='Y';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
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
ip=`cat $output_json | grep -iw 'IP' | sed -e 's/"//g'  -e 's/\,//g' | awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
hostnme=`cat $output_json | grep -iw 'HOSTNAME' | sed -e 's/"//g'  -e 's/\,//g'| awk -F':' '{print $2}' | awk -F' ' '{print $'$i'}'`
create_inventory $ip $hostnme
  ((i=i+1))
done

}

create_inventory(){

echo "================= Inside Create Inventory Funtion !!! ==================="
echo "$2 ansible_host=$1" >> $destn_invent
}

calling_playbook()
{
target_hostnames=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT GROUP_CONCAT(DISTINCT DB_TYPE) FROM $CDDB_DB_LOG_TABLE WHERE CUSTOMER='$input_customer' AND LOB='$input_lob';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`
target_port=`mysql -N -u $CDDB_USERNAME -p$CDDB_PASSWORD -h $CDDB_IP -P $CDDB_PORT -D $CDDB_NAME -e "SELECT DISTINCT DB_PORT FROM $CDDB_DB_LOG_TABLE WHERE CUSTOMER='$input_customer' AND LOB='$input_lob';" 2>/dev/null | grep -v "mysql: [Warning] Using a password on the command line interface can be insecure."`

echo "=============== CALLING THE MAIN PLAYBOOK ==============="
ansible-playbook /opt/ProvisioningAPI_2022/Enable_Transaction_Database_API/Enable_Transaction_Database_API.yml -i $destn_invent --extra-vars="customer_name=$input_customer lob_name=$input_lob target_host=$target_hostnames port_num=$target_port"
if [[ $? != 0 ]]
then
echo "Enable TransactionDB Playbook execution got failed"
exit 1
fi
echo "=============== END OF PLAY ============================="
}

fileclr
select_ip
select_hostname
echo "["$group_name"]" >> $destn_invent
extracting_json
calling_playbook
