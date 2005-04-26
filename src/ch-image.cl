;;
;; file: image.cl
;; author: cyrus harmon
;; time-stamp: Fri Apr 23 12:19:55 EDT 2004
;;

;;;
;;; This file contains the core of the image common-lisp class.
;;; This class represents images and provides utility functions for
;;; accessing images and image content.
;;;
;;; The main open question is how do we store multichannel (e.g. RGB)
;;; images? Do we store the images as planes? As interleaved planes?
;;; As an array of RGB values? I'm going to try the separate plane
;;; approach and see where that gets us.
;;;

;;; should the image accessor functions be row, col or x,y???

;;; TODO:
;;;  1. Support for 565-rgb images
;;;  2. Support for 888-rgb images
;;;  3. Support for FFF-rgb and FFFF-argb images
;;;  4. Support for 48-rgb and 64-argb images
;;;  5. Support for chunky images 

(in-package :image)

(defclass image ()
  ((data :accessor image-data)
   (width :accessor image-width :initarg :width)
   (height :accessor image-height :initarg :height)
   (channels :accessor image-channels :initform 1)
   )
  (:documentation "abstract image class"))
(defmethod image ((width fixnum) (height fixnum))
  (let ((img (make-instance 'image)))
    (setf (image-width img) width)
    (setf (image-height img) height)
    img))

(defclass argb-image (image)
  ((a :accessor image-a)
   (r :accessor image-r)
   (g :accessor image-g)
   (b :accessor image-b))
  (:documentation "ARGB (Alpha/Red/Green/Blue) image class"))

(defclass argb-8888-image (argb-image) ())

(defmethod shared-initialize :after
    ((img argb-8888-image) slot-names &rest initargs &key &allow-other-keys)
  (declare (ignore initargs))
  (if (and (slot-boundp img 'width)
	   (slot-boundp img 'height))
      (let ((width (slot-value img 'width))
	    (height (slot-value img 'height)))
	(setf (image-a img) (make-instance 'unsigned-byte-matrix :rows width :cols height))
	(setf (image-r img) (make-instance 'unsigned-byte-matrix :rows width :cols height))
	(setf (image-g img) (make-instance 'unsigned-byte-matrix :rows width :cols height))
	(setf (image-b img) (make-instance 'unsigned-byte-matrix :rows width :cols height))
	(setf (image-data img) (list (image-a img) (image-r img) (image-g img) (image-b img))))))

(defmethod pad-image ((img argb-8888-image))
  (setf (image-a img) (pad-matrix (image-a img)))
  (setf (image-r img) (pad-matrix (image-r img)))
  (setf (image-g img) (pad-matrix (image-g img)))
  (setf (image-b img) (pad-matrix (image-b img)))
  (setf (image-data img) (list (image-a img) (image-r img) (image-g img) (image-b img)))
  (setf (image-width img) (rows (image-r img)))
  (setf (image-height img) (cols (image-r img)))
  img)
  
(defmethod set-argb-values ((img argb-image)
			    (x fixnum)
			    (y fixnum)
			    (a fixnum)
			    (r fixnum)
			    (g fixnum)
			    (b fixnum))
  "Sets the alpha, red, green and blue values at x, y"
  (matrix::%set-val (image-a img) x y a)
  (matrix::%set-val (image-r img) x y r)
  (matrix::%set-val (image-g img) x y g)
  (matrix::%set-val (image-b img) x y b)
  )

(defmethod get-argb-values ((img argb-image) (x fixnum) (y fixnum))
  "Gets the alpha, red, green and blue values at x, y"
  (values (val (image-a img) x y)
	  (val (image-r img) x y)
	  (val (image-g img) x y)
	  (val (image-b img) x y)))

(defclass gray-image (image) ()
  (:documentation "Grayscale 8-bit image class"))

(defmethod shared-initialize :after
    ((img gray-image) slot-names &rest initargs &key &allow-other-keys)
  (declare (ignore initargs))
  (if (and (slot-boundp img 'width)
	   (slot-boundp img 'height))
      (let ((width (slot-value img 'width))
	    (height (slot-value img 'height)))
	(setf (image-data img)
	      (make-instance 'unsigned-byte-matrix :rows width :cols height)))))

(defmethod pad-image ((img gray-image))
  (set-image-data img (pad-matrix (image-data img))))

(defmethod get-gray-value ((img gray-image) (x fixnum) (y fixnum))
  "Gets the grayscale value at x, y"
  (val (image-data img) x y))

(defmethod set-gray-value ((img gray-image) (x fixnum) (y fixnum) (v fixnum))
  "Sets the grayscale value at x, y to v"
  (matrix::set-val-fit (image-data img) x y v))

(defmethod set-image-data ((img gray-image) (m matrix))
  "Sets the gray-image data to the matrix m and updates image-width and image-height"
  (destructuring-bind (w h) (dim m)
    (setf (image-width img) w)
    (setf (image-height img) h)
    (setf (image-data img) m)))

(defun map-pixels (f img)
  (dotimes (y (image-height img))
    (declare (dynamic-extent y) (fixnum y))
    (dotimes (x (image-width img))
      (declare (dynamic-extent x) (fixnum x))
      (funcall f img x y)))
  img)

(defmethod set-pixel ((img image) x y val)
  (declare (ignore x y val))
  (print "set-pixel not implemented for generic image class"))

(defmethod get-pixel ((img image) x y)
  (declare (ignore x y))
  (print "set-pixel not implemented for generic image class"))

(defmethod set-pixel ((img gray-image) x y val)
  (set-gray-value img x y val))

(defmethod get-pixel ((img gray-image) x y)
  (get-gray-value img x y))

(defmethod set-pixel ((img argb-image) x y val)
  (set-argb-values img x y
		   (car val)
		   (cadr val)
		   (caddr val)
		   (cadddr val)))

(defmethod get-pixel ((img argb-image) x y)
  (multiple-value-bind (a r g b) (get-argb-values img x y)
    (list a r g b)))

(defun rgb-to-gray-pixel (r g b)
  (declare (dynamic-extent r g b) (fixnum r g b))
  (floor (/ (+ r g b) 3)))

(defmethod argb-image-to-gray-image ((src argb-image))
  (let ((dest (make-instance 'gray-image :width (image-width src) :height (image-height src))))
    (map-pixels #'(lambda (img x y)
		    (declare (dynamic-extent x y) (fixnum x y))
		    (destructuring-bind (a r g b) (get-pixel img x y)
		      (declare (dynamic-extent a r g b) (fixnum a r g b))
		      (declare (ignore a))
		      (set-pixel dest x y (rgb-to-gray-pixel r g b))))
		src)
    dest))

(defclass matrix-gray-image (gray-image unsigned-byte-matrix)
  ((matrix:rows :initarg :width :accessor image-width)
   (matrix:cols :initarg :height :accessor image-height)
   (matrix::initial-element :accessor initial-element
			    :initarg :initial-element
			    :initform (coerce 0 'unsigned-byte)))
  (:documentation "Grayscale 8-bit image class that is also a matrix"))

;(defmethod shared-initialize :around
;    ((img matrix-gray-image) slot-names &rest initargs &key &allow-other-keys)
;  (let ((rows) (cols) (width) (height))
;    (labels ((parse-init-args (alist)
;	       (let ((arg (pop alist))
;		     (val (pop alist)))
;		 (cond
;		   ((equal arg :width) (setf rows val))
;		   ((equal arg :height) (setf cols val))
;		   )
;		 (when alist (parse-init-args alist)))))
;      (parse-init-args initargs))
;    (if (not (getf initargs :width))
;	(setf width (getf initargs :rows)))
;    (if (not (getf initargs :height))
;	(setf height (getf initargs :cols)))
;    
;    (apply #'call-next-method img slot-names (append initargs
;						     (if rows (list :rows rows))
;						     (if cols (list :cols cols))
;						     (if width (list :width width))
;						     (if height (list :height height))
;						     ))))

(defmethod shared-initialize :after
    ((img matrix-gray-image) slot-names &rest initargs &key &allow-other-keys)
  (declare (ignore initargs))
  (setf (image-data img) img))
