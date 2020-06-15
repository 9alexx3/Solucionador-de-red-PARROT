#!/bin/bash

echo -e "\nScript Realizado por: 9alexx3 | variant"
echo -e "Criticas y bugs en: https://github.com/9alexx3/Solucionador-de-red-PARROT\n"

/etc/init.d/network-manager start > /dev/null 
#*****************************************************************************************************************
#										VER TODAS LAS INTERFACES
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
interfaces=`ifconfig -a | grep ": f" | cut -d : -f1`
echo -e "Las interfaces de red de este sistema son:\n$interfaces\n"
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#										SELECCIONAR UNA INTERFAZ VALIDA
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Introduce el nombre de la interfaz: " interfaz
ifdown -a 2> /dev/null> /dev/null
ifup -a 2> /dev/null> /dev/null
ifconfig -a $interfaz  2> /dev/null > /dev/null
while [ $? -eq 1 ]
do
echo -e "Error. No se ha encontrado la interfaz de red.\n"
read -p "Introduce el nombre de la interfaz: " interfaz
ifup -a 2> /dev/null > /dev/null
ifconfig $interfaz 2> /dev/null > /dev/null
done
echo -e "\nEscogida interfaz: $interfaz\n"
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#												SELECCIONAR LOS CASES
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
v=0
while [ $v -eq 0 ]
do
echo "¿Que escoges?"
echo "1) Revisar las caracteristicas de la red."
echo "2) Escanear la conf. de red en busca de fallos."
echo "3) Modificar (y reparar) la conf. de red (root). "
echo "4) Re-elegir la interfaz." 
echo -e "5) Salir.\n"
read -p "Escoge la opcion que desees: " escoger
case $escoger in
#-----------------------------------------------------------------------------------------------------------------
1)
#*****************************************************************************************************************
#										MOSTRAR CARACTERISTICAS DE RED
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
router=`ip route show | grep "default" | grep "$interfaz" | cut -d " " -f3`
ip=`ifconfig -a $interfaz | grep -w "inet" | cut -d " " -f10`
broadcast=`ifconfig -a $interfaz | grep -w "inet" | cut -d " " -f16`
netmask=`ifconfig -a $interfaz | grep -w "inet" | cut -d " " -f13`
IPv6=`ifconfig -a $interfaz | grep -w "inet6" | cut -d " " -f10`
MAC=`ifconfig -a $interfaz | grep -w "ether" | cut -d " " -f10`
DNS=`cat /etc/resolv.conf | grep "nameserver" | cut -d " " -f2 | tr "\n" "| "`

echo -e "Las caracteristicas de $interfaz son:\nIPv4: $ip. IPv6: $IPv6."
echo "La puerta de enlace es: $router."
echo -e "Máscara de red: $netmask.\t Broadcast: $broadcast."
echo "Los servidores DNS son: $DNS "
echo -e "La dirección física (MAC) es: $MAC\n"
#-----------------------------------------------------------------------------------------------------------------

;;
2)
#*****************************************************************************************************************
#										ESCANEA LA CONF. DE RED PARA SABER QUE FALLA.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
router=`route -n | grep "$interfaz" | cut -d " " -f10`
ip=`ifconfig -a $interfaz | grep -w "inet" | cut -d " " -f10`
contador=0
sources=`cat /etc/apt/sources.list | grep -v "^#"`
repos=`cat /etc/apt/sources.list.d/parrot.list | grep -e "^deb" -e "parrot" -e "non-free$"`
#									SABER SI TIENE PUERTA DE ENLACE FUNCIONA
ip_gw=`ping -c 4 $router -I $interfaz | grep "^64 bytes" > /dev/null 2> /dev/null`
if [ $? -eq 0 ]
then
	echo "Puerta de enlace de: $interfaz ($router) funciona."
	let contador=contador+1
else
	echo "Puerta de enlace de: $interfaz ($router) puede estar mal configurada."
fi
#									SABER SI FUNCIONA DNS
nslookup youtube.com > /dev/null > /dev/null 2> /dev/null
if [ $? -eq 1 ]
then	
	echo "Los servidores DNS no funcionan (o no hay salida a Internet)."
else
	echo "Los servidores DNS funcionan correctamente."
	let contador=contador+1
