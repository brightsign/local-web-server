cp $2 autorun.brs
curl "$1/delete?filename=sd%2f/autorun.brs&delete=Delete"
curl -i -F filedata=@autorun.brs http://$1/upload.html?rp=sd
curl "$1/delete?filename=sd%2f/$3&delete=Delete"
curl -i -F filedata=@$3 http://$1/upload.html?rp=sd
curl "$1/action.html?reboot=Reboot"
rm autorun.brs
