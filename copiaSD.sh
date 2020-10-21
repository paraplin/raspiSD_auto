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
  echo "Los cuatro parametros requeridos son: (separados por espacios)"
  echo " - Primero, el nombre de la red WiFi a conectar"
  echo " - Segundo, la contraseña de la red Wifi indicada como primer parametro"
  echo " - Tercero, la dirección IP a asignar al equipo"
  echo " - Cuarto, la direccion IP de la puerta de enlace"
  echo "Ejemplo: ${0} nombre_wifi clave_wifi 192.168.0.2 192.168.0.1"
  exit 0
fi

#Comprobar acceso a https://downloads.raspberrypy.org
echo "Comprobando acceso a ${SERVIDOR}"
RETORNO=$(curl -m 5 -s -I ${SERVIDOR} | grep HTTP | awk {'print $2'})
if [ ${RETORNO} -ne 200 ] ; then
  echo "Sin acceso a la web. No se puede continuar. Adios ..."
  exit 0
else
  echo "Acceso a ${SERVIDOR} correcto!"
fi

#Obtener identificador de la SD (/dev/sdX)
echo "Copia y configuración de una SD para Raspberry Pi 3 B+"
echo "Detectando tarjeta SD ..."
UNIDAD=$(lsblk -n -p -o PATH,TYPE,HOTPLUG,TRAN | grep disk | grep 1 | grep usb)
RUTAUNIDAD=($(echo "${UNIDAD}" | tr ' ' '\n'))
UNIDAD=${RUTAUNIDAD[0]}
if [ -z ${UNIDAD} ] ; then
  echo "Tarjeta SD NO detectada. No se puede continuar. Adios ..."
  exit 0
else
  echo "Tarjeta SD detectada en ${UNIDAD}"
fi

#Descarga, copia y modificación de SD
echo "####################################"
echo "ATENCION:"
echo "Se sobreescribirá TODO el contenido de la unidad ${UNIDAD}"
echo "Además, en ${UNIDAD} se configurará:"
echo " - Acceso por SSH"
echo " - Acceso WiFi a ${1}"
echo " - IP estatica: ${3}"
echo " - Servidores DNS: ${4} 8.8.8.8"
echo "####################################"
read -rp $'Quiere continuar? (S -> continuar) : ' -en1 RESPUESTA;
case $RESPUESTA in
  S)
    echo "Comprobando si existe el fichero de imagen ..."
    if [ -f raspios.zip ] ; then
      echo "Fichero encontrado!"
    else
      #Descarga del fichero
      echo "No encuentro el fichero de imagen. Descargandolo ..."
      wget -q --show-progress -O raspios.zip ${SERVIDOR}${IMAGEN}
      echo "Fichero descargado!"
    fi
    #Comprobar integridad del fichero descargado
    if [ -f raspios.sha1 ] ; then
      echo "Fichero de comprobacion encontrado ..."
    else
      echo "Descargando fichero de comprobación ..." 
      wget -q --show-progress -O raspios.sha1 ${SERVIDOR}${IMAGEN}.sha1
    fi
    echo "Comprobando integridad de la imagen, espere por favor ..."
    CHECKSUM=$(tail -n1 raspios.sha1 | cut -d " " -f1)
    CHECKSUMAUX=$(sha1sum -b raspios.zip | cut -d " " -f1)
    if [ $CHECKSUM == $CHECKSUMAUX ] ; then
      if [ -z $CHECKSUM ] ; then
        echo "Fichero incorrecto!!. Error, no puedo continuar. Adios ..."
        exit 0
      else
        echo "Fichero correcto!!"
      fi
    else
      echo "Fichero incorrecto!!. Borre los ficheros raspios.* ..."
      echo "No se puede continuar. Adios ..."
      exit 0
    fi
    #Descompresion y copia de imagen a SD (sudo necesario)
    echo "Copiando fichero de imagen a SD:"
    unzip -p raspios.zip | sudo dd of=${UNIDAD} bs=16K status=progress && sync
    #Modificacion de ficheros para acceso SSH y conexion WiFi (sudo necesario)
    echo "Creando puntos de montaje para particiones de la SD ..."
    DIRECTORIO=$(mktemp -d --tmpdir=/tmp/ PART1.XXX)
    sudo mount -o umask=000 "${UNIDAD}"1 ${DIRECTORIO}
    echo "Permitiendo acceso por SSH"
    touch ${DIRECTORIO}/ssh
    echo "Configurando acceso a red WiFi ${1}"
    echo -e "country=ES\nctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\nupdate_config=1" > ${DIRECTORIO}/wpa_supplicant.conf
    wpa_passphrase ${1} ${2} >> ${DIRECTORIO}/wpa_supplicant.conf
    sed -i '/#/d' ${DIRECTORIO}/wpa_supplicant.conf 2>/dev/null
    sudo umount ${DIRECTORIO}
    echo "Configurando IP estatica ${3} con puerta de enlace ${4}"
    sudo mount "${UNIDAD}"2 ${DIRECTORIO}
    echo -e "interface wlan0\nstatic ipaddress=${3}/24\nstatic routers=${4}\nstatic domain_name_servers=${4} 8.8.8.8" >> ${DIRECTORIO}/etc/dhcpcd.conf
    sudo umount ${DIRECTORIO}
    rmdir ${DIRECTORIO}
    echo "Proceso finalizado correctamente."
  ;;
  *)
    echo "NO ha contestado que si (S). No se continúa. Adios ..."
  ;;
esac