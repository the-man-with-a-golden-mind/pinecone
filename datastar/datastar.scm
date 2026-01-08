(module datastar
  (
   ds-response
   ds-event

   ds-signals
   ds-elements
   ds-attributes
   ds-properties
   ds-classes
   ds-style
   ds-events
   ds-teleport
   ds-remove
   ds-replace
  )

(import scheme
        (chicken base)
        (chicken string)
        srfi-1
        srfi-13)

(define (ds-event name lines)
  (string-append
    "event: " name "\n"
    (string-join
      (map (lambda (l) (string-append "data: " l)) lines)
      "\n")
    "\n\n"))

(define (ds-response . chunks)
  (apply string-append chunks))

(define (ds-signals json)
  (ds-event "datastar-patch-signals"
            (list (string-append "signals " json))))

(define (ds-elements html)
  (ds-event "datastar-patch-elements"
            (list (string-append "elements " html))))

(define (ds-attributes selector json)
  (ds-event "datastar-patch-attributes"
            (list (string-append selector " " json))))

(define (ds-properties selector json)
  (ds-event "datastar-patch-properties"
            (list (string-append selector " " json))))

(define (ds-classes selector json)
  (ds-event "datastar-patch-classes"
            (list (string-append selector " " json))))

(define (ds-style selector json)
  (ds-event "datastar-patch-style"
            (list (string-append selector " " json))))

(define (ds-events selector json)
  (ds-event "datastar-patch-events"
            (list (string-append selector " " json))))

(define (ds-teleport from to)
  (ds-event "datastar-patch-teleport"
            (list (string-append from " " to))))

(define (ds-remove selector)
  (ds-event "datastar-patch-remove"
            (list selector)))

(define (ds-replace selector html)
  (ds-event "datastar-patch-replace"
            (list (string-append selector " " html))))
)
