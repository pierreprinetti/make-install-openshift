
OS_CLOUD ?= osp1
BASE_DOMAIN ?= ocp.jkfd.ovh
CLUSTER_NAME ?= ocp1
OCP_DIR ?= clusters/$(OS_CLOUD)_$(CLUSTER_NAME)
CACHE_DIR ?= cache/$(OS_CLOUD)_$(CLUSTER_NAME)
OCP_VERSION ?= latest-4.12
AWS_ZONE_ID ?= $(shell pass show aws/zone-ocp.jkfd.ovh)
OPENSHIFT_INSTALLER ?= openshift-install

install: setversion $(OCP_DIR)/install-config.yaml dns_up
	'$(OPENSHIFT_INSTALLER)' --dir '$(OCP_DIR)' create cluster
.PHONY: install

install-techpreview: setversion dns_up $(OCP_DIR)/manifests
	cp templates/manifest_tech_preview.yaml '$(OCP_DIR)/manifests/'
	'$(OPENSHIFT_INSTALLER)' --dir '$(OCP_DIR)' create cluster
.PHONY: install-techpreview

manifests: $(OCP_DIR)/manifests
.PHONY: manifests

$(OCP_DIR)/manifests: $(OCP_DIR)/install-config.yaml
	'$(OPENSHIFT_INSTALLER)' --dir '$(OCP_DIR)' create manifests

dns_up: $(CACHE_DIR)/dns_up.json $(CACHE_DIR)/dns_down.json
	aws route53 change-resource-record-sets \
		--hosted-zone-id='$(AWS_ZONE_ID)' \
		--change-batch='file://$<'
.PHONY: dns_up

$(CACHE_DIR)/dns_down.json: $(CACHE_DIR)/dns_up.json
	sed 's/UPSERT/DELETE/;s/Upsert/Delete/' '$<' > '$@'

dns_down:
ifneq (,$(wildcard $(CACHE_DIR)/dns_down.json)) # If the file exists
	aws route53 change-resource-record-sets \
		--hosted-zone-id='$(AWS_ZONE_ID)' \
		--change-batch='file://$(CACHE_DIR)/dns_down.json'
	rm '$(CACHE_DIR)/dns_down.json'
endif
.PHONY: dns_down

$(CACHE_DIR)/dns_up.json: $(CACHE_DIR)
	BASE_DOMAIN='$(BASE_DOMAIN)' \
	CLUSTER_NAME='$(CLUSTER_NAME)' \
	OS_CLOUD='$(OS_CLOUD)' \
	API_IP='$(shell cat '$(CACHE_DIR)/api_ip')' \
	INGRESS_IP='$(shell cat '$(CACHE_DIR)/ingress_ip')' \
		envsubst < templates/dns_up.json > '$@'

$(CACHE_DIR)/api_ip: EXTERNAL_NETWORK=$(shell sed -n 's|^external_network=||p' 'data/resources_$(OS_CLOUD).sh')
$(CACHE_DIR)/api_ip: $(CACHE_DIR)
	openstack floating ip create '$(EXTERNAL_NETWORK)' \
		--description '$(CLUSTER_NAME)-api' \
		--format value --column 'floating_ip_address' \
		> '$@'

$(CACHE_DIR)/ingress_ip: EXTERNAL_NETWORK=$(shell sed -n 's|^external_network=||p' 'data/resources_$(OS_CLOUD).sh')
$(CACHE_DIR)/ingress_ip: $(CACHE_DIR)
	openstack floating ip create '$(EXTERNAL_NETWORK)' \
		--description '$(CLUSTER_NAME)-ingress' \
		--format value --column 'floating_ip_address' \
		> '$@'

fips_down: API_IP=$(shell cat '$(CACHE_DIR)/api_ip' || true)
fips_down: INGRESS_IP=$(shell cat '$(CACHE_DIR)/ingress_ip' || true)
fips_down:
	echo '$(API_IP) $(INGRESS_IP)' | xargs --no-run-if-empty openstack floating ip delete
	rm -f '$(CACHE_DIR)/api_ip' '$(CACHE_DIR)/ingress_ip'
.PHONY: fips_down

$(OCP_DIR)/install-config.yaml: $(CACHE_DIR)/api_ip $(CACHE_DIR)/ingress_ip $(OCP_DIR)
	@ \
		OS_CLOUD='$(OS_CLOUD)' \
		BASE_DOMAIN='$(BASE_DOMAIN)' \
		CLUSTER_NAME='$(CLUSTER_NAME)' \
		PULL_SECRET='$(shell pass show redhat/pull-secret)' \
		CONTROL_PLANE_FLAVOR='$(shell sed -n 's|^controlplane_flavor=||p' 'data/resources_$(OS_CLOUD).sh')' \
		COMPUTE_FLAVOR='$(shell sed -n 's|^compute_flavor=||p' 'data/resources_$(OS_CLOUD).sh')' \
		EXTERNAL_NETWORK='$(shell sed -n 's|^external_network=||p' 'data/resources_$(OS_CLOUD).sh')' \
		API_IP='$(shell cat '$(CACHE_DIR)/api_ip')' \
		INGRESS_IP='$(shell cat '$(CACHE_DIR)/ingress_ip')' \
		SSH_PUB_KEY='$(shell ssh-add -L | sed -n '/cardno/p')' \
			envsubst < templates/install-config.yaml > '$@'

install-config: $(OCP_DIR)/install-config.yaml
	@echo '$(OCP_DIR)/install-config.yaml'
.PHONY: install-config

setversion:
	# '$(OPENSHIFT_INSTALLER)' setversion '$(OCP_VERSION)'
.PHONY: setversion

clean:
	rm -rf '$(OCP_DIR)' '$(CACHE_DIR)'
.PHONY: clean

destroy: $(OCP_DIR) fips_down dns_down
ifneq (,$(wildcard $(OCP_DIR)/metadata.json)) # If the file exists
	'$(OPENSHIFT_INSTALLER)' --dir '$(OCP_DIR)' destroy cluster
endif
.PHONY: destroy

$(CACHE_DIR):
	mkdir -p '$@'

$(OCP_DIR):
	mkdir -p '$@'

print_kubeconfig_path:
	@echo '$(PWD)/$(OCP_DIR)/auth/kubeconfig'
.PHONY: print_kubeconfig_path
