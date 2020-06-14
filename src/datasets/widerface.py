# author: liangchen (https://cs.lcsky.org)
import os
import sys
import argparse
import cv2
import scipy.io

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mat", help = "Path to .mat file")
    parser.add_argument("--images", default = "", help = "The image folder")
    parser.add_argument("--out", default = "", help = "The output folder")

    args = parser.parse_args()
    mat_path = args.mat
    if not os.path.exists(mat_path):
        print ("{} does not exist!".format(mat_path))
        sys.exit()

    out_folder = args.out
    if out_folder:
        if not os.path.exists(out_folder):
            os.makedirs(out_folder)

    mat_file = scipy.io.loadmat(mat_path)
    event_list = mat_file.get('event_list')
    file_list = mat_file.get('file_list')
    face_bbx_list = mat_file.get('face_bbx_list')

    i = 0
    for event_idx, event in enumerate(event_list):
        directory = event[0][0]
        for im_idx, im in enumerate(file_list[event_idx][0]):
            im_name = im[0][0]
            face_bbx = face_bbx_list[event_idx][0][im_idx][0]
            i += 1
            # if (i % (skip + 1) != 0):
            #     continue
            #  print face_bbx.shape

            im_path = os.path.join(args.images, directory, im_name + '.jpg')
            image = cv2.imread(im_path)
            height, width, _ = image.shape
            dw = 1. / width
            dh = 1. / height

            content = ''
            for i in range(face_bbx.shape[0]):
                xmin = int(face_bbx[i][0])
                ymin = int(face_bbx[i][1])
                xmax = int(face_bbx[i][2]) + xmin
                ymax = int(face_bbx[i][3]) + ymin

                x_center = (xmin+xmax)/2.0
                y_center = (ymin+ymax)/2.0
                w = xmax - xmin
                h = ymax - ymin
                x_center = x_center * dw
                y_center = y_center * dh
                w = w * dw
                h = h * dh
                cat_id = 0
                bbox = (x_center, y_center, w, h)
                content += str(cat_id) + " " + " ".join([str(a) for a in bbox]) + '\n'

            if out_folder:
                if (len(content) > 0):
                    yolo_data_filename = "{}/{}.txt".format(out_folder, im_name)
                    yolo_data_file = open(yolo_data_filename, 'w')
                    yolo_data_file.write(content)

                    os.symlink(os.path.relpath(im_path, out_folder), os.path.join(out_folder, im_name + '.jpg'))
