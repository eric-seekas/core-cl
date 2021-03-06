;; setup ASDF
(require :asdf)
(let ((cur-dir (truename *default-pathname-defaults*)))
  (setf asdf:*central-registry* (list cur-dir (truename "./app/asdf/registry/") (truename "./app/")))
  (setf asdf::*user-cache* (list (merge-pathnames #p"app/asdf/" cur-dir) "cache" :IMPLEMENTATION)))
;; setup sockets. we really don't need the full socket lib though since all comm
;; goes through cl-async, but we do need to fool ECL into thinking the
;; sb-bsd-sockets package exists.
;(require :sockets)
(defpackage sb-bsd-sockets)

;; load main libraries/initialize
(asdf:operate 'asdf:load-op :turtl-core)

;; -----------------------------------------------------------------------------
;; start the app
;; -----------------------------------------------------------------------------
(format t "~%~%")
(format t "Turtl loaded.~%")
(turtl-core:start
  :single-thread t
  :start-fn (lambda ()
              (let ((event (turtl-core::make-event
                             "http"
                             :data "http://api.turtl.it")))
                (turtl-core::push-event event))))

