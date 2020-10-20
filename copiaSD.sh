#!/bin/bash
#Automatización de copia y configuracion WiFi de SD para Raspberry Pi
#Sólo probado en Raspberry Pi 3 B+

#Limpiar pantalla y comprobar parametros. Se pide pass para sudo aqui
sudo clear
if [ $# -ne 2 ] ; then
  echo "Numero incorrecto de parámetros, se necesitan 2 y ha introducido $#"
  echo "Los dos parametros requeridos son:"
  echo " - Primero, el nombre de la red WiFi a conectar"
  echo " - Segundo, la contraseña de la red Wifi indicada como primer parametro"
  echo "Ejemplo: ${0} nombre_de_la_red clave_de_acceso"
  exit 0
fi

#Comprobar acceso a https://downloads.raspberrypy.org
echo "Comprobando acceso a www.raspberripy.org"
RETORNO=$(curl -m5 -s -I https://downloads.raspberrypi.org | grep HTTP | awk {'$
if [ $RETORNO -ne 200 ] ; then
  echo "Sin acceso a la web. No se puede continuar. Adios ..."
  exit 0
else
  echo "Acceso a www.raspberripy.org correcto!"
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
         if [ -f raspios_lite_arm64_latest ] ; then
           echo "Fichero encontrado!"
         else
           #Descarga del fichero
           echo "No encuentro el fichero de imagen. Descargandolo ..."
           wget https://downloads.raspberrypi.org/raspios_lite_arm64_latest
           echo "Descargando verificación del fichero ..."
           wget https://downloads.raspberrypi.org/raspios_lite_arm64_latest.sha1
           echo "Ficheros descargados!"
         fi
         
         #Comprobar integridad del fichero descargado
         echo "Comprobando integridad del fichero descargado, espere por favor ..."
         CHECKSUM=$(tail -n1 raspios_lite_arm64_latest.sha1 | cut -d " " -f1)
         CHECKSUMAUX=$(sha1sum -b raspios_lite_arm64_latest | cut -d " " -f1)
         if [ $CHECKSUM == $CHECKSUMAUX ] ; then
           echo "Fichero correcto!!"
         else
           echo "Fichero descargado incorrecto!!. No se puede continuar. Adios ..."
           #rm -f raspios_lite_arm64_latest
           exit 0
         fi
         
         #Descompresion y copia de imagen a SD (sudo necesario)
         echo "Copiando fichero de imagen a SD:"
         unzip -p raspios_lite_arm64_latest | sudo dd of=/dev/sdb bs=16K status=progress && sync
         #Modificacion de ficheros para acceso SSH y conexion WiFi (sudo necesario)
         echo "Creando puntos de montaje para particiones de la SD ..."
         DIRECTORIO=$(mktemp -d --tmpdir=/tmp/ PART1.XXX)
         sudo mount -o umask=000 "${UNIDAD}"1 ${DIRECTORIO}
         echo "Permitiendo acceso por SSH"
         touch ${DIRECTORIO}/ssh
         echo "Configurando acceso a red WiFi ${1}"
         echo -e "country=ES\nctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > ${DIRECTORIO}/wpa_supplicant.conf
         wpa_passphrase ${1} ${2} >> ${DIRECTORIO}/wpa_supplicant.conf
         #sudo sed -i "/#/d" ${DIRECTORIO}/wpa_supplicant.conf
         sed -i "/#/d" ${DIRECTORIO}/wpa_supplicant.conf 2>/dev/null
         sudo umount ${DIRECTORIO}
         rm -rf {$DIRECTORIO}
         echo "Proceso finalizado correctamente."
         break;;
         
    No ) echo "Ha contestado NO. No se continúa. Adios ..."
         break;;

  esac
done
exit 0