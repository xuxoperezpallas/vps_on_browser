#!/bin/bash

# Script de instalación y configuración de noVNC con LXDE
# Este script instalará LXDE, los requisitos para noVNC y configurará todo

# Verificar si el usuario es root
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script debe ejecutarse como root. Usa 'sudo' por favor."
    exit 1
fi

# Actualizar paquetes e instalar dependencias
echo "Actualizando paquetes e instalando dependencias..."
apt-get update
apt-get install -y git python3-websockify x11vnc net-tools lxde-core lxterminal tightvncserver

# Configurar VNC para usar LXDE
echo "Configurando VNC para usar LXDE..."
USER_HOME=$(eval echo ~$(logname))
VNC_DIR="$USER_HOME/.vnc"

# Crear directorio .vnc si no existe
mkdir -p "$VNC_DIR"

# Configurar xstartup para LXDE
cat > "$VNC_DIR/xstartup" <<EOL
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startlxde
EOL

chmod +x "$VNC_DIR/xstartup"
chown -R $(logname):$(logname) "$VNC_DIR"

# Configurar contraseña VNC (por defecto: password)
echo "Configurando contraseña VNC (por defecto: password)..."
sudo -u $(logname) vncpasswd -f <<< "password" > "$VNC_DIR/passwd" 2>/dev/null
chmod 600 "$VNC_DIR/passwd"

# Clonar noVNC
echo "Clonando repositorio noVNC..."
git clone https://github.com/novnc/noVNC.git /opt/noVNC

# Crear enlace simbólico para el certificado
echo "Configurando certificado autofirmado..."
openssl req -x509 -nodes -newkey rsa:2048 -keyout /opt/noVNC/self.pem -out /opt/noVNC/self.pem -days 365 -subj "/CN=localhost"

# Configurar servicio VNC
echo "Configurando servicio VNC..."
cat > /etc/systemd/system/vncserver.service <<EOL
[Unit]
Description=TightVNC Server
After=syslog.target network.target

[Service]
Type=simple
User=$(logname)
PAMName=login
ExecStart=/usr/bin/vncserver :1 -geometry 1280x720 -depth 24 -localhost
ExecStop=/usr/bin/vncserver -kill :1

[Install]
WantedBy=multi-user.target
EOL

# Configurar servicio noVNC
echo "Configurando servicio noVNC..."
cat > /etc/systemd/system/novnc.service <<EOL
[Unit]
Description=noVNC Service
After=network.target vncserver.service

[Service]
ExecStart=/usr/bin/python3 /opt/noVNC/utils/websockify/websockify.py --web /opt/noVNC --cert /opt/noVNC/self.pem 6080 localhost:5901
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOL

# Habilitar y iniciar servicios
echo "Iniciando servicios..."
systemctl daemon-reload
systemctl enable vncserver.service
systemctl start vncserver.service
systemctl enable novnc.service
systemctl start novnc.service

# Obtener dirección IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo ""
echo "¡Instalación completada!"
echo ""
echo "Puedes acceder a noVNC desde tu navegador web usando la siguiente URL:"
echo ""
echo "    https://${IP_ADDRESS}:6080/vnc.html"
echo ""
echo "Credenciales por defecto:"
echo "  Contraseña VNC: password"
echo "  (Cambia esta contraseña ejecutando 'vncpasswd' como usuario normal)"
echo ""
echo "Nota: Usa un certificado autofirmado (puedes aceptar la advertencia de seguridad)"
echo ""