fi
#									SABER SI TIENE IPV4
if [ -z $ip ]
then
	echo "No hay una direccion IPv4."
else
	ping -c 4 $router -I $interfaz | grep "bytes from" > /dev/null 2> /dev/null
	if [ $? -eq 0 ]
	then
		echo "La direccion IPv4 ($ip) configurada adecuadamente."
		let contador=contador+1
	else
		echo "Posible mal configuracion de la IPv4 ($ip)."
	fi
fi	
#									SABER SI FALLA LOS REPOS
if [ -z "$sources" ]
then
    echo "No hay errores en el sources.list (repositorio 1/2)."
	let contador=contador+1
else
	echo "Hay errores en el sources.list (repositorio 1/2)."
fi
if [ -z "$repos" ]
then
	echo -e "Fallos en los mirrors de Parrot (repositorio 2/2)."
else
	echo "No hay fallos en los mirrors de Parrot (repositorio 2/2)."
	let contador=contador+1
fi

if [ $contador -eq 5 ]
then
	echo -e "\nToda la configuracion de red está perfecto.\n"
else
	echo -e "\nHay fallos en la conf. de red, se recomienda repararlos.\n"
fi
#-----------------------------------------------------------------------------------------------------------------
;;
3)
#*****************************************************************************************************************
#													EJECUTAR COMO ROOT.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if [[ `id -u` -ne 0 ]]
then
	echo -e "Para modificar la configuración de red necesitas permisos de root."
	exit 1
fi
#-----------------------------------------------------------------------------------------------------------------
ifup -a > /dev/null 
echo -e "Parando el demonio de la red temporalmente, para evitar errores.\n"
/etc/init.d/network-manager stop > /dev/null 
sources=`cat /etc/apt/sources.list | grep -v "^#"`
repos=`cat /etc/apt/sources.list.d/parrot.list | grep -e "^deb" -e "parrot" -e "non-free$"`
#*****************************************************************************************************************
#													RECONFIGURAR IPV4.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Quieres cambiar la direccion IPv4? Escribe S para cambiarla o N para dejarla [S/n]: " confirmar_ip
while [ $v -eq 0 ]
do
	if [ $confirmar_ip == N ] || [ $confirmar_ip == n ]
	then
		echo "De acuerdo, no se ha cambiado la direccion IPv4."
		break
	else
		if [ $confirmar_ip == S ] || [ $confirmar_ip == s ]
		then
			read -p "Introduzca la nueva direccion IPv4: " nuevo_ip
			echo "$nuevo_ip" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
			while [ $? -ne 0 ]
			do
				read -p "Debes poner una nueva direccion IPv4 correcta: " nuevo_ip
				echo "$nuevo_ip" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
				if [ $? -eq 0 ]
				then
					break
				fi
			done
			ifconfig $interfaz $nuevo_ip
			break
		else
			read -p "Debes poner 'S' para aceptar o 'N' para negar [S/n]: " confirmar_ip
		fi
	fi
done
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#												RECONFIGURAR GATEWAY
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Quieres cambiar la puerta de enlace? [S/n]: " confirmar_gateway
while [ $v -eq 0 ]
do
	if [ $confirmar_gateway == N ] || [ $confirmar_gateway == n ]
	then
		echo "Entendido, no se ha tocado la puerta de enlace."
		break
	else
		if [ $confirmar_gateway == S ] || [ $confirmar_gateway == s ]
		then
			read -p "Introduzca la nueva puerta de enlace: " nuevo_gateway
			echo "$nuevo_gateway" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
			while [ $? -ne 0 ]
			do
				read -p "Debes poner una puerta de enlace correcta: " nuevo_gateway
				echo "$nuevo_gateway" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
				if [ $? -eq 0 ]
				then
					break
				fi
			done
			echo "$router $nuevo_gateway $interfaz"
			route del default gw $router $interfaz > /dev/null 2> /dev/null
			route add default gw $nuevo_gateway $interfaz > /dev/null 2> /dev/null
			break
		else
			read -p "Debes poner 'S' para aceptar o 'N' para negar [S/n]: " confirmar_gateway
		fi
	fi
