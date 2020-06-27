# YOLOv4-nano

YOLOv4-nano是一个对原版YOLOv4的变更，主要目的正如其名：更小更快，因为YOLO官方一般使用tiny命名其裁减版，因此我的裁减版命名为nano。改动如下：
1. 将MISH和Leaky激活函数替换成ReLU，以便于NPU执行推理，代价是降低了mAP ~1%
2. 采用类似Mobilenet的通道数缩放机制，不改变整体模型网络结构的前提下，将通道数量减少到0.125、0.25、0.5倍，加快推理速度，并大大降低模型尺寸
3. 基于Makefile的训练脚本，方便的“一键训练”

## 系统依赖
1. Ubuntu 18.04，安装了Nvidia GPU驱动和CUDA 10.0，在这些显卡上测试过：GTX 1660Ti (DELL G3 3590) / T4 / V100
2. OpenCV-dev 3.x
``` sh
sudo apt install libopencv-dev
```

## 起步
``` sh
git clone https://github.com/liangchen-harold/yolo4-nano.git --recursive
cd yolo4-nano
make install
```
然后需要准备数据集（MS COCO 2017），放到这个文件夹：datasets/coco2017，文件夹结构看起来像这样：

```
datasets/
└── coco2017/
    ├── annotations/
    │   ├── instances_train2017.json
    │   └── instances_val2017.json
    └── images/
        ├── train2017/
        │   ├── 000000000139.jpg
        │   └── ...
        └── val2017/
            ├── 000000000009.jpg
            └── ...
```

## 训练模型
默认的检测类别是😺和🐶，如果你想训练自己的类别，自己改动Makefile的第9行：

CLS=cat,dog

默认模型通道缩放比例NANO=0.25，weights文件大小仅16MB，推理速度比原版快3~4倍，自己改动Makefile的第17行，选择合适的缩放比例，详细数据请参考[这里](https://cs.lcsky.org/?p=342)。

``` sh
# 如果你改动过CLS，需要重新运行：
make data

# 开始训练
make train
```
## 更多用法
``` sh
# 训练完成后，计算算法指标（AP）
make validation

# 放一个test.mp4文件到目录中，可以输出检测结果
make inference
```

## 更多信息
博客文章: https://cs.lcsky.org/?p=342

---

YOLOv4-nano is a series of improvements on AlexeyAB's YOLOv4 with darknet:
1. Replace MISH and Leaky to ReLU, can run much faster on NPU, only decreased mAP ~1%
2. Add channel number multiplier factor(inspired by MobileNet), which can reduce the size of weights and accelerate inference
3. An easy to use Makefile system

## Pre requires
1. Ubuntu 18.04 with Nvidia GPU driver and CUDA 10.0 installed, tested on GTX 1660Ti (DELL G3 3590) / T4 / V100
2. OpenCV-dev 3.x
``` sh
sudo apt install libopencv-dev
```

## Getting start
``` sh
git clone https://github.com/liangchen-harold/yolo4-nano.git --recursive
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
        │   ├── 000000000139.jpg
        │   └── ...
        └── val2017/
            ├── 000000000009.jpg
            └── ...
```

## Train the model
The default detection classes is cat and dog, if you want train the model to detect other target, modify line 9 of the Makefile

CLS=cat,dog

The default channel multiplier factor NANO=0.25, the size of weights file is only 16MB, and the inference speed is 3~4x faster than the original YOLOv4, modify line 17 of the Makefile to choose the factor. For more experiments data please reference [here](https://cs.lcsky.org/?p=342).

``` sh
# if you changed the CLS value in Makefile, you need to run this again:
make data

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

## More infomation
blog page: https://cs.lcsky.org/?p=342
