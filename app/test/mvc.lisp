(in-package :turtl-core-test)
(in-suite turtl-core-mvc)

(defclass dog (model) ())
(defclass dogs (collection)
  ((model-type :accessor model-type :initform 'dog)
   (sort-function :accessor sort-function :initform (lambda (a b)
                                                      (let ((a-id (write-to-string (or (mid a) 0)))
                                                            (b-id (write-to-string (or (mid b) 0))))
                                                        (string< a-id b-id))))))

(defclass shiba (dog) ())
(defclass shibas (dogs)
  ((model-type :accessor model-type :initform 'shiba)))

(test create-model/mget
  "Test creation of models and their data."
  (let ((model (create-model 'dog '(:name "wookie" :likes ("barking"
                                                           "growling"
                                                           "shrieking")))))
    (is (string= "wookie" (mget model "name")))
    (is (string= "growling" (cadr (mget model "likes")))))
  (let ((model (create-model 'dog (hu:hash ("name" "kofi")
                                           ("breed" "shiba")
                                           ("says" "harrrr")))))
    (is (string= "kofi" (mget model "name")))
    (is (string= "harrrr" (mget model "says")))))

(defmethod minit ((shiba shiba))
  (mset shiba '(:says "harl")))
(defmethod minit ((shibas shibas))
  (madd shibas '(:name "kofi")))

(test minit
  "Test model/collection intialization."
  (let ((model (create-model 'shiba))
        (collection (create-collection 'shibas)))
    (is (string= "harl" (mget model "says")))
    (is (= 1 (length (models collection))))
    (is (string= "kofi" (mget (car (models collection)) "name")))))

(test mset
  "Test mset usage."
  (let ((model (create-model 'dog)))
    (mset model '(:name "slappy"))
    (mset model '(:age 17 :likes "slapping"))
    (mset model (hu:hash ("eats" "doritos") ("is" "bold and daring")))
    (is (string= "slappy" (mget model "name")))
    (is (= 17 (mget model "age")))
    (is (string= "slapping" (mget model "likes")))
    (is (string= "doritos" (mget model "eats")))
    (is (string= "bold and daring" (mget model "is")))
    (is (null (mget model "unknown")))
    (is (= 487 (mget model "__LOL__" 487)))))

(test mdestroy
  "There is a D in destroy...is in...DESTROY THEM."
  (let ((model (create-model 'dog '(:name "barky"
                                    :owner "terrance"))))
    (is (string= "barky" (mget model "name")))
    (mdestroy model)
    (is (eq nil (mget model "name")))
    (is (= 0 (hash-table-count (data model))))))

(test model-clone
  "Test cloning a model."
  (let* ((model1 (create-model 'dog '(:name "timmy" :says "gfff" :friends ("wookie" "lucy"))))
         (model2 (mclone model1))
         (model3 (mclone model1 'shiba)))
    (is (not (eq (gethash "friends" (data model1)) (gethash "friends" (data model2)))))
    (is (not (eq (gethash "friends" (data model1)) (gethash "friends" (data model3)))))
    (is (not (eq (gethash "friends" (data model2)) (gethash "friends" (data model3)))))
    (is (equalp '("wookie" "lucy") (gethash "friends" (data model2))))
    (is (equalp '("wookie" "lucy") (gethash "friends" (data model3))))
    (is (eq 'dog (type-of model2)))
    (is (eq 'shiba (type-of model3)))))
  
(test model-events
  "Test that models trigger events properly."
  (let ((model (create-model 'dog))
        (changed nil)
        (name nil)
        (age nil)
        (destroyed nil))
    (bind "change" (lambda (ev) (setf changed t) ev) :dispatch (dispatch model))
    (bind "change:name" (lambda (ev) (setf name (data ev))) :dispatch (dispatch model))
    (bind "change:age" (lambda (ev) (setf age (data ev))) :dispatch (dispatch model))
    (bind "destroy" (lambda (ev) (setf destroyed t) ev) :dispatch (dispatch model))
    (mset model '(:name "kofi"))
    (mset model '(:age 2))
    (mdestroy model)
    (is (eq changed t))
    (is (string= "kofi" name))
    (is (= 2 age))
    (is (eq destroyed t))))

(test model-serialization
  "Test models can be properly serialized."
  (let ((model (create-model 'dog))
        (res "{\"name\":\"kofi\",\"classification\":\"mecha shiba\",\"powers\":[\"harr\",\"mechachomp\",\"shiba500\"]}"))
    (mset model '(:name "kofi"
                  :classification "mecha shiba"
                  :powers ("harr" "mechachomp" "shiba500")))
    (let* ((serialized (mserialize model))
           (json (with-output-to-string (s)
                   (yason:encode serialized s))))
      (is (string= res json)))))

(test create-collection
  "Test creation of collection and sub-models."
  (let ((collection (create-collection 'dogs '((:name "wookie")
                                               (:name "little timmy")
                                               (:name "kofi")))))
    (is (eq (model-type collection) 'dog))
    (dolist (model (models collection))
      (is (typep model 'dog))
      (is (stringp (mget model "name"))))))

(test collection-triggering
  "Collection should trigger events of models."
  (let ((collection (create-collection 'dogs '((:name "wookie")
                                               (:name "timmy")
                                               (:name "lucy"))))
        (likes nil))
    (bind "change:likes" (lambda (ev) (setf likes (data ev)))
          :dispatch (dispatch collection))
    (mset (car (models collection)) '("likes" "barking"))
    (is (string= "barking" likes))))

(test collection-sorting
  "Make sure sorting works properly."
  (let ((collection (create-collection 'dogs)))
    (setf (sort-function collection)
            (lambda (a b)
              (string< (mget a "name") (mget b "name"))))
    (madd collection '(:name "seal"))
    (madd collection '(:name "toby"))
    (madd collection '(:name "ruby"))
    (madd collection '(:name "timmy"))
    (madd collection '(:name "wookie"))
    (madd collection '(:name "lucy"))
    (madd collection '(:name "kofi"))
    (madd collection '(:name "moses"))
    (let ((names (mapcar (lambda (m) (mget m "name")) (models collection))))
      (is (equalp '("kofi" "lucy" "moses" "ruby" "seal" "timmy" "toby" "wookie") names)))))

(test collection-remove
  "Collections can remove a model."
  (let ((collection (create-collection 'dogs))
        (dog1 (create-model 'dog '(:name "slappy")))
        (dog2 (create-model 'dog '(:name "barky"))))
    (madd collection dog1)
    (madd collection dog2)
    (mrem collection dog1)
    (is (= 1 (length (models collection))))
    (is (eq dog2 (car (models collection))))))

(test collection-find
  "Find a model by id."
  (let ((collection (create-collection 'dogs '((:id 123 :name "barky")
                                               (:id 666 :name "satany")
                                               (:id 999 :name "obsessed")))))
    (let ((found1 (mfind collection 999))
          (found2 (mfind collection "satany" :field "name")))
      (is (typep found1 'dog))
      (is (string= "obsessed" (mget found1 "name")))
      (is (typep found2 'dog))
      (is (= 666 (mid found2))))))

(test collection-filter
  "Test filtering models in a collection."
  (let* ((collection (create-collection 'dogs '((:id 1 :name "barky" :likes "barking")
                                                (:id 2 :name "wookie" :likes "denning")
                                                (:id 3 :name "timmy" :likes "barking")
                                                (:id 4 :name "kofi" :likes "harr"))))
         (models (mfilter collection "likes" "barking")))
    (is (= 2 (length models)))
    (is (string= "barky" (mget (car models) "name")))
    (is (string= "timmy" (mget (cadr models) "name")))))