done
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#													RECONFIGURAR NETMASK
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Quieres cambiar la mascara de red? Escribe 'S' para cambiarla o 'N' para dejarla [S/n]: " confirmar_netmask
while [ $v -eq 0 ]
do
	if [ $confirmar_netmask == N ] || [ $confirmar_netmask == n ]
	then
		echo "Ok, no se modifico la mascara de red."
		break
	else
		if [ $confirmar_netmask == S ] || [ $confirmar_netmask == s ]
		then
			read -p "Introduzca la nueva mascara de red: " nuevo_netmask
			echo "$nuevo_netmask" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
			while [ $? -ne 0 ]
			do
				read -p "Debes poner una mascara de red correcta: " nuevo_netmask
				echo "$nuevo_netmask" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
				if [ $? -eq 0 ]
				then
					break
				fi
			done
			ifconfig $interfaz netmask $nuevo_netmask
			break
		else
			read -p "Debes poner 'S' para aceptar o 'N' para negar [S/n]: " confirmar_netmask
		fi
	fi
done
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#													RECONFIGURAR DNS
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Quieres cambiar la conf. de los DNS? [S/n]: " confirmar_dns
while [ $v -eq 0 ]
do
	if [ $confirmar_dns == N ] || [ $confirmar_dns == n ]
	then
		echo "Claro, no se han modificados los servidores DNS."
		break
	else
		if [ $confirmar_dns == S ] || [ $confirmar_dns == s ]
		then
			read -p "Introduzca el nuevo servidor DNS: " nuevo_DNS
			echo "$nuevo_DNS" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
			while [ $? -ne 0 ]
			do
				read -p "Debes poner un servidor DNS: " nuevo_DNS
				echo "$nuevo_DNS" | egrep "([0-9]{1,3}\.){3}[0-9]{1,3}" > /dev/null
				if [ $? -eq 0 ]
				then
					break
				fi
			done
			cat > /etc/resolv.conf <<EOF
				nameserver $nuevo_DNS
EOF
			break
		else
			read -p "Debes poner 'S' para aceptar o 'N' para negar [S/n]: " confirmar_dns
		fi
	fi
done
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#													RECONFIGURAR REPOS
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if [ -n "$sources" ]
then
	echo "" > /etc/apt/sources.list
	echo -e "\nSolucionado el problema de los repos automaticamente (1/2)."
