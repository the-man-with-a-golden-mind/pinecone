(import scheme pinecone)

(define app
  (create-app
    port: 8080
    root-path: "./static"))

(app-add-route! app 'GET '("health")
  (lambda (req)
    (send-json (list (cons 'ok  #t)))))

(app-add-route! app 'GET '("users" ":id")
  (lambda (params)
    (let ((user-id (alist-ref 'id params)))
      (send-json (list  (cons 'id user-id))))))

(app-start! app)
