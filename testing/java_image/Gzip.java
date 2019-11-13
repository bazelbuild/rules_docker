// Copyright 2017 The Bazel Authors. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package tools.gzip;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.zip.GZIPInputStream;
import java.util.zip.GZIPOutputStream;

public class Gzip {
    public static void main(String[] args) throws IOException {
        boolean decompress = args.length > 0 && args[0].equals("-d");
        InputStream in = decompress ? new GZIPInputStream(System.in, 8 * 1024) : System.in;
        OutputStream out = decompress ? System.out : new GZIPOutputStream(System.out);
        byte[] buffer = new byte[8 * 1024 * 1024];
        int n;
        while (-1 != (n = in.read(buffer))) {
            out.write(buffer, 0, n);
        }
        out.close();
        in.close();
    }
}
