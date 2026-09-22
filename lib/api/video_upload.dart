import 'package:http/http.dart' as http;

class VideoUpload {
  static const maxBytes = 100 * 1024 * 1024;
  http.Client? client;
  bool canceled = false;
  void cancel() {
    canceled = true;
    client?.close();
  }
}

class ProgressMultipartRequest extends http.MultipartRequest {
  ProgressMultipartRequest(super.method, super.url, this.progress);
  final void Function(double) progress;
  @override
  http.ByteStream finalize() {
    final stream = super.finalize();
    final total = contentLength;
    var sent = 0;
    return http.ByteStream(
      stream.map((bytes) {
        sent += bytes.length;
        progress(total == 0 ? 0 : sent / total);
        return bytes;
      }),
    );
  }
}
