(import scheme
        (chicken base)
        pinecone)

(print "Creating app...")
(define app (create-app port: 8080 root-path: "./static"))

(print "Adding route...")
(app-add-route! app 'GET '("test")
  (lambda (params)
    (print "HANDLER CALLED!")
    (send-json (list (cons 'message "it works!")))))

(print "Starting server...")
(app-start! app)