fi
spain="deb http://matojo.unizar.es/parrot/ rolling main contrib non-free"
france="deb https://parrot.mirror.cythin.com/parrot rolling main contrib non-free"
ecuador_uta="deb https://mirror.uta.edu.ec/parrot/rolling main contrib non-free"
ecuador_UEB="deb https://mirror.ueb.edu.ec/parrot/ rolling main contrib non-free"
portugal="deb https://mirrors.up.pt/parrot/ rolling main contrib non-free"
universal="deb https://deb.parrot.sh/parrot/ rolling main contrib non-free"
universal2="deb https://deb.parrot.sh/parrot/ rolling-security main contrib non-free"
massachussetts="deb http://mirrors.mit.edu/parrot/ rolling main contrib non-free"
new_york="deb https://mirror.clarkson.edu/parrot/ rolling main contrib non-free"
oregon="deb https://ftp.osuosl.org/pub/parrotos rolling main contrib non-free"
california_berkeley="deb https://mirrors.ocf.berkeley.edu/parrot/ rolling main contrib non-free"
california_leaseweb="deb https://mirror.sfo12.us.leaseweb.net/parrot rolling main contrib non-free"
florida="deb https://mirror.mia11.us.leaseweb.net/parrot rolling main contrib non-free"
Virginia="deb https://mirror.wdc1.us.leaseweb.net/parrot rolling main contrib non-free"
texas="deb https://mirror.dal10.us.leaseweb.net/parrot rolling main contrib non-free"
winnipeg_canada="deb https://muug.ca/mirror/parrot/ rolling main contrib non-free"
beauharnois_canada="deb https://parrot.ca.mirror.cythin.com/parrot rolling main contrib non-free"
brazil="deb http://sft.if.usp.br/parrot/ main contrib non-free"
italy_garr="deb https://parrot.mirror.garr.it/mirrors/parrot/ rolling main contrib non-free"
italy_udupalermo="deb http://mirror.udupalermo.it/parrot/ rolling main contrib non-free"
Germany_Halifax="deb https://ftp.halifax.rwth-aachen.de/parrotsec/ rolling main contrib non-free"
Germany_Esslingen="deb https://ftp-stud.hs-esslingen.de/pub/Mirrors/archive.parrotsec.org/ rolling main contrib non-free"
Germany_Leaseweb="deb https://mirror.fra10.de.leaseweb.net/parrot rolling main contrib non-free"
Netherlands_Leaseweb="deb https://mirror.ams1.nl.leaseweb.net/parrot rolling main contrib non-free"
Netherlands_NLUUG="deb https://ftp.nluug.nl/os/Linux/distr/parrot/ rolling main contrib non-free"
Sweden="deb https://ftp.acc.umu.se/mirror/parrotsec.org/parrot/ rolling main contrib non-free"
Greece="deb https://ftp.cc.uoc.gr/mirrors/linux/parrot/ rolling main contrib non-free"
Belgium="deb http://ftp.belnet.be/mirror/archive.parrotsec.org/ rolling main contrib non-free"
Denmark="deb https://mirrors.dotsrc.org/parrot/ rolling main contrib non-free"
Hungary="deb https://quantum-mirror.hu/mirrors/pub/parrot rolling main contrib non-free"
Turkey="deb http://turkey.archive.parrotsec.org/parrot/ rolling main contrib non-free"
Russia_Yandex="deb https://mirror.yandex.ru/mirrors/parrot/ rolling main contrib non-free"
Russia_Truenetwork="deb https://mirror.truenetwork.ru/parrot/ rolling main contrib non-free"
Ukraine="deb https://parrotsec.volia.net/ rolling main contrib non-free"
iran="deb http://parrot.asis.io/ rolling main contrib non-free"
Bangladesh="deb http://mirror.amberit.com.bd/parrotsec/ rolling main contrib non-free"
Taiwan="deb http://free.nchc.org.tw/parrot/ rolling main contrib non-free"
Singapore="deb https://mirror.0x.sg/parrot/ rolling main contrib non-free"
China_USTC="deb http://mirrors.ustc.edu.cn/parrot rolling main contrib non-free"
China_TUNA="deb https://mirrors.tuna.tsinghua.edu.cn/parrot/ rolling main contrib non-free"
China_SJTUG="deb https://mirrors.sjtug.sjtu.edu.cn/parrot/ rolling main contrib non-free"
New_Caledonia="deb http://mirror.lagoon.nc/pub/parrot/ rolling main contrib non-free"
Thailand="deb https://mirror.kku.ac.th/parrot/ rolling main contrib non-free"
Indonesia="deb http://kartolo.sby.datautama.net.id/parrot/ rolling main contrib non-free"
New_Zeland="deb https://mirrors.takeshi.nz/parrot rolling main contrib non-free"
b=0
if [ -z "$repos" ]
	then
		echo "Forzado a cambiar los repositoreos por una mala configuracion (2/2)."
		b=1
fi
while [ $b -eq 0 ]
do
read -p "Quieres cambiar de ubicacion tus repositorios? [S/n] " confirmar_repos
	if [ $confirmar_repos == N ] || [ $confirmar_repos == n ]
	then
		echo "No se van a hacer cambios en los repositorios."
		b=0
		break
	else
		if [ $confirmar_repos == S ] || [ $confirmar_repos == s ]
		then
			echo -e "Modificando la ubicacion de los repositorios.\n"
			b=1
			break
		else
			read -p "Debes introducir N para negar o S para aceptar: " confirmar_repos
			fi
		fi
	
