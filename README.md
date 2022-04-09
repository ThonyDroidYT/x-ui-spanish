# x-ui
Panel webui x-ray con soporte a multi-usuarios/protocolos

# Características
- Supervisión del estado del sistema
- Visualizacion via web: multi-protocolos, multi-usuarios
- Compatibilidad con：vmess、vless、trojan、shadowsocks、dokodemo-door、socks、http
- Soporte para configurar mas configuraciones de protocolos
- Estadisticas de trafico, limitar trafico, cuentas con fecha de caducidad
- Plantillas de configuracion de x-ray personalizables
- Panel de acceso con encriptacion SSL/TLS ( nombre de dominio + certificado ssl )
- Consule el panel,para ver mas configuraciones

# instalar y actualizar
```
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
```

## Instalacion y actualizacion manual
1. Descargue el ultimo binario de https://github.com/vaxilu/x-ui/releases (Seleccione la arquitectura de su cpu)
2. A continuación, descargue el paquete comprimido en el directorio /root/ del servidor vps e inicie sesión como usuario root.

> Reemplaze `amd64` de acuerdo a la arquitectura de su cpu.

```
cd /root/
rm x-ui/ /usr/local/x-ui/ /usr/bin/x-ui -rf
tar zxvf x-ui-linux-amd64.tar.gz
chmod +x x-ui/x-ui x-ui/bin/xray-linux-* x-ui/x-ui.sh
cp x-ui/x-ui.sh /usr/bin/x-ui
cp -f x-ui/x-ui.service /etc/systemd/system/
mv x-ui/ /usr/local/
systemctl daemon-reload
systemctl enable x-ui
systemctl restart x-ui
```

## Instalar usando docker

> Este tutorial y la imagen Docker esta echo por : [Chasing66](https://github.com/Chasing66)
1. Instalar docker
```shell
curl -fsSL https://get.docker.com | sh
```
2. Instalar x-ui
```shell
mkdir x-ui && cd x-ui
docker run -itd --network=host \
    -v $PWD/db/:/etc/x-ui/ \
    -v $PWD/cert/:/root/cert/ \
    --name x-ui --restart=unless-stopped \
    enwaiax/x-ui:latest
```
>Build image
```shell
docker build -t x-ui .
```

## Sistemas operativos compatibles
- CentOS 7+
- Ubuntu 16+
- Debian 8+

## Migracion desde v2-ui
Primero instale la ultima version de x-ui en el servidor donde esta instalado v2-ui,posteriormente: ejecute el comando para migrar los datos. Los datos a migrar son: "Todos los datos de la cuentas entrantes", "La configuracion (Nombre de usuario y contraseña)" del panel no se migraran.

> Después de que la migración sea exitosa, `cierre v2-ui` y `reinicie x-ui`, de lo contrario, la entrada de v2-ui causará un `conflicto de puerto` con la entrada de x-ui
```shell
x-ui v2-ui
```

## issue 关闭

各种小白问题看得血压很高

## Stargazers over time

[![Stargazers over time](https://starchart.cc/vaxilu/x-ui.svg)](https://starchart.cc/vaxilu/x-ui)
