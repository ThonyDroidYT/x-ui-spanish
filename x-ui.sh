#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Add some basic function here
function LOGD() {
    echo -e "${yellow}[DEG] $* ${plain}"
}

function LOGE() {
    echo -e "${red}[ERR] $* ${plain}"
}

function LOGI() {
    echo -e "${green}[INF] $* ${plain}"
}
# check root
[[ $EUID -ne 0 ]] && LOGE "Este script debe ser ejecutado con privilegios de superusuario!\n" && exit 1

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
    LOGE "No se detecto la version del sistema.\n" && exit 1
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
        LOGE "Utilice Centos 7 o superior" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        LOGE "Utilice ubuntu 16 o superior\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        LOGE "Utilice Debian 8 o superior\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Reiniciar el panel,tambien reinicia xray" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Presione enter para regresar al menu principal${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    confirm "Esta función obligará a reinstalar la última versión y los datos no se perderán. ¿Desea continuar?" "n"
    if [[ $? != 0 ]]; then
        LOGE "Cancelado"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 0
    fi
    bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh)
    if [[ $? == 0 ]]; then
        LOGI "La actualización está completa, el panel se ha reiniciado automáticamente"
        exit 0
    fi
}

uninstall() {
    confirm "¿Está seguro de que desea desinstalar el panel? Xray también se desinstalará?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop x-ui
    systemctl disable x-ui
    rm /etc/systemd/system/x-ui.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/x-ui/ -rf
    rm /usr/local/x-ui/ -rf

    echo ""
    echo -e "La desinsalacion fue exitosa. Para eliminar por completo,salga del script y ejecute; ${green}rm /usr/bin/x-ui -f${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

reset_user() {
    confirm "¿Está seguro de que desea restablecer el nombre de usuario y la contraseña a admin ?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -username admin -password admin
    echo -e "El nombre de usuario y la contraseña se han restablecido a ${green}admin${plain}"
    confirm_restart
}

reset_config() {
    confirm "¿Está seguro de que desea restablecer todas las configuraciones del panel, los datos de la cuenta no se perderán, el nombre de usuario y la contraseña no se cambiarán?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    /usr/local/x-ui/x-ui setting -reset
    echo -e "Todas las configuraciones del panel se han restablecido a los valores predeterminados, reinicie el panel ahora y use la configuración predeterminada. Puerto: ${green}54321${plain}"
    confirm_restart
}

set_port() {
    echo && echo -n -e "Puerto de escucha [1-65535]: " && read port
    if [[ -z "${port}" ]]; then
        LOGD "Cancelado"
        before_show_menu
    else
        /usr/local/x-ui/x-ui setting -port ${port} &>/dev/null
        echo -e "Reinicie el panel para aplicar el nuevo puerto :${green}${port}${plain}"
        confirm_restart
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        LOGI "El panel ya se esta ejecutando,no es necesario inicarlo. "
    else
        systemctl start x-ui
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            LOGI "x-ui iniciado con exito."
        else
            LOGE "El panel no pudo iniciarse."
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    check_status
    if [[ $? == 1 ]]; then
        echo ""
        LOGI "El panel se ha detenido."
    else
        systemctl stop x-ui
        sleep 2
        check_status
        if [[ $? == 1 ]]; then
            LOGI "x-ui xray detenido con exito"
        else
            LOGE "Fallo al detener el panel"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart x-ui
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        LOGI "x-ui xray Reiniciado con exito."
    else
        LOGE "Fallo al reinicar el panel."
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status x-ui -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui Configurar el inicio automático."
    else
        LOGE "x-ui No se pudo configurar el inicio automático."
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable x-ui
    if [[ $? == 0 ]]; then
        LOGI "x-ui deshabiitado con exito.s"
    else
        LOGE "x-ui No se pudo cancelar el inicio automatico"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u x-ui.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

migrate_v2_ui() {
    /usr/local/x-ui/x-ui v2-ui

    before_show_menu
}

install_bbr() {
    # temporary workaround for installing bbr
    bash <(curl -L -s https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
    echo ""
    before_show_menu
}

update_shell() {
    wget -O /usr/bin/x-ui -N --no-check-certificate https://github.com/vaxilu/x-ui/raw/master/x-ui.sh
    if [[ $? != 0 ]]; then
        echo ""
        LOGE "El script de descarga fallo."
        before_show_menu
    else
        chmod +x /usr/bin/x-ui
        LOGI "Script actualizado exitosamente" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/x-ui.service ]]; then
        return 2
    fi
    temp=$(systemctl status x-ui | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled x-ui)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        LOGE "El panel ya esta instalado, no es necesario instalarlo de nuevo."
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        LOGE "Instale primero el panel"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
    0)
        echo -e "Estado del panel: ${green}[ en ejecucion ]${plain}"
        show_enable_status
        ;;
    1)
        echo -e "Estado del panel: ${yellow}[ Detenido ]${plain}"
        show_enable_status
        ;;
    2)
        echo -e "Estado del panel: ${red}[ No instalado ]${plain}"
        ;;
    esac
    show_xray_status
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Inicio automatico: ${green}[ OK ]${plain}"
    else
        echo -e "Inicio automatico: ${red}[ OFF ]${plain}"
    fi
}

