# author: liangchen (https://cs.lcsky.org)
.PHONY: all train inference validation data install pb

# 数据集 | dataset
DATA=datasets/coco2017
# DATA=datasets/widerface
# DATA=datasets/CCPD2019
# 需要检测的目标类别 | The categories you want
# CLS=person,bicycle,car,motorbike,aeroplane,bus,train,truck,boat,traffic light,fire hydrant,stop sign,parking meter,bench,bird,cat,dog,horse,sheep,cow,elephant,bear,zebra,giraffe,backpack,umbrella,handbag,tie,suitcase,frisbee,skis,snowboard,sports ball,kite,baseball bat,baseball glove,skateboard,surfboard,tennis racket,bottle,wine glass,cup,fork,knife,spoon,bowl,banana,apple,sandwich,orange,broccoli,carrot,hot dog,pizza,donut,cake,chair,sofa,pottedplant,bed,diningtable,toilet,tvmonitor,laptop,mouse,remote,keyboard,cell phone,microwave,oven,toaster,sink,refrigerator,book,clock,vase,scissors,teddy bear,hair drier,toothbrush
# CLS_DISPLAY=all
CLS=cat,dog
# CLS=person,cat,dog
# CLS=bicycle,car,motorcycle,bus,train,truck
# CLS=face
# CLS=plate
# 训练多少代（看整个训练集多少次） | epochs
EPOCHS=100
# 模型通道数量缩放倍数(0.125, 0.25, 0.5, 1.0) | channel number scale factor(0.125, 0.25, 0.5, 1.0)
NANO=0.25
# PRETRAIN=yolov4.conv.137
# 训练结果 | folder to put the trained model
RESULTS=results
INFERENCE_FILE=test.mp4

# 内部变量 | internal use
CLS_DISPLAY?=$(CLS)
_CLS=`echo $(CLS_DISPLAY) | tr ' ' '_' | tr ',' '-'`
N_CLS=`echo $(CLS) | tr ' ' '_' | tr ',' '\n' | wc -l`
_NANO=`echo $(NANO) | tr -d '.'`
YOLO_DATA=stage/$(notdir $(DATA))-$(_CLS)

ifneq ($(NANO),)
	VAR:=$(VAR)-nano$(_NANO)
endif
ifneq ($(PRETRAIN),)
	VAR:=$(VAR)-pretrain
	PRETRAIN:=../../stage/$(PRETRAIN)
endif
VERSION_YOLO=yolo-v4$(VAR)-$(notdir $(DATA))-$(_CLS)
BATCHES=$$(( $(shell cat $(YOLO_DATA)/train.txt | wc -l) * $(EPOCHS) / 64 ))

install:
	pip3 install pycocotools
	git clone https://github.com/AlexeyAB/darknet.git
	cd darknet && git reset --hard 6c6f04a9b3960edda232c3edd847a6704b946ee3
	cd darknet && sed -i 's/cmake_minimum_required(VERSION 3.12)/cmake_minimum_required(VERSION 3.8)/g' CMakeLists.txt
	cd darknet && sed -i 's/find_package(OpenMP)/# find_package(OpenMP)/g' CMakeLists.txt
	cd darknet && mkdir build-release
	cd darknet/build-release && cmake ..
	cd darknet/build-release && make -j6

data:
	rm -rf $(YOLO_DATA)

ifeq ($(notdir $(DATA)),coco2017)
	python3 src/datasets/coco.py --cls "$(CLS)" --out $(YOLO_DATA)/train --image_folder $(DATA)/images/train2017 --json $(DATA)/annotations/instances_train2017.json
	python3 src/datasets/coco.py --cls "$(CLS)" --out $(YOLO_DATA)/val --image_folder $(DATA)/images/val2017 --json $(DATA)/annotations/instances_val2017.json
endif
ifeq ($(notdir $(DATA)),widerface)
	python3 src/datasets/widerface.py --out $(YOLO_DATA)/train --images $(DATA)/WIDER_train/images --mat $(DATA)/wider_face_split/wider_face_train.mat
	python3 src/datasets/widerface.py --out $(YOLO_DATA)/val --images $(DATA)/WIDER_val/images --mat $(DATA)/wider_face_split/wider_face_val.mat
endif
ifeq ($(notdir $(DATA)),CCPD2019)
	python3 src/datasets/ccpd2coco.py --input $(DATA)/splits/train.txt --output $(YOLO_DATA)/train.json
	python3 src/datasets/ccpd2coco.py --input $(DATA)/splits/val.txt --output $(YOLO_DATA)/val.json

	python3 src/datasets/coco.py --cls "$(CLS)" --out $(YOLO_DATA)/train --image_folder $(DATA) --json $(YOLO_DATA)/train.json
	python3 src/datasets/coco.py --cls "$(CLS)" --skip 50 --out $(YOLO_DATA)/val --image_folder $(DATA) --json $(YOLO_DATA)/val.json
