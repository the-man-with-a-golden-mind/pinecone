(import scheme
        (chicken base)
        (chicken time)
        pinecone)

;; Create app
(define app (create-app port: 8080 root-path: "./static"))

;; Add middlewares
(app-use! app (make-middleware logging-middleware "logger"))
(app-use! app (make-middleware cookie-parser-middleware "cookie-parser"))
(app-use! app (make-middleware session-middleware "session"))

;; Custom middleware
(define (auth-middleware params next)
  (let ((user (session-get 'user #f)))
    (if user
        (begin
          (print "  [Auth] User logged in: " user)
          (next params))
        (begin
          (print "  [Auth] No user session")
          (next params)))))

(app-use! app (make-middleware auth-middleware "auth"))

;; Routes
(app-add-route! app 'GET '("api" "login")
  (lambda (params)
    (session-set! 'user "john@example.com")
    (session-set! 'login-time (current-seconds))
    (send-json (list (cons 'message "Logged in!")
                     (cons 'user "john@example.com")))))

(app-add-route! app 'GET '("api" "profile")
  (lambda (params)
    (let ((user (session-get 'user #f))
          (login-time (session-get 'login-time #f)))
      (if user
          (send-json (list (cons 'user user)
                           (cons 'login-time login-time)
                           (cons 'message "Profile data")))
          (send-error 'unauthorized "Not logged in")))))

(app-add-route! app 'GET '("api" "logout")
  (lambda (params)
    (destroy-session!)
    (send-json (list (cons 'message "Logged out")))))

(app-add-route! app 'GET '("api" "counter")
  (lambda (params)
    (let* ((count (session-get 'counter 0))
           (new-count (+ count 1)))
      (session-set! 'counter new-count)
      (send-json (list (cons 'counter new-count)
                       (cons 'message "Counter incremented"))))))

(app-start! app)