check_xray_status() {
    count=$(ps -ef | grep "xray-linux" | grep -v "grep" | wc -l)
    if [[ count -ne 0 ]]; then
        return 0
    else
        return 1
    fi
}

show_xray_status() {
    check_xray_status
    if [[ $? == 0 ]]; then
        echo -e "Estado de xray: ${green}[ en ejecucion ]${plain}"
    else
        echo -e "Estado de xray: ${red}[ detenido ]${plain}"
    fi
}

ssl_cert_issue() {
    echo -E ""
    LOGD "******Instrucciones de uso******"
    LOGI "Este script utilizará el script Acme para solicitar un certificado y debe asegurarse de que:"
    LOGI "1.Conozca el correo electrónico registrado en Cloudflare"
    LOGI "2.Conozca la clave API global de Cloudflare"
    LOGI "3.El nombre de dominio se ha resuelto en el servidor actual a través de Cloudflare"
    LOGI "4.La ruta predeterminada del certificado es : /root/cert"
    confirm "Desea continuar [y/n]" "y"
    if [ $? -eq 0 ]; then
        cd ~
        LOGI "Instalando script ACME"
        curl https://get.acme.sh | sh
        if [ $? -ne 0 ]; then
            LOGE "No se pudo instalar el script ACME"
            exit 1
        fi
        CF_Domain=""
        CF_GlobalKey=""
        CF_AccountEmail=""
        certPath=/root/cert
        if [ ! -d "$certPath" ]; then
            mkdir $certPath
        else
            rm -rf $certPath
            mkdir $certPath
        fi
        read -p "Nombre de dominio:" CF_Domain
        LOGD "Dominio configurado:${CF_Domain}"
        read -p "CloudFlare Global API:" CF_GlobalKey
        LOGD "Clave api:${CF_GlobalKey}"
        read -p "Cloudflare email:" CF_AccountEmail
        LOGD "Correo registradp:${CF_AccountEmail}"
        ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
        if [ $? -ne 0 ]; then
            LOGE "La modificación de la CA predeterminada a Lets'Encrypt fallo."
            exit 1
        fi
        export CF_Key="${CF_GlobalKey}"
        export CF_Email=${CF_AccountEmail}
        ~/.acme.sh/acme.sh --issue --dns dns_cf -d ${CF_Domain} -d *.${CF_Domain} --log
        if [ $? -ne 0 ]; then
            LOGE "La emisión del certificado falló"
            exit 1
        else
            LOGI "El certificado se emitio correctamente"
        fi
        ~/.acme.sh/acme.sh --installcert -d ${CF_Domain} -d *.${CF_Domain} --ca-file /root/cert/ca.cer \
            --cert-file /root/cert/${CF_Domain}.cer --key-file /root/cert/${CF_Domain}.key \
            --fullchain-file /root/cert/fullchain.cer
        if [ $? -ne 0 ]; then
            LOGE "La instalacion del certificado fallo"
            exit 1
        else
            LOGI " El certificado se instaló correctamente. Habilite la actualización automática..."
        fi
        ~/.acme.sh/acme.sh --upgrade --auto-upgrade
        if [ $? -ne 0 ]; then
            LOGE "La configuracion de actualización automática fallo"
            ls -lah cert
            chmod 755 $certPath
            exit 1
        else
            LOGI "Se ha instalado el certificado y se ha activado la actualización automática, los detalles son los siguientes:"
            ls -lah cert
            chmod 755 $certPath
        fi
    else
        show_menu
    fi
}