done
while [ $b -eq 1 ] 
do
echo "Escoge la opcion mas cercana a tu localizacion:"
echo "1) Estados Unidos"
echo "2) America"
echo "3) Asia"
echo "4) Europa"
echo "5) Oceania"
echo "6) Universal (por defecto de instalacion)"
echo "7) Cancelar"
read -p "Introduce tu respuesta: " respuesta_repos
case $respuesta_repos in
1)
echo "1) California Berkeley"
echo "2) California Leaseweb"
echo "3) Florida"
echo "4) Oregon"
echo "5) Massachussetts"
echo "6) New_York"
echo "7) Texas"
echo "8) Virginia"
echo "9) Salir de los espejos de Estados Unidos."
read -p "Introduzca aquí tu contestacion: " Estados_Unidos
	case $Estados_Unidos in
	1)
	echo "Escogido mirror de California Berkeley."
	echo "$california_berkeley" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de California Berkeley."
	break
	break
	;;
	2)
	echo "Escogido mirror de California Leaseweb."
	echo "$california_leaseweb" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de California Leaseweb."
	break
	;;
	3)
	echo "Escogido mirror de Florida."
	echo "$florida" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Florida."
	break
	;;
	4)
	echo "Escogido mirror de Oregon."
	echo "$oregon" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Oregon."
	break
	;;
	5)
	echo "Escogido mirror de Massachussetts."
	echo "$massachussetts" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Massachussetts."
	break
	;;
	6)
	echo "Escogido mirror de Nueva York."
	echo "$new_york" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Nueva York."
	break
	;;
	7)
	echo "Escogido mirror de Texas."
	echo "$texas" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Texas."
	break
	;;
	8)
	echo "Escogido mirror de Virginia."
	echo "$Virginia" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Virginia."
	break
	;;
	9)
	echo "Saliendo de los espejos de Estados Unidos."
	;;
	*)
	echo "No se que numero has puesto."
	;;
	esac
;;
2)
echo "1) Brasil"
echo "2) Canada (Beauharnois)"
echo "3) Canada (Winnipeg)"
echo "4) Ecuador UEB"
echo "5) Ecuador UTA"
echo "6) Salir"
read -p "Que mirror eliges? " respuesta_america
	case $respuesta_america in
	1)
	echo "Escogido mirror de Brasil."
	echo "$brazil" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Brasil."
	break
	;;
	2)
	echo "Escogido mirror de Canada (Beauharnois)."
	echo "$beauharnois_canada" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Canada (Beauharnois)."
	break
	;;
	3)
	echo "Escogido mirror de Canada (Winnipeg)."
	echo "$winnipeg_canada" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Canada (Winnipeg)."
	break
	;;
	4)
	echo "Escogido mirror de Ecuador UEB."
	echo "$ecuador_UEB" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Ecuador UEB."
	break
	;;
	5)
	echo "Escogido mirror de Ecuador UTA."
	echo "$ecuador_uta" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Ecuador UTA."
	break
	;;
	6)
	echo "Salieno de los espejos americanos."
	;;
	*)
	echo "No se que numero has puesto."
	;;
	esac
;;
3)
echo "1) Bangladesh"
echo "2) Indonesia"
echo "3) Iran"
echo "4) Singapur"
echo "5) Tailandia"
echo "6) Taiwan"
echo "7) China"
echo "8) Rusia"
echo "9) Cancelar"
read -p "Introduzca aquí tu contestacion: " asia
	case $asia in
	1)
	echo "Escogido mirror de Bangladesh."
	echo "$Bangladesh" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Bangladesh."
	break
	;;
	2)
	echo "Escogido mirror de Indonesia."
	echo "$Indonesia" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Indonesia."
	break
	;;
	3)
	echo "Escogido mirror de Iran."
	echo "$iran" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Iran."
	break
	;;
	4)
	echo "Escogido mirror de Singapur."
	echo "$Singapore" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Singapur."
	break
	;;
	5)
	echo "Escogido mirror de Tailandia."
	echo "$Thailand" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Tailandia."
	break
	;;
	6)
	echo "Escogido mirror de Taiwan."
	echo "$Taiwan" > /etc/apt/sources.list.d/parrot.list
	echo "Ya se ha sobreescrito los repositoreos de Taiwan."
	break
	;;
	7)
	echo "1) China_USTC"
	echo "2) China_TUNA"
	echo "3) China_SJTUG"
	echo "4) Salir"
	read -p "Que repositorios de China quieres? " China_repositorios
		case $China_repositorios in
		1)
		echo "Escogido mirror de China_USTC."
		echo "$China_USTC" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de China_USTC."
		break
		;;
		2)
		echo "Escogido mirror de China_TUNA."
		echo "$China_TUNA" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de China_TUNA."
		break
		;;
		3)
		echo "Escogido mirror de China_SJTUG."
		echo "$China_TUNA" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de China_SJTUG."
		break
		;;
		4)
		echo "Saliendo de los repositorios chinos."
		;;
		*) 
		echo "No se que numero has puesto."
		;;
		esac
	;;
	8)
	echo "1) Russia (Truenetwork)"
	echo "2) Russia (Yandex)"
	echo "3) Salir"
	read -p "Introduce aqui tu respuesta." respuesta_rusa
		case $respuesta_rusa in
		1)
		echo "Escogido mirror de Russia (Truenetwork)."
		echo "$Russia_Truenetwork" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Russia (Truenetwork)."
		break
		;;
		2)
		echo "Escogido mirror de Russia (Yandex)."
		echo "$Russia_Yandex" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Russia (Yandex)."
		break
		;;
		3)
		echo "Saliendo de los repositorios rusos."
		;;
		*)
		echo "No se que numero has introducido."
		;;
		esac
	;;
	*)
	echo "No se que numero has puesto."
	esac
