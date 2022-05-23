schemaVersion: 2.0.0

fileContentTests:
  - name: "validate architecture"
    path: "/Files/got_arch.txt"
    expectedContents: ["%WANT_ARCH%"]
  - name: "validate os"
    path: "/Files/got_os.txt"
    expectedContents: ["%WANT_OS%"]