show_usage() {
    echo "Como utilizar el scipt de gestion x-ui: "
    echo "------------------------------------------"
    echo "x-ui              - Mostrar el menu de gestion ( mas funciones )"
    echo "x-ui start        - Iniciar el panel x-ui"
    echo "x-ui stop         - Detener el panel x-ui"
    echo "x-ui restart      - Reiniciar el panel x-ui"
    echo "x-ui status       - Mostrar el estado del panel x-ui"
    echo "x-ui enable       - Habilitar el inicio automatico del panel x-ui"
    echo "x-ui disable      - Deshabilitar el inicio automatico del panel x-ui"
    echo "x-ui log          - Mostrar el log del panel x-ui"
    echo "x-ui v2-ui        - Migre los datos de la cuenta v2-ui de esta máquina a x-ui"
    echo "x-ui update       - Actualizar el panel x-ui"
    echo "x-ui install      - Instalar el panel x-ui"
    echo "x-ui uninstall    - Desinstalar el panel x-ui"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}x-ui${plain} | ${yellow}Script de gestion${plain} | Traducido: ${red}M1001-byte${plain}
  ${green}0.${plain} Salir  
————————————————
  ${green}1.${plain} Instalar x-ui
  ${green}2.${plain} Actualizar x-ui
  ${green}3.${plain} Desinstalar x-ui
————————————————
  ${green}4.${plain} Restablecer contraseña de usuario
  ${green}5.${plain} Restablecer la configuracion del panel
  ${green}6.${plain} Configurar puerto de escucha del panel
————————————————
  ${green}7.${plain} Iniciar x-ui
  ${green}8.${plain} Detener x-ui
  ${green}9.${plain} Reiniciar x-ui
 ${green}10.${plain} Ver el estado de x-ui
 ${green}11.${plain} Ver registros de x-ui
————————————————
 ${green}12.${plain} Configurar x-ui para que se inicie automáticamente al arrancar
 ${green}13.${plain} Cancelar inicio automático de arranque x-ui
————————————————
 ${green}14.${plain} Instalar bbr (último kernel)
 ${green}15.${plain} Solicitud de certificado SSL (utilizando acme)
————————————————
 "
    show_status
    echo && read -p "Opcion [0-14]: " num

    case "${num}" in
    0)
        exit 0
        ;;
    1)
        check_uninstall && install
        ;;
    2)
        check_install && update
        ;;
    3)
        check_install && uninstall
        ;;
    4)
        check_install && reset_user
        ;;
    5)
        check_install && reset_config
        ;;
    6)
        check_install && set_port
        ;;
    7)
        check_install && start
        ;;
    8)
        check_install && stop
        ;;
    9)
        check_install && restart
        ;;
    10)
        check_install && status
        ;;
    11)
        check_install && show_log
        ;;
    12)
        check_install && enable
        ;;
    13)
        check_install && disable
        ;;
    14)
        install_bbr
        ;;
    15)
        ssl_cert_issue
        ;;
    *)
        LOGE "Opcion Invalida [0-14]"
        ;;
    esac
}

if [[ $# > 0 ]]; then
    case $1 in
    "start")
        check_install 0 && start 0
        ;;
    "stop")
        check_install 0 && stop 0
        ;;
    "restart")
        check_install 0 && restart 0
        ;;
    "status")
        check_install 0 && status 0
        ;;
    "enable")
        check_install 0 && enable 0
        ;;
    "disable")
        check_install 0 && disable 0
        ;;
    "log")
        check_install 0 && show_log 0
        ;;
    "v2-ui")
        check_install 0 && migrate_v2_ui 0
        ;;
    "update")
        check_install 0 && update 0
        ;;
    "install")
        check_uninstall 0 && install 0
        ;;
    "uninstall")
        check_install 0 && uninstall 0
        ;;
    *) show_usage ;;
    esac
else
    show_menu
fi
