# make-install-openshift

1. Creates an `install-config.yaml` based on the template in `templates/install-config.yaml`, replacing variables using `data/resouces_${OS_CLOUD}.sh`
1. Creates floating IPs
1. Sets the floating IPs in an AWS DNS zone
1. Runs the installer

Usage:

```shell
export OS_CLOUD=<a clouds.yaml entry>
export AWS_ZONE_ID=<your AWS zone ID>
make install
```

```shell
make destroy
```
