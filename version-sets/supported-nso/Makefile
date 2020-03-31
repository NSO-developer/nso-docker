
build-all4.yaml build-all5.yaml build-all.yaml build-tot4.yaml build-tot5.yaml build-tot.yaml: versions.json
	../version-gen versions.json --job build

push-all4.yaml push-all5.yaml push-all.yaml push-tot4.yaml push-tot5.yaml push-tot.yaml: versions.json
	../version-gen versions.json --job push

multiver.yaml: versions.json
	../version-gen versions.json --multiver multiver.yaml

versions.txt: versions.json
	../version-gen versions.json --flat $@

nso-docker.yaml: build-all.yaml multiver.yaml push-all.yaml
	cat build-all.yaml multiver.yaml push-all.yaml > $@

generate: build-all4.yaml build-all5.yaml build-all.yaml build-tot4.yaml build-tot5.yaml build-tot.yaml multiver.yaml push-all4.yaml push-all5.yaml push-all.yaml push-tot4.yaml push-tot5.yaml push-tot.yaml versions.txt nso-docker.yaml
