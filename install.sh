#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'
blue='\033[0;36m'
cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} El script debe ser ejecutado con permisos de superusuarios！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}No se detecto la version del sistema！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
else
    arch="amd64"
    echo -e "${red}No se pudo detectar la arquitectura del cpu. Usando el valor por defecto: ${arch}${plain}"
fi

echo "Arquitectura CPU: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "Este software no es compatible con el sistema de 32 bits (x86), utilice el sistema de 64 bits (x86_64)."
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Utilice en Centos 7 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Utilice en ubuntu 16 o superior！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Utilice en debian 8 superior ！${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
show_usage() {
    echo -e "Como utilizar el scipt de gestion x-ui: "
    echo -e "------------------------------------------"
    echo -e "${green}x-ui${plain}              - Mostrar el menu de gestion ( mas funciones )"
    echo -e "${green}x-ui start${plain}        - Iniciar el panel x-ui"
    echo -e "${green}x-ui stop${plain}         - Detener el panel x-ui"
    echo -e "${green}x-ui restart${plain}      - Reiniciar el panel x-ui"
    echo -e "${green}x-ui status${plain}       - Mostrar el estado del panel x-ui"
    echo -e "${green}x-ui enable${plain}       - Habilitar el inicio automatico del panel x-ui"
    echo -e "${green}x-ui disable${plain}      - Deshabilitar el inicio automatico del panel x-ui"
    echo -e "${green}x-ui log${plain}          - Mostrar el log del panel x-ui"
    echo -e "${green}x-ui v2-ui${plain}        - Migre los datos de la cuenta v2-ui de esta máquina a x-ui"
    echo -e "${green}x-ui update${plain}       - Actualizar el panel x-ui"
    echo -e "${green}x-ui install${plain}      - Instalar el panel x-ui"
    echo -e "${green}x-ui uninstall${plain}    - Desinstalar el panel x-ui"
    echo -e "------------------------------------------"
}
config_after_install() {
    echo -e "${yellow}Antes de continuar, necesito hacerle algunas preguntas${plain}"
    read -p "Nombre de cuenta:" config_account
    echo -e "${yellow}Nombre de cuenta establecido a : ${green}${config_account}${plain}"
    read -p "Por favor, establezca la contraseña de su cuenta: " config_password
    echo -e "${yellow}Contraseña de la cuenta establecido a : ${green}${config_password}${plain}"
    read -p "Puerto de escucha para el panel:" config_port
    echo -e "${yellow}Puerto de acceso establecido a : ${green}${config_port}${plain}"
    read -p "¿Estás seguro de que la configuración está completa?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        echo -e "${yellow}Confirmar configuracion${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}&> /dev/null
        echo -e "${yellow}Configuración de la contraseña de la cuenta completada${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}&> /dev/null
        echo -e "${yellow}Configuración del puerto del panel completada${plain}"
    else
        echo -e "${red}Cancelado. Se establecio la configuracion por defecto.${plain}"
    fi
}


install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/M1001-byte/x-ui-spanish/releases" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}No se pudo detectar la version de x-ui${plain}"
            exit 1
        fi
        echo -e "x-ui, la ultima version es ${green}${last_version}${plain}"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz https://github.com/M1001-byte/x-ui-spanish/releases/download/${last_version}/x-ui-linux-${arch}-spanish.tar.gz -q --show-progress
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Error al descargar x-ui${plain}"
            exit 1
        fi
    else
        last_version=$1
        
        url="https://github.com/M1001-byte/x-ui-spanish/releases/download/${last_version}/x-ui-linux-${arch}-spanish.tar.gz"
        echo -e "Empezar instalacion de x-ui"
        wget -N --no-check-certificate -O /usr/local/x-ui-linux-${arch}.tar.gz ${url} -q --show-progress
        if [[ $? -ne 0 ]]; then
            echo -e "${red}La descarga de x-ui fallo.${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-linux-${arch}.tar.gz &>/dev/null
    rm x-ui-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/M1001-byte/x-ui-spanish/main/x-ui.sh -q --show-progress
    chmod +x /usr/local/x-ui/x-ui.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "如果是全新安装，默认网页端口为 ${green}54321${plain}，用户名和密码默认都是 ${green}admin${plain}"
    #echo -e "请自行确保此端口没有被其他程序占用，${yellow}并且确保 54321 端口已放行${plain}"
    #    echo -e "若想将 54321 修改为其它端口，输入 x-ui 命令进行修改，同样也要确保你修改的端口也是放行的"
    #echo -e ""
    #echo -e "如果是更新面板，则按你之前的方式访问面板"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui ${last_version}${plain}, instalado correctamente"
    show_usage
}

echo -e "${green}Comenzando instalacion${plain}"
install_base
install_x-ui $1
