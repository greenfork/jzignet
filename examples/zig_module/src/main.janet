(use zig_module)

(defn main [& args]
  (def st (init-struct))
  (pp (get-counter st))
  (add st 5)
  (pp (get-counter st)))
