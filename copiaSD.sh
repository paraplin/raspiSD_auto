#!/bin/bash
#Automatización de copia y configuracion WiFi de SD para Raspberry Pi
#Sólo probado en Raspberry Pi 3 B+

SERVIDOR="https://downloads.raspberrypi.org/"
IMAGEN="raspios_lite_arm64_latest"
#Para 32 bits usar esta imagen: "raspios_lite_latest"

#Limpiar pantalla y comprobar parametros. Se pide pass para sudo aqui
sudo clear
if [ $# -ne 4 ] ; then
  echo "Numero incorrecto de parámetros, se necesitan 4 y ha introducido $#"
  echo "Los dos parametros requeridos son:"
  echo " - Primero, el nombre de la red WiFi a conectar"
  echo " - Segundo, la contraseña de la red Wifi indicada como primer parametro"
  echo " - Tercero, la dirección IP a asignar al equipo"
  echo " - Cuarto, la direccion IP de la puerta de enlace"
  echo "Ejemplo: ${0} nombre_wifi clave_wifi 192.168.0.2 192.168.0.1"
  exit 0
fi

#Comprobar acceso a https://downloads.raspberrypy.org
echo "Comprobando acceso a $SERVIDOR"
RETORNO=$(curl -m 5 -s -I $SERVIDOR | grep HTTP | awk {'print $2'})
if [ $RETORNO -ne 200 ] ; then
  echo "Sin acceso a la web. No se puede continuar. Adios ..."
  exit 0
else
  echo "Acceso a $SERVIDOR correcto!"
fi

#Obtener identificador de la SD (/dev/sdX)
echo "Copia y configuración de una SD para Raspberry Pi 3 B+"
echo "Detectando tarjeta SD ..."
UNIDAD=$(lsblk -n -p -o PATH,TYPE,HOTPLUG,TRAN | grep disk | grep 1 | grep usb)
RUTAUNIDAD=($(echo "$UNIDAD" | tr ' ' '\n'))
UNIDAD=${RUTAUNIDAD[0]}
if [ -z $UNIDAD ] ; then
  echo "Tarjeta SD NO detectada. No se puede continuar. Adios ..."
  exit 0
else
  echo "Tarjeta SD detectada en $UNIDAD"
fi

#Descarga, copia y modificación de SD
echo "ATENCION:"
echo " - Se sobreescribirá TODO el contenido de la unidad ${UNIDAD}."
echo " - Se configurará la SD para acceder a la WiFi ${1}."
echo "¿Quiere continuar?"
select RESPUESTA in Si No ; do
  case $RESPUESTA in
    Si ) echo "Comprobando si existe el fichero de imagen ..."
         if [ -f $IMAGEN ] ; then
           echo "Fichero encontrado!"
         else
           #Descarga del fichero
           echo "No encuentro el fichero de imagen. Descargandolo ..."
           wget $SERVIDOR$IMAGEN
           echo "Descargando verificación del fichero ..."
           wget $SERVIDOR$IMAGEN.sha1
           echo "Ficheros descargados!"
         fi
         
         #Comprobar integridad del fichero descargado
         echo "Comprobando integridad del fichero descargado, espere por favor ..."
         CHECKSUM=$(tail -n1 $IMAGEN.sha1 | cut -d " " -f1)
         CHECKSUMAUX=$(sha1sum -b $IMAGEN | cut -d " " -f1)
         if [ $CHECKSUM == $CHECKSUMAUX ] ; then
           echo "Fichero correcto!!"
         else
           echo "Fichero descargado incorrecto!!. No se puede continuar. Adios ..."
           #rm -f $IMAGEN $IMAGEN.sha1
           exit 0
         fi
         
         #Descompresion y copia de imagen a SD (sudo necesario)
         echo "Copiando fichero de imagen a SD:"
         unzip -p $IMAGEN | sudo dd of=/dev/sdb bs=16K status=progress && sync
         #Modificacion de ficheros para acceso SSH y conexion WiFi (sudo necesario)
         echo "Creando puntos de montaje para particiones de la SD ..."
         DIRECTORIO=$(mktemp -d --tmpdir=/tmp/ PART1.XXX)
         sudo mount -o umask=000 "${UNIDAD}"1 ${DIRECTORIO}
         echo "Permitiendo acceso por SSH"
         touch ${DIRECTORIO}/ssh
         echo "Configurando acceso a red WiFi ${1}"
         echo -e "country=ES\nctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > ${DIRECTORIO}/wpa_supplicant.conf
         wpa_passphrase ${1} ${2} >> ${DIRECTORIO}/wpa_supplicant.conf
         sed -i "/#/d" ${DIRECTORIO}/wpa_supplicant.conf 2>/dev/null
         sudo umount ${DIRECTORIO}
         echo "Configurando IP estatica ${3} con puerta de enlace ${4}"
         sudo mount "${UNIDAD}"2 ${DIRECTORIO}
         echo -e "interface wlan0\n ipaddress=${3}/24\n routers=${4}\n domain_name_servers=${4} 8.8.8.8" >> ${DIRECTORIO}/etc/dhcpcd.conf
         sudo umount ${DIRECTORIO}
         rm -rf {$DIRECTORIO}
         echo "Proceso finalizado correctamente."
         break;;
         
    No ) echo "Ha contestado NO. No se continúa. Adios ..."
         break;;

  esac
done
exit 0