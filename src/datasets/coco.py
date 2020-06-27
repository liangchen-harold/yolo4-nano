# author: liangchen (https://cs.lcsky.org)
import os
import sys
import argparse
from pycocotools.coco import COCO

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", help = "Path to instances_train2017.json or instances_val2017.json")
    parser.add_argument("--image_folder", help = "Path to original image folder")
    parser.add_argument("--out", default = "", help = "The output folder")
    parser.add_argument("--cls", type=str, default='cat', help = "The catalogues you want")
    parser.add_argument("--skip", nargs='*', type=int, default=[], help = "The skip count per catalogues")

    args = parser.parse_args()
    print(args)
    coco_json_path = args.json
    if not os.path.exists(coco_json_path):
        print ("{} does not exist!".format(coco_json_path))
        sys.exit()

    out_folder = args.out
    if out_folder:
        if not os.path.exists(out_folder):
            os.makedirs(out_folder)

    # COCO api
    coco = COCO(coco_json_path)

    cat_ids = coco.getCatIds(catNms=args.cls.split(','))
    img_ids = []
    for i, cat_id in enumerate(cat_ids):
        ids = coco.getImgIds(catIds=[cat_id])
        if (len(args.skip) > i):
            ids = ids[::args.skip[i]]
        img_ids += ids
        # print(img_ids)
    img_ids = list(set(img_ids))
    for img_id in img_ids:
        # image path
        img = coco.loadImgs(img_id)
        file_name = img[0]["file_name"]
        name = os.path.splitext(file_name)[0]
        if out_folder:
            # annotation
            anno_ids = coco.getAnnIds(imgIds=img_id, iscrowd=None)
            anno = coco.loadAnns(anno_ids)
            width = img[0]["width"]
            height = img[0]["height"]
            dw = 1. / width
            dh = 1. / height
            content = ''
            if(len(anno) > 0):
                for box in anno:
                    x_center = box["bbox"][0]+box["bbox"][2]/2.0
                    y_center = box["bbox"][1]+box["bbox"][3]/2.0
                    w = box["bbox"][2]
                    h = box["bbox"][3]
                    x_center = x_center * dw
                    y_center = y_center * dh
                    w = w * dw
                    h = h * dh
                    cat_id = box["category_id"]
                    bbox = (x_center, y_center, w, h)
                    if (cat_id in cat_ids):
                        cat_id = cat_ids.index(cat_id)
                        content += str(cat_id) + " " + " ".join([str(a) for a in bbox]) + '\n'
            if (len(content) > 0):
                # yolo_data_filename = "{}/{}.txt".format(out_folder, name)
                yolo_data_filename = "{}/{}.txt".format(out_folder, img[0]['id'])
                yolo_data_file = open(yolo_data_filename, 'w')
                yolo_data_file.write(content)

                out_image_filename = "{}/{}.{}".format(out_folder, img[0]['id'], img[0]['file_name'].split('.')[-1])
                in_image_filename = os.path.join(args.image_folder, file_name)
                os.symlink(os.path.relpath(in_image_filename, out_folder), out_image_filename)