endif

	ls $(YOLO_DATA)/val/|grep txt| awk '{split($$1,a,"."); printf("%s%s.jpg\n", "'../../$(YOLO_DATA)/val/'", a[1])}' > $(YOLO_DATA)/val.txt
	ls $(YOLO_DATA)/train/|grep txt| awk '{split($$1,a,"."); printf("%s%s.jpg\n", "'../../$(YOLO_DATA)/train/'", a[1])}' > $(YOLO_DATA)/train.txt

train:
	mkdir -p $(RESULTS)/$(VERSION_YOLO)
	echo "classes= $(N_CLS)\n\
	train  = ../../$(YOLO_DATA)/train.txt\n\
	valid  = ../../$(YOLO_DATA)/val.txt\n\
	names  = ../../$(RESULTS)/$(VERSION_YOLO)/coco.names\n\
	backup = ../../$(RESULTS)/$(VERSION_YOLO)\n\
	eval   = coco" > $(RESULTS)/$(VERSION_YOLO)/coco.data
	echo $(CLS) | tr ',' '\n' > $(RESULTS)/$(VERSION_YOLO)/coco.names

ifneq ($(NANO),)
	cat darknet/cfg/yolov4.cfg | \
		awk -F "=" '{if ($$1=="filters" && $$2!=255) print($$1"="int($$2*'$(NANO)')); else print($$0)}' | \
		sed 's/activation=leaky/activation=relu/g' | \
		sed 's/activation=mish/activation=relu/g' > $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1
else
	cp darknet/cfg/yolov4.cfg $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1
endif

ifeq ($(SMALL),yes)
	cat $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1 | \
		sed '894s/.*/layers=23/g' | \
		sed '891s/.*/stride=4/g' | \
		sed '988s/.*/stride=4/g' | \
		> $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg
	cp $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1
endif

	cat $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1 | \
		awk -F "[= ]" '{if ($$1=="max_batches") print($$1"="'$(BATCHES)'); else print($$0)}' | \
		awk -F "[= ]" '{if ($$1=="steps") print($$1"="int('$(BATCHES)'*0.75)","int('$(BATCHES)'*0.85)); else print($$0)}' | \
		sed 's/width=608/width=416/g' | \
		sed 's/height=608/height=416/g' | \
		sed 's/subdivisions=8/subdivisions=64/g' | \
		sed 's/mosaic=1/mosaic=1\nmosaic_bound=1/g' | \
		sed 's/filters=255/filters='$$((($(N_CLS)+5)*3))'/g' | \
		sed 's/classes=80/classes='$(N_CLS)'/g' \
		> $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg

ifeq ($(notdir $(DATA)),CCPD2019)
	echo 'resize=5' >> $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg
endif

	rm $(RESULTS)/$(VERSION_YOLO)/yolov4.cfg.1

	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector train coco.data yolov4.cfg -map $(PRETRAIN)
	# -dont_show -json_port 8070 -ext_output -mjpeg_port 8090
	# yolov4_last.weights

validation:
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector map coco.data yolov4.cfg yolov4_last.weights -points 101

test:
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector test coco.data yolov4.cfg yolov4_last.weights ../../vlcsnap-2020-06-13-21h57m00s209-r.jpg

inference:
	cd $(RESULTS)/$(VERSION_YOLO) && ../../darknet/build-release/darknet detector demo coco.data yolov4.cfg yolov4_last.weights ../../$(INFERENCE_FILE) -prefix pictures
	cd $(RESULTS)/$(VERSION_YOLO) && ffmpeg -i pictures_%08d.jpg -vf drawtext="text='YOLOv4"$(VAR)"': fontcolor=white: fontsize=24: box=1: boxcolor=black@0.8: boxborderw=5: x=2: y=2" result-$(INFERENCE_FILE)
	cd $(RESULTS)/$(VERSION_YOLO) && rm pictures_*.jpg
	nautilus $(RESULTS)/$(VERSION_YOLO) &

pb:
	cd $(RESULTS)/$(VERSION_YOLO) && cat yolov4.cfg | awk -F "[=]" '{if ($$1=="anchors ") print($$2)}' > anchors.txt
	cd $(RESULTS)/$(VERSION_YOLO) && CUDA_VISIBLE_DEVICES= python3 ../../src/keras-yolo4-converter/convert.py --alpha $(NANO) --model_path yolov4_best.weights --anchors_path anchors.txt --classes_path coco.names --output_layer_file outputs.txt -o yolov4_best.h5
	# cd $(RESULTS)/$(VERSION_YOLO) && CUDA_VISIBLE_DEVICES= python3 ../../src/keras-yolo4-converter/test.py --alpha $(NANO) --model_path yolov4_best.h5 --anchors_path anchors.txt --classes_path coco.names