;;
4)
	echo "1) Europa del Sur (no Rusia)."
	echo "2) El resto de Europa (no Rusia)."
	echo "3) Salir"
	read -p "Escoge: " respuesta_europa
		case $respuesta_europa in
		1)
		echo "1) España"
		echo "2) Francia"
		echo "3) Portugal"
		echo "4) Italia"
		echo "5) Grecia"
		echo "6) Salir"
		read -p "Que pais escojes? " respuesta_sur_europa
			case $respuesta_sur_europa in
			1)
			echo "Escogido mirror de España."
			echo "$spain" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de España."
			break
			;;
			2)
			echo "Escogido mirror de Francia."
			echo "$france" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de Francia."
			break
			;;
			3)
			echo "Escogido mirror de Portugal."
			echo "$portugal" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de Portugal."
			break
			;;
			4)
			echo "1) Italia Udupalermo"
			echo "2) Italia GARR"
			echo "3) Salir."
			read -p "Que repositorios escoges?" respuesta_italia
				case $respuesta_italia in
				1)
				echo "Escogido mirror de Italia Udupalermo."
				echo "$italy_udupalerm" > /etc/apt/sources.list.d/parrot.list
				echo "Ya se ha sobreescrito los repositoreos de Italia Udupalermo."
				break
				;;
				2)
				echo "Escogido mirror de Italia GARR."
				echo "$italy_garr" > /etc/apt/sources.list.d/parrot.list
				echo "Ya se ha sobreescrito los repositoreos de Italia GARR."
				break
				;;
				3)
				echo "Saliendo de los repositorios italianos."
				;;
				*)
				echo "No se que has puesto."
				esac
			;;
			3)
			echo "Saliendo de los repositorios sur euro"
			;;
			5)
			echo "Escogido mirror de Grecia."
			echo "$Greece" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de Grecia."
			break
			;;
			*)
			echo "No se que has puesto."
			esac
		;;
		*)
			echo "No se que has puesto."
		esac
