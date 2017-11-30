#!/bin/bash

bucle1="continuar"

echo "Esperando un stress a la maquina mv1..."

while [ $bucle1 != "parar" ]; do

	#Ver ip mv1:
	ipmv1=$(virsh net-dhcp-leases nat | grep 'mv1'|tr -s " "|cut -d " " -f 6 | cut -d "/" -f 1)


	#Saber RAM libre:
	LIB=$(ssh -i /home/juanma/.ssh/id_rsa.pub juanma@$ipmv1 cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
	MIN=40000
	if [ $LIB -lt $MIN ]
	then
		echo "Maquina mv1 sin memoria"
		discoad=$(ssh -i /home/juanma/.ssh/id_rsa.pub juanma@$ipmv1 sudo lsblk -l | grep -v 'vda' | grep ^vd | tr -s " " | cut -d " " -f 1)

		echo " "
		echo "Desmontando disco adicional de mv1..."
		ssh -i /home/juanma/.ssh/id_rsa.pub juanma@$ipmv1 sudo umount /dev/$discoad

		echo " "
		echo "Desasociando disco adicional de mv1..."
		virsh -c qemu:///session detach-disk mv1 /dev/mapper/vgsistema-discoad

		echo " "
		echo "Redimensionando disco adicional..."
		lvresize -L +20M /dev/mapper/vgsistema-discoad
		mount /dev/mapper/vgsistema-discoad /mnt
		xfs_growfs /dev/mapper/vgsistema-discoad
		umount /mnt

                echo " "
		echo "Asociando disco adicional a mv2..."
		virsh -c qemu:///session attach-disk mv2 /dev/mapper/vgsistema-discoad vdb 

		ipmv2=$(virsh net-dhcp-leases nat | grep 'mv2'|tr -s " "|cut -d " " -f 6 | cut -d "/" -f 1)

                echo " "
		echo "Modificando reglas de iptables..."
		iptables -t nat -D PREROUTING 1
		iptables -I FORWARD -d $ipmv2/32 -p tcp --dport 80 -j ACCEPT
		iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination $ipmv2:80

		echo " "
		echo "Montando disco adicional en mv2..."
		ssh -i /home/juanma/.ssh/id_rsa.pub juanma@$ipmv2 sudo	mount /dev/vdb /var/www/practicahlc

		echo " "
		echo "mv2 disponible"

		bucle1="parar"
	fi
done

echo " "
echo "Esperando un stress a la maquina mv2"

bucle2="continuar"
while [ $bucle2 != "parar" ]; do
	LIB=$(ssh -i /home/juanma/.ssh/id_rsa.pub juanma@$ipmv2 cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
	MIN2=40000
	if [ $LIB -lt $MIN2 ]
	then
		echo " "
		echo "Maquina mv2 sin memoria"
		echo " "
		echo "Aumentando memoria RAM de la maquina mv2 a 2 GiB..."
		virsh setmem mv2 2G --live
		echo "Memoria RAM aumentada"
		bucle2="parar"
	fi
done
