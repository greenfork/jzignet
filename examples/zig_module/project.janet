(declare-project
 :name "janet_exec"
 :dependencies ["https://github.com/greenfork/jzignet-module-template"])

(declare-executable
 :name "janet_exec"
 :entry "src/main.janet")
