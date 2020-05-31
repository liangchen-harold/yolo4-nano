# YOLOv4-nano

YOLOv4-nano is a series of improvements on AlexeyAB's YOLOv4 with darknet:
1. Replace MISH and Leaky to ReLU, can run much faster on NPU, only decreased mAP ~1%
2. Add channel number scale factor, which can reduce the size of weights and accelerate inference
3. An easy to use Makefile system

## Pre requires
Ubuntu 18.04 with Nvidia GPU driver and CUDA 10.0 installed, tested on GTX 1660Ti (DELL G3 3590) / T4 / V100

## Getting start
``` sh
git clone https://github.com/liangchen-harold/yolo4-nano.git
cd yolo4-nano
make install
```
Then you need to get a copy of MS COCO 2017, put into datasets/coco2017, the folder struct like this:

```
datasets/
└── coco2017/
    ├── annotations/
    │   ├── instances_train2017.json
    │   └── instances_val2017.json
    └── images/
        ├── train2017/
        |   ├── 000000000139.jpg
        |   └── ...
        └── val2017/
            ├── 000000000009.jpg
            └── ...
```

## Train the model
The default detection classes is cat and dog, if you want train the model to detect other target, modify line 5 of the Makefile

CLS=cat dog

``` sh
# train the model
make train
```
## Usage
``` sh
# after train, calculate AP of the model
make validation

# put test.mp4 at root of the repo, inference with the trained model
make inference
```

## more infomation
blog page: https://cs.lcsky.org/?p=342
