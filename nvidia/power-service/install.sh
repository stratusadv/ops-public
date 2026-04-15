#!

echo "Installing Nvidia Power Service ... "

cp set-gpu-power-350.sh /usr/local/bin/set-gpu-power-350.sh

chmod +x /usr/local/bin/set-gpu-power-350.sh

cp nvidia-power.service /etc/systemd/system/nvidia-power.service

systemctl daemon-reload

systemctl enable nvidia-power

systemctl start nvidia-power

nvidia-smi -q -d POWER

echo "Done"