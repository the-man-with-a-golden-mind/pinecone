(import scheme
        (chicken base)
        (chicken time)
        pinecone
        datastar)

;; Create Pinecone app
(define app (create-app port: 8080 root-path: "./static"))

;; Get SSE manager
(define sse-mgr (app-sse-manager app))

;; SSE permanent connection
(app-add-route! app 'GET '("sse")
  (lambda (params)
    ((sse-manager-handler sse-mgr))))

;; POST /type - Datastar text counter
(app-add-route! app 'POST '("type")
  (lambda (params)
    (let* ((json (get-post-json))
           (txt (if json (or (alist-ref 'text json) "") ""))
           (len (string-length txt))
           (chunk (ds-response
                    (ds-signals (string-append "{count: " (number->string len) "}"))
                    (ds-elements (string-append "<p id=\"status\">Length: "
                                                (number->string len) "</p>")))))
      (print "POST /type - length: " len)
      (sse-manager-broadcast! sse-mgr chunk)
      (send-sse chunk))))

;; GET /inc - Datastar increment
(app-add-route! app 'GET '("inc")
  (lambda (params)
    (let ((chunk (ds-response
                   (ds-signals "{count: $count + 1}")
                   (ds-elements "<p id=\"status\">increment</p>"))))
      (print "GET /inc")
      (sse-manager-broadcast! sse-mgr chunk)
      (send-sse chunk))))

;; GET /api/hello - JSON API example
(app-add-route! app 'GET '("api" "hello")
  (lambda (params)
    (send-json (list (cons 'message "Hello from Pinecone!")
                     (cons 'timestamp (current-seconds))))))

;; GET /api/user/:id - Path parameters example
(app-add-route! app 'GET '("api" "user" ":id")
  (lambda (params)
    (let ((user-id (alist-ref 'id params)))
      (print "GET /api/user/" user-id)
      (send-json (list (cons 'id user-id)
                       (cons 'name (string-append "User " user-id))
                       (cons 'email (string-append "user" user-id "@example.com")))))))

;; GET /api/posts/:post-id/comments/:comment-id - Nested parameters
(app-add-route! app 'GET '("api" "posts" ":post-id" "comments" ":comment-id")
  (lambda (params)
    (let ((post-id (alist-ref 'post-id params))
          (comment-id (alist-ref 'comment-id params)))
      (print "GET /api/posts/" post-id "/comments/" comment-id)
      (send-json (list (cons 'post-id post-id)
                       (cons 'comment-id comment-id)
                       (cons 'content "This is a sample comment")
                       (cons 'author "John Doe"))))))

;; POST /api/echo - Echo JSON back
(app-add-route! app 'POST '("api" "echo")
  (lambda (params)
    (let ((json (get-post-json)))
      (if json
          (send-json (list (cons 'received json)
                           (cons 'timestamp (current-seconds))))
          (send-error 'bad-request "Invalid JSON")))))

;; Start server
(app-start! app)
