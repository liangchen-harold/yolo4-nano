# author: liangchen (https://cs.lcsky.org)
.PHONY: all train inference validation data install

# 需要检测的目标类别 | The categories you want
CLS=cat dog
# CLS=person cat dog
# CLS=bicycle car motorcycle bus train truck
# 训练多少代（看整个训练集多少次） | epochs
EPOCHS=200
# 数据集 | dataset
DATA=datasets/coco2017
# 模型通道数量缩放倍数(0.125, 0.25, 0.5, 1.0) | channel number scale factor(0.125, 0.25, 0.5, 1.0)
NANO=0.25
# 训练结果 | folder to put the trained model
RESULTS=results

# 内部变量 | internal use
_CLS=`echo $(CLS) | tr ' ' '-'`
N_CLS=`echo $(CLS) | tr ' ' '\n' | wc -l`
_NANO=`echo $(NANO) | tr -d '.'`
YOLO_DATA=stage/coco-$(_CLS)
VERSION_YOLO=yolo-v4-nano$(_NANO)-$(notdir $(DATA))-$(_CLS)
BATCHES=$$(( $(shell cat $(YOLO_DATA)/train2017.txt | wc -l) * $(EPOCHS) / 64 ))

install:
	pip3 install pycocotools
	git clone https://github.com/AlexeyAB/darknet.git
	cd darknet && git reset --hard f14054ec2b49440ad488c3e28612e7a76780bc5f
	cd darknet && mkdir build-release
	cd darknet && cd build-release
	cd darknet && cmake ..
	cd darknet && make -j6

data:
	rm -rf $(YOLO_DATA)
	python3 src/datasets/coco.py --cls $(CLS) --out $(YOLO_DATA)/train2017 --json $(DATA)/annotations/instances_train2017.json
	python3 src/datasets/coco.py --cls $(CLS) --out $(YOLO_DATA)/val2017 --json $(DATA)/annotations/instances_val2017.json
	ls $(YOLO_DATA)/val2017/|grep txt| awk '{split($$1,a,"."); print "../../../$(DATA)/images/val2017/"a[1]".jpg"}'|xargs -I{} ln -s {} $(YOLO_DATA)/val2017
	ls $(YOLO_DATA)/train2017/|grep txt| awk '{split($$1,a,"."); print "../../../$(DATA)/images/train2017/"a[1]".jpg"}'|xargs -I{} ln -s {} $(YOLO_DATA)/train2017
	ls $(YOLO_DATA)/val2017/|grep txt| awk '{split($$1,a,"."); printf("%s%s.jpg\n", "'../../$(YOLO_DATA)/val2017/'", a[1])}' > $(YOLO_DATA)/val2017.txt
	ls $(YOLO_DATA)/train2017/|grep txt| awk '{split($$1,a,"."); printf("%s%s.jpg\n", "'../../$(YOLO_DATA)/train2017/'", a[1])}' > $(YOLO_DATA)/train2017.txt

train:
	mkdir -p $(RESULTS)/$(VERSION_YOLO)
	echo "classes= $(N_CLS)\n\
	train  = ../../$(YOLO_DATA)/train2017.txt\n\
	valid  = ../../$(YOLO_DATA)/val2017.txt\n\
	names  = ../../$(RESULTS)/$(VERSION_YOLO)/coco.names\n\
	backup = ../../$(RESULTS)/$(VERSION_YOLO)\n\
	eval   = coco" > $(RESULTS)/$(VERSION_YOLO)/coco.data
	cat darknet/cfg/yolov4.cfg | \
		awk -F "=" '{if ($$1=="filters" && $$2!=255) print($$1"="int($$2*'$(NANO)')); else print($$0)}' | \
		awk -F "[= ]" '{if ($$1=="max_batches") print($$1"="'$(BATCHES)'); else print($$0)}' | \
		awk -F "[= ]" '{if ($$1=="steps") print($$1"="int('$(BATCHES)'*0.75)","int('$(BATCHES)'*0.85)); else print($$0)}' | \
		sed 's/subdivisions=8/subdivisions=32/g' | \
		sed 's/filters=255/filters='$$((($(N_CLS)+5)*3))'/g' | \
		sed 's/classes=80/classes='$(N_CLS)'/g' | \
		sed 's/activation=leaky/activation=relu/g' | \
		sed 's/activation=mish/activation=relu/g' > $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg
	echo $(CLS) | tr ' ' '\n' > $(RESULTS)/$(VERSION_YOLO)/coco.names
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector train coco.data yolov4.cfg -map
	# -dont_show -json_port 8070 -ext_output -mjpeg_port 8090

validation:
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector map coco.data yolov4.cfg yolov4_best.weights -points 101

inference:
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector demo coco.data yolov4.cfg yolov4_best.weights ../../test.mp4 -prefix pictures
	cd $(RESULTS)/$(VERSION_YOLO) && ffmpeg -i pictures_%08d.jpg -vf drawtext="text='YOLOv4-nano"$(_NANO)"': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.8: boxborderw=5: x=2: y=2" test-result.mp4
	cd $(RESULTS)/$(VERSION_YOLO) && rm pictures_*.jpg
