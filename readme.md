# raspiSD_auto
Scrip para automatizar la creación de una SD basada en Raspberry Pi OS con acceso WiFi y SSH.

# Funcionamiento
Para el correcto funcionamiento del Script, este debe recibir dos parámetros, el nombre de la red a la que nos queremos conectar con nuestra Raspberry Pi y la clave de acceso para conectarnos.
Debido a que el script hace uso del comando dd para escribir en la tarjeta SD nos pedirá la contraseña del usuario para poder ejecutar el comando "sudo" (el usuario que ejecuta el script debe ester incluido en el fichero sudoers para poder utilizar el comando sudo).
Tras comprobar que se han introducido los parámetros comprueba el acceso a la web.
Luego obtiene el identificador donde se encuentra la SD conectada y posteriormente descarga el ultimo fichero de imagen del sistema operativo Raspberry Pi OS de 64 bits. A continuación descarga el fichero que contiene la suma de comprobación para verificar la correcta descarga del fichero a través de la red.
Si todo ha ido correcto descomprime el archivo descargado a la vez que comienza la escritura en el dispositivo que ha detectado como SD
Por último monta una de las particiones que ha creado en la tarjeta para modificar dos archivos, uno para permitir el acceso mediante ssh a la Raspberry Pi y otro para configurar el acceso por WiFi al Router.
Debido a que utiliza una version de Raspberry Pi OS de 64 bits este script sólo funcionará en Raspberry Pi 3 y 4, para crear tarjetas para sistemas de 32 bits debemos modificar la variable IMAGEN por la del sistema operativo que deseemos descargar y copiar a la SD.

# Instalación
Clona este repositorio o copia el fichero .sh a tu PC, dale permisos de ejecución al fichero y ejecútalo.
