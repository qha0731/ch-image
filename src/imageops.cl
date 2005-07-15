;;
;; file: imageops.cl
;; author: cyrus harmon
;; time-stamp: Tue Jul  6 17:03:39 PDT 2004
;;

(in-package :ch-image)

(defparameter *masked-pixel* '(255 0 0 0))

(defun mask-image (img seg &key (mask-val 0) (masked-pixel *masked-pixel*))
  (let ((mask (make-instance 'argb-8888-image :width (image-width img) :height (image-height img))))
    (map-pixels #'(lambda (img x y)
		    (if (/= (get-pixel seg x y) mask-val)
			(set-pixel mask x y (get-pixel img x y))	
			(set-pixel mask x y masked-pixel)	
			))
		img)
    mask))

(defun flip-image (img)
  (let ((h (image-height img))
	(w (image-width img)))
    (declare (dynamic-extent h w) (fixnum h w))
    (let ((fimg (make-instance (class-of img) :width w :height h)))
      (dotimes (i (image-height img))
	(declare (dynamic-extent i) (fixnum i))
	(dotimes (j (image-width img))
	  (declare (dynamic-extent j) (fixnum j))
	  (set-pixel fimg (- w j 1) i
		     (get-pixel img j i))))
      fimg)))

(defmethod get-gray-image-levels ((img gray-image))
  (let ((l (make-array 256)))
    (dotimes (i (image-height img))
      (declare (dynamic-extent i) (fixnum i))
      (dotimes (j (image-width img))
	(declare (dynamic-extent j) (fixnum j))
	(setf (aref l (get-pixel img j i)) 1)))
    l))

(defmethod get-level-ordering ((l vector))
  (let ((o (make-array 256 :initial-element 0))
	(v 0)
	k)
    (dotimes (i 256)
      (declare (dynamic-extent i) (fixnum i))
      (when (> (aref l i) 0)
	(setf (aref o i) (postincf v))
	(push i k)))
    (values o (reverse k))))

(defmethod argb-image-to-blue-image ((src argb-image))
  (let ((dest (make-instance 'gray-image :width (image-width src) :height (image-height src))))
    (map-pixels #'(lambda (img x y)
		    (destructuring-bind (a r g b) (get-pixel img x y)
		      (declare (ignore a r g))
		      (set-pixel dest x y b)))
		src)
    dest))

(defgeneric affine-transform-image (img xfrm &key interpolation background))
(defmethod affine-transform-image
    ((img image)
     (xfrm clem:affine-transformation)
     &key
     (interpolation nil interpolation-supplied-p)
     (background nil background-supplied-p))
  (let ((m (clem:mat-copy-proto (image-r img))))
    (mapcar #'(lambda (channel)
                (apply #'clem:transform-matrix channel m xfrm
                       (append
                        (when background-supplied-p
                          (list :background background))
                        (when interpolation-supplied-p
                          (list :interpolation interpolation))))
                (clem:matrix-move m channel))
            (get-channels img))))

(defun gaussian-blur-image (img &key (k 2) (sigma 1) (truncate nil))
  (declare (ignore truncate))
  (let* ((hr (clem::gaussian-kernel-1d k sigma))
         (hc (transpose hr)))
    (let ((mr (image-height img)) (mc (image-width img)) (hrows (rows hr)) (hcols (cols hc)))
      (let ((z1r mr) (z1c (+ mc hcols -1))
            (z2r (+ mr hrows -1)) (z2c (+ mc hcols -1))
            (matrix-class (class-of (car (get-channels img)))))
        (let ((z1 (make-instance matrix-class :rows z1r :cols z1c)))
          (set-channels
           img
           (mapcar #'(lambda (channel)
                       (let ((z2 (make-instance matrix-class :rows z2r :cols z2c)))
                         (clem::%separable-discrete-convolve channel hr hc z1 z2 :norm-v nil)))
                   (get-channels img)))
          (setf (image-height img) (clem:rows (ch-image::image-r img)))
          (setf (image-width img) (clem:cols (ch-image::image-r img)))))))
  img)

