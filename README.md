# make-install-openshift

1. Creates an `install-config.yaml` based on the template in `templates/install-config.yaml`, replacing variables using `data/resouces_${OS_CLOUD}.sh`
1. Creates floating IPs
1. Sets the floating IPs in an AWS DNS zone
1. Runs the installer

Usage:
```shell
export OS_CLOUD=$your_favourite_clouds-yaml_entry
export AWS_ZONE_ID=$_your_AWS_zone_ID
export BASE_DOMAIN=$domain_of_your_AWS_zone
make install
```

Optionals:
```shell
export CLUSTER_NAME=$arbitrary_name
export OPENSHIFT_INSTALLER=$path_of_your_openshift_installer
```

Then:
```shell
make destroy
make clean # to remove logs and temporary files
```
