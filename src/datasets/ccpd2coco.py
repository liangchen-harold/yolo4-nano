# author: liangchen (https://cs.lcsky.org)
# some code borrowed from https://github.com/Tony607/labelme2coco
import os
import sys
import json
import argparse
from functools import reduce

class COCOWriter:
    def __init__(self, output_json_path="./coco.json"):
        self.output_json_path = output_json_path
        self.images = []
        self.categories = []
        self.annotations = []
        self.label = []
        self.annID = 1
        self.height = 0
        self.width = 0

    def category(self, label):
        category = {}
        category["supercategory"] = label[0]
        category["id"] = len(self.categories)
        category["name"] = label[0]
        return category

    def getcatid(self, label):
        for category in self.categories:
            if label == category["name"]:
                return category["id"]
        print("label: {} not in categories: {}.".format(label, self.categories))
        exit()
        return -1

    def image(self, path, image_id, width = -1, height = -1):
        image = {}
        if (width == -1 or height == -1):
            img = cv2.imread(path)
            height, width = img.shape[:2]
        image["height"] = height
        image["width"] = width
        image["id"] = image_id
        image["file_name"] = path

        self.height = height
        self.width = width

        return image

    def annotation(self, rect, label, image_id):
        annotation = {}
        annotation["iscrowd"] = 0
        annotation["image_id"] = image_id

        rect = list(map(float, rect))
        rect[2] -= rect[0]
        rect[3] -= rect[1]
        annotation["bbox"] = rect

        annotation["category_id"] = label[0]  # self.getcatid(label)
        annotation["id"] = self.annID
        self.annID += 1
        return annotation

    def save(self):
        data_coco = {}
        data_coco["images"] = self.images
        data_coco["categories"] = self.categories
        data_coco["annotations"] = self.annotations

        print('[save]', self.output_json_path)
        os.makedirs(os.path.dirname(os.path.abspath(self.output_json_path)), exist_ok=True)
        json.dump(data_coco, open(self.output_json_path, "w"), indent=4)

class CCPD2COCO(COCOWriter):
    def __init__(self, intput_txt_path, output_json_path):
        COCOWriter.__init__(self, output_json_path)
        self.statistic_province = {}
        self.load(intput_txt_path)

    def load(self, path):
        provinces = ["皖", "沪", "津", "渝", "冀", "晋", "蒙", "辽", "吉", "黑", "苏", "浙", "京", "闽", "赣", "鲁", "豫", "鄂", "湘", "粤", "桂", "琼", "川", "贵", "云", "西", "陕", "甘", "青", "宁", "新"]
        with open(path) as fin:
            for i, line in enumerate(fin):
                line = line.replace('\n', '')
                self.images.append(self.image(line, i, 720, 1160))

                parts = line.split('/')[1].split('-')
                rect = parts[2].replace('&', '_').split('_')
                plate_parts = parts[4].split('_')
                pstr = provinces[int(plate_parts[0])] + chr(int(plate_parts[1])+ord('A'))
                plate = pstr + str(reduce(lambda x,y:x+y, map(lambda x:chr(int(x)+ord('A')) if int(x) < 24 else str(int(x)-24), plate_parts[2:])))
                # print(rect, plate)
                if not pstr in self.statistic_province:
                    self.statistic_province[pstr] = 0
                self.statistic_province[pstr] += 1
                label = ['plate']
                if label not in self.label:
                    self.label.append(label)
                self.annotations.append(self.annotation(rect, label, i))

        sk = list(self.statistic_province.keys())
        sk.sort()
        print(reduce(lambda x,y:x+'\n'+y, [k+': '+str(self.statistic_province[k]) for k in sk]))

        self.label.sort()
        for label in self.label:
            self.categories.append(self.category(label))
        for annotation in self.annotations:
            annotation["category_id"] = self.getcatid(annotation["category_id"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", help = "Path to CCPD splits file e.g. train.txt")
    parser.add_argument("--output", default = "", help = "The output file")

    args = parser.parse_args()

    CCPD2COCO(args.input, args.output).save()