;;
		2)
		echo "1) Alemania"
		echo "2) Paises Bajos"
		echo "3) Suecia"
		echo "4) Belgica"
		echo "5) Dinamarca"
		echo "6) Hungria"
		echo "7) Salir"
		read -p "Escoge tu opcion: " respuesta_otra_europa
		case $respuesta_otra_europa in 
			1)
			echo "Alemania (Esslinge)"
			echo "Alemania Halifax (Halifax Students Group)"
			echo "Alemania Leaseweb"
			read -p "Que repositorios alemanes escoges? " respuesta_aleman
				case $respuesta_aleman in
				1)
				echo "Escogido mirror de Alemania (Esslinge)."
				echo "$Germany_Esslingen" > /etc/apt/sources.list.d/parrot.list
				echo "Ya se ha sobreescrito los repositoreos de Alemania (Esslinge)."
				break
				;;
				2)
				echo "Escogido mirror de Halifax (Halifax Students Group)"
				echo "$Germany_Halifax" > /etc/apt/sources.list.d/parrot.list
				echo "Ya se ha sobreescrito los repositoreos de Halifax (Halifax Students Group)."
				break
				;;
				3)
				echo "Escogido mirror de Alemania Leaseweb"
				echo "$Germany_Leaseweb" > /etc/apt/sources.list.d/parrot.list
				echo "Ya se ha sobreescrito los repositoreos de Leaseweb."
				break
				;;
				*)
				echo "No se que numero has introucido."
				esac
		;;
		2)
		echo "Paises Bajos (Leaseweb)."
		echo "Paises Bajos (NLUUG)."
		read -p "Elige: " respuesta_bajos
			case $respuesta_bajos in
			1)
			echo "Escogido mirror de Paises Bajos (Leaseweb)."
			echo "$Netherlands_Leaseweb" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de Paises Bajos (Leaseweb)."
			break
			;;
			2)
			echo "Escogido mirror de Paises Bajos (NLUUG)."
			echo "$Netherlands_NLUUG" > /etc/apt/sources.list.d/parrot.list
			echo "Ya se ha sobreescrito los repositoreos de Paises Bajos (NLUUG)."
			break
			;;
			3)
			echo "No se que numero has introucido."
			;;
			*)
			echo "Saliendo de los repositorios de este pais."
			esac
		;;
		3)
		echo "Escogido mirror de Suecia."
		echo "$Sweden" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Suecia."
		break
		;;
		4)
		echo "Escogido mirror de Belgica."
		echo "$Belgium" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Belgica."
		break
		;;
		5)
		echo "Escogido mirror de Dinamarca."
		echo "$Denmark" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Dinamarca."
		break
		;;
		6)
		echo "Escogido mirror de Hungria."
		echo "$Hungary" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Dinamarca."
		break
		;;
		7)
		echo "Salieno de los repositorios europeos2."
		;;
		*)
		echo "No se que has puesto."
		esac
;;
5)
	echo "1) Nueva Caledonia"
	echo "2) Nueva Zelanda"
	echo "3) Salir"
		read -p "Escoge tu opcion: " respuesta_oceania
		case $respuesta_oceania in
		1)
		echo "Escogido mirror de Nueva Caledonia."
		echo "$New_Caledonia" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Nueva Caledonia."
		break
		;;
		2)
		echo "Escogido mirror de Nueva Zelanda."
		echo "$New_Zeland" > /etc/apt/sources.list.d/parrot.list
		echo "Ya se ha sobreescrito los repositoreos de Nueva Zelanda."
		break
		;;
		3)
		echo "Saliendo de los repositorios oceanicos."
		;;
		*)
		echo "No se que numero has puesto"
		;;
		esac
;;
6)
echo "Escogido mirror Universales."
echo "$universal" > /etc/apt/sources.list.d/parrot.list
echo "$universal2" >> /etc/apt/sources.list.d/parrot.list
echo "Ya se ha sobreescrito los repositoreos universales."
break
;;
7)
echo -e "Saliendo de reconfigurar los repositorios."
break
;;
*)
echo "No se que has puesto."
;;
esac
done
#-----------------------------------------------------------------------------------------------------------------
echo -e "\nRe-activando el demonio de la red.\n"
/etc/init.d/network-manager start > /dev/null
;;
4)
#*****************************************************************************************************************
#									MIRAR TODAS LAS INTERFACES DE RED DEL PC.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
interfaces=`ifconfig -a | grep ": f" | cut -d : -f1`
echo -e "Las interfaces de red de este sistema son:\n$interfaces\n"
#-----------------------------------------------------------------------------------------------------------------

#*****************************************************************************************************************
#											SELECCIONAR UNA INTERFAZ VALIDA
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
read -p "Introduce el nombre de la interfaz: " interfaz
ifup $interfaz 2> /dev/null> /dev/null
ifconfig -a $interfaz  2> /dev/null > /dev/null
while [ $? -eq 1 ]
do
echo -e "Error. No se ha encontrado la interfaz de red.\n"
read -p "Introduce el nombre de la interfaz: " interfaz
ifup $interfaz 2> /dev/null > /dev/null
ifconfig $interfaz 2> /dev/null > /dev/null
done
echo -e "\nEscogida interfaz: $interfaz\n"
#-----------------------------------------------------------------------------------------------------------------
;;
5)
#*****************************************************************************************************************
#													SALIENDO DEL SCRIPT.
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo -e "\nSaliendo de Script..."
exit 1
;;
#-----------------------------------------------------------------------------------------------------------------
*)
echo -e "\nNo se que numero has puesto"
;;
esac
done