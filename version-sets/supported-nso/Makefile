SUBSETS_PROTO=-all4.yaml -all5.yaml -all.yaml -tot4.yaml -tot5.yaml -tot.yaml
SUBSETS_BUILD=$(addprefix build,$(SUBSETS_PROTO))
SUBSETS_PUSH=$(addprefix push,$(SUBSETS_PROTO))


$(SUBSETS_BUILD): versions.json
	../version-gen versions.json --job build

$(SUBSETS_PUSH): versions.json
	../version-gen versions.json --job push

multiver.yaml: versions.json
	../version-gen versions.json --multiver multiver.yaml

versions.txt: versions.json
	../version-gen versions.json --flat $@

test-version-set.yaml:
	sed -i 's/VERSION_SET:.*/VERSION_SET: "$(shell pwd | xargs basename)"/' test-version-set.yaml

nso-docker.yaml: build-all.yaml multiver.yaml push-all.yaml test-version-set.yaml
	cat build-all.yaml multiver.yaml push-all.yaml test-version-set.yaml > $@

generate: $(SUBSETS_BUILD) multiver.yaml $(SUBSETS_PUSH) versions.txt nso-docker.yaml
