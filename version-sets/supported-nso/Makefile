
build-all4.yaml build-all5.yaml build-all.yaml build-tot4.yaml build-tot5.yaml build-tot.yaml:
	../version-gen versions.json --job build

push-all4.yaml push-all5.yaml push-all.yaml push-tot4.yaml push-tot5.yaml push-tot.yaml:
	../version-gen versions.json --job push

multiver.yaml:
	../version-gen versions.json --multiver multiver.yaml

versions.txt:
	../version-gen versions.json --flat $@

generate: build-all4.yaml build-all5.yaml build-all.yaml build-tot4.yaml build-tot5.yaml build-tot.yaml multiver.yaml push-all4.yaml push-all5.yaml push-all.yaml push-tot4.yaml push-tot5.yaml push-tot.yaml versions.txt
